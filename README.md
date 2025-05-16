# MattsAslainsModpackInstallerMaintainer

A tool to automatically check for and silently install updates to Aslain’s World of Warships Modpack.

---

## 🚀 How It Works

After installing Aslain’s Modpack manually, run this tool once. On first run, it will:

1. Prompt you to select your `World_of_Warships` directory.
2. Ask how frequently to check for updates:
   ```
   Select how often the updater should check for updates:
   1) Hourly
   2) Every 6 Hours
   3) Daily
   Enter 1, 2, or 3:
   ```
3. Create a scheduled task named:

   ```
   Matt's 'Aslain's Modpack Installer' Maintainer
   ```

   This task runs invisibly as SYSTEM on your chosen schedule.
4. Save your game path and schedule config to `wows_config.json` in the game folder.
5. Move itself into the game folder and delete the original copy.

---

## 🔄 Auto-Update Behavior

Once configured:

- The script checks the [Aslain Modpack page](https://aslain.com/index.php?/topic/2020-download-%E2%98%85-world-of-warships-%E2%98%85-modpack/) for updates.
- If a new version is available:
  - It downloads the installer
  - Verifies the SHA-256 checksum
  - Installs silently using your previous configuration
- Logs are saved to `MattsAslainsModpackInstallerMaintainer.log` in the game folder.

---

## ⏱ Update Frequency Options

| Option | Schedule                            |
|--------|-------------------------------------|
| 1      | Every 60 minutes (`/SC MINUTE /MO 60`) |
| 2      | Every 6 hours from midnight (`/RI 360`) |
| 3      | Once daily at 03:00 AM              |

---

## 📁 Files Created in the Game Directory

- `MattsAslainsModpackInstallerMaintainer.ps1` – Self-copied here on first run; executes update logic  
- `MattsInvisibleLauncher.vbs` – Auto-generated; used by Task Scheduler to run invisibly  
- `wows_config.json` – Stores WoWS path and schedule config  
- `MattsAslainsModpackInstallerMaintainer.log` – Logs all update actions, hash verifications, and errors  

---

## 🛠 Manual Execution

To run the updater manually from the game directory:

```powershell
powershell.exe -ExecutionPolicy Bypass -File MattsAslainsModpackInstallerMaintainer.ps1
```

Or via the included batch file:

```bat
@echo off
powershell.exe -ExecutionPolicy Bypass -File MattsAslainsModpackInstallerMaintainer.ps1
```

---

To **uninstall the updater** and remove its scheduled task:

```powershell
powershell.exe -File MattsAslainsModpackInstallerMaintainer.ps1 /Uninstall
```

This removes:
- The script
- The `.vbs` launcher
- The config and log files
- The scheduled task

---

## 📄 License

MIT License – Created by Matt_Thomas
