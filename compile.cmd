@echo off
set ARTEFACT_NAME=veaf-scripts
echo.
echo ----------------------------------------
echo building %ARTEFACT_NAME%
echo ----------------------------------------
echo.

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
echo VERSION_TAG can be set to a specific value that will be appended to the version number
echo defaults to not set
IF [%VERSION_TAG%] == [] GOTO DefineDefaultVERSION_TAG
goto DontDefineDefaultVERSION_TAG
:DefineDefaultVERSION_TAG
set VERSION_TAG=
:DontDefineDefaultVERSION_TAG
echo current value is "%VERSION_TAG%"

echo ----------------------------------------
echo DEVELOPMENT_VERSION_FLAG if set to "true", will configure the artefact with a specific development environment behavior
echo defaults to "false"
IF [%DEVELOPMENT_VERSION_FLAG%] == [] GOTO DefineDefaultDEVELOPMENT_VERSION_FLAG
goto DontDefineDefaultDEVELOPMENT_VERSION_FLAG
:DefineDefaultDEVELOPMENT_VERSION_FLAG
set DEVELOPMENT_VERSION_FLAG=false
:DontDefineDefaultDEVELOPMENT_VERSION_FLAG
echo current value is "%DEVELOPMENT_VERSION_FLAG%"

echo ----------------------------------------
echo QUIET_FLAG if set to "true", will not output anything while compiling the artefact
echo defaults to "false"
IF [%QUIET_FLAG%] == [] GOTO DefineDefaultQUIET_FLAG
goto DontDefineDefaultQUIET_FLAG
:DefineDefaultQUIET_FLAG
set QUIET_FLAG=false
:DontDefineDefaultQUIET_FLAG
echo current value is "%QUIET_FLAG%"

echo ----------------------------------------
echo VERBOSE_LOG_FLAG if set to "true", will configure the artefact with tracing enabled (meaning that, when run, it will log a lot of details in the dcs log file)
echo defaults to "false"
IF [%VERBOSE_LOG_FLAG%] == [] GOTO DefineDefaultVERBOSE_LOG_FLAG
goto DontDefineDefaultVERBOSE_LOG_FLAG
:DefineDefaultVERBOSE_LOG_FLAG
set VERBOSE_LOG_FLAG=false
:DontDefineDefaultVERBOSE_LOG_FLAG
echo current value is "%VERBOSE_LOG_FLAG%"

echo ----------------------------------------
echo SECURITY_DISABLED_FLAG if set to "true", will configure the artefact with security disabled (meaning that no password is ever required)
echo defaults to "false"
IF [%SECURITY_DISABLED_FLAG%] == [] GOTO DefineDefaultSECURITY_DISABLED_FLAG
goto DontDefineDefaultSECURITY_DISABLED_FLAG
:DefineDefaultSECURITY_DISABLED_FLAG
set SECURITY_DISABLED_FLAG=false
:DontDefineDefaultSECURITY_DISABLED_FLAG
echo current value is "%SECURITY_DISABLED_FLAG%"

set DEVELOPMENT_VERSION_PARAM=
if "%DEVELOPMENT_VERSION_FLAG%"=="true" set DEVELOPMENT_VERSION_PARAM=-DevelopmentVersion

set QUIET_PARAM=
if "%QUIET_FLAG%"=="true" set QUIET_PARAM=-Quiet

set VERBOSE_PARAM=
if "%VERBOSE_FLAG%"=="true" set VERBOSE_PARAM=-KeepLogging

set SECURITY_DISABLED_PARAM=
if "%SECURITY_DISABLED_FLAG%"=="true" set SECURITY_DISABLED_PARAM=-DisableSecurity

powershell -file compile.ps1 -ArtefactName "%ARTEFACT_NAME%" -VersionTag "%VERSION_TAG%" %DEVELOPMENT_VERSION_PARAM% %VERBOSE_PARAM% %SECURITY_DISABLED_PARAM% %QUIET_PARAM%

IF [%NOPAUSE%] == [true] GOTO EndOfFile
pause
:EndOfFile
