# Units and groups

## Units databases

### dcsUnits

The *dcsUnits.lua* script defines a database named *dcsUnits.DcsUnitsDatabase*, which lists all the units in the current DCS World universe. 

### veafUnits

The *veafUnits.lua* script provides a *veafUnits.UnitsDatabase* list containing aliases, referencing units in the *dcsUnits.DcsUnitsDatabase* list.  
It also defines functions that scan these databases for a specific unit.

## Groups definitions

In the *veafUnits.lua* script, we also define groups.

A group is a list of units that are used together to form a usable battle group.  
It has a layout template, used to make the group units spawn at the correct place and heading.

### Syntax

#### Example of a group definition

##### Simple group

```lang=lua
    {
        aliases = {"sa13", "sa-13"},
        group = {
            units = {"sa-13"},
            description = "SA-13 SAM site",
            groupName = "SA13"
        }
    }
```

##### Specifying disposition and cells

```lang=lua
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

##### Specifying the number of instances of a unit

```lang=lua
    {
        aliases = {"infantry section", "infsec"},
        group = {
            disposition = { h= 10, w= 4},
            units = { {"IFV BTR-80", cell=38},{"IFV BTR-80", cell=39},{"INF Soldier AK", number = {min=12, max=30}}, {"SA-18 Igla manpad", number = {min=0, max=2} } },
            description = "Mechanized infantry section with APCs",
            groupName = "Mechanized infantry section"
        }
    }
```

##### Specifying the heading of a unit

```lang=lua
    {
        aliases = {"sa2", "sa-2", "fs"},
        group = {
            disposition = { h= 6, w= 8},
            units = { {"SNR_75V", cell = 20}, {"p-19 s-125 sr", cell = 48}, {"S_75M_Volhov", cell = 2, hdg = 315}, {"S_75M_Volhov", cell = 6, hdg = 45}, {"S_75M_Volhov", cell = 17, hdg = 270}, {"S_75M_Volhov", cell = 24, hdg = 90}, {"S_75M_Volhov", cell = 34, hdg = 225}, {"S_75M_Volhov", cell = 38, hdg = 135} },
            description = "SA-2 SAM site",
            groupName = "SA2"
        }
    }
```

#### Explanation of the fields

- aliases : list of aliases which can be used to designate this group, case insensitive
- disposition : height and width (in cells) of the group layout template (see explanation of group layouts below)
- units : list of all the units composing the group. Each unit in the list is composed of :
  - alias : alias of the unit in the VEAF units database, or actual DCS type name in the DCS units database
  - cell : preferred layout cell ; the unit will be spawned in this cell, in the layout defined in the *layout* field. (see explanation of group layouts below) ; when nothing else is specified, a number after the unit alias is considered to be the *cell* parameter
  - size : fixes the cell size (in meters), instead of relying on the contained unit size (modified with the *spacing* parameter) ; can be either a table with width and height, or a number for square cells
  - number : either a number, which will be the quantity of this unit type spawned ; or a table, with *min* and *max* values that will be used to spawn a random quantity of this unit typ
  - hdg : the unit heading will mean that, if the group is spawned facing north, this unit will be facing this heading (in degrees). If not set, units will face the group heading
  - random : if set, the unit will be placed randomly in the cell, leaving a one unit size margin around.
- description = human-friendly name for the group
- groupName   = name used when spawning this group (will be flavored with a numerical suffix)

#### Group layout

The units in the group will be spawned in their respective cell, or sequentially from the top-left cell if no preferred cell is set.  

##### Step 1

First, a layout defines the number of cells (height and width) for the group. At the moment the cells measure by default 10m x 10m.

Here's an example with the Tarawa group defined above :

![unitSpawnGridExplanation-01](./unitSpawnGridExplanation-01.png?raw=true "unitSpawnGridExplanation-01")

##### Step 2

Then, when a unit is placed in a cell, this cell size grows to accomodate the unit's size.  
We can add a spacing parameter if needed, to allow for some freedom inside the cells. When set, the size of the cell will be expanded by the size of the unit *times* the spacing parameter.

Let's continue with our example ; here the Tarawa itself is placed in cell #2 :

![unitSpawnGridExplanation-02](./unitSpawnGridExplanation-02.png?raw=true "unitSpawnGridExplanation-02")

##### Step 3

This process continues until all the units are placed.  
In our example, we still have to place 2 Perry frigates in cells #7 and #9 :

![unitSpawnGridExplanation-03](./unitSpawnGridExplanation-03.png?raw=true "unitSpawnGridExplanation-03")

##### Step 4

At the end of the process, we need to compute the size of the rectangle that contains all the group units.  

Continuing with our example :  

![unitSpawnGridExplanation-04](./unitSpawnGridExplanation-04.png?raw=true "unitSpawnGridExplanation-04")

And we can actually spawn all the units at the center of each cell, with a random variation if the *random* parameter was set
