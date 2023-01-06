# [![VEAF-logo]][VEAF website] Mission Creation Tools - Mission maker documentation

# /!\ **WORK IN PROGRESS** /!\
The documentation is being reworked, piece by piece. 
In the meantime, you can browse the [old documentation](../old_documentation/_index.md).

**GO BACK TO THE MAIN [MISSION CREATION TOOLS INDEX](../index.md)**

## Introduction

## Workflow

All missions that use the VEAF Mission Creation Tools share some base concepts:

* they integrate (some of) the VEAF and community scripts in a load trigger
* they initialize and configure these scripts in another trigger
* they share a few conventions when naming units and groups

This is easier if the mission folder is organized like that:

* *src* - all the mission source files
* *src/mission* - the mission definition (the lua files created by the DCS mission editor and originally compressed into a zipped *.miz* file)
* *src/scripts* - (optional) the custom scripts used to configure the VEAF modules specifically for this mission
* *src/radioSettings.lua* - (optional) the radio frequencies that will be injected
* *build.cmd* - the build script is responsible for creating the *.miz* file that will contain all the lua definitions, the scripts, the configuration files, etc.
* *extract.cmd* - this script will extract the lua definition files from a *.miz* file freshly edited with the DCS mission editor
* *package.json* - this allows the build and extract scripts to download the latest version of the VEAF Mission Creation Tools

![demo-mission-structure]

The easiest way to create such a folder is to fork the demo mission provided by us (please read the [demo mission](./mission-maker/demo-mission/) page).


When working on the mission, always follow this workflow:

![workflow-01]

First, create a mission in the DCS mission editor, and save it in the main folder of your mission (alongside the _build_ and _extract_ scripts)

1. run the _extract_ script to put all the lua definition files in the _src_ folder
2. edit the configuration scripts, the radio presets configuration, update the VEAF Mission Creation Tools, etc.
3. run the _build_ script to assemble all the scripts, the configuration files, and the mission into a _.miz_ file; it'll be generated in the _build_ folder
4. edit the _.miz_ file with the DCS mission editor
5. -> back to step 1; rinse and repeat.

## Contacts

If you need help or you want to suggest something, you can:

* contact [Zip][Zip on Github] on Github
* go to the [VEAF website]
* post on the [VEAF forum]
* join the [VEAF Discord]


[Badge-Discord]: https://img.shields.io/discord/471061487662792715?label=VEAF%20Discord&style=for-the-badge
[VEAF-logo]: ./.images/logo.png?raw=true
[VEAF Discord]: https://www.veaf.org/discord
[Zip on Github]: https://github.com/davidp57
[VEAF website]: https://www.veaf.org
[VEAF forum]: https://www.veaf.org/forum

[demo-mission-structure]: ../.images/demo-mission-structure.png
[workflow-01]: ../.images/editor_workflow.png