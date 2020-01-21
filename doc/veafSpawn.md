# veafSpawn.lua module documentation

## Introduction

This module allows the user to spawn several type of DCS objects in a running mission ; it can spawn :

* groups that have been defined with the veafUnits module
* units that are defined in DCS (either via their veafUnits alias, or their DCS type name
* dynamic groups that use templates defined with the veafUnits module, but can be configured and are randomized
* convoys that can go from a point to another, and be tracked and managed with radio commands
* cargo statics and logistic points that are registered with [CTLD](https://github.com/ciribob/DCS-CTLD) and can be transported via helicopter
* bombs that can destroy scenery, units and groups (even client aircrafts and vehicles)
* smoke and illumination flares

It also provides commands to :

* teleport an existing unit or group to a different location
* cleanly destroy a unit or several units inside a defined circle (without leaving a smoking wreck behind, that is)

## How to set up a mission

Let's start by saying that you can clone the *[VEAF-Demo-Mission](https://github.com/VEAF/VEAF-Demo-Mission)* repository and use it as an example (or fork it and create a new mission from your fork).

### Load the script and its prerequisites

In DCS mission editor, set up a "mission start" trigger that will :

* load the following scripts (in order) :
  * mist.lua (from the *community* folder)
  * veaf.lua
  * veafUnits.lua
  * veafMarkers.lua
  * veafRadio.lua
  * veafCasMission.lua
  * veafSpawn.lua
* run the following lua code : `veafUnits.initialize();veafMarkers.initialize();veafRadio.initialize();veafCasMission.initialize();veafSpawn.initialize();`

## How to use in a mission

### Markers

The veafSpawn module is managed by creating markers, which names should follow a specific syntax (see next headings).
This syntax is composed of a mandatory instruction (at the beginning) and mandator or optional (depending on the instruction) parameters separated by commas.
Example : ``_spawn group, name US infgroup, country USA``

For more informations about markers, see [veafMarkers](veafMarkers.md)

### Spawn units and groups

The **_spawn** instruction can spawn units (**_spawn unit**) or groups (**_spawn groups**).
Both commands accept the same set of mandatory (bold) or optional (bold italic) parameters:

* **name** is the name of the unit or group in the VEAF and DCS databases; e.g. ``_spawn unit, name sa6``
* ***country*** (default *RUSSIA*) is the name of the country this unit will belong to; e.g. ``_spawn group, name US infgroup, country USA``
* ***speed*** (default *0*) is the speed of the unit/group, when it spawns. For most units/groups it will reset to its predefined orders; e.g. ``_spawn unit, name sa6, speed 15``
* ***altitude*** or ***alt*** (default *0*) is the altitude of the unit/group (same remarks as _speed_); e.g. ``_spawn unit, name sa6, alt 15``
* ***heading*** or ***hdg*** (default *0*) is the heading of the unit/group (same remarks as _speed_); e.g. ``_spawn unit, name sa6, hdg 270``

Some parameters are specific to the **_spawn unit** instruction:

* ***unitName*** (default is the unit display name in DCS suffixed with a numeric counter) will be the name this unit will have in the DCS mission (not to be mistaken with the unit type parameter, **name**); e.g. ``_spawn unit, name sa6, unitname My proud SA6``

A special instruction will spawn a specific unit with a JTAC role, and set it as invisible and invincible: **_spawn jtac**.
It has a specific parameter:

* ***laser*** (default *1688*) can be used to choose a laser code for the JTAC ; e.g. ``_spawn jtac, laser 1681``

Some parameters are specific to the **_spawn group** instruction:

* ***spacing*** (default *5*) is used to add space between a group's units (see [veafUnits](veafUnits.md)) 
* ***isconvoy*** (default *false*) if set, makes the group behave like a convoy

  * **dest** (mandatory in this case) the named point where the convoy must go (see [veafNamedPoints](veafNamedPoints.md))
  * ***patrol*** (default *false*) if set, makes the group go back and forth between its spawn point and its destination point
  * ***offroad*** (default *false*) if set, the group will not try and use roads

### Spawn dynamic groups

The **_spawn** instruction can also spawn dynamic groups; these groups are randomized, and parameters can be used to choose several aspects of this randomization.
The type of the dynamic group is linked to the instruction itself :

* **_spawn infantrygroup** will spawn an infantry section (an armored personnel carrier with an infantry section and optional air defense - manpads)
  * ***defense*** (default *1*) will determine the air defense generated for this group:
    * if 0: no manpad
    * 1..3: between 1 and *defense* older manpad systems
    * 4..5: between 1 and *defense*-2 modern manpad systems
  * ***armor*** (default *1*) will determine the personnel carrier vehicle:
    * if 0: a M 818 (BLUE) or a GAZ-3308 (RED) truck
    * 1..3: a IFV Boman (BLUE) or a BTR-80 (RED)
    * 4..5: a M-2 Bradley (BLUE) or a BMP-1 (RED)
* **_spawn armorgroup** will spawn an armor platoon (3-6 armored vehicles with optional escorting air defence systems)
  * ***defense*** (default *1*) will determine the air defense generated for this group:
    * if 0: no air defense
    * 1..3: a Gepard (BLUE) or a ZSU-23-4 Shilka (RED)
    * 4..5: an M6 Linebacker (BLUE) or a 2S6 Tunguska (RED)
  * ***armor*** (default *1*) will determine the personnel carrier vehicle:
    * 0..2: random choice between M-2 Bradley, IFV MCV-80, IFV Boman (BLUE) or BMP-1, BMD-1, BRDM-2 (RED)
    * 3: random choice between M-2 Bradley (66%), M-60 (33%) (BLUE) or BMP-1, BMP-2, T-55 (RED)
    * 4: random choice between M-2 Bradley (50%), M-60 (25%), Leopard-2 (25%) (BLUE) or BMP-1, BMP-2, T-55, T-72 (RED)
    * 5: random choice between M-2 Bradley (50%), MBT Leopard1A3 (25%), M-1 Abrams (25%) (BLUE) or BMP-2, BMP-3, T-80UD, T-90 (RED)
* **_spawn samgroup** will spawn an air defense battery (multiple air defense launchers/systems, a search radar and support vehicles)
  * ***defense*** the group will be spawned from the *veafUnit* template called "generateAirDefenseGroup-<side>-<defense>" where <side> is either RED or BLUE and <defense> is the *defense* parameter value
* **_spawn transportgroup** will spawn a transport company (several trucks with optional escorting air defence systems)
  * ***defense*** (default *1*) will determine the air defense generated for this group, one of these air defense system for every ten trucks:
    * if 0: no air defense
    * 1: a Gepard (BLUE) or a Ural-375 ZU-23 (RED)
    * 2: a Gepard (BLUE) or a ZSU-23-4 Shilka (RED)
    * 3: an M6 Linebacker (BLUE) or a 2S6 Tunguska (RED)
    * 4..5: an M6 Linebacker and a Gepard (BLUE) or a 2S6 Tunguska and a ZSU-23-4 Shilka (RED)
  * ***size*** (default *10*) the number of trucks that will be spawned
* **_spawn combatgroup** will spawn a full combat group, composed of multiple infantry groups, multiple armor platoons, several transport companies and 1 or 2 air defense groups
  * ***defense*** (default *1*) will be used for every generated group (see above)
  * ***armor*** (default *1*) will be used for every generated group (see above)
  * ***size*** (default *10*) will be used for every generated group (see above) and condition the groups that will be generated:
    * between *size*-2 and *size*+1 infantry groups
    * between *size*-2 and *size*+1 armor platoons
    * 1 or 2 air defense groups if *defense* is not 0
    * between 1 and *size* transport companies

Aside from the specific parameters already listed above, there are common parameters:

* ***side*** (default *RED*) is the coalition the group(s) will belong to (RED or BLUE)
* ***country*** (default *USA* for side=blue, *RUSSIA* for side=red) is the country the group(s) will belong to
* ***heading*** (default *0*) is the global heading of the groups; units in the group will have their individual heading (in the template definition) adapted to be relative to this global heading
* ***spacing*** (default *5*) is used to add space between a group's units (see [veafUnits](veafUnits.md)), but also to add space between the groups

### Spawn convoys

The **_spawn convoy** instruction will generate a dynamic convoy, and send it on its route to a named point (see [veafNamedPoints](veafNamedPoints.md)).
The convoys are tracked and managed in the VEAF SPAWN radio menu. 
It is possible to find out if a convoy still exists (or was destroyed entirely), find out where it is (or between which points it travels) thanks to smoke markers, or dispose of a convoy.
The convoy will be composed of a transport company (see **_spawn transportgroup** above), 
This instruction accepts several parameters:

