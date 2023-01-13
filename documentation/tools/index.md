# [![VEAF-logo]][VEAF website] Mission Creation Tools - tools documentation

# /!\ **WORK IN PROGRESS** /!\
The documentation is being reworked, piece by piece. 
In the meantime, you can browse the [old documentation](../old_documentation/_index.md).

**GO BACK TO THE MAIN [MISSION CREATION TOOLS INDEX](../index.md)**

## Introduction

The VEAF Mission Creation Tools provide scripts that make missions behave dynamically, and tools that are used to manipulate missions.

## veaf-tools application

This nodeJS application is a collection of tools that can be used to manipulate missions.

At the moment, it contains the following tools:
- Weather injector
- mission selector

See the [VEAF Tools application documentation page](veaf-tools.md) for more details.

### Weather injector

The Weather injector is a tool that transforms a single mission file into a collection of missions, with the same content but different weather and starting conditions.

It can be used to inject a predefined DCS weather definition, read a METAR and generate a mission with the corresponding weather, or even use real-world weather.

It can also create different starting time and dates for the mission, either with absolute values (e.g. 26/01/2023 at 14:20), or with predefined "moments" (e.g. 2 hours after sunset).

This is a very useful tool to use with a server that runs 24/7 and that needs to have different weather conditions for time it starts the same mission.

See the [VEAF Tools application documentation page](veaf-tools.md) for more details.

### Mission selector

The mission selector is used to start a dedicated server with a specific mission, depending on a schedule that is defined in a configuration file.

See the [VEAF Tools application documentation page](veaf-tools.md) for more details.

## LUA dictionary normalizer

TBD

Full documentation is available [here](lua_dictionary_normalizer.md).

## Contacts

If you need help or you want to suggest something, you can:

* contact [Zip][Zip on Github] on Github
* go to the [VEAF website]
* post on the [VEAF forum]
* join the [VEAF Discord]


[Badge-Discord]: https://img.shields.io/discord/471061487662792715?label=VEAF%20Discord&style=for-the-badge
[VEAF-logo]: ../.images/logo.png?raw=true
[VEAF Discord]: https://www.veaf.org/discord
[Zip on Github]: https://github.com/davidp57
[VEAF website]: https://www.veaf.org
[VEAF forum]: https://www.veaf.org/forum

[demo-mission-structure]: ../.images/demo-mission-structure.png?raw=true
[workflow-01]: ../.images/editor_workflow.png?raw=true
