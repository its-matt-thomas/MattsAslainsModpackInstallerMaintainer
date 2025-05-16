# MattsAslainsModpackInstallerMaintainer

A PowerShell tool to programmatically check for and install updates to Aslain's World of Warships Modpack.

---

## 📦 Overview

After manually installing Aslain's Modpack once, run this script to automate future updates.

It will silently check for new versions and install them using your existing modpack configuration.

---

## 🚀 First Run Setup

On first execution, the script will:

1. Prompt you to select your **World of Warships installation folder**.
2. Ask how often you want to check for updates:

Select how often the updater should check for updates:
1. Hourly
2. Every 6 Hours
3. Daily
Enter 1, 2, or 3:

3. Create a **scheduled task** named  
`Matt's 'Aslain's Modpack Installer' Maintainer`  
which runs invisibly and re-executes the script at the chosen interval.

4. Save your game path and task setup info to `wows_config.json` in the game folder.
5. Move itself into the game folder and **self-delete** from its original location.

---

## 🔄 Auto-Update Behavior

Once configured:

- The script checks the [Aslain Modpack page](https://aslain.com/index.php?/topic/2020-download-%E2%98%85-world-of-warships-%E2%98%85-modpack/) for a new version.
- If an update is available:
- Downloads the installer
- Verifies the SHA-256 checksum
- Installs silently using your previous configuration
- Logs are written to `MattsAslainsModpackInstallerMaintainer.log` in the game folder.

---

## 📁 Files Created in the Game Directory

- `MattsAslainsModpackInstallerMaintainer.ps1` – The main script  
- `MattsInvisibleLauncher.vbs` – Runs the script invisibly via Task Scheduler  
- `wows_config.json` – Stores path and task config  
- `MattsAslainsModpackInstallerMaintainer.log` – Logs update activity  

---

## 🧪 Manual Execution

To run manually:

```powershell
powershell.exe -ExecutionPolicy Bypass -File MattsAslainsModpackInstallerMaintainer.ps1
```
Or via batch file:
```batch
@echo off
powershell.exe -ExecutionPolicy Bypass -File MattsAslainsModpackInstallerMaintainer.ps1
```
🧹 Uninstallation
To remove all files and the scheduled task created by this script, run:
```powershell
powershell.exe MattsAslainsModpackInstallerMaintainer.ps1 /Uninstall
```
Or to override Execution Policy:
```powershell
powershell.exe -ExecutionPolicy Bypass -File MattsAslainsModpackInstallerMaintainer.ps1 /Uninstall
```
⚖ License
MIT License • Created by Matt_Thomas

---
