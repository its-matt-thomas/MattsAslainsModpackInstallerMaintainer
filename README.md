# MattsAslainsModpackInstallerMaintainer

A PowerShell utility that checks Aslain's World of Warships modpack page for updates and silently installs new versions when available.

## Features

- Monitors [Aslain's Modpack](https://aslain.com/index.php?/topic/2020-download-%E2%98%85-world-of-warships-%E2%98%85-modpack/)
- Parses latest version and official SHA256 hash
- Compares against installed version (via `_Aslains_Installer.log`)
- Automatically downloads, verifies hash, and installs silently
- Scheduled task runs under `SYSTEM`, no user login required
- Logs actions to:  
  - `C:\ProgramData\MattsMaintainer\MattsAslainsModpackInstallerMaintainer.log`  
  - `C:\ProgramData\MattsMaintainer\MattsMaintainer_Debug.log`

---

## First-Time Setup

After installing Aslain’s Modpack manually:

1. Run `PS_Execution_Bypass.bat`
2. Select your World of Warships game folder
3. Choose how often to check for updates:

   ```
   Select how often the updater should check for updates:
   1) Hourly
   2) Every 6 Hours
   3) Daily
   Enter 1, 2, or 3:
   ```
4. A scheduled task will be created to re-run the script silently using `powershell.exe`

The script self-destructs from your Downloads folder and copies itself to your game directory.  
A `wows_config.json` file is generated to remember your choices.

---

## Files Created

- Game directory:
- `MattsAslainsModpackInstallerMaintainer.ps1`
- `wows_config.json`
- System folder:
- `C:\ProgramData\MattsMaintainer\...` (temp files, logs)
- Scheduled Task:
- **Matt's 'Aslain's Modpack Installer' Maintainer**

---

## Manual Execution

You can run the script manually at any time:

```powershell
powershell.exe -ExecutionPolicy Bypass -File "MattsAslainsModpackInstallerMaintainer.ps1"
```
Optional Arguments
Argument	Function
`/Uninstall`	Removes all created files and the task
`/Reset`	Deletes wows_config.json and re-prompts
`/Debug`	Enables extra logging and disables cleanup

Example Output
Sample log in MattsAslainsModpackInstallerMaintainer.log:
```
[05/16/2025 10:32:42] Installer exited with code: 0
[05/16/2025 10:32:42] Temp file removed.
[05/16/2025 10:32:42] Update complete: 14.4.0_01 -> 14.4.0_02
```

## 🔄 Auto-Update Behavior

Once configured:

- The script checks the [Aslain Modpack page](https://aslain.com/index.php?/topic/2020-download-%E2%98%85-world-of-warships-%E2%98%85-modpack/) for updates.
- If a new version is available:
  - It downloads the installer
  - Verifies the SHA-256 checksum
  - Installs silently using your previous configuration
- Logs are saved to:  
  - `C:\ProgramData\MattsMaintainer\MattsAslainsModpackInstallerMaintainer.log`  
  - `C:\ProgramData\MattsMaintainer\MattsMaintainer_Debug.log`

## ⏱ Update Frequency Options

| Option | Schedule                               |
|--------|----------------------------------------|
| 1      | Every 60 minutes (`/SC MINUTE /MO 60`) |
| 2      | Every 6 hours from midnight (`/RI 360`) |
| 3      | Once daily at 03:00 AM                 |

## 📁 Files Created

**In your game folder:**
- `MattsAslainsModpackInstallerMaintainer.ps1` – Self-copied on first run; executes update logic
- `wows_config.json` – Stores WoWS path and schedule configuration

**In system config:**
- `C:\ProgramData\MattsMaintainer\Aslains_Modpack_Setup.exe` – Temporary downloaded installer
- `C:\ProgramData\MattsMaintainer\MattsAslainsModpackInstallerMaintainer.log` – Main update log
- `C:\ProgramData\MattsMaintainer\MattsMaintainer_Debug.log` – Script debug log

**Scheduled Task:**
- `Matt's 'Aslain's Modpack Installer' Maintainer` – Runs silently as SYSTEM



## 🛠 Manual Execution

To run the updater manually from the game directory:

```powershell
powershell.exe -ExecutionPolicy Bypass -File MattsAslainsModpackInstallerMaintainer.ps1
```
To uninstall the updater and remove all files and the scheduled task:
```powershell
powershell.exe -File MattsAslainsModpackInstallerMaintainer.ps1 /Uninstall
```

License
MIT, but use at your own risk. This script is unaffiliated with Aslain.
