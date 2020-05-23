@echo off
echo -
echo -----------------------------------------------------
echo  Building Documentation site
echo -----------------------------------------------------
echo.

rem -- default options values
echo This script can use these environment variables to customize its behavior :
echo ----------------------------------------
echo HUGO (a string) points to the hugo executable
echo defaults "hugo", so it needs to be in the path
IF [%HUGO%] == [] GOTO DefineDefaultHUGO
goto DontDefineDefaultHUGO
:DefineDefaultHUGO
set HUGO=hugo
:DontDefineDefaultHUGO
echo current value is "%HUGO%"
echo ----------------------------------------

rem -- preparing the folders
echo preparing the folders
rd /s /q .\docs
mkdir .\docs

rem -- building the documentation site
echo building the documentation site
pushd documentation
%HUGO% -d ..\docs
popd

echo.
echo _________________________
echo  Documentation generated
pause