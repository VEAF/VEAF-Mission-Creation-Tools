@echo off 

echo This script should be ran in an elevated shell (a.k.a. an admin shell)
pause

echo We will now install git if you don't stop the script after this pause
pause
choco install -y git
echo stop the script if this wasn't successful
pause

echo We will now install 7zip if you don't stop the script after this pause
pause
choco install -y 7zip.commandline
echo stop the script if this wasn't successful
pause

echo We will now install lua if you don't stop the script after this pause
pause
choco install -y Lua
echo stop the script if this wasn't successful
pause

echo We will now install nodejs and npm if you don't stop the script after this pause
pause
choco install -y nodejs
echo stop the script if this wasn't successful
pause

echo If you want to install the optionals, you can start the install-optionals.cmd script
pause
