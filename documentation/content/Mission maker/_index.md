+++
title = "Mission maker"
weight = 1
chapter = false
+++


## Introduction

With these tools offered free of charge by the [Virtual European Air Force](https://www.veaf.org), any mission maker can easily create a complex, dynamic mission in the DCS mission editor.
In as little as 1 or 2 hours, you will have a mission with :

- a complex setup of dozens of units, easily added by using special templating commands.
- a system that dresses up FARP units to make them complete forwards bases of operations, with the required logistic vehicles, tents, guards and even windsocks
- a build system that will normalize your mission files so they aren't completely randomized and shuffled each time you edit them with the DCS editor.
- a radio presets frequencies injector; it'll use a template to set all the radio presets in the players planes.
- a player-controlled radio menu to control this mission at runtime.
- a robust, easy-to-setup security system that can restrict certain features to specific user groups.
- a *[Zeus](https://arma3.com/dlc/zeus)*-like system that can be used to spawn AI groups, convoys and units at runtime.
- a carrier vehicle that can automatically navigate upwind when requested by the players, and automatically return to its initial location afterwards; it can also manage a rescue helicopter on station (port side of the ship), and a S3-B emergency tanker.
- a ground attack mission system; this will generate a ground attack mission when requested, and create the radio menus needed to control it.
- a helo transport mission system; this will generate a helicopter transport mission when requested, and create the radio menus needed to control it.

## Prerequisites

There are two sets of prerequisites to use the VEAF Mission Creation Tools.
First, if you simply want to use them in your missions, then you'll need :

- DCS World (of course)
- mist.lua (provided in the *community* folder)

But if you want to use the full development environment, and take advantage of the advanced features (normalization, injection), and easily publish your mission to a source control system (e.g. GitHub), you'll also need :

- git
- an IDE (notepad++, visual studio code...)
- npm - for that install [node.js](https://nodejs.org/en/download/)
- 7za from the [7-Zip Extra: standalone console version](https://www.7-zip.org/a/7z1900-extra.7z)
- lua from [Lua for Windows](https://github.com/rjpcomputing/luaforwindows)

## How to set up a mission

You can clone the *[VEAF-Demo-Mission](https://github.com/VEAF/VEAF-Demo-Mission)* repository and use it as an example (or fork it and create a new mission from your fork).
Then you should read the *readme.md* file in this repository. It will explain how you should setup your development environment.
There is detailed documentation for all the modules (see menu on the left).

If you choose to start with a new mission (and not clone our demo mission), the important point is to load and initialize the scripts.

Start by adding a new "mission start" trigger; it should be the first trigger

![create-mission-01](/VEAF-Mission-Creation-Tools/images/create-mission-01.png?raw=true "create-mission-01")

This trigger (1) must be of type "mission start" (2), and it should load all the scripts (3).

![create-mission-02](/VEAF-Mission-Creation-Tools/images/create-mission-02.png?raw=true "create-mission-02")

Here is the list of scripts to load, in the correct order:

- **... (MiST is mandatory, and must be the very first to load)**
- mist.lua
- **... (all the non-mandatory, external scripts)**
- CTLD.lua *(CTLD is not mandatory)*
- WeatherMark.lua *(WeatherMark is not mandatory)*
- **... (now the VEAF scripts, in the order of their dependencies)**
- veaf.lua *(the main library, must be the first of the VEAF scripts)*
- dcsUnits.lua *(mandatory)*
- veafUnits.lua *(mandatory)*
- veafMarkers.lua *(mandatory)*
- veafRadio.lua *(mandatory)*
- veafSecurity.lua *(mandatory)*
- veafSpawn.lua *(mandatory)*
- veafAssets.lua *(used in other scripts)*
- veafCasMission.lua *(used in other scripts)*
- veafNamedPoints.lua *(used in other scripts)*
- veafCarrierOperations.lua *(not mandatory)*
- veafCombatZone.lua *(not mandatory)*
- veafGrass.lua *(not mandatory)*
- veafMove.lua *(not mandatory)*
- veafTransportMission.lua *(not mandatory)*
- veafInterpreter.lua *(not mandatory)*
- **...(now the configuration scripts)**
- veafAssetsConfig.lua
- veafAutogftConfig.lua
- veafCTLDConfig.lua
- veafCombatZoneConfig.lua
- veafNamedPointsConfig.lua
- veafSecurityConfig.lua

Then, it should run the following initialization code:

```lua
veafRadio.initialize()
veafAssets.initialize()
veafCasMission.initialize()
veafGrass.initialize()
veafMove.initialize()
veafSpawn.initialize()
veafCarrierOperations.initialize()
veafTransportMission.initialize()
veafNamedPoints.initialize()
veafSecurity.initialize()
veafCombatZone.initialize()
veafInterpreter.initialize()
ctld.initialize() -- only needed if you use CTLD
```

Then, for each script that you use (and its dependencies), you should read the specific documentation and find out how to use and configure it.
