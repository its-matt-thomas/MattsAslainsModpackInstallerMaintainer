Add-Type -AssemblyName System.Windows.Forms

# Handle /Uninstall
if ($args -contains "/Uninstall") {
    $WoWSPath = $PSScriptRoot
    $taskName = "Matt's 'Aslain's Modpack Installer' Maintainer"
    $filesToDelete = @(
        "MattsAslainsModpackInstallerMaintainer.ps1",
        "MattsInvisibleLauncher.vbs",
        "MattsAslainsModpackInstallerMaintainer.log",
        "wows_config.json"
    )
    foreach ($file in $filesToDelete) {
        $fullPath = Join-Path $WoWSPath $file
        if (Test-Path $fullPath) {
            try {
                Remove-Item $fullPath -Force -ErrorAction Stop
                Write-Host "Deleted $file"
            } catch {
                Write-Warning "Failed to delete $file: $($_.Exception.Message)"
            }
        }
    }

    # Delete scheduled task
    try {
        schtasks /Delete /F /TN "$taskName" | Out-Null
        Write-Host "Scheduled task '$taskName' removed."
    } catch {
        Write-Warning "Could not delete scheduled task: $_"
    }

    exit
}

function Select-Folder($description) {
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = $description
    $dialog.ShowNewFolderButton = $false
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        return $dialog.SelectedPath
    }
    return $null
}

# === CONFIG SETUP ===
$ScriptName = "MattsAslainsModpackInstallerMaintainer.ps1"
$ConfigPath = Join-Path $WoWSPath "wows_config.json"
$Config = @{}

if (Test-Path $ConfigPath) {
    $Config = Get-Content $ConfigPath | ConvertFrom-Json
    $WoWSPath = $Config.wows_path
    $TaskAlreadyCreated = $Config.ScheduledTaskCreated -eq $true
} else {
    $WoWSPath = $null
    $TaskAlreadyCreated = $false
}

# === FIRST TIME SETUP ===
if (-not $WoWSPath) {
    $WoWSPath = Select-Folder "Select your World of Warships installation folder"
    if (-not $WoWSPath) {
        Write-Host "No folder selected. Exiting."
        exit 1
    }
    $Config.wows_path = $WoWSPath
}

$TargetPath = Join-Path $WoWSPath $ScriptName

if (-not $TaskAlreadyCreated) {
    # Copy self to WoWS folder if not already there
    if ($MyInvocation.MyCommand.Path -ne $TargetPath) {
        Copy-Item -Path $MyInvocation.MyCommand.Path -Destination $TargetPath -Force
        Write-Host "Script copied to game directory: $TargetPath"
    }

    # Prompt for schedule
    $frequencies = @{
        "1" = @{ label = "Hourly"; trigger = "/SC HOURLY" }
        "2" = @{ label = "Every 6 Hours"; trigger = "/SC DAILY /RI 1 /MO 1 /ST 00:00 /DU 06:00" }
        "3" = @{ label = "Daily"; trigger = "/SC DAILY" }
    }

    Write-Host "`nSelect how often the updater should check for updates:"
    Write-Host "1) Hourly"
    Write-Host "2) Every 6 Hours"
    Write-Host "3) Daily"
    $choice = Read-Host "Enter 1, 2, or 3"
    $trigger = $frequencies[$choice].trigger
    if (-not $trigger) {
        Write-Error "Invalid selection. Exiting."
        exit 1
    }

    # Create invisible VBS launcher
    $VbsPath = Join-Path $WoWSPath "MattsInvisibleLauncher.vbs"
    $psCmd = "powershell.exe -ExecutionPolicy Bypass -File `"$ScriptName`""
    $VbsContent = @"
Set objShell = CreateObject("Wscript.Shell")
objShell.Run ""$psCmd"", 0, False
"@
    Set-Content -Path $VbsPath -Value $VbsContent -Encoding ASCII

    # Register scheduled task
    $taskName = "Matt's 'Aslain's Modpack Installer' Maintainer"
    $cmd = "wscript.exe `"$VbsPath`""
    schtasks /Create /F /TN "$taskName" /TR "$cmd" $trigger /RL HIGHEST /RU SYSTEM | Out-Null

    Write-Host "Scheduled task created: $taskName to run $($frequencies[$choice].label)"

    # Update config and save
    $Config.ScheduledTaskCreated = $true
    $Config | ConvertTo-Json | Set-Content $ConfigPath

    # Self-delete after first run
    Start-Sleep -Seconds 1
    Remove-Item -LiteralPath $MyInvocation.MyCommand.Path -Force
    exit
}

# === REGULAR RUN ===
$LogPath = Join-Path $WoWSPath "MattsAslainsModpackInstallerMaintainer.log"
$SetupLogPath = Join-Path $WoWSPath "_Aslains_Installer.log"
$TempFile = Join-Path $env:TEMP "Aslains_Modpack_Setup.exe"
$Url = "https://aslain.com/index.php?/topic/2020-download-%E2%98%85-world-of-warships-%E2%98%85-modpack/"

# Detect current version from original log
$CurrentVersion = ""
if (Test-Path $SetupLogPath) {
    $line = Get-Content $SetupLogPath -First 10 | Where-Object { $_ -like "*Original Setup EXE*" }
    if ($line -match "Aslains_WoWs_Modpack_Installer_v\.(\d+\.\d+\.\d+_\d+)\.exe") {
        $CurrentVersion = $Matches[1]
    }
}

# Download update page
try {
    $WebContent = Invoke-WebRequest -Uri $Url -UseBasicParsing
} catch {
    Add-Content -Path $LogPath -Value "[$(Get-Date)] Failed to fetch update page."
    exit 1
}

# Parse latest version and download URL
if ($WebContent.Content -match 'href="(https://dl\.aslain\.com/Aslains_WoWs_Modpack_Installer_v\.(\d+\.\d+\.\d+_\d+)\.exe)".*?>main download link<') {
    $DownloadUrl = $Matches[1]
    $LatestVersion = $Matches[2]
} else {
    Add-Content -Path $LogPath -Value "[$(Get-Date)] Could not find download link."
    exit 1
}

# Get SHA-256 hash
if ($WebContent.Content -match 'SHA-256.*?([a-fA-F0-9]{64})') {
    $ExpectedHash = $Matches[1].ToLower()
} else {
    Add-Content -Path $LogPath -Value "[$(Get-Date)] Could not find SHA256 hash."
    exit 1
}

# Skip if already installed
if ($CurrentVersion -eq $LatestVersion) {
    exit 0
}

# Download new installer
try {
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $TempFile
} catch {
    Add-Content -Path $LogPath -Value "[$(Get-Date)] Failed to download installer."
    exit 1
}

# Verify hash
$ActualHash = Get-FileHash $TempFile -Algorithm SHA256 | Select-Object -ExpandProperty Hash
if ($ActualHash.ToLower() -ne $ExpectedHash) {
    Add-Content -Path $LogPath -Value "[$(Get-Date)] Hash mismatch! Aborting install."
    Remove-Item $TempFile -Force
    exit 1
}

# Run installer silently
Start-Process -FilePath $TempFile -ArgumentList "/SP- /VERYSILENT /NORESTART /DIR=`"$WoWSPath`"" -Wait

# Cleanup
Remove-Item $TempFile -Force
Add-Content -Path $LogPath -Value "[$(Get-Date)] Installed $LatestVersion successfully."
