@echo off 

echo This script should be ran in an elevated shell (a.k.a. an admin shell)
pause

echo We will install Chocolatey (https://chocolatey.org) if you don't stop the script after this pause
pause
powershell.exe -ExecutionPolicy Bypass -File install-chocolatey.ps1
echo.
echo Please close and restart your elevated shell, then run install-requirements.cmd
echo.
pause
