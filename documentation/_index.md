![VEAF-logo](./_images/logo.png?raw=true "logo.png")

## Introduction

The VEAF Mission Creation Tools contains tools and scripts designed to make it easy to create, share and maintain dynamic missions.

It is composed of:

* the VEAF scripts (modules)
* the community scripts, sometimes edited by VEAF
* a mission creation, edition and publication workflow
* tools to support this workflow
* this documentation

## Roles

When you have an interest in the VEAF Mission Creation Tools, you may be a mission programmer or a mission maker.

Mission makers want to use the tools to create, share and maintain a mission.

Mission programmers help us maintain and enhance the tools by adding features, correcting bugs, configuring new data.

### How to use the tools as a mission maker

Please have a look at the [Misson Maker documentation](./mission-maker/).

For those looking for a quick start, read the [demo mission](./mission-maker/demo-mission/) page to learn how you can fork the demo repository and create your own mission.

### How to participate to the development of the tools

The [Misson Programmer documentation](./mission-programmer/) details all you need to know about that.

You can contact us, we'll guide you into our community.

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

![demo-mission-structure](/VEAF-Mission-Creation-Tools/images/demo-mission-structure.png?raw=true "demo-mission-structure.png")

The easiest way to create such a folder is to fork the demo mission provided by us (please read the [demo mission](./mission-maker/demo-mission/) page).

When working on the mission, always follow this workflow:

![workflow-01](/VEAF-Mission-Creation-Tools/images/editor_workflow.png?raw=true "workflow-01")

First, create a mission in the DCS mission editor, and save it in the main folder of your mission (alongside the _build_ and _extract_ scripts)

1. run the _extract_ script to put all the lua definition files in the _src_ folder
2. edit the configuration scripts, the radio presets configuration, update the VEAF Mission Creation Tools, etc.
3. run the _build_ script to assemble all the scripts, the configuration files, and the mission into a _.miz_ file; it'll be generated in the _build_ folder
4. edit the _.miz_ file with the DCS mission editor
5. -> back to step 1; rinse and repeat.

## Questions, feature requests, bug reports

There are several ways of getting in touch with the VEAF:

* we have a [very nice forum](https://community.veaf.org); you can post in the open [International Room](https://community.veaf.org/category/29/international-room)
* you can [create issues](https://github.com/VEAF/VEAF-Mission-Creation-Tools/issues) and [pull requests](https://github.com/VEAF/VEAF-Mission-Creation-Tools/pulls) on the [GitHub repository](https://github.com/VEAF/VEAF-Mission-Creation-Tools)
* our [Discord server](https://discord.gg/YezPzzQ) can be used to chat (both text and voice) with the VEAF members and developpers; we're nice people and some of us even speak english ^^
* you can send [emails](mailto:veaf@gmail.com) to the VEAF; they won't be read everyday, so please try and use one of the other communication mediums.

## Hall of fame

* David "Zip" Pierron, VEAF
* "Mitch", VEAF
