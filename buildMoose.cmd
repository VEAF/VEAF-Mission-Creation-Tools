rem MOOSE_PATH must be set to your local MOOSE github repository clone
@echo off
set MOOSE_PATH=..\Moose
echo.
echo ----------------------------------------
echo building Moose in %MOOSE_PATH%
echo ----------------------------------------
echo.

echo ----------------------------------------
echo LUA (a string) points to the lua executable
echo defaults "lua", so it needs to be in the path
IF [%LUA%] == [] GOTO DefineDefaultLUA
goto DontDefineDefaultLUA
:DefineDefaultLUA
set LUA=lua
:DontDefineDefaultLUA
echo current value is "%LUA%"
echo ----------------------------------------

for /f "delims=" %%A in ('git rev-parse --verify HEAD -C"%MOOSE_PATH%"') do set "MOOSE_GITHASH=%%A"
echo MOOSE_GITHASH=[%MOOSE_GITHASH%]
%LUA% "%MOOSE_PATH%/Moose Setup/Moose_Create.lua" S %MOOSE_GITHASH% "%MOOSE_PATH%/Moose Development/Moose" "%MOOSE_PATH%/Moose Setup" "./scripts/community"
