+++
title = "veafUnits"
weight = 5
+++

## Introduction

This module allows the user to define groups that can be spawned in a mission using either the veafSpawn, the veafInterpreter or the veafCombatZone modules.
It is also possible to define aliases for units that will be used in groups, or spawned directly.

## How to set up a mission

Let's start by saying that you can clone the *[VEAF-Demo-Mission](https://github.com/VEAF/VEAF-Demo-Mission)* repository and use it as an example (or fork it and create a new mission from your fork).

### Load the script and its prerequisites

In DCS mission editor, set up a "mission start" trigger that will :

* load the following scripts (in order) :
  * mist.lua (from the *community* folder)
  * veaf.lua
  * veafUnits.lua
  * any module that you'll use to spawn the groups (veafSpawn, veafInterpreter or veafCombatZone)
* run the following lua code : `veafUnits.initialize();`

You can use the groups defined in the veafUnits.lua script, or define your own groups by creating a mission-specific file :

* load a new file that you'll write, and that will add entries in the veafUnits databases specifically for your mission ; usually it's called _veafUnitsConfig.lua_, and if you follow our model (*VEAF-Demo-Mission*) it's stored in the *scripts* folder of your mission.

### How to configure the script in a mission

The *veafUnitsConfig.lua* file will add entries to the _veafUnits.UnitsDatabase_ and/or _veafUnits.GroupsDatabase_ tables

Here's a annotated example:

```lua
table.insert(veafUnits.UnitsDatabase, {
        aliases = {"sa15", "sa-15"},
        unitType = "Tor 9A331",
    })
```

In this code, we add aliases for the Tor SAM system (more on the syntax later).

```lua
table.insert(veafUnits.GroupsDatabase, {
        aliases = {"rapier_optical", "rpo"},
        group = {
            disposition = { h= 3, w= 5},
            units = {{"rapier_fsa_optical_tracker_unit", cell = 13}, {"rapier_fsa_launcher", cell = 1}, {"rapier_fsa_launcher", cell = 5}},
            description = "Rapier SAM site",
            groupName = "Rapier"
        },
    })
```

In this code, we add a group called _rpo_ or *rapier_optical* that contains 3 units (more on the syntax later).

## Unit aliases syntax

The syntax of an entry in the _veafUnits.UnitsDatabase_ is quite simple.
Example :

```lua
{
    aliases = {"sa15", "sa-15"},
    unitType = "Tor 9A331",
}
```

An entry is composed of 2 elements :

* the **aliases** keyword defines a list of aliases that can be used to refer to the unit
* the **unitType** keyword specifies which DCS unit is referred to from the list defined in *dcsUnits.lua* (not very up-to-date).

## Group definition syntax

A group is a list of units that are used together to form a usable battle group.  
It has a layout template, used to make the group units spawn at the correct place and heading.
The syntax of an entry in the _veafUnits.GroupsDatabase_ is much more complex than a simple alias.
Example :

```lua
    {
        aliases = {"Tarawa"},
        group = {
            disposition = { h = 3, w = 3},
            units = { {"tarawa", 2}, {"PERRY", 7}, {"PERRY", 9} },
            description = "Tarawa battle group",
            groupName = "Tarawa",
        }
    }
```

### Syntax

#### aliases

The **aliases** keyword defines a list of aliases that can be used to refer to the group.

Example :

```lua
    aliases = {"sa2", "sa-2", "fs"},
```

#### disposition

The **disposition** keyword defines the group layout template (see explanation of group layouts below).

Example :

```lua
    disposition = { h= 6, w= 8},
```

#### units

The **units** keyword defines a list of all the units composing the group. 

Example :

```lua
    units = {
        {"IFV Hummer", cell = 1, fitToUnit},
        {"Truck Predator GCS", cell = 3, hdg = 225},
        {"Truck M 818", number = 4, random},
        {"Truck M978 HEMTT Tanker", number = {min=0, max=3}, random},
    },
```

* the first element of the unit table is always the unit type, either from the _dcsUnits_ database, or from an alias in _veafUnits.UnitsDatabase_.
* the position of the unit is either specified with the **cell** parameter (containing the cell number), or left as random if the **cell** keyword is omitted.
* the **random** parameter, if set, means that the unit will be placed randomly in the cell, leaving a one unit size margin around.
* the **hdg** parameter, if set, fixes the unit heading (in degrees, from 0 to 359); when not set, unit heading is random.
* the **number** parameter is used to spawn multiple units in several cells; it cannot be combined with the **cell** parameter, of course, and can either be a fixed number or an interval from which the actual number of units will be chosen randomly.
* **fitToUnit**, when specified, makes the cell shrink around the unit ; it will not be a square but a rectangle of the unit's exact size (plus the spacing, if set)

#### description

the **description** keyword contains a human-friendly name for the group that will be used in lists (e.g. in the *list all groups* radio menu of *veafSpawn*).

#### groupName

the **groupName** keyword defines the DCS group name used when spawning this group (will be completed with a numerical suffix)

### Group layout grid and placement algorithm

A group template is defined relative to a grid, composed of cells, numbered from left to right and top to bottom :

![group-units-disposition-00](/images/group-units-disposition.png?raw=true "group-units-disposition")

The units in the group will be spawned in their respective cell, or sequentially from the top-left cell if no preferred cell is set.  
Let's describe the algorithm so everything is clear.

#### Step 1

First, a layout defines the number of cells (height and width) for the group. At the moment the cells measure by default 10m x 10m.
The **disposition** keyword defines this layout.
Here's an example with the Tarawa group defined above :

```lua
    disposition = { h = 3, w = 3},
```

![unitSpawnGridExplanation-01](/images/unitSpawnGridExplanation-01.png?raw=true "unitSpawnGridExplanation-01")

#### Step 2

Then, when a unit is placed in a cell, this cell size grows to accomodate the unit's size.  
We can add a **spacing** parameter (in the spawn method call) if needed, to allow for some freedom inside the cells. When set, the size of the cell will be expanded by the size of the unit *times* the spacing parameter.

Let's continue with our example ; here the Tarawa itself is placed in cell #2 :

```lua
    units = { {"tarawa", 2} ... },
```

![unitSpawnGridExplanation-02](/images/unitSpawnGridExplanation-02.png?raw=true "unitSpawnGridExplanation-02")

#### Step 3

This process continues until all the units are placed.  
In our example, we still have to place 2 Perry frigates in cells #7 and #9 :

```lua
    units = { ... {"PERRY", 7}, {"PERRY", 9} },
```

![unitSpawnGridExplanation-03](/images/unitSpawnGridExplanation-03.png?raw=true "unitSpawnGridExplanation-03")

#### Step 4

At the end of the process, we need to compute the size of the rectangle that contains all the group units.  

Continuing with our example :  

![unitSpawnGridExplanation-04](/images/unitSpawnGridExplanation-04.png?raw=true "unitSpawnGridExplanation-04")

And we can actually spawn all the units at the center of each cell, with a random variation if the **random** parameter was set

### Actual examples

#### A seemingly realistic russian air defense batteries

```lua
{
    aliases = {"RU-SAM-Shilka-Battery"},
    group = {
        disposition = { h= 5, w= 5},
        units = {
            -- the search radar
            {"Dog Ear radar", cell = 13},  
            -- the actual air defense units
            {"ZSU-23-4 Shilka", hdg = 0, random}, {"ZSU-23-4 Shilka", hdg = 90, random}, {"ZSU-23-4 Shilka", hdg = 180, random}, {"ZSU-23-4 Shilka", hdg = 270, random},
            -- a supply truck or three
            {"Transport Ural-4320-31 Armored", number = {min=1, max=3}, random},
        },
        description = "ZSU-23-4 battery",
        groupName = "ZSU-23-4 battery"
    },
},
```

#### A quite random, but nonetheless deadly air defense group

```lua
{
    aliases = {"generateAirDefenseGroup-RED-5"},
    hidden,
    group = {
        disposition = { h= 7, w= 7},
        units = {
            -- the search radar
            {"Dog Ear radar", random},  
            -- Tor battery
            {"Tor 9A331", hdg = 0, random}, {"Tor 9A331", hdg = 90, random}, {"Tor 9A331", hdg = 180, random}, {"Tor 9A331", hdg = 270, random}, 
            -- Some SA13
            {"Strela-10M3", number = {min=2, max=4}, random},
            -- Some Shilkas
            {"ZSU-23-4 Shilka", number = {min=2, max=4}, random},
            -- a supply truck or three
            {"Transport Ural-4320-31 Armored", number = {min=1, max=3}, random}, 
        },
        description = "generateAirDefenseGroup-RED-5",
        groupName = "generateAirDefenseGroup-RED-5",
    },
},
```

#### A very simple infantry group

```lua
{
    aliases = {"US infgroup"},
    group = {
        disposition = { h = 5, w = 5},
        units = {{"IFV Hummer", number = {min=1, max=2}, random},{"INF Soldier M249", number = {min=1, max=2}, random},{"INF Soldier M4 GRG", number = {min=2, max=4}, random},{"INF Soldier M4", number = {min=6, max=15}, random}},
        description = "US infantry group",
        groupName = "US infantry group",
    },
},
```

## How to use in a mission

Depending on the mission, it is possible to spawn groups and units defined with this module by using the commands in the veafSpawn, the veafInterpreter and the veafCombatZone modules.
See their specific documentation to find out how.
