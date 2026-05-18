@echo off
setlocal

rem ---------------------------------------------------------------------------
rem  VEAF Mission Build Script — adapt to your mission
rem
rem  Place this file at the root of your mission folder, next to:
rem    veaf-tools-updater.exe   (downloaded from the VEAF release)
rem    veaf-tools.exe           (downloaded by the updater at run time)
rem    src\                     (your source files)
rem      mission\               (DCS mission data extracted from the .miz)
rem      scripts\               (your Lua scripts, e.g. missionConfig.lua)
rem      presets.yaml           (radio preset configuration, optional)
rem      waypoints.yaml         (waypoint configuration, optional)
rem      aircraft-templates.yaml (aircraft group templates, optional)
rem      missions.yaml          (weather/time variant configuration, optional)
rem
rem  Output: <MISSION_NAME>_YYYYMMDD.miz  (in the current folder)
rem ---------------------------------------------------------------------------

set MISSION_NAME=mission

rem ---------------------------------------------------------------------------
rem 1. Update VEAF scripts to the latest published release
rem ---------------------------------------------------------------------------
veaf-tools-updater.exe
if errorlevel 1 goto :error

rem ---------------------------------------------------------------------------
rem 2. Build the mission
rem    Reads from src\mission\ and src\scripts\ — outputs %MISSION_NAME%_YYYYMMDD.miz
rem ---------------------------------------------------------------------------
veaf-tools.exe build %MISSION_NAME% .
if errorlevel 1 goto :error

rem ---------------------------------------------------------------------------
rem 3. Inject radio presets (uncomment if you have a presets.yaml)
rem ---------------------------------------------------------------------------
rem veaf-tools.exe inject-presets %MISSION_NAME% --presets-file src\presets.yaml
rem if errorlevel 1 goto :error

rem ---------------------------------------------------------------------------
rem 4. Inject waypoints (uncomment if you have a waypoints.yaml)
rem ---------------------------------------------------------------------------
rem veaf-tools.exe inject-waypoints %MISSION_NAME% --waypoints-file src\waypoints.yaml
rem if errorlevel 1 goto :error

rem ---------------------------------------------------------------------------
rem 5. Inject aircraft groups (uncomment if you have aircraft-templates.yaml)
rem ---------------------------------------------------------------------------
rem veaf-tools.exe inject-aircraft-groups %MISSION_NAME% --template-file src\aircraft-templates.yaml
rem if errorlevel 1 goto :error

rem ---------------------------------------------------------------------------
rem 6. Inject weather variants (uncomment if you have missions.yaml)
rem    Note: this creates additional .miz files, one per variant defined in the config
rem ---------------------------------------------------------------------------
rem veaf-tools.exe inject-weather %MISSION_NAME% --config-file src\missions.yaml
rem if errorlevel 1 goto :error

echo.
echo Build successful.
goto :eof

:error
echo.
echo Build FAILED (exit code %errorlevel%).
exit /b 1
