+++
title = "veafCombatZone"
weight = 17
+++

## Introduction

With this module, the mission maker can define combat missions that will be referenced in the COMBAT ZONES radio menu.
In this menu, each of the missions can be checked (briefing), activated (if inactive) or deactivated (if active), smoke markers or lighting flares can be requested.

## How to set up a mission

Let's start by saying that you can clone the *[VEAF-Demo-Mission](https://github.com/VEAF/VEAF-Demo-Mission)* repository and use it as an example (or fork it and create a new mission from your fork).

### Load the script and its prerequisites

Please refer to the [Load scripts in the mission](../concepts/load-with-triggers.md) for loading the scripts.

### How to configure the script in a mission

In the previous paragraph, you were told to create a *missionConfig.lua* script containing all the mission-specific code.
Now we're going to use it to define combat missions.

Here is the kind of code that you must add in the mission initialisation script:

```lua
-- configure COMBAT ZONE
if veafCombatZone then
 veafCombatZone.logInfo("Loading configuration")
 veafCombatZone.AddZone(
    VeafCombatZone.new()
      :setMissionEditorZoneName("combatZone_CrossKobuleti")
      :setFriendlyName("Cross Kobuleti")
      :setBriefing("This is a simple mission\n" ..
             "You must destroy the comm antenna\n" ..
             "The other ennemy units are secondary targets\n")
      :initialize()
  )
  veafCombatZone.AddZone(
    VeafCombatZone.new()
      :setMissionEditorZoneName("combatZone_Batumi")
      :setFriendlyName("Batumi airbase")
      :setBriefing("A BTR patrol and a few manpads are dispersed around the Batumi airbase")
      :setTraining(true)
      :initialize()
  )

  veafCombatZone.initialize()
end
```

Let's detail this code.

First, we define two combat zones: the *Cross Kobuleti* and the *Batumi airbase*.
For each of these zones, we specify a mission editor zone name (more about this later), a friendly name (that will be displayed in the radio menu) and a briefing (also displayed when getting info about a combat zone).
One of the zone is considered a *training zone* (with the `:setTraining(true)` code). This means that:

- the count of remaining units in the briefing will be split into unit type (e.g. *2 Shilka, 4 SA-18*)
- the location of the marker smoke will be the exact barycenter of all the remaining units, instead of being the center of the zone

Then we call the `:initialize()` method to finish preparing the combat zone.

Eventually, when all our zones are defined, we call `veafCombatZone.initialize()` to initialise the script (build the combat zones and prepare the radio menu).

### How to setup a Combat Zone in the mission editor

A combat zone starts with a mission editor zone object.
So, first thing first, you must place such an object on the map and name it with a memorable name.

![create-combatzone-01](../../_images/create-combatzone-01.png)

Then, you must add units inside the mission editor zone object (this is very important, as only the units inside the zone will be part of the combat zone), and name the groups with a name that starts with the mission editor zone name (this is equally important, as groups named otherwise will not be part of the combat zone).

![create-combatzone-02](../../_images/create-combatzone-02.png)

Groups can either be actual DCS groups or statics (as the one in the screenshot above) or special groups containing a VEAF command.
Whatever type a group is, **the first unit** of the group can have specific options inserted in its name, conditionning the spawn of the group (or the execution of the command) when the mission is later activated.
The groups can have a route, which will be set on the actual group(s) that will be spawned when the mission is activated.

All these groups define *combat zone elements*, which are stored in memory until the zone is activated.
**They'll be destroyed at mission start !**

#### Spawn options

The options all start with a pound symbol, followed by a keyword, an equal sign and a value (surrounded with french quotes if it's a text value).
E.g. `#spawnGroup="patrol-group1"`, or `#spawnCount=1`
All these options are, as their name implies, optional.

- *spawnRadius* (in meters) the spawn point of the *combat zone element* will be chosen randomly in this radius around the actual group position in the mission editor. E.g. `#spawnRadius=500`
- *spawnChance* (in percent) the *combat zone element* will have *spawnChance* out of 100 chances of being actually spawned or executed. E.g. `#spawnChance=25`
- *spawnGroup* (text) (used with *spawnCount*) groups together *combat zone elements*, in such a way that only a certain number of them will actually get spawned or executed. This is useful to randomise the position of an enemy group in the mission, by specifying all the possible spawn points with a different group. E.g. `#spawnGroup="manpad-group1",#spawnCount=2`, repeated over a few mission editor groups in the zone, will make only 2 of them spawn (based on the *spawnChance* of each one).
- *spawnCount* (number) (used with *spawnGroup*) defines the number of *combat zone elements* grouped together with *spawnGroup* that will always spawn or be executed.

**Important note**: DCS has a way of making unit and group names unique by adding a pound symbol followed by a 3 digits number. This is all well and good, but if you separate the different options in a unit name with spaces, only the first option will be kept (DCS mission editor will automatically erase the rest and replace it with its numbering system).
The solution is to use other characters to separate the options in the unit name, such as a comma. E.g. `#spawnGroup="patrol-group1",#spawnCount=1,#spawnChance=25`

**Example of randomisation by using *spawnGroup* and *spawnCount***

![create-combatzone-03](../../_images/create-combatzone-03.png)

In this example, we created a zone named *combatZone_Batumi*, with 6 mission editor groups named *combatZone_Batumi - manpad-group1*, each one a manpad group with its first unit named *#spawnGroup="manpad-group1",#spawnCount=2,#spawnChance=25* (DCS adds its numbering system to make the names unique).

The result is a randomisation of these manpad groups: each time the combat zone is activated, two random manpad groups out of the six possible groups are spawned.

![create-combatzone-04](../../_images/create-combatzone-04.png)

(this animation also shows a random BTR patrol)

#### VEAF commands

Instead of "simply" adding a DCS group to the mission editor, it's possible to define a *VEAF command* that will be executed when the *combat zone element* will be activated.
This is done by using the *#command* spawn option; e.g. `#command="_spawn group, name sa6"`.
The command itself can be any VEAF command that will be recognized inside a marker at runtime (see [Markers](../concepts/usermarks.md)), such as:

- a *_spawn* command (see the [veafSpawn](./veafSpawn.md) documentation); e.g. `#command="_spawn group, name sa6"`
- an *alias* (see the [veafShortcuts](./veafshortcuts.md) documentation); e.g. `#command="-samlr"`
- the definition of a *named point* (see the [veafNamedPoints](./veafnamedpoints.md) documentation); e.g. `#command="_name point Kobuleti City"`
- the start of a *CAS mission* (see the [veafCasMission](./veafCasMission.md) documentation); e.g. `#command="_cas, defense 3, size 5"`
- a command for the *security* module (see the [veafSecurity](./veafsecurity.md) documentation); e.g. `#command="_auth mysecretp@ssw0rd"`

The *#command* spawn option can, of course, be combined with other spawn options.

#### Conclusion

Using this powerful script, it's very easy to define a complex, dynamic, randomized yet hand-crafted mission that can be triggered as will by the players when they want to use it.
For example, I designed a combat zone that starts a vivid ground battle with (for each side):

- a static air defense group: `#command="_spawn samgroup, size 1, defense 4"`
- 3 armor platoons, moving toward their enemy counterpart: `#command="_spawn armorgroup, size 5, armor 5, defense 0" #spawnradius=500`
- 4 manpad groups, of which only 2 will actually spawn: `#spawnGroup="RU-manpad",#spawnCount=2,#spawnChance=25`

## How to use in a mission

Use the radio menus to :

- get information (briefing) about a combat zone
- activate or deactivate a combat zone
- request a smoke marker on the combat zone
- request a lighting flare dropped over the combat zone
