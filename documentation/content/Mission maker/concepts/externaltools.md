+++
title = "External tools"
weight = 4
chapter = false
+++

The VEAF Mission Creation Tools contains .lua scripts that are meant to be ran inside a DCS mission, and also other tools that are meant to act on a mission file from the outside.

These tools are mainly used in the mission building and extraction pipelines (see [workflow](../../#workflow)).

### Normalizer

DCS mission editor saves the mission data as a set of .lua files compressed in the .miz mission file.

* _mission_ - contains the details of the mission, including all the groups and units. This is the most important file.
* _theatre_ - the name of the map where the mission takes place
* _options_ - a set of options enforced in the mission
* _warehouses_ - data about the fuel and munitions providers in the mission
* _l10n/DEFAULT/dictionary_ - all the names of all the mission objects, mapped to arbitrary keys used in the other files
* _l10n/DEFAULT/mapResource_ - all the other files of the mission are listed here

Unfortunately, due to the way lua handles tables and to the way the mission editor is programmed, there is a good chance the content of these lua files is completely shuffled everytime a mission is saved, even if the change is small.

This makes comparing two versions of a mission difficult, and merging concurrent editions in a source control system (e.g. GIT) all but impossible.

The _veafMissionNormalizer_ script can be used in the extraction pipeline (_extract.cmd_) to normalize the output of the DCS mission editor; this means that the data inside the lua files is sorted and written in a predefined way (always the same).

It is way easier to pinpoint modifications in the resulting lua files than in the raw DCS mission editor files.

Example of use:

* a user edits the mission and saves it
* the normalizer is ran (e.g. via the _extract.cmd_ command) and the files are cleaned up
* the files are stored in the source control system (e.g. GIT)
* another user edits the mission and saves it
* the normalizer is ran (e.g. via the _extract.cmd_ command) and the files are cleaned up
* the user compares the resulting files with the last version in the source control repository and (hopefully) finds his edit

#### New - 2020.05.23

The normalizer now removes unused dictionary keys from the `l10n\DEFAULT\dictionary` file.

### Radio preset frequencies injector

A lot of planes in DCS can use presets in their onboard radios. This makes it easy to share a pre-briefed frequency plan (a.k.a. crystallization) among players.

Unfortunately, editing these presets in the DCS mission editor, and maintaining the crystallization, is hard.

The VEAF radio preset frequencies injector is a lua script that can be run in the build and/or the extract pipelines.

It parses the mission files, and uses an internal database to find out how to configure the planes in the mission.

The configuration is stored in a mission-specific lua file and its syntax is simple.

It's a single table called _radioSettings_, that contains entries (freely named) which can specify a unit type, a coalition and/or a country.

When the script runs, each unit in the mission is tested against the data in this table, and if it matches one of the entries then it's processed. When processing a unit, its radio configuration is replaced with the one in the _radioSettings_ entry

Example:

```lua
radioSettings = {
    ["blue F-14B"] = {
        ["type"] = "F-14B",
        ["coalition"] = "blue",
        ["Radio"] = {
            [1] = {
                ["channels"] = {
                    [1] = 243,
                    ...
                    [20] = 271.7,
                }, -- end of ["channels"]
                ["modulations"] = {
                    [1] = 0,
                    ...
                    [20] = 0,
                }, -- end of ["modulations"]
            }, -- end of [1]
        }, -- end of ["Radio"]
```

In this example, all the _blue_ units of type _F-14B_ will be configured with these radio settings. F-14 in other coalitions and other unit types will not be processed.

Other example:

```lua
radioSettings = {
    ["Ka-50"] = {
        ["type"] = "Ka-50",
        ["Radio"] = {...}
```

All the Ka-50 in the mission will be processed, regardless of their coalition.

### Stand alone tool

The standalone VEAF tool does not need anything else than [NodeJS](https://nodejs.org/en/).

#### Install the tool

The VEAF tool is included in the VEAF Mission Creation Tools, but it can be installed independently by simply installing the *veaf-mission-creation-tools* npm package globally.

Simply use the `npm install -g veaf-mission-creation-tools` command in a shell (command line) and the tool will be installed.

![veaf-tools-01](/VEAF-Mission-Creation-Tools/images/veaf-tools-01.png?raw=true "veaf-tools-01")

You'll be able to run the tool with the `veaf-tools` command in a shell.

![veaf-tools-02](/VEAF-Mission-Creation-Tools/images/veaf-tools-01.png?raw=true "veaf-tools-02")

The tool contains inline help for all commands. For example, the help for the `inject` command can be displayed with `veaf-tools inject --help`.

![veaf-tools-03](/VEAF-Mission-Creation-Tools/images/veaf-tools-03.png?raw=true "veaf-tools-03")

### Time and weather versioning

Thanks to this tool, it's really easy to produce multiple versions of an existing mission, with different start times and weather.

It's even possible to inject real weather into a mission.

This magic is handled by the `inject` and the `injectall` commands.

To use these commands, you'll need a `configuration.json` file containing all the configuration data, including your CheckWX API key (go to [this page](https://www.checkwx.com/api/newkey) on the CheckWX site to get one, free of charge).

This file will be generated for you with defaults values the first time you run the `inject` or `injectall` commands.
You'll simply need to edit it and enter your CheckWX API key.

#### The `injectall` command

To use the `injectall` command, you'll need a file describing all the versions you want to generate. It's usually named `versions.json`.

Let's explain the syntax of the `versions.json` file with a few examples.

```json
{
  "variableForMetar": "METAR",
  "targets": [
    {
      "version": "0200-real",
      "realweather": true,
      "time": 7200
    },
    {
      "version": "0600-overcast-low",
      "weatherfile": "overcast-low.lua",
      "time": 21600
    },
    {
      "version": "0700-scattered",
      "weather": "KQND 150856Z AUTO VRB04G11KT 9999 SCT050 SCT100 39/05 A2989 RMK AO2 SLP103 WND DATA ESTMD T03900045 50007",
      "time": 25200
    }
  ]
}
```

Each version (target) is described in an element of the `targets` table.

The `version` key contains the name of the version ; it'll be used by the tool to name the target mission file.

Then, the `time` key sets the mission start time, in seconds after midnight. Thats the same format as in the DCS mission file.

And finally, there are 3 ways of specifying the weather :

* with the `realweather` key, set to `true`; the tool will connect to CheckWX, get the weather in your mission's theater (coordinates are defined, for each theater, in the `configuration.json` file )
* with the `weather` key, set to a METAR text ; the tool will interpret the METAR and set the weather accordingly (if it fails to do it, please contact me on the [VEAF Discord](https://tinyurl.com/veafdisc) so I can correct the code)
* with the `weatherfile` key, set to the name of a lua file containing the weather part of a DCS mission file (the `weather` table)

The first two options for weather (`realweather` and `weather`) will replace the variable you specified in the `variableForMetar` key with the METAR text.

For example, if you set the `variableForMetar` key to `METAR`, then place `${METAR}` somewhere in your briefing (or elsewhere) and it will be replaced by the actual METAR being injected in your mission.

#### The `inject` command

The `inject` command is configured with command-line parameters, so you can use it without a configuration file.

The configuration elements are the same as in the `injectall` configuration file, but you specify them on the command line.

Example : `veaf-tools inject mymission.miz mynewmission.miz -s 21600 --variable METAR --real` will create the file `mynewmission.miz` from the source `mymission.miz`, inject the real weather using CheckWX, and set the mission start time to 0600L.

### DCS data exporter

TODO
