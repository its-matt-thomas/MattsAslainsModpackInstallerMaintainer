@echo off
:: Check for admin rights
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting admin privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: Already elevated, run script
powershell.exe -ExecutionPolicy Bypass -File "%~dp0MattsAslainsModpackInstallerMaintainer.ps1"
