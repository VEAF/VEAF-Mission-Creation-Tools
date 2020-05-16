"use strict";

var fs = require("fs");
const fsPromises = fs.promises;
var JSZip = require("jszip");
const CheckWX = require('./weather/CheckWX.js');
const DCSCheckWXConvertEnricher = require('./weather/DCSCheckWXConvertEnricher.js');
const MetarCache = require('./weather/MetarCache.js');
const CachedMetar = MetarCache.CachedMetar;
const Configuration = require('./Configuration.js');
const configuration = new Configuration();
const path = require('path');

String.prototype.regexLastIndexOf = function (regex) {
  var match = this.match(regex);

  return match ? this.lastIndexOf(match.slice(-1)) : -1;
}

async function injectWeatherFromConfiguration(parameters) {
  let { sourceMissionFileName, targetMissionFileName, configurationFile, trace, quiet } = parameters;
  if (!quiet) console.log(`DCS multiple missions weather injector starting`);

  // read the configuration file
  try {
    if (!fs.existsSync(configurationFile)) {
      console.error(`configuration file ${configurationFile} does not exist`);
      process.exit(-1);
    } else {
      let configurationFolder = path.dirname(configurationFile) + "/";
      let json = fs.readFileSync(configurationFile);
      if (!json) {
        console.error("cannot read file " + configurationFile); // no file ?
        return;
      }
      let data = JSON.parse(json);
      if (!data) {
        console.error("cannot parse file content " + configurationFile); // invalid content
        return;
      }
      for (let i=0; i<data.targets.length; i++) {       
        let { version, weather, weatherfile, time } = data.targets[i];
        let parameters = {
          sourceMissionFileName: sourceMissionFileName,
          targetMissionFileName: targetMissionFileName.replace("${version}", version),
          missionStartTime: time,
          weatherFileName:  weatherfile ? configurationFolder + weatherfile : null,
          metarString: weather,
          variableForMetar: data.variableForMetar,
          trace: trace,
          quiet: quiet
        }
        await injectWeather(parameters);
      }
    }
  } catch (error) {
    console.error(error);
  }
  if (!quiet) console.log("All done !");
}

async function injectWeather(parameters) {
  let { sourceMissionFileName, targetMissionFileName, missionStartTime, weatherFileName, metarString, variableForMetar, trace, quiet } = parameters;
  if (targetMissionFileName && targetMissionFileName.indexOf(".miz") < 0)
    targetMissionFileName = targetMissionFileName + ".miz";
  if (!quiet) console.log(`DCS weather injector starting`);

  let theatreName = "caucasus";
  let missionData;
  let dictionaryData;

  // open the DCS mission
  if (!quiet) console.log(`opening DCS mission ${sourceMissionFileName}`);
  try {
    let zippedMissionFile = await fsPromises.readFile(sourceMissionFileName);
    let zippedMissionObject = await JSZip.loadAsync(zippedMissionFile);
    // Read the contents of the 'mission' file
    missionData = await zippedMissionObject.file("mission").async("string")
    if (variableForMetar)
      dictionaryData = await zippedMissionObject.file("l10n/DEFAULT/dictionary").async("string")

    if (!missionData) {
      console.error("cannot read mission file");
      process.exit(-1);
    } else {
      // process the "theatre" value
      let matchResult = missionData.match('\\["theatre"\\]\\s*=\\s*"(.+)"');
      if (matchResult && matchResult.length >= 1)
        theatreName = matchResult[1].toLowerCase();
    }
  
  } catch (err) {
    console.error(err);
    process.exit(-1);
  }

  // set the mission start time
  if (missionStartTime) {
    if (!quiet) console.log(`Setting mission start time to ${missionStartTime}`);
    let matchpos = missionData.regexLastIndexOf(/\["start_time"\] = (\d+)/g);
    missionData = missionData.slice(0, matchpos) + missionData.slice(matchpos).replace(/\["start_time"\] = (\d+)/, `["start_time"] = ${missionStartTime}`);
  }

  if (trace)
  {
    let writeStream = fs.createWriteStream('mission.lua');
    writeStream.write(missionData, 'utf8');
    writeStream.on('finish', () => {
      console.log('wrote all data to mission.lua');
    });
    writeStream.end();
  }

  // read the new weather data 
  let weatherDataString;
  if (weatherFileName) {
    // read it from the weather file
    if (!quiet) console.log(`Reading weather from DCS lua file ${weatherFileName}`);
    try {
      weatherDataString = await fsPromises.readFile(weatherFileName);
    } catch (err) {
      console.error(err);
      process.exit(-1);
    }
  } else {
    let metar;
    
    if (metarString) {
      if (!quiet) console.log(`Generating weather from METAR string "${metarString}"`);
      metar = metarString;
    } else {
      // search for real weather in the cache
      const theatre = configuration.theatres[theatreName] || configuration.theatres.caucasus;
      if (!quiet) console.log(`Getting real weather from CheckWX in "${theatreName}"`);
      metar = await MetarCache.getMetarFromCache(configuration.cacheFolder, theatreName);
      if (!metar || metar.age > configuration.maxAge) {
        // read it from CheckWX
        let checkwx = new CheckWX(configuration.checkwx_apikey);
        metar = await checkwx.getWeatherForLatLon(theatre.lat, theatre.lon);
        if (trace) console.log(metar);
        if (!metar) {
          console.error("cannot get metar from CheckWX !");
          process.exit(-1);
        }
        await MetarCache.storeMetarIntoCache(configuration.cacheFolder, theatreName, metar);
      } else {
        if (!quiet) console.log("Using cached data from " + new Date(metar.datestamp));
        metar = metar.metar;
      }
    }

    // process METAR and inject it into the DCS Weather object
    let weatherdata = new DCSCheckWXConvertEnricher(metar, trace);
    if (trace) console.log("getStationElevation=" + weatherdata.getStationElevation());
    if (trace) console.log("getBarometerMMHg=" + weatherdata.getBarometerMMHg());
    if (trace) console.log("getTemperature=" + weatherdata.getTemperature());
    if (trace) console.log("getTemperatureASL=" + weatherdata.getTemperatureASL());
    if (trace) console.log("getWindASL=" + weatherdata.getWindASL());
    if (trace) console.log("getWind2000=" + weatherdata.getWind2000());
    if (trace) console.log("getWind8000=" + weatherdata.getWind8000());
    if (trace) console.log("getGroundTurbulence=" + weatherdata.getGroundTurbulence());
    if (trace) console.log("getCloudMinMax=" + weatherdata.getCloudMinMax());
    if (trace) console.log("getCloudBase=" + weatherdata.getCloudBase());
    if (trace) console.log("getCloudThickness=" + weatherdata.getCloudThickness());
    if (trace) console.log("getCloudDensity=" + weatherdata.getCloudDensity());
    if (trace) console.log("getWeatherType=" + weatherdata.getWeatherType());
    if (trace) console.log("getFogEnabled=" + weatherdata.getFogEnabled());
    if (trace) console.log("getFogVisibility=" + weatherdata.getFogVisibility());
    if (trace) console.log("getFogThickness=" + weatherdata.getFogThickness());
    if (trace) console.log("getVisibility=" + weatherdata.getVisibility());

    weatherDataString = `
    ["weather"] = {
      ["atmosphere_type"] = 0,
      ["clouds"] = {
        ["base"] = ${weatherdata.getCloudBase()},
        ["density"] = ${weatherdata.getCloudDensity()},
        ["iprecptns"] = ${weatherdata.getWeatherType()},
        ["thickness"] = ${weatherdata.getCloudThickness()},
      }, -- end of ["clouds"]
      ["cyclones"] = {
      }, -- end of ["cyclones"]
      ["dust_density"] = 0,
      ["enable_dust"] = false,
      ["enable_fog"] = ${weatherdata.getFogEnabled()},
      ["fog"] = {
        ["thickness"] = ${weatherdata.getFogThickness()},
        ["visibility"] = ${weatherdata.getFogVisibility()},
      }, -- end of ["fog"]
      ["groundTurbulence"] = ${weatherdata.getGroundTurbulence()},
      ["qnh"] = ${weatherdata.getBarometerMMHg()},
      ["season"] = {
        ["temperature"] = ${weatherdata.getTemperatureASL()},
      }, -- end of ["season"]
      ["type_weather"] = 2,
      ["visibility"] = {
        ["distance"] = ${weatherdata.getVisibility()},
      }, -- end of ["visibility"]
      ["wind"] = {
        ["at2000"] = {
          ["dir"] = ${weatherdata.getWind2000()['direction']},
          ["speed"] = ${weatherdata.getWind2000()['speed']},
        }, -- end of ["at2000"]
        ["at8000"] = {
          ["dir"] = ${weatherdata.getWind8000()['direction']},
          ["speed"] = ${weatherdata.getWind8000()['speed']},
        }, -- end of ["at8000"]
        ["atGround"] = {
          ["dir"] = ${weatherdata.getWindASL()['direction']},
          ["speed"] = ${weatherdata.getWindASL()['speed'] / 2},
        }, -- end of ["atGround"]
      }, -- end of ["wind"]
    }, -- end of ["weather"]     
    `;

    // add the METAR string to dictionary
    if (dictionaryData) {
      if (!quiet) console.log("Setting variable ${"+variableForMetar+"} to the METAR string \""+weatherdata.metar+"\"");
      dictionaryData = dictionaryData.replace("${"+variableForMetar+"}", weatherdata.metar);
    }

  }

  // store the weather in the mission data
  let weatherStartPos = missionData.indexOf('["weather"] = ');
  let weatherEndPos = missionData.lastIndexOf('-- end of ["weather"]') + '-- end of ["weather"]'.length;
  missionData = missionData.slice(0, weatherStartPos) + weatherDataString + missionData.slice(weatherEndPos);

  if (trace)
  {
    let writeStream = fs.createWriteStream('mission.lua');
    writeStream.write(missionData, 'utf8');
    writeStream.on('finish', () => {
      console.log('wrote all data to mission-2.lua');
    });
    writeStream.end();
  }

  // store the mission data back in the DCS mission file
  // open the DCS mission
  try {
    if (!targetMissionFileName)
      targetMissionFileName = sourceMissionFileName;
    let zippedMissionFile = await fsPromises.readFile(sourceMissionFileName);
    let zippedMissionObject = await JSZip.loadAsync(zippedMissionFile);
    zippedMissionObject.file("mission", missionData);
    zippedMissionObject.file("l10n/DEFAULT/dictionary", dictionaryData);
    zippedMissionObject
      .generateNodeStream({ type: 'nodebuffer', streamFiles: true, compression: "DEFLATE" })
      .pipe(fs.createWriteStream(targetMissionFileName))

  } catch (err) {
    console.error(err);
    process.exit(-1);
  }

  console.log(`Mission saved to "${targetMissionFileName}"`);

}

module.exports.injectWeather = injectWeather;
module.exports.injectWeatherFromConfiguration = injectWeatherFromConfiguration;
