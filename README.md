# MattsAslainsModpackInstallerMaintainer

A PowerShell tool to programmatically check for and install updates to Aslain's World of Warships Modpack.

## Overview

After installing Aslain's Modpack manually once, run this tool to automate future updates.  
It will silently check for new versions and install them using your existing modpack configuration.

## First Run Behavior

On first execution, the script will:

1. Prompt you to select your **World of Warships installation folder**.
2. Ask how often you want to check for updates:

Select how often the updater should check for updates:
1. Hourly
2. Every 6 Hours
3. Daily
Enter 1, 2, or 3:


3. Create a scheduled task named:  
`Matt's 'Aslain's Modpack Installer' Maintainer`  
which runs invisibly and re-executes the script at the chosen interval.

4. Save your selected game path and task setup in `wows_config.json` (placed in the game directory).

5. Move itself into the game folder and **self-delete** from its original location.

## Silent Auto-Update Behavior

Once configured:

- The script will silently check the [Aslain Modpack download page](https://aslain.com/index.php?/topic/2020-download-%E2%98%85-world-of-warships-%E2%98%85-modpack/) for the latest version.
- If an update is found, it will:
- Download the new installer
- Verify its SHA-256 hash
- Silently install using the previously used game/modpack configuration
- Actions and errors are logged to `MattsAslainsModpackInstallerMaintainer.log` in the game folder.

## Files Created in the Game Directory

- `MattsAslainsModpackInstallerMaintainer.ps1` — The update script  
- `MattsInvisibleLauncher.vbs` — Used by the scheduled task to run invisibly  
- `wows_config.json` — Stores your game path and task setup status  
- `MattsAslainsModpackInstallerMaintainer.log` — Log of update results and errors

## Manual Use

For manual execution, you can run:

```powershell
powershell.exe -ExecutionPolicy Bypass -File MattsAslainsModpackInstallerMaintainer.ps1
