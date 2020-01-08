# VEAF radio presets editor tool for DCS World

By Zip (2020)

## Features:
* This tool processes a mission and sets predefined radio presets.
* The preset templates can be customized (see radioSettings-example.lua)

## Prerequisite:
* The mission file archive must already be exploded ; the script only works on the mission files, not directly on the .miz archive

## Usage:
Call the script by running it in a lua environment ; it needs the veafMissionEditor library, so the script working directory must contain the veafMissionEditor.lua file

```veafMissionRadioPresetsEditor.lua <mission folder path> <radio settings file> [-debug|-trace]```

Command line options:
* *<mission folder path>* the path to the exploded mission files (no trailing backslash)
* *<radio settings file>* the path to the preset templates file (see radioSettings-example.lua)
* *-debug* if set, the script will output some information ; useful to find out which units were edited
* *-trace* if set, the script will output a lot of information : useful to understand what went wrong
