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
const SolarCalc = require('solar-calc');
var sunrise = 18000; // default value = 5:00
var sunset = 68400; // default value = 19:00
const DefaultMetar = 'LFJY 221130Z 04515KT CAVOK 17/12 Q1020 NOSIG';


String.prototype.regexLastIndexOf = function (regex) {
  var match = this.match(regex);

  return match ? this.lastIndexOf(match.slice(-1)) : -1;
}

function parseMoment(moment) {
  if (isNaN(moment)) {
    if (moment.indexOf(':') >= 0) {
      // this is a time string
      var timeSplits = moment.split(':');
      var seconds = (+timeSplits[0]) * 60 * 60 + (+timeSplits[1]) * 60; 
      return seconds
    } else {
      var seconds = eval(moment)
      return seconds
    }
  }
  else return moment
}

function toDcsTime(date) {
  return date.getHours()*3600 + date.getMinutes()*60 + date.getSeconds();
}

async function injectWeatherFromConfiguration(parameters) {
  let { sourceMissionFileName, targetMissionFileName, configurationFile, trace, quiet, nocache } = parameters;
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
      var midnight = new Date();
      midnight.setHours(0,0,0,0);
      if (data.position) {
        let lat = data.position["lat"];
        let lon = data.position["lon"];
        let tz = data.position["tz"];
        var solar = new SolarCalc(midnight, lat, lon);
        sunrise = toDcsTime(new Date(solar.sunrise.toLocaleString("en-US", {timeZone: tz})));
        sunset = toDcsTime(new Date(solar.sunset.toLocaleString("en-US", {timeZone: tz})));
      }
      let moments = {
        "night" : "02:00",
        "beforedawn" : "sunrise-90*60",
        "sunrise" : "sunrise",
        "dawn" : "sunrise+30*60",
        "morning" : "sunrise+90*60",
        "day" : "15:00",
        "beforesunset" : "sunset-90*60",
        "sunset" : "sunset" 
      } // default moments
      for (const key in data.moments) {
        if (Object.hasOwnProperty.call(data.moments, key)) {
          let value = data.moments[key];
          moments[key] = value;
        }
      }
      for (const key in moments) {
        if (Object.hasOwnProperty.call(moments, key)) {
          let value = moments[key];
          moments[key] = parseMoment(value);
        }
      }
      for (let i=0; i<data.targets.length; i++) {
        let { version, weather, weatherfile, date, time, moment, dontSetToday, dontSetTodayYear, clearsky } = data.targets[i];
        if (!time && moment && moments && moments[moment]) {
          time = moments[moment];
        }
        if (date) dontSetToday = true
        let parameters = {
          sourceMissionFileName: sourceMissionFileName,
          targetMissionFileName: targetMissionFileName.replace("${version}", version),
          missionStartTime: time,
          missionStartDate: date,
          weatherFileName:  weatherfile ? configurationFolder + weatherfile : null,
          metarString: weather,
          variableForMetar: data.variableForMetar,
          setToday: !dontSetToday,
          setTodayYear: !dontSetTodayYear,
          trace: trace,
          quiet: quiet,
          clearsky: clearsky,
          nocache: nocache
        }
        await injectWeather(parameters);
      }
    }
  } catch (error) {
    console.error(error);
  }
  if (!quiet) console.log("All done !");
}

function isNumeric(n) {
  return !isNaN(parseFloat(n)) && isFinite(n);
}

async function injectWeather(parameters) {
  let { sourceMissionFileName, targetMissionFileName, missionStartTime, missionStartDate, weatherFileName, metarString, clearsky, variableForMetar, setToday, setTodayYear, trace, quiet, nocache } = parameters;
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
    missionStartTime = '' + missionStartTime
    if (!quiet) console.log(`Setting mission start time to ${missionStartTime}`);
      let matchpos = missionData.regexLastIndexOf(/\["start_time"\] = (\d+)/g);
    missionData = missionData.slice(0, matchpos) + missionData.slice(matchpos).replace(/\["start_time"\] = (\d+)/, `["start_time"] = ${missionStartTime}`);
  }

  if (missionStartDate) {
    missionStartDate = '' + missionStartDate
    // set the mission start date
    if (missionStartDate.length == 12) {
      var hours = missionStartDate.slice(8,10)
      var minutes = missionStartDate.slice(10,12)
      if (isNumeric(hours) && hours >= 0 && hours <= 23 && isNumeric(minutes) && minutes >= 0 && minutes <= 59) {
        if (!quiet) console.log(`Setting mission start time to ${hours}:${minutes}`)
        var dcsTime = hours * 3600 + minutes * 60
        let matchpos = missionData.regexLastIndexOf(/\["start_time"\] = (\d+)/g);
        missionData = missionData.slice(0, matchpos) + missionData.slice(matchpos).replace(/\["start_time"\] = (\d+)/, `["start_time"] = ${dcsTime}`);
      }
    }
    if (missionStartDate.length >= 8) {
      var year = missionStartDate.slice(0,4)
      var month = missionStartDate.slice(4,6)
      var day = missionStartDate.slice(6,8)
      if (isNumeric(year) && isNumeric(month) && isNumeric(day) && year > 1900 && year < 2100 && month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        if (!quiet) console.log(`Setting mission start date to ${day}/${month}/${year}`);
        let matchpos = missionData.regexLastIndexOf(/\["Day"\] = (\d+)/g);
        missionData = missionData.slice(0, matchpos) + missionData.slice(matchpos).replace(/\["Day"\] = (\d+)/, `["Day"] = ${day}`);
        matchpos = missionData.regexLastIndexOf(/\["Month"\] = (\d+)/g);
        missionData = missionData.slice(0, matchpos) + missionData.slice(matchpos).replace(/\["Month"\] = (\d+)/, `["Month"] = ${month}`);
        matchpos = missionData.regexLastIndexOf(/\["Year"\] = (\d+)/g);
        missionData = missionData.slice(0, matchpos) + missionData.slice(matchpos).replace(/\["Year"\] = (\d+)/, `["Year"] = ${year}`);
      }
    }
  } else if (setToday) {
    // set the mission date to the current date
    var dateObj = new Date();
    var month = dateObj.getUTCMonth() + 1; //months from 1-12
    var day = dateObj.getUTCDate();
    var year = dateObj.getUTCFullYear();
    if (!quiet) console.log(`Setting mission start date to ${day}/${month}`);
    let matchpos = missionData.regexLastIndexOf(/\["Day"\] = (\d+)/g);
    missionData = missionData.slice(0, matchpos) + missionData.slice(matchpos).replace(/\["Day"\] = (\d+)/, `["Day"] = ${day}`);
    matchpos = missionData.regexLastIndexOf(/\["Month"\] = (\d+)/g);
    missionData = missionData.slice(0, matchpos) + missionData.slice(matchpos).replace(/\["Month"\] = (\d+)/, `["Month"] = ${month}`);
      if (setTodayYear) { // set the current year
        matchpos = missionData.regexLastIndexOf(/\["Year"\] = (\d+)/g);
        missionData = missionData.slice(0, matchpos) + missionData.slice(matchpos).replace(/\["Year"\] = (\d+)/, `["Year"] = ${year}`);
      }
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
      let key = theatreName
      if (clearsky) key = key + "-clearsky";
      if (!quiet) console.log(`Getting real weather from CheckWX in "${theatreName}"`);
      if (!quiet) console.log(`Cache key is "${key}"`);
      if (!nocache) metar = await MetarCache.getMetarFromCache(configuration.cacheFolder, key);
      if (!metar || metar.age > configuration.maxAge) {
        // read it from CheckWX
        let checkwx = new CheckWX(configuration.checkwx_apikey);
        try {
          metar = await checkwx.getWeatherForLatLon(theatre.lat, theatre.lon);
          if (!metar || metar.results == 0) {
            console.log("No metar returned from CheckWX, using default metar " + DefaultMetar)
            metar = DefaultMetar
          }
        } catch (error) {
          console.log("Error while fetching weather on checkwx ! ", error)
          metar = DefaultMetar;
        }
        if (trace) console.log(metar);
        if (!metar) {
          console.error("cannot get metar from CheckWX !");
          process.exit(-1);
        }
        await MetarCache.storeMetarIntoCache(configuration.cacheFolder, key, theatre, metar);
      } else {
        if (!quiet) console.log("Using cached data from " + new Date(metar.datestamp));
        metar = metar.metar;
      }
    }

    // process METAR and inject it into the DCS Weather object
    let weatherdata = new DCSCheckWXConvertEnricher(metar, clearsky, trace);
    if (trace) console.log("getStationElevation=" + weatherdata.getStationElevation());
    if (trace) console.log("getBarometerMMHg=" + weatherdata.getBarometerMMHg());
    if (trace) console.log("getTemperature=" + weatherdata.getTemperature());
    if (trace) console.log("getTemperatureASL=" + weatherdata.getTemperatureASL());
    if (trace) console.log("getWindASL=" + weatherdata.getWindASL());
    if (trace) console.log("getWind2000=" + weatherdata.getWind2000());
    if (trace) console.log("getWind8000=" + weatherdata.getWind8000());
    if (trace) console.log("getGroundTurbulence=" + weatherdata.getGroundTurbulence());
    if (trace) console.log("getCloudPreset=" + weatherdata.getCloudPreset());
    if (trace) console.log("getCloudMinMax=" + weatherdata.getCloudMinMax());
    if (trace) console.log("getCloudBase=" + weatherdata.getCloudBase());
    if (trace) console.log("getCloudThickness=" + weatherdata.getCloudThickness());
    if (trace) console.log("getCloudDensity=" + weatherdata.getCloudDensity());
    if (trace) console.log("getWeatherType=" + weatherdata.getWeatherType());
    if (trace) console.log("getFogEnabled=" + weatherdata.getFogEnabled());
    if (trace) console.log("getFogVisibility=" + weatherdata.getFogVisibility());
    if (trace) console.log("getFogThickness=" + weatherdata.getFogThickness());
    if (trace) console.log("getVisibility=" + weatherdata.getVisibility());

    let presetString = ""
    if (weatherdata.getCloudPreset())
      presetString = `["preset"] = "${weatherdata.getCloudPreset()}",`;

    weatherDataString = `
    ["weather"] = 
    {
      ["atmosphere_type"] = 0,
      ["groundTurbulence"] = ${weatherdata.getGroundTurbulence()},
      ["enable_fog"] = ${weatherdata.getFogEnabled()},
      ["season"] = 
      {
        ["temperature"] = ${weatherdata.getTemperatureASL()},
      }, -- end of ["season"]
      ["type_weather"] = 2,
      ["qnh"] = ${weatherdata.getBarometerMMHg()},
      ["cyclones"] = 
      {
      }, -- end of ["cyclones"]
      ["wind"] = 
      {
        ["at8000"] = 
        {
          ["speed"] = ${weatherdata.getWind8000()['speed']},
          ["dir"] = ${weatherdata.getWind8000()['direction']},
        }, -- end of ["at8000"]
        ["at2000"] = 
        {
          ["speed"] = ${weatherdata.getWind2000()['speed']},
          ["dir"] = ${weatherdata.getWind2000()['direction']},
        }, -- end of ["at2000"]
        ["atGround"] = 
        {
          ["speed"] = ${weatherdata.getWindASL()['speed']},
          ["dir"] = ${weatherdata.getWindASL()['direction']},
        }, -- end of ["atGround"]
      }, -- end of ["wind"]
      ["dust_density"] = 0,
      ["enable_dust"] = false,
      ["fog"] = 
      {
        ["thickness"] = ${weatherdata.getFogThickness()},
        ["visibility"] = ${weatherdata.getFogVisibility()},
      }, -- end of ["fog"]
      ["visibility"] = 
      {
        ["distance"] = ${weatherdata.getVisibility()},
      }, -- end of ["visibility"]
      ["clouds"] = 
      {
        ${presetString}
        ["density"] = ${weatherdata.getCloudDensity()},
        ["thickness"] = ${weatherdata.getCloudThickness()},
        ["base"] = ${weatherdata.getCloudBase()},
        ["iprecptns"] = ${weatherdata.getWeatherType()},
      }, -- end of ["clouds"]
    },
    `;
    weatherDataString = weatherDataString.replace("NaN","0"); // just in case some computation went wrong

    // add the METAR string to dictionary
    if (dictionaryData) {
      if (!quiet) console.log("Setting variable ${"+variableForMetar+"} to the METAR string \""+weatherdata.metar+"\"");
      dictionaryData = dictionaryData.replace("${"+variableForMetar+"}", weatherdata.metar);
    }

  }

  // store the weather in the mission data
  let weatherStartPos = missionData.indexOf('["weather"] = ');
  // find the first brace
  let nbBraces = 0;
  let weatherEndPos = weatherStartPos;
  do {
    let charToCheck = missionData.charAt(weatherEndPos)
    if (charToCheck == '{')
      nbBraces++;
      weatherEndPos++;
  } while (nbBraces == 0)
  // count the braces to find the end of the weather block
  do {
    let charToCheck = missionData.charAt(weatherEndPos)
    if (charToCheck == '{')
      nbBraces++;
    if (charToCheck == '}')
      nbBraces--;
    weatherEndPos++;
  } while (nbBraces > 0)
  weatherEndPos++;
  missionData = missionData.slice(0, weatherStartPos) + weatherDataString + missionData.slice(weatherEndPos);

  if (trace)
  {
    let writeStream = fs.createWriteStream('mission-2.lua');
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
