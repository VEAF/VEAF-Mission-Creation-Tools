# How to use the VEAF mission creation tools as a mission maker

## Introduction

With these tools offered free of charge by the [VEAF](https://www.veaf.org), any mission maker can easily create a complex, dynamic mission in the DCS mission editor.
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
There is detailed documentation for all the modules:

- [veafAssets](veafAssets.md)
- [veafCarrierOperations](veafCarrierOperations.md)
