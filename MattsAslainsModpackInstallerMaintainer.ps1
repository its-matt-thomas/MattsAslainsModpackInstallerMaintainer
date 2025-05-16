Add-Type -AssemblyName System.Windows.Forms

# === HANDLE /Uninstall ===
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
                Write-Warning ("Failed to delete {0}: {1}" -f $file, $_.Exception.Message)
            }
        }
    }

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

# === INITIAL SETUP ===
$ScriptName = "MattsAslainsModpackInstallerMaintainer.ps1"
$Config = @{}
$WoWSPath = $null
$TaskAlreadyCreated = $false

$TempConfigPath = Join-Path $PSScriptRoot "wows_config.json"
if (Test-Path $TempConfigPath) {
    $Config = Get-Content $TempConfigPath | ConvertFrom-Json
    $WoWSPath = $Config.wows_path
    $TaskAlreadyCreated = $Config.ScheduledTaskCreated -eq $true
}

if (-not $WoWSPath) {
    $WoWSPath = Select-Folder "Select your World of Warships installation folder"
    if (-not $WoWSPath) {
        Write-Host "No folder selected. Exiting."
        exit 1
    }
    $Config.wows_path = $WoWSPath
}

$ConfigPath = Join-Path $WoWSPath "wows_config.json"
$TargetPath = Join-Path $WoWSPath $ScriptName

# === FIRST RUN ===
if (-not $TaskAlreadyCreated) {
    if ($MyInvocation.MyCommand.Path -ne $TargetPath) {
        Copy-Item -Path $MyInvocation.MyCommand.Path -Destination $TargetPath -Force
        Write-Host "Script copied to game directory: $TargetPath"
    }

    $frequencies = @{
        "1" = @{ label = "Hourly"; trigger = "/SC HOURLY /MO 1 /ST 00:00" }
        "2" = @{ label = "Every 6 Hours"; trigger = "/SC DAILY /MO 1 /ST 00:00 /RI 6" }
        "3" = @{ label = "Daily"; trigger = "/SC DAILY /MO 1 /ST 03:00" }
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

    $VbsPath = Join-Path $WoWSPath "MattsInvisibleLauncher.vbs"
    $psCmd = "powershell.exe -ExecutionPolicy Bypass -File `"$ScriptName`""
    $VbsContent = @"
Set objShell = CreateObject("Wscript.Shell")
objShell.Run ""$psCmd"", 0, False
"@
    Set-Content -Path $VbsPath -Value $VbsContent -Encoding ASCII

    $taskName = "Matt's 'Aslain's Modpack Installer' Maintainer"
    $cmd = "wscript.exe `"$VbsPath`""
    $taskCreate = schtasks /Create /F /TN "$taskName" /TR "$cmd" $trigger /RL HIGHEST /RU SYSTEM 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Scheduled task created: $taskName to run $($frequencies[$choice].label)"
        $Config.ScheduledTaskCreated = $true
    } else {
        Write-Warning "Failed to create scheduled task:"
        Write-Warning $taskCreate
        Write-Host "The script will still run manually, but scheduled automation will not occur."
        $Config.ScheduledTaskCreated = $false
    }

    $Config | ConvertTo-Json | Set-Content $ConfigPath

    if ($TempConfigPath -ne $ConfigPath -and (Test-Path $TempConfigPath)) {
        Remove-Item $TempConfigPath -Force
    }

    Start-Sleep -Seconds 1
    Remove-Item -LiteralPath $MyInvocation.MyCommand.Path -Force
    exit
}

# === REGULAR UPDATE RUN ===
$LogPath = Join-Path $WoWSPath "MattsAslainsModpackInstallerMaintainer.log"
$SetupLogPath = Join-Path $WoWSPath "_Aslains_Installer.log"
$TempFile = Join-Path $env:TEMP "Aslains_Modpack_Setup.exe"
$Url = "https://aslain.com/index.php?/topic/2020-download-%E2%98%85-world-of-warships-%E2%98%85-modpack/"

$CurrentVersion = ""
if (Test-Path $SetupLogPath) {
    $line = Get-Content $SetupLogPath -First 10 | Where-Object { $_ -like "*Original Setup EXE*" }
    if ($line -match "Aslains_WoWs_Modpack_Installer_v\.(\d+\.\d+\.\d+_\d+)\.exe") {
        $CurrentVersion = $Matches[1]
    }
}

try {
    $WebContent = Invoke-WebRequest -Uri $Url -UseBasicParsing
} catch {
    Add-Content -Path $LogPath -Value "[$(Get-Date)] Failed to fetch update page."
    exit 1
}

if ($WebContent.Content -match 'href="(https://dl\.aslain\.com/Aslains_WoWs_Modpack_Installer_v\.(\d+\.\d+\.\d+_\d+)\.exe)".*?>main download link<') {
    $DownloadUrl = $Matches[1]
    $LatestVersion = $Matches[2]
} else {
    Add-Content -Path $LogPath -Value "[$(Get-Date)] Could not find download link."
    exit 1
}

if ($WebContent.Content -match 'SHA-256.*?([a-fA-F0-9]{64})') {
    $ExpectedHash = $Matches[1].ToLower()
} else {
    Add-Content -Path $LogPath -Value "[$(Get-Date)] Could not find SHA256 hash."
    exit 1
}

if ($CurrentVersion -eq $LatestVersion) {
    Add-Content -Path $LogPath -Value "[$(Get-Date)] Already up to date ($CurrentVersion)"
    exit 0
}

try {
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $TempFile
} catch {
    Add-Content -Path $LogPath -Value "[$(Get-Date)] Failed to download installer."
    exit 1
}

$ActualHash = Get-FileHash $TempFile -Algorithm SHA256 | Select-Object -ExpandProperty Hash
if ($ActualHash.ToLower() -ne $ExpectedHash) {
    Add-Content -Path $LogPath -Value "[$(Get-Date)] Hash mismatch! Expected $ExpectedHash but got $ActualHash."
    Remove-Item $TempFile -Force
    exit 1
}

Start-Process -FilePath $TempFile -ArgumentList "/SP- /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /DIR=`"$WoWSPath`"" -Wait

Remove-Item $TempFile -Force
Add-Content -Path $LogPath -Value "[$(Get-Date)] Installed $LatestVersion successfully."
