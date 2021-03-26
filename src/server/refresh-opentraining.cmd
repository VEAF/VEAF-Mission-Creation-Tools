cd
@echo off
rem ----------------------------------------
rem the name of the server to update
rem defaults to an error
set SERVERNAME=%1
IF [%SERVERNAME%] == [] GOTO ErrorServerName
goto NoErrorServerName
:ErrorServerName
echo ERROR : the server name ("public" or "private") is a mandatory parameter
exit
:NoErrorServerName
echo refreshing OpenTraining missions for %SERVERNAME% server
set VEAF_FOLDER=C:\Users\veaf
rem set VEAF_FOLDER=d:\dev\_VEAF\VEAF-Open-Training-Mission\veaf
echo VEAF_FOLDER=%VEAF_FOLDER%
set MISSION_FOLDER=%VEAF_FOLDER%\Saved Games\DCS.missions\_VEAF_OpenTraining.%SERVERNAME%
echo MISSION_FOLDER=%MISSION_FOLDER%
del /Q /F "%MISSION_FOLDER%\*.*"

rem refresh Caucasus
set OPENTRAINING_FOLDER=%VEAF_FOLDER%\Saved Games\DCS.missions\VEAF_OpenTraining-Caucasus
echo OPENTRAINING_FOLDER=%OPENTRAINING_FOLDER%
FOR %%f IN ("%OPENTRAINING_FOLDER%\VEAF_OpenTraining_Caucasus*.miz") DO (
	echo Refreshing OpenTraining for server %SERVERNAME% based on %%f
	call veaf-tools injectall --quiet "%%f"	"%MISSION_FOLDER%\VEAF_OpenTraining_Caucasus-${version}.miz" "%OPENTRAINING_FOLDER%\weatherAndTime\versions.json"
)
rem refresh Syria
set OPENTRAINING_FOLDER=%VEAF_FOLDER%\Saved Games\DCS.missions\VEAF_OpenTraining-Syria
echo OPENTRAINING_FOLDER=%OPENTRAINING_FOLDER%
FOR %%f IN ("%OPENTRAINING_FOLDER%\VEAF_OpenTraining_Syria*.miz") DO (
	echo Refreshing OpenTraining for server %SERVERNAME% based on %%f
	call veaf-tools injectall --quiet "%%f" "%MISSION_FOLDER%\VEAF_OpenTraining_Syria-${version}.miz" "%OPENTRAINING_FOLDER%\weatherAndTime\versions.json"
)
