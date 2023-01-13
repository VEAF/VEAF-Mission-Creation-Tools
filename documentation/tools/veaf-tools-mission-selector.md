# [![VEAF-logo]][VEAF website] Mission Creation Tools - veaf-tools Weather Injector command

# /!\ **WORK IN PROGRESS** /!\
The documentation is being reworked, piece by piece. 
In the meantime, you can browse the [old documentation](../old_documentation/_index.md).

**GO BACK TO THE [TOOLS INDEX](index.md)**

## Introduction

The Mission selector is part of the VEAF Tools application. Read the installation and description in the global [VEAF Tools application documentation](./veaf-tools.md).

## Using the Mission selector

The goal of the mission selector is to choose a mission based on a schedule that you'll provide, and setup your server to start with the selected mission.

Therefore, some prerequisites are needed:
- you need to have a [dedicated DCS server](https://www.digitalcombatsimulator.com/en/downloads/world/server_beta/) configured on your machine
- you need a list of missions that you want to use (a library of sorts); you can use the [Weather injector](./veaf-tools-weather-injector.md#using-the-weather-injector) to generate missions with different weather conditions based on a single template.
- you need a schedule that defines which mission to run at which time; you should think about this in advance! Here's a [Google Sheet][veaf-mission-selector-helper-google-sheet] that will help you to define your schedule, generate the schedule definition file, and construct the DCS server mission list.

The way it works is quite simple: you setup a `serverSettings-default.lua` file. This file is the same as the classic `serverSettings.lua`; it contains the list of all your existing missions (it can easily become huge, with the all the weather and starting conditions!). 

The Mission selector tool reads the schedule, decide which mission it will select, and searches for it in the `serverSettings-default.lua` file. If it finds it, it creates a `serverSettings.lua` file and sets the `current` and `listStartIndex` properties set to the correct index for the selected mission; the next time the server starts, it will automatically load this misison..

### Command line options

The Mission selector tool is designed to be launched from the command line.

It's actually a specific command of the *veaf-tools* application.

```cmd
veaf-tools select-mission <source> <target> <configuration>
```

#### Mandatory command-line options

The following command-line options are mandatory; don't use the option name, they're positional arguments (i.e. you must specify them in the order they're listed here):

- `--source`: the path to the default server settings file. This file will be copied to the target file, and the `current` and `listStartIndex` properties will be updated. See [Default server settings](#default-server-settings).

- `--target`: the path to the actual server settings file that will be used by the server. This file will be created by the tool.

- `--configuration`: the path to the schedule configuration file. This file will be read by the tool to determine which mission to select. See [Schedule definition file](#schedule-definition-file).

Example:

```cmd
veaf-tools select-mission serverSettings-default.lua serverSettings.lua schedule.json
```

#### Optional command-line options

The following command-line options are optional, and are available for both the `inject` and `injectall` commands:

- `--verbose`: if set, the tool will output more information about what it's doing.

- `--quiet`: if set, the tool will output less information about what it's doing. 

### Default server settings

As we said, this is a copy of the main `serverSettings.lua` file, with all the missions that you want to use. [Here][veaf-mission-selector-helper-example-serversettings] is an example of such a file.

It's very important that all the available missions are listed, and that the indexes of the missions array is correct. You can use the [Google Sheet helper][veaf-mission-selector-helper-google-sheet] tab "Mission list helper" to help with renumbering the missions.

### Schedule definition file

The schedule definition file is a JSON file that defines the schedule of your missions. [Here][veaf-mission-selector-helper-example-cron] is an example of such a file.

It defines several items:

- the server name, in the `server` element; it's not used.
- the default mission, in the `default` element; it's used to select a mission if no other mission corresponds to the current time in the schedule.
- the `moments` collection; this is the heart of the system; we'll describe this below.

Each moment in the `moments` collection defines a mission to run at a specific time. It has the following elements:

- `//comment`: optional; a comment to describe the moment
- `month`: the month of the year, from 1 to 12; you can use `null` to indicate all months, or simply omit the element
- `dayOfMonth`: the day of the month, from 1 to 31; you can use `null` to indicate all days, or simply omit the element
- `dayOfWeek`: the day of the week, from 1 to 7, or as a string (english or french, either the complete day name or the 3 first letters); you can use `null` to indicate all days, or simply omit the element
- `hour`: the hour of the day, from 0 to 23, or as a string ("morning", "afternoon", "day", "night", "matin", "après-midi", "jour", "nuit"); you can use `null` to indicate all hours, or simply omit the element
- `missions`: an array of missions to choose from; the mission selector will randomly choose one of them
- `mission`: a single mission; the mission selector will use this mission

### Google sheet helper

We made this [handy Google Sheet][veaf-mission-selector-helper-google-sheet] to help you with the schedule definition file. It has 3 tabs:
- `Calendar`: lets you define the schedule of your missions by adding a line for each schedule.
- `Mission selector cron.json helper`: here the serverCron.json file will be generated from the data entered in the "Calendar" tab. You can copy/paste the content of the C column in your schedule definition file (please remove the extra comma at the end of the last "moment" row)
- `Mission list helper`: with this tool, you can easily renumber a modified missions list in the `serverSettings-default.lua` file. Start by pasting your existing mission list lua code (even if it's not numbered correctly) in the A column; you can then copy/paste the content of the C column in your `serverSettings-default.lua` file, it's renumbered correctly.`

Here's [an example][veaf-mission-selector-helper-example-cron-generated] of a generated schedule definition file.

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

[veaf-mission-selector-helper-google-sheet]: https://docs.google.com/spreadsheets/d/1DP78g43NsmC7hjyrVWKnPd7xNSb1vUi5PIRP9vxmfjo

[veaf-mission-selector-helper-example-serversettings]: ../.examples/serverSettings-default.lua
[veaf-mission-selector-helper-example-cron]: ../.examples/serverCron-example.json
[veaf-mission-selector-helper-example-cron-generated]: ../.examples/serverCron-example_generated.json