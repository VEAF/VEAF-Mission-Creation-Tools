@echo off
setlocal

rem ---------------------------------------------------------------------------
rem  VEAF Mission Build Script
rem
rem  Place this file at the root of your mission folder, next to:
rem    veaf-tools-updater.exe   (downloaded from the VEAF release)
rem    veaf-tools.exe           (downloaded by the updater at run time)
rem    mission.yaml             (optional build configuration)
rem    src\                     (your source files)
rem      mission\               (DCS mission data extracted from the .miz)
rem      scripts\               (your Lua scripts: missionConfig.lua, etc.)
rem
rem  Optional injection steps are auto-detected from src\ by veaf-tools:
rem    src\presets.yaml          → radio presets injection
rem    src\waypoints.yaml        → waypoints injection
rem    src\aircraft-templates.yaml → aircraft groups injection
rem    src\missions.yaml         → weather/time variants
rem
rem  To disable or customize a step, add a `pipeline:` section to mission.yaml.
rem  Output: <MISSION_NAME>_YYYYMMDD.miz  (in the current folder)
rem ---------------------------------------------------------------------------

set MISSION_NAME=mission

rem ---------------------------------------------------------------------------
rem 1. Update VEAF scripts to the latest published release
rem ---------------------------------------------------------------------------
veaf-tools-updater.exe
if errorlevel 1 goto :error

rem ---------------------------------------------------------------------------
rem 2. Build the mission — optional injection steps run automatically
rem    based on files found in src\ (see header above)
rem ---------------------------------------------------------------------------
veaf-tools.exe build %MISSION_NAME% .
if errorlevel 1 goto :error

echo.
echo Build successful.
goto :eof

:error
echo.
echo Build FAILED (exit code %errorlevel%).
exit /b 1
