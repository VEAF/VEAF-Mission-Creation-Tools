# veafAssets.lua module documentation

## Introduction

This module creates a radio menu (VEAF / ASSETS) that allows the players to manage the mission air assets.

For each air asset, they can request information (is the asset alive ? What information has the mission maker set up - radio frequencies, TACANs, etc.), respawn the asset (and its eventual linked DCS groups, e.g. escort planes for a High Value Target), dispose of the asset (if set up by the mission maker).

## How to set up a mission

Let's start by saying that you can clone the *[VEAF-Demo-Mission](https://github.com/VEAF/VEAF-Demo-Mission)* repository and use it as an example (or fork it and create a new mission from your fork).

### Load the script and its prerequisites

In DCS mission editor, set up a "mission start" trigger that will :

* load the following scripts (in order) :
  * mist.lua (from the *community* folder)
  * veaf.lua
  * veafRadio.lua
  * veafAssets.lua
* run the following lua code : `veafRadio.initialize();veafAssets.initialize();`
* load a new file that you'll write, and that will initialize the veafAsset script specifically for your mission ; usually it's called *veafAssetsConfig.lua*, and if you follow our model (*VEAF-Demo-Mission*) it's stored in the *scripts* folder of your mission.

### How to configure the script in a mission

The *veafAssetsConfig.lua* file will declare a table, listing all the assets in your mission along with the information you want the players to receive.

Here's a annotated example:

```lua
veafAssets.Assets = {
    -- list the assets common to all missions below
    {sort=1, name="Arco", description="Arco (KC-135)", information="Tacan 11Y\nVHF 130.4 Mhz\nZone OUEST", linked={"Arco-escort1","Arco-escort2"}},
    {sort=2, name="Petrolsky", description="900 (IL-78M, RED)", information="VHF 267 Mhz", linked="Petrolsky-escort"},  
    {sort=3, name="Mig-28", description="Mig-29x2 (dogfight zone, RED)", disposable=true, information="They spawn near N41° 09' 31\" E043° 05' 08\""},
}
```

In this code, we define 3 assets.

First, *Arco* (the **name** attribute must contain the name of the group in DCS) is a tanker, described by "Arco (KC-135)" (the **description** field is the name that will appear in the radio menu).
It has information that players can request freely (in the **information** attribute); it also has two linked DCS groups (not listed in the assets list, although they could be) : *Arco-escort1* and 
*Arco-escort2* (these are the name of the groups in DCS).
When the players choose to respawn *Arco*, these linked groups will also automatically be respawned.

*Petrolsky* has the same characteristics, except that it has a single linked group, described using the concise syntax (a single string instead if a list).

*Mig-28* is an aggressor F5 ([of course](https://topgun.fandom.com/wiki/MiG-28)) which is **disposable**. It means that the player can choose not only to respawn it when they want to, but also to dispose of it when they don't want to play with it anymore.
In this particular case (an AI aggressor plane), the mission maker should put it in the mission with the "Late activation" setting checked, so it is only spawned when players respawn it with this script.

## How to use in a mission

The radio menu will list all the assets defined in the *veafAssets.Assets* table, and for each asset add submenus :

* *respawn* the asset and its linked groups
* *info* shows information about the asset, if provided in the **information** tag
* *dispose* disposes of the asset if **disposable** is set to *true*
