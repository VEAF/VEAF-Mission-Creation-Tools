+++
title = "veafGrass"
weight = 12
+++

## Introduction

This module helps place a Forward Armament and Refuel Point (FARP) in a mission.
It also helps with grass runways (hence its name).
The mission creator simply has to place one or few units in the DCS mission editor, and name them following a specific convention; the script will then automatically find and dress these units up at mission start.

## How to set up a mission

Let's start by saying that you can clone the *[VEAF-Demo-Mission](https://github.com/VEAF/VEAF-Demo-Mission)* repository and use it as an example (or fork it and create a new mission from your fork).

### Load the script and its prerequisites

In DCS mission editor, set up a "mission start" trigger that will :

* load the following scripts (in order) :
  * mist.lua (from the *community* folder)
  * veaf.lua
  * veafGrass.lua
* run the following lua code : `veafGrass.initialize();`

### Place the units in the mission

There are two naming conventions that you can use with this script:

* units with "FARP " in their name will trigger the creation of a FARP; tents and other static objects like generators, ammo dumps, a windsock will be placed around the unit; supply vehicles (mandatory for rearming, refueling and getting external power) will be spawned; the FARP will also be added to the named points database (see [namedPoints](./veafnamedpoints.md))
* units with "GRASS_RUNWAY" in their name will trigger the creation of a grass runway by replicating the unit to form two parallel lines, add a guard tower, a windsock and also add the grass runway to the named points database (see [namedPoints](./veafnamedpoints.md))

## How to use in a mission

Nothing to do ; at mission start the script will automatically run, and then the FARPs and grass runways will be available for the players.