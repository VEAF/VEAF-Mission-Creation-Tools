# [![VEAF-logo]][VEAF website] Mission Creation Tools - veaf-tools application

# /!\ **WORK IN PROGRESS** /!\
The documentation is being reworked, piece by piece. 
In the meantime, you can browse the [old documentation](../old_documentation/_index.md).

## Introduction

This nodeJS application is a collection of tools that can be used to manipulate missions.

At the moment, it contains the following tools:
- Weather injector
- mission selector

### Weather injector

The Weather injector is a tool that transforms a single mission file into a collection of missions, with the same content but different weather and starting conditions.

It can be used to inject a predefined DCS weather definition, read a METAR and generate a mission with the corresponding weather, or even use real-world weather.

It can also create different starting time and dates for the mission, either with absolute values (e.g. 26/01/2023 at 14:20), or with predefined "moments" (e.g. 2 hours after sunset).

This is a very useful tool to use with a server that runs 24/7 and that needs to have different weather conditions for time it starts the same mission.

[Demonstration video][veaftools-injectall-demo]

### Mission selector

The mission selector is used to start a dedicated server with a specific mission, depending on a schedule that is defined in a configuration file.


## Installation

This is an autonomous tool, it does not need a specific VEAF Mission Creation Tools environment (as described [here](..\environment\index.md)).

It's therefore very easy to install on a server, or on your own computer.

***Nota bene: this chapter is also available as a [tutorial video][install-chocolatey-nodejs-veaftools]***

You'll need to install these tools on your computer:

- *nodeJS*: you need NodeJS to run the javascript programs in the VEAF mission creation tools; see [here](https://nodejs.org/en/)
- *yarn*: you need the Yarn package manager to fetch and update the VEAF mission creation tools; see [here](https://yarnpkg.com/)

### Install the tools using Chocolatey

The required tools can easily be installed using *Chocolatey* (see [here](https://chocolatey.org/)).

To install Chocolatey, use this command  in an elevated (admin) Powershell prompt:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
```

After *Chocolatey* is installed, install NodeJS by typing this simple command in a command prompt:

```cmd
choco install -y nodejs
```

Then close and reopen the command prompt.

### Install the veaf-tools application

In a command prompt, go to the directory where you want to install the veaf-tools application, and type:

```cmd
npm install -g veaf-mission-creation-tools
```

Then close and reopen the command prompt.

## General usage of the application

To run the VEAF tools, simply type `veaf-tools` in a command prompt.

[![veaftools-options]][veaftools-options]

## Using the Weather injector

The Weather injector is actually two commands of the veaf-tools application.

The `inject` command will inject the weather in the mission file you specify, and create a new mission file with the weather and starting conditions you specified in the command line options.

Type `veaf-tools inject --help` to get help:

[![veaftools-inject-options]][veaftools-inject-options]

The `injectall` command will read a versions file containing several weather and starting conditions, and inject them in the source mission file, creating a collection of target mission files.

Type `veaf-tools injectall --help` to get help:

[![veaftools-injectall-options]][veaftools-injectall-options]

### Options

#### Mandatory command-line options

The following command-line options are mandatory for both the `inject` and `injectall` commands; don't use the option name, they're positional arguments (i.e. you must specify them in the order they're listed here):

- `--source`: the path to the mission file to inject the weather in.

- `--target`: the path to the mission file to create with the injected weather. With the `injectall` command, "${version}" will be replaced by the name of the version being generated.

Additionally, the `injectall` command must have the `--configuration` option that points to the versions configuration file. Again, this is a positional argument, so don't use the option name.

Example:

```cmd
veaf-tools inject source.miz target.miz 
```

or

```cmd
veaf-tools injectall source.miz target-${version}.miz versions.json
```

#### Optional command-line options

The following command-line options are optional, and are available for both the `inject` and `injectall` commands:

- `--verbose`: if set to *true*, the tool will output more information about what it's doing.

- `--quiet`: if set to *true*, the tool will output less information about what it's doing. 

- `--nocache`: if set to *true*, the tool will not use the cache for the weather files. This is useful if you want to force the tool to fetch the weather from the CheckWX API each time it runs.

#### Common options

The `injectall` command eventually calls the same code as the `inject` command to inject the weather into a target mission file, with the options defined in each target of the configuration file. 

Therefore, all the options that can be set in each target of the configuration file for the `injectall` command, can also be set as command-line options for the `inject` command.

Here are the available options, with each time the command-line option followed by the corresponding target option:

- `--real`, `realweather`: if set to *true*, the weather will be fetched from the real world using CheckWX (see ["Injecting real world weather"](#injecting-real-world-weather)).

- `--clearsky`, `clearsky`: if set to *true*, and if real-world weather is fetched, the cloud cover will be limited to 3 octas. This allows for real weather, but clear enough for Close Air Support.

- `--metar`, `metar`: if set to a valid [METAR](https://en.wikipedia.org/wiki/METAR), the weather will be generated from the parsed METAR (e.g. *UG27 221130Z 04515KT +SHRA BKN008 OVC024 Q1006 NOSIG*)

- `--start`, `time`: the starting time of the mission in seconds after midnight

- `--variable`, `variableForMetar`: the name of the variable that will be replaced by the METAR fetched from CheckWX; it's a useful feature to show the weather in the briefing.

- `--weather`, `weatherFile`: the path to the DCS weather file to use as a static weather definition.

- `--dontSetToday`, `dontSetToday`: if set to *true*, the date of the mission will not be set to today's date.

- `--dontSetTodayYear`, `dontSetTodayYear`: if set to a valid year, and dontSetToday is set to `false`, the year of the mission will be set to the specified year while the rest of the date is set to today's date.

### Versions file

The versions file is a JSON file that contains the weather and starting conditions you want to inject in the mission file, when using the `injectall` command.

It contains several sections:

- `position`: the coordinates of the mission, used to compute the sunset and sunrise time.

- `moments`: an array of moments, each moment defining a specific time and date that can be used in the `targets` section. 
They're defined with Javascript expressions and time values; you can use the  *sunset* and *sunrise* variables (e.g. 3h after sunset: `sunset + 3*60`, or 15 past 9 pm: `21:15`). 
By default, these moments are already defined:

  - night: 02:00
  - beforedawn: 01h30 to sunrise
  - sunrise: sunrise
  - dawn: 0h30 after sunrise
  - morning: 1h30 after sunrise
  - day: 15:00
  - beforesunset: 1h30 to sunset
  - sunset: sunset

- `targets`: an array of targets, each target containing the weather and starting conditions that will be used to create a specific version of the mission file.

Each target can contain the options listed [here](#common-options), and must define the name of the version that will be generated with `version` (used to create the name of the mission file; e.g. `my-mission-beforedawn-real-clear.miz` from `my-mission.miz`).

Example of a versions file:

```json
{
  "variableForMetar": "METAR",
  "moments": 
    {
      "onehour_tosunrise" : "sunrise-60*60",
      "late_morning" : "sunrise+120*60"
    },
  "position": 
    {
      "lat": 42.355691,
      "lon": 43.323853,
      "tz": "Asia/Tbilisi"
    },
  "targets": [
    {
      "version": "beforedawn-real-clear",
      "realweather": true,
      "clearsky": true,
      "moment": "beforedawn"
    },
    {
      "version": "beforesunrise-real",
      "realweather": true,
      "moment": "onehour_tosunrise"
    },
    {
      "version": "dawn-broken",
      "weatherfile": "broken-1.lua",
      "moment": "dawn"
    },
    {
      "version": "dawn-crosswind-vaziani",
      "weather": "UG27 221130Z 04515KT CAVOK Q1020 NOSIG",
      "moment": "dawn"
    }
  ]
}
```

### Configuration file

The configuration file is located in the working directory of the tool, and is named `configuration.json`.

It will be created automatically the first time you run the tool, and contains the following sections:

- `theatres`: a list of theathers, with the coordinates where the weather will be looked up with CheckWX.

- `cacheFolder`: the folder where the weather cache files will be stored.

- `maxAgeInHours`: the maximum age of the weather cache files, in hours.

- `checkwx_apikey`: the API key to use to fetch the weather from CheckWX. Get one [here](https://www.checkwxapi.com/).

Example of a configuration file:

```json
{
  "theatres": {
    "caucasus": {
      "lat": 42.355691,
      "lon": 43.323853
    },
    "persiangulf": {
      "lat": 26.304151,
      "lon": 56.378506
    },
    "nevada": {
      "lat": 36.145615,
      "lon": -115.187618
    },
    "normandy": {
      "lat": 49.183336,
      "lon": -0.365908
    },
    "syria": {
      "lat": 32.666667,
      "lon": 35.183333
    },
    "marianaislands": {
      "lat": 14.079866,
      "lon": 145.15311411102653
    }
  },
  "checkwx_apikey": "53506465454660465040465",
  "cacheFolder": "./cache",
  "maxAgeInHours": 1
}
```

### Injecting real world weather

This is the default if there is no METAR nor DCS weather file specified in the options.

The weather will be fetched from the closest airport to the mission theater coordinates defined in the [`configuration.json`](#configuration-file) file.

The tool uses the CheckWX API to fetch the weather; you need to register to CheckWX and get a free API key (see [here](https://www.checkwxapi.com/)), and store it in the [`configuration.json`](#configuration-file) file.

The fetched weather will be stored in a cache file, so that the tool doesn't have to fetch the weather each time it runs. This is to avoid overloading the CheckWX API.

The cache location, as well as the cache expiration time, can be configured in the [`configuration.json`](#configuration-file) file.

Example of using `inject` to inject real world weather:

```cmd
veaf-tools inject my-mission.miz my-mission-real.miz --real
```

Example of using `injectall` to inject real world weather:

```json
{
  "variableForMetar": "METAR",
  "position": 
    {
      "lat": 42.355691,
      "lon": 43.323853,
      "tz": "Asia/Tbilisi"
    },
  "targets": [
    {
      "version": "beforedawn-real-clear",
      "realweather": true,
      "clearsky": true,
      "moment": "beforedawn"
    },
    {
      "version": "dawn-real",
      "realweather": true,
      "moment": "dawn"
    }
  ]
}
```

```cmd
veaf-tools injectall my-mission.miz my-mission-${version}.miz versions.json
```

### Injecting a predefined weather

Using either a METAR or a DCS weather file, you can inject a predefined weather in the mission file.

You can extract weather definition from a DCS mission by edition the `mission` file that is stored inside the ".miz" file (hint: it's a ZIP archive), and looking for the `["weather"]` section. Write this section in a LUA file, and use it as the `--weather` parameter or the `weatherFile` option.

Here's an example of a DCS weather definition:

```lua
["weather"] = {
	["atmosphere_type"] = 0,
    ["clouds"] = 
    {
        ["thickness"] = 200,
        ["density"] = 0,
        ["preset"] = "Preset13",
        ["base"] = 3400,
        ["iprecptns"] = 0,
    }, -- end of ["clouds"]
    ["cyclones"] = {
	}, -- end of ["cyclones"]
	["dust_density"] = 0,
	["enable_dust"] = false,
	["enable_fog"] = false,
	["fog"] = {
			["thickness"] = 0,
			["visibility"] = 0,
	}, -- end of ["fog"]
	["groundTurbulence"] = 26.656422237728,
	["qnh"] = 758.444,
	["season"] = {
			["temperature"] = 23.200000762939,
	}, -- end of ["season"]
	["type_weather"] = 2,
	["visibility"] = {
			["distance"] = 1593,
	}, -- end of ["visibility"]
	["wind"] = {
			["at2000"] = {
					["dir"] = 148,
					["speed"] = 10.604474819794,
			}, -- end of ["at2000"]
			["at8000"] = {
					["dir"] = 160,
					["speed"] = 12.07985101455,
			}, -- end of ["at8000"]
			["atGround"] = {
					["dir"] = 150,
					["speed"] = 4.5,
			}, -- end of ["atGround"]
	}, -- end of ["wind"]
}, -- end of ["weather"]
```

```cmd
veaf-tools inject my-mission.miz my-mission-real.miz --weather scattered-rain.lua
```

Or, if using `injectall`:

```json
{
  "variableForMetar": "METAR",
  "position": 
    {
      "lat": 42.355691,
      "lon": 43.323853,
      "tz": "Asia/Tbilisi"
    },
  "targets": [
    {
      "version": "dawn-broken",
      "weatherfile": "broken-1.lua",
      "moment": "dawn"
    }
  ]
}
```

```cmd
veaf-tools injectall my-mission.miz my-mission-${version}.miz versions.json
```

Using a METAR is easier, as you can get it from the internet. Here's an example:

```cmd
veaf-tools inject my-mission.miz my-mission-real.miz --metar "UG27 221130Z 04515KT CAVOK Q1020 NOSIG"
```

Or, if using `injectall`:

```json
{
  "variableForMetar": "METAR",
  "position": 
    {
      "lat": 42.355691,
      "lon": 43.323853,
      "tz": "Asia/Tbilisi"
    },
  "targets": [
    {
      "version": "dawn-crosswind-vaziani",
      "weather": "UG27 221130Z 04515KT CAVOK Q1020 NOSIG",
      "moment": "dawn"
    }
  ]
}
```

```cmd
veaf-tools injectall my-mission.miz my-mission-${version}.miz versions.json
```

## Using the Mission selector

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

[install-chocolatey-nodejs-veaftools]: ../.images/install-chocolatey-nodejs-veaftools.mp4?raw=true
[veaftools-options]: ../.images/veaftools-options.png?raw=true
[veaftools-inject-options]: ../.images/veaftools-inject-options.png?raw=true
[veaftools-injectall-options]: ../.images/veaftools-injectall-options.png?raw=true
[veaftools-injectall-demo]: ../.images/veaftools-injectall-demo.mp4?raw=true