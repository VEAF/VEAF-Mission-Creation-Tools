@echo off
rem params:
rem  - mission name
rem  - dynamic scripts path
rem  - dynamic loading mode

rem update

rem build

rem inject spawnable aircrafts

rem inject waypoints

rem inject presets

rem disable modules requirement
rem  -- disable the C130 module requirement
rem powershell -File replace.ps1 .\build\tempsrc\mission "\[\"Hercules\"\] = \"Hercules\"," " " >nul 2>&1
rem -- disable the UH-60L module requirement
rem powershell -File replace.ps1 .\build\tempsrc\mission "\[\"UH-60L\"\] = \"UH-60L\"," " " >nul 2>&1
rem -- disable the A-4E-C module requirement
rem powershell -File replace.ps1 .\build\tempsrc\mission "\[\"A-4E-C\"\] = \"A-4E-C\"," " " >nul 2>&1
rem -- disable the T-45 module requirement
rem powershell -File replace.ps1 .\build\tempsrc\mission "\[\"T-45\"\] = \"T-45\"," " " >nul 2>&1
rem -- disable the AM2 module requirement
rem powershell -File replace.ps1 .\build\tempsrc\mission "\[\"AM2\"\] = \"AM2\"," " " >nul 2>&1
rem -- disable the SU-30* module requirement
rem powershell -File replace.ps1 .\build\tempsrc\mission "\[\"FlankerEx by Codename Flanker\"\] = \"FlankerEx by Codename Flanker\"," " " >nul 2>&1
rem -- disable the Bronco-OV-10A module requirement
rem powershell -File replace.ps1 .\build\tempsrc\mission "\[\"Bronco-OV-10A\"\] = \"Bronco-OV-10A\"," " " >nul 2>&1

rem -- generate the time and weather versions
