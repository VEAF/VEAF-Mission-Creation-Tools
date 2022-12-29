+++
title = "veafCarrierOperations"
weight = 13
+++

## Introduction

This module creates a radio menu (VEAF / CARRIER OPERATIONS) that allows the players to manage the aircraft carriers (CV) in the mission, at runtime.

For each CV, they can get information (including ATC) and start/end carrier air operations (CAO).
During CAO, the CV will sail into the wind at a speed and heading computed to get a specific wind speed right in front of the runway. A rescue helicopter (Pedro) and an emergency tanker can be placed in the mission and will be launched and recovered at appropriate times.
After some time (45 or 90 minutes), it will automatically sail at flank speed to its initial position.

## How to set up a mission

Let's start by saying that you can clone the *[VEAF-Demo-Mission](https://github.com/VEAF/VEAF-Demo-Mission)* repository and use it as an example (or fork it and create a new mission from your fork).

### Load the script and its prerequisites

In DCS mission editor, set up a "mission start" trigger that will :

* load the following scripts (in order) :
  * mist.lua (from the *community* folder)
  * veaf.lua
  * veafRadio.lua
  * veafCarrierOperations.lua
* run the following lua code : `veafRadio.initialize();veafCarrierOperations.initialize();`

### How to configure the script in a mission

The name that is given to the CV is central to all the configuration of this module.
For example, let's consider a John C. Stennis aircraft carrier steaming along its escort group.

* the DCS group is named "*CSG-74 Stennis*" (Carrier Strike Group)
* the aircraft carrier (DCS unit) is named "*CVN-74 Stennis*" (Cruiser Voler Nuclear, the acronym used by americans for their nuclear aircraft carriers)
* the Pedro helicopter (DCS unit) is aptly named "*CVN-74 Stennis Pedro*"
* the S3-B tanker (DCS unit) is named "*CVN-74 Stennis S3B-Tanker*"

The script first searches for aircraft carriers in the mission.
For each aircraft carriers, it searches for units with the same name concatenated with " Pedro" (these are the rescue helos) and with " S3B-Tanker" (these are the emergency tankers)

## How to use in a mission

Use the radio menus to :

* start the carrier air operations (CAO) for a specific carrier, either for 45 or 90 minutes (available only when they are not yet started)
* stop the CAO (available only when they are started)
* request information (ATC, recovery bearing, etc.)
