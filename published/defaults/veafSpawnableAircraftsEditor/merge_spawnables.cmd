@echo off

rem -- default options values
echo This script can use these environment variables to customize its behavior :
echo ----------------------------------------
echo NOPAUSE if set to "true", will not pause at the end of the script (useful to chain calls to this script)
echo defaults to "false"
IF [%NOPAUSE%] == [] GOTO DefineDefaultNOPAUSE
goto DontDefineDefaultNOPAUSE
:DefineDefaultNOPAUSE
set NOPAUSE=false
:DontDefineDefaultNOPAUSE
echo current value is "%NOPAUSE%"

echo ----------------------------------------
echo LUA_SCRIPTS_DEBUG_PARAMETER can be set to "-debug" or "-trace" (or not set) ; this will be passed to the lua helper scripts (e.g. veafMissionRadioPresetsEditor and veafMissionNormalizer)
echo defaults to not set
IF [%LUA_SCRIPTS_DEBUG_PARAMETER%] == [] GOTO DefineDefaultLUA_SCRIPTS_DEBUG_PARAMETER
goto DontDefineDefaultLUA_SCRIPTS_DEBUG_PARAMETER
:DefineDefaultLUA_SCRIPTS_DEBUG_PARAMETER
set LUA_SCRIPTS_DEBUG_PARAMETER=
:DontDefineDefaultLUA_SCRIPTS_DEBUG_PARAMETER
echo current value is "%LUA_SCRIPTS_DEBUG_PARAMETER%"

echo ----------------------------------------
echo SEVENZIP (a string) points to the 7za executable
echo defaults "7za", so it needs to be in the path
IF ["%SEVENZIP%"] == [""] GOTO DefineDefaultSEVENZIP
goto DontDefineDefaultSEVENZIP
:DefineDefaultSEVENZIP
set SEVENZIP=7za
:DontDefineDefaultSEVENZIP
echo current value is "%SEVENZIP%"

echo ----------------------------------------
echo LUA (a string) points to the lua executable
echo defaults "lua", so it needs to be in the path
IF ["%LUA%"] == [""] GOTO DefineDefaultLUA
goto DontDefineDefaultLUA
:DefineDefaultLUA
set LUA=lua
:DontDefineDefaultLUA
echo current value is "%LUA%"

echo.
echo Adding or replacing spawnable groups (named "veafSpawn-XXX") from spawnables.miz to settings.lua

echo.
echo prepare the folders
rd /s /q .\build >nul 2>&1
mkdir .\build >nul 2>&1

rem extracting MIZ files
echo extracting MIZ files
set MISSION_PATH=%cd%\src\mission
"%SEVENZIP%" x -y spawnables.miz -o".\build\"

rem -- run the spawnable aircrafts editor
pushd ..\..\\scripts\veaf
"%LUA%" veafSpawnableAircraftsEditor.lua ..\..\defaults\veafSpawnableAircraftsEditor\build ..\..\defaults\veafSpawnableAircraftsEditor\settings.lua %LUA_SCRIPTS_DEBUG_PARAMETER% -import -namefilter "veafSpawn-.+"
popd

rd /s /q .\build >nul 2>&1

echo.
echo ----------------------------------------
rem -- done !
echo Done !
echo ----------------------------------------
echo.

IF [%NOPAUSE%] == [true] GOTO EndOfFile
pause
:EndOfFile
