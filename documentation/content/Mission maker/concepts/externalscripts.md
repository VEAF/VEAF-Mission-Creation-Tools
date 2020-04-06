+++
title = "External scripts"
weight = 4
chapter = false
+++

The VEAF Mission Creation Tools contains .lua scripts that are meant to be ran inside a DCS mission, and also other scripts that are meant to run outside a mission.

These scripts are mainly used in the mission building and extraction pipelines (see [workflow](../../#workflow)).

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

### DCS data exporter

TODO