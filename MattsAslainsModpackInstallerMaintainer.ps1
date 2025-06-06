Add-Type -AssemblyName System.Windows.Forms

$WorkingDir = "C:\ProgramData\MattsMaintainer"
$LogPath    = Join-Path $WorkingDir "MattsAslainsModpackInstallerMaintainer.log"
$DebugLog   = Join-Path $WorkingDir "MattsMaintainer_Debug.log"
$TempFile   = Join-Path $WorkingDir "Aslains_Modpack_Setup.exe"

New-Item -ItemType Directory -Path $WorkingDir -Force | Out-Null
"[$(Get-Date)] Script started under $env:USERNAME ($env:COMPUTERNAME)" | Out-File -FilePath $DebugLog -Encoding UTF8 -Append

# === HANDLE /Uninstall ===
if ($args -contains "/Uninstall") {
    $WoWSPath = $PSScriptRoot
    $taskName = "Matt's 'Aslain's Modpack Installer' Maintainer"
    $filesToDelete = @("MattsAslainsModpackInstallerMaintainer.ps1", "wows_config.json")

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

    if (Test-Path $WorkingDir) {
        try {
            Remove-Item "$WorkingDir\*" -Force -ErrorAction Stop
            Remove-Item $WorkingDir -Force
            Write-Host "Removed $WorkingDir and all contents."
        } catch {
            Write-Warning ("Failed to clean up {0}: {1}" -f $WorkingDir, $_.Exception.Message)
        }
    }

    exit
}

# === HANDLE /Reset ===
if ($args -contains "/Reset") {
    Remove-Item "$PSScriptRoot\wows_config.json" -Force -ErrorAction SilentlyContinue
    Write-Host "Reset: Configuration file deleted."
}

$Debug = $args -contains "/Debug"

function Select-Folder($description) {
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = $description
    $dialog.ShowNewFolderButton = $false
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        return $dialog.SelectedPath
    }
    return $null
}

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

# Exit early if World of Warships is currently running
if (Get-Process -Name "WorldOfWarships64" -ErrorAction SilentlyContinue) {
    $logPath = Join-Path $GameDir "MattsAslainsModpackInstallerMaintainer.log"
    "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Game running (WorldOfWarships64.exe), skipping update." | Out-File -FilePath $logPath -Append -Encoding utf8
    exit
}

if (-not $TaskAlreadyCreated) {
    if ($MyInvocation.MyCommand.Path -ne $TargetPath) {
        Copy-Item -Path $MyInvocation.MyCommand.Path -Destination $TargetPath -Force
        Write-Host "Script copied to game directory: $TargetPath"
    }

    $frequencies = @{
        "1" = @{ label = "Hourly"; trigger = "/SC MINUTE /MO 60" }
        "2" = @{ label = "Every 6 Hours"; trigger = "/SC DAILY /MO 1 /ST 00:00 /RI 360" }
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

    $taskName = "Matt's 'Aslain's Modpack Installer' Maintainer"
    $escapedPath = '"' + $TargetPath + '"'
    $cmd = "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File $escapedPath"
    $triggerArgs = $trigger -split ' '
    $taskCreate = schtasks /Create /F /TN "$taskName" /TR "$cmd" @triggerArgs /RL HIGHEST /RU SYSTEM /NP 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Scheduled task created: $taskName to run $($frequencies[$choice].label)"
        $Config.ScheduledTaskCreated = $true
    } else {
        Write-Warning "Failed to create scheduled task:"
        Write-Warning ($taskCreate -join "`n")
        Write-Host "The script will still run manually, but scheduled automation will not occur."
        $Config.ScheduledTaskCreated = $false
    }

    $Config | ConvertTo-Json | Set-Content $ConfigPath

    if ($TempConfigPath -ne $ConfigPath -and (Test-Path $TempConfigPath)) {
        Remove-Item $TempConfigPath -Force
    }

    if (-not $Debug) {
        Start-Sleep -Seconds 1
        Remove-Item -LiteralPath $MyInvocation.MyCommand.Path -Force
    }
    exit
}

# --- Installer Execution ---
$SetupLogPath = Join-Path $WoWSPath "_Aslains_Installer.log"
$Url = "https://aslain.com/index.php?/topic/2020-download-%E2%98%85-world-of-warships-%E2%98%85-modpack/"
$CurrentVersion = ""

if (Test-Path $SetupLogPath) {
    $line = Get-Content $SetupLogPath -First 10 | Where-Object { $_ -like "*Original Setup EXE*" }
    if ($line -match "Aslains_WoWs_Modpack_Installer_v\.(\d+\.\d+\.\d+_\d+)\.exe") {
        $CurrentVersion = $Matches[1]
    }
}

try {
    $wc = New-Object System.Net.WebClient
    $WebContent = $wc.DownloadString($Url)
} catch {
    Add-Content -Path $LogPath -Value "[$(Get-Date)] Failed to fetch update page (WebClient): $($_.Exception.Message)"
    exit 1
}

# ✅ Fixed regex pattern for new HTML format
if ($WebContent -match 'href="(https://dl\.aslain\.com/Aslains_WoWs_Modpack_Installer_v\.(\d+\.\d+\.\d+_\d+)\.exe)"') {
    $DownloadUrl = [System.Uri]::EscapeUriString($Matches[1])
    $LatestVersion = $Matches[2]
} else {
    Add-Content -Path $LogPath -Value "[$(Get-Date)] Could not find download link."
    exit 1
}

if ($WebContent -match 'SHA-256.*?([a-fA-F0-9]{64})') {
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
    $wc.DownloadFile($DownloadUrl, $TempFile)
} catch {
    Add-Content -Path $LogPath -Value "[$(Get-Date)] WebClient failed. Attempting curl fallback..."
    try {
        & curl.exe -L -o $TempFile $DownloadUrl
    } catch {
        Add-Content -Path $LogPath -Value "[$(Get-Date)] curl fallback also failed: $($_.Exception.Message)"
        exit 1
    }
}

$ActualHash = Get-FileHash $TempFile -Algorithm SHA256 | Select-Object -ExpandProperty Hash
if ($ActualHash.ToLower() -ne $ExpectedHash) {
    Add-Content -Path $LogPath -Value "[$(Get-Date)] Hash mismatch! Expected $ExpectedHash but got $ActualHash."
    Remove-Item $TempFile -Force
    exit 1
}

Add-Content -Path $LogPath -Value "[$(Get-Date)] Starting installer..."

try {
$installerArgs = @(
    "/SP-"
    "/VERYSILENT"
    "/SUPPRESSMSGBOXES"
    "/NORESTART"
    "/DIR=`"$WoWSPath`""
)

$proc = Start-Process -FilePath $TempFile -ArgumentList $installerArgs -PassThru

} catch {
    Add-Content -Path $LogPath -Value "[$(Get-Date)] Failed to start installer: $($_.Exception.Message)"
    Remove-Item $TempFile -Force
    exit 1
}

if ($null -eq $proc) {
    Add-Content -Path $LogPath -Value "[$(Get-Date)] Start-Process did not return a process object."
    Remove-Item $TempFile -Force
    exit 1
}

if ($proc | Wait-Process -Timeout 300) {
    Add-Content -Path $LogPath -Value "[$(Get-Date)] Installer completed within timeout."
} else {
    if (Get-Process -Id $proc.Id -ErrorAction SilentlyContinue) {
        try {
            Stop-Process -Id $proc.Id -Force
            Add-Content -Path $LogPath -Value "[$(Get-Date)] Installer forcefully terminated after timeout."
        } catch {
            Add-Content -Path $LogPath -Value "[$(Get-Date)] Failed to kill process ID $($proc.Id): $($_.Exception.Message)"
        }
    } else {
        Add-Content -Path $LogPath -Value "[$(Get-Date)] Process ID $($proc.Id) already exited before Stop-Process."
    }
}

try {
    Add-Content -Path $LogPath -Value "[$(Get-Date)] Installer exited with code: $($proc.ExitCode)"
} catch {
    Add-Content -Path $LogPath -Value "[$(Get-Date)] Could not retrieve installer exit code: $($_.Exception.Message)"
}

try {
    Remove-Item $TempFile -Force
    Add-Content -Path $LogPath -Value "[$(Get-Date)] Temp file removed."
} catch {
    Add-Content -Path $LogPath -Value "[$(Get-Date)] Failed to remove temp file: $($_.Exception.Message)"
}

Add-Content -Path $LogPath -Value "[$(Get-Date)] Update complete: $CurrentVersion -> $LatestVersion"

exit 0
