+++
title = "veafCasMission"
weight = 16
+++

## Introduction

This module allows the players to manage a Close Air Support mission at runtime.

The mission is created by placing a marker with a specific command (see [Concepts / F10 map user marks](../../concepts/#f10-map-user-marks))

Example : ``_cas, defense 3, size 5``

## How to set up a mission

Let's start by saying that you can clone the *[VEAF-Demo-Mission](https://github.com/VEAF/VEAF-Demo-Mission)* repository and use it as an example (or fork it and create a new mission from your fork).

### Load the script and its prerequisites

In DCS mission editor, set up a "mission start" trigger that will :

* load the following scripts (in order) :
  * mist.lua (from the *community* folder)
  * veaf.lua
  * veafRadio.lua
  * veafCasMission.lua
* run the following lua code : `veafRadio.initialize();veafCasMission.lua.initialize();`

## How to use in a mission

### Markers

The veafCasMission module is managed by creating markers, which names should follow a specific syntax (see next headings).

This syntax is composed of a mandatory instruction (at the beginning) and mandatory or optional (depending on the instruction) parameters separated by commas.

Example : ``_cas, defense 3, size 5``

For more informations about markers, see [Concepts / F10 map user marks](../../concepts/#f10-map-user-marks)

### Radio menus

The radio menu, when a CAS mission is active, contain the following commands:

* _Target information_: get a report about the battle zone (coordinates, weather, enemy units)
* _Skip current objective_: cancel the CAS mission and clean up all the spawned units
* _Request smoke on target area_: pop a smoke at the barycenter of the spawned units (the menu will change to _Target is marked with red smoke_ until the smoke runs out)
* _Request illumination flare over target area_: send an illumination flare above the battle zone (the menu will change to _Target area is marked with illumination flare_ until the flare runs out)

### Syntax

The command that will create a CAS mission is ``_cas``

The options are the same as the ones in the _veafSpawn_ module for [spawning dynamic groups](../veafspawn/#spawn-dynamic-groups).

Specifically, the act of creating a CAS mission starts with the [spawning of a dynamic full combat group](../veafspawn/#full-combat-group)
