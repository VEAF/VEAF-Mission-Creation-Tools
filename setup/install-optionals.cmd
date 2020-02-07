@echo off 

echo This script should be ran in an elevated shell (a.k.a. an admin shell)
pause

echo We will now install notepad++ if you don't stop the script after this pause
pause
choco install -y notepadplusplus 
echo stop the script if this wasn't successful
pause

echo We will now install conemu if you don't stop the script after this pause
pause
choco install -y ConEmu 
echo stop the script if this wasn't successful
pause

echo We will now install Visual Studio Code if you don't stop the script after this pause
pause
choco install -y vscode
echo stop the script if this wasn't successful
pause
