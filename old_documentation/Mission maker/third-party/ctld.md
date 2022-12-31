+++
title = "CTLD"
weight = 101
+++

## Introduction

[CTLD](https://github.com/ciribob/DCS-CTLD) is a third-party script that allow the players of a well-configured mission to transport troops and deployable crates with helicopters and transport airplanes.

## How to set up a mission

Let's start by saying that you can clone the *[VEAF-Demo-Mission](https://github.com/VEAF/VEAF-Demo-Mission)* repository and use it as an example (or fork it and create a new mission from your fork).

### Load the script and its prerequisites

In DCS mission editor, set up a "mission start" trigger that will :

* load the following scripts (in order) :
  * mist.lua (from the *community* folder)
  * CTLD.lua
* run the following lua code : `ctld.initialize();`
* load a new file that you'll write, and that will initialize the veafAsset script specifically for your mission ; usually it's called *veafCTLDConfig.lua*, and if you follow our model (*VEAF-Demo-Mission*) it's stored in the *scripts* folder of your mission.

### How to configure the script in a mission

The *veafCTLDConfig.lua* file should contain CTLD-specific configuration.

As CTLD is not part of the VEAF Mission Creation Tools, we'll simply explain the most often used sections of this configuration. For more information, see the [CTLD](https://github.com/ciribob/DCS-CTLD) project page.

#### Pickup zones

The ``ctld.pickupZones`` table defines a list of Trigger Zone (or ship) names that will be configured as CTLD pickup zones.

In the active radius of a pickup zone, one can load troops and spawn deployable crates.

Example:

```lua
ctld.pickupZones = {
    { "pickzone1", "none", -1, "yes", 0 },
    { "pickzone2", "none", -1, "yes", 0 },
    { "pickzone3", "none", -1, "yes", 0 },
    { "pickzone4", "none", -1, "yes", 0 },
    { "pickzone5", "none", -1, "yes", 0 },
    { "CVN-74 Stennis", "none", 10, "yes", 0, 1001 }, -- instead of a Zone Name you can also use the UNIT NAME of a ship
    { "LHA-1 Tarawa", "none", 10, "yes", 0, 1002 }, -- instead of a Zone Name you can also use the UNIT NAME of a ship
}
```

#### Transport pilots

The ``ctld.transportPilotNames`` table lists the names of all the pilots that will be allowed to use CTLD. If a client unit in the mission has a pilot name that is in this list, then the player piloting this unit will be allowed to use CTLD.

Example:

```lua
ctld.transportPilotNames = {
    "helicargo1",
    "helicargo1",
    "helicargo2",
    "helicargo3",
    "helicargo4",
    "helicargo5"
}
```

#### Load limits

The ``ctld.unitLoadLimits`` table overloads the default load limits for specific unit types. In the following example, we allow the Mi-8 to transport 24 units of load:

```lua
ctld.unitLoadLimits = {
    ["Mi-8MT"] = 24
}
```
