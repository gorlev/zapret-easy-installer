@echo off
rem Zapret Easy Installer for Windows - launcher
rem https://github.com/gorlev/zapret-easy-installer
rem
rem Double-click this file. It starts install_zapret.ps1 (from the same folder if present,
rem otherwise the latest version from GitHub). The PowerShell script asks for
rem administrator rights by itself.

setlocal
set "PS1=%~dp0install_zapret.ps1"
set "URL=https://raw.githubusercontent.com/gorlev/zapret-easy-installer/main/install_zapret.ps1"

if exist "%PS1%" (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%" %*
) else (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12; irm '%URL%' | iex"
)

if errorlevel 1 (
    echo.
    echo The installer could not be started. Check your internet connection and try again.
    pause
)
endlocal
