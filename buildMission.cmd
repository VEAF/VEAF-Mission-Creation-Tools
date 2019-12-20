@echo off
set MISSION_NAME=Test
set MISSION_PATH=..\VEAF-Mission
set SECURITY_DISABLED_FLAG=true
set VERBOSE_LOG_FLAG=true

echo ------------------------------
echo building Test 
echo ------------------------------

rem -- prepare the folders
echo preparing the folders
rd /s /q .\build  
mkdir .\build  
mkdir .\build\tempsrc  

rem -- default options values
echo options values :
IF [%VERBOSE_LOG_FLAG%] == [] GOTO DefineDefaultVERBOSE_LOG_FLAG
goto DontDefineDefaultVERBOSE_LOG_FLAG
:DefineDefaultVERBOSE_LOG_FLAG
set VERBOSE_LOG_FLAG=false
:DontDefineDefaultVERBOSE_LOG_FLAG
echo VERBOSE_LOG_FLAG = %VERBOSE_LOG_FLAG%

IF [%SECURITY_DISABLED_FLAG%] == [] GOTO DefineDefaultSECURITY_DISABLED_FLAG
goto DontDefineDefaultSECURITY_DISABLED_FLAG
:DefineDefaultSECURITY_DISABLED_FLAG
set SECURITY_DISABLED_FLAG=false
:DontDefineDefaultSECURITY_DISABLED_FLAG
echo SECURITY_DISABLED_FLAG = %SECURITY_DISABLED_FLAG%

IF [%MISSION_FILE_SUFFIX%] == [] GOTO DefineDefaultMISSION_FILE_SUFFIX
goto DontDefineDefaultMISSION_FILE_SUFFIX
:DefineDefaultMISSION_FILE_SUFFIX
set MISSION_FILE_SUFFIX=%date:~-4,4%%date:~-7,2%%date:~-10,2%
:DontDefineDefaultMISSION_FILE_SUFFIX
set MISSION_FILE=.\build\%MISSION_NAME%_%MISSION_FILE_SUFFIX%
echo MISSION_FILE = %MISSION_FILE%.miz

IF [%SEVENZIP%] == [] GOTO DefineDefaultSEVENZIP
goto DontDefineDefaultSEVENZIP
:DefineDefaultSEVENZIP
set SEVENZIP=7za
:DontDefineDefaultSEVENZIP
echo SEVENZIP = %SEVENZIP%

echo building the mission
rem -- copy all the source mission files and mission-specific scripts
xcopy /y /e %MISSION_PATH%\src\mission .\build\tempsrc\ >nul 2>&1
copy %MISSION_PATH%\src\scripts\*.lua .\build\tempsrc\l10n\Default  >nul 2>&1

rem -- copy the documentation images to the kneeboard
xcopy /y /e %MISSION_PATH%\doc\*.png .\build\tempsrc\KNEEBOARD\IMAGES >nul 2>&1

rem -- copy all the community scripts
copy %MISSION_PATH%\src\scripts\community\*.lua .\build\tempsrc\l10n\Default  >nul 2>&1
copy .\scripts\community\*.lua .\build\tempsrc\l10n\Default  >nul 2>&1

rem -- copy all the common scripts
copy .\scripts\veaf\*.lua .\build\tempsrc\l10n\Default  >nul 2>&1

rem -- set the flags in the scripts according to the options
powershell -Command "(gc .\build\tempsrc\l10n\Default\veaf.lua) -replace 'veaf.Development = false', 'veaf.Development = %VERBOSE_LOG_FLAG%' | sc .\build\tempsrc\l10n\Default\veaf.lua" >nul 2>&1
powershell -Command "(gc .\build\tempsrc\l10n\Default\veaf.lua) -replace 'veaf.SecurityDisabled = false', 'veaf.SecurityDisabled = %SECURITY_DISABLED_FLAG%' | sc .\build\tempsrc\l10n\Default\veaf.lua" >nul 2>&1

rem -- compile the mission
"%SEVENZIP%" a -r -tzip %MISSION_FILE%.miz .\build\tempsrc\* -mem=AES256 >nul 2>&1

rem -- cleanup
rd /s /q .\build\tempsrc  

rem -- done !
echo Built %MISSION_FILE%.miz
