# VEAF mission normalizer tool for DCS World

By Zip (2020)

## Features:
This tool processes all files in a mission, apply filters to normalize them and writes them back.
Usually, DCSW Mission Editor shuffles the data in the mission files each time the mission is saved, making it all but impossible to compare with a previous version.
With this tool, it becomes easy to compare mission files after an edition in DCS World Mission Editor.

## Prerequisite:
* The mission file archive must already be exploded ; the script only works on the mission files, not directly on the .miz archive

## Usage:
The following workflow should be used :
* explode the mission (unzip it)
* run the normalizer on the exploded mission
* version the exploded mission files (save it, back it up, commit it to a source control system, whatever fits your routine)
* compile the mission (zip the exploded files again)
* edit the compiled mission with DCSW Mission Editor
* explode the mission (unzip it)
* run the normalizer on the exploded mission
* now you can run a comparison between the exploded mission and its previous version

Call the script by running it in a lua environment ; it needs the veafMissionEditor library, so the script working directory must contain the veafMissionEditor.lua file

```veafMissionNormalizer.lua <mission folder path> [-debug|-trace]```

Command line options:
* *<mission folder path>* the path to the exploded mission files (no trailing backslash)
* *-debug* if set, the script will output some information ; useful to find out which units were edited
* *-trace* if set, the script will output a lot of information : useful to understand what went wrong

See extract-example.cmd for an example of command script that will explode, normalize and clean up a DCS mission file