@echo off

FOR %%f IN (*.miz) DO (
	echo Refreshing OpenTraining based on %%f
	call veaf-tools injectall %%f "missions\VEAF_OpenTraining_Caucasus-${version}.miz" "weatherAndTime\versions.json"
)
echo Copying files to destination folders
copy missions\*.miz "C:\Users\veaf\Saved Games\DCS.missions\VEAF_OpenTraining\"
pause