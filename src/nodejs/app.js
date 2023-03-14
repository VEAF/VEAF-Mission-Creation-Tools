#!/usr/bin/env node

require('yargs')
  .scriptName("veaf-mission-creation-tools")
  .command('inject <source> [target]', 'Inject weather data in a DCS mission', (yargs) => {
    yargs
      .positional('source', {
        type: 'string',
        describe: 'path to the source mission file'
      })
      .positional('target', {
        type: 'string',
        describe: 'path to the target mission file'
      })
      .option('start', {
        alias: 's',
        type: "number",
        required: false,
        describe: "the new mission start time in seconds since midnight"
      })
      .option('date', {
        type: "number",
        required: false,
        describe: "the starting date of the mission, with an optional clock time (e.g. `20230126` or `202301260635` for 6:35am)"
      })
      .option('metar', {
        alias: 'm',
        type: "string",
        required: false,
        describe: "a METAR string that will be parsed for weather data, then injected"
      })
      .option('variable', {
        type: "string",
        required: false,
        describe: "all occurences of ${<variable>} in the dictionary file will be replaced with the METAR"
      })
      .option('weather', {
        alias: 'w',
        type: "string",
        required: false,
        describe: "path to a LUA file containing a DCS weather table that will be injected"
      })
      .option('real', {
        alias: 'r',
        type: "boolean",
        describe: "if set, connects to CheckWX to get real weather over the theatre; default if no weather or metar is specified"
      })
      .option('clearsky', {
        type: "boolean",
        describe: "if set, limits to 3 octas or less"
      })
      .option('verbose', {
        alias: 'v',
        type: "boolean",
        default: false,
        describe: "Verbosely log data to the console"
      })
      .option('quiet', {
        alias: 'q',
        type: "boolean",
        default: false,
        describe: "Be extra quiet"
      })
      .option('dontSetToday', {
        alias: 'dst',
        type: "boolean",
        default: false,
        describe: "Don't set today's date"
      })
      .option('dontSetTodayYear', {
        alias: 'dsty',
        type: "string",
        required: false,
        describe: "Set today's date, but specify another year"
      })
      .option('nocache', {
        alias: 'nc',
        type: "boolean",
        default: false,
        describe: "Don't use cached data"
      })
      .conflicts("metar", ["weather", "real"])
      .conflicts("weather", ["metar", "real"])
      .conflicts("real", ["weather", "metar"])
      .example("$0 inject test.miz --real")
      .example('$0 inject d:\\tmp\\test.miz -s 34000 -m "KQND 150856Z AUTO VRB04G11KT 9999 CLR 39/05 A2989 RMK AO2 SLP103 WND DATA ESTMD T03900045 50007"')
      .example("$0 inject ./tmp/test.miz ./tmp/newmission.miz --start 86000 --weather scattered.lua")
      .example("$0 inject ./tmp/test.miz ./tmp/newmission.miz --date 202301260635 --weather scattered.lua")
      .epilog('for more information visit https://github.com/VEAF/VEAF-Mission-Creation-Tools')
  }, (argv) => {
    const {injectWeather} = require('./veaf-weather-injector.js');
    injectWeather(
      {
        sourceMissionFileName: argv.source,  // the name of the source mission file (mandatory)
        targetMissionFileName: argv.target,  // the name of the target mission file (default to the source)
        missionStartTime: argv.start, // the new mission start time (default: do not change time)
        missionStartDate: argv.date, // the new mission start date (default: do not change date)
        metarString: argv.metar,  // a raw metar string to parse for weather injection
        clearsky: argv.clearsky, // real weather but limits to 3 octas or less
        weatherFileName: argv.weather, // a lua file with the DCS weather ready to inject
        variableForMetar: argv.variable, // the name of a variable that will be replaced with the METAR string in the mission dictionary
        trace: argv.verbose,
        quiet: argv.quiet,
        nocache: argv.nocache
      });
    })
    .command('injectall <source> <target> <configuration>', 'Use a configuration file to create multiple copies of a DCS mission with specific start time and weather', (yargs) => {
      yargs
        .positional('source', {
          type: 'string',
          describe: 'path to the source mission file'
        })
        .positional('target', {
          type: 'string',
          describe: 'path to the target mission file ; ${version} will be replaced by the name of the version being generated'
        })
        .positional('configuration', {
          type: 'string',
          describe: 'path to the configuration file'
        })
        .option('verbose', {
          alias: 'v',
          type: "boolean",
          default: false,
          describe: "Verbosely log data to the console"
        })
        .option('quiet', {
          alias: 'q',
          type: "boolean",
          default: false,
          describe: "Be extra quiet"
        })
        .option('nocache', {
          alias: 'nc',
          type: "boolean",
          default: false,
          describe: "Don't use cached data"
        })
        .example("$0 injectall test.miz opentraining.json")
        .epilog('for more information visit https://github.com/VEAF/VEAF-Mission-Creation-Tools')
    }, (argv) => {
      const {injectWeatherFromConfiguration} = require('./veaf-weather-injector.js');
      injectWeatherFromConfiguration(
        {
          sourceMissionFileName: argv.source,  // the name of the source mission file (mandatory)
          targetMissionFileName: argv.target, // the target mission name where ${version} will be replaced with the version string
          configurationFile: argv.configuration,  // the name of the configuration file
          trace: argv.verbose,
          quiet: argv.quiet,
          nocache: argv.nocache
        });
      })
      .command('select-mission <source> <target> <configuration>', 'Use a configuration file to create a copy of a serverSettings.lua file which startup mission is set according to the cron scheduling rules found in the configuration', (yargs) => {
        yargs
          .positional('source', {
            type: 'string',
            describe: 'path to the source serverSettings.lua file'
          })
          .positional('target', {
            type: 'string',
            describe: 'path to the target serverSettings.lua file'
          })
          .positional('configuration', {
            type: 'string',
            describe: 'path to the configuration file'
          })
          .option('verbose', {
            alias: 'v',
            type: "boolean",
            default: false,
            describe: "Verbosely log data to the console"
          })
          .option('quiet', {
            alias: 'q',
            type: "boolean",
            default: false,
            describe: "Be extra quiet"
          })
          .example("$0 select-mission serverSettings-private-OpenTraining-Syria-dawn.lua serverSettings.lua opentraining-public.json")
          .epilog('for more information visit https://github.com/VEAF/VEAF-Mission-Creation-Tools')
      }, (argv) => {
        const {selectMission} = require('./veaf-server-mission-selector.js');
        selectMission(
          {
            sourceFileName: argv.source,
            targetFileName: argv.target,
            configurationFile: argv.configuration,
            trace: argv.verbose,
            quiet: argv.quiet
          });
        })
    .demandCommand()
  .help()
  .wrap(null)
  .argv;