# VEAF-Mission-Creation-Tools

[![Badge-Discord]][Link-Discord]

All scripts, libraries and documentation needed to build a dynamic mission in DCS using the VEAF scripts

## How to work on this package ?

Read the [documentation]()!

## What is this ? Is it like Moose ?

A bit like that, and not.
It uses MiST (and a tiny teeny part of Moose, for air spawns) to handle lots of runtime functionality :
- spawning of units and groups (and portable TACANs)
- air-to-ground missions 
- air-to-air missions
- transport missions
- carrier operations (not Moose)
- tanker move
- weather and ATC
- shelling a zone, lighting it up
- managing assets (tankers, awacs, aircraft carriers) : getting info, state, respawning them if needed
- managing named points (position, info, ATC)
- managing a dynamic radio menu
- managing remote calls to the mission through NIOD (RPC) and SLMOD (LUA sockets)
- managing security (not allowing everyone to do every action)
- define groups templates

And also lots of design-time functionality :
- automatically populating FARPs and grass runways with all that is neeed
- spawning things at the start of a mission (interpreter of data stored in a fake unit on the mission)
- normalizing a mission file (removing useless key in the dictionary, sorting everything) so it's easy to compare versions
- injecting radio presets globally (e.g. all blue F18 get a standard freq plan)
- injecting real weather in a mission

And probably other things I forget ;)

[Badge-Discord]: https://img.shields.io/discord/471061487662792715?label=VEAF%20Discord&style=for-the-badge
[Link-Discord]: https://tinyurl.com/veafdisc
