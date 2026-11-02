@echo off
setlocal
title OpenMultiSeat
:: usbipd bind needs administrator privileges.
net session >nul 2>&1
if errorlevel 1 (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b 0
)
where node >nul 2>&1 || (echo Node.js 18+ is required: https://nodejs.org & pause & exit /b 1)
if not exist "%~dp0node_modules\express" (pushd "%~dp0" & call npm install --no-fund --no-audit & popd)
start "" http://localhost:3100
node "%~dp0app.js"
endlocal
