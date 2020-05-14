var fs = require("fs");
const fsPromises = fs.promises;
var JSZip = require("jszip");
const CheckWX = require('./weather/CheckWX.js'); 
const DCSCheckWXConvertEnricher = require('./weather/DCSCheckWXConvertEnricher.js'); 
const fengari = require('fengari');

const configuration = require('./configuration.json')

const TRACE = true;

String.prototype.regexLastIndexOf = function(regex) {
  var match = this.match(regex);

  return  match ? this.lastIndexOf(match.slice(-1)) : -1;
}

/*
* VEAF Mission Creation Tools main pipeline
*/

function buildMission() {
  //TODO
}

function extractMission() {
  //TODO
}

function normalizeMission() {
  //TODO
}

function injectRadioPresets() {
  //TODO
}

function injectWeather(missionFileName, missionStartTime, weatherFileName) {
  console.log("injectWeather");
  (async () => {
    let theatreName = "caucasus";
    let missionData;
    
    // open the DCS mission
    try {
      let zippedMissionFile = await fsPromises.readFile(missionFileName);
      let zippedMissionObject = await JSZip.loadAsync(zippedMissionFile);
      // Read the contents of the 'mission' file
      missionData = await zippedMissionObject.file("mission").async("string")

      if (!missionData) {
        console.error("cannot read mission file");
        process.exit(-1);
      } else {
        // process the "theatre" value
        let matchResult = missionData.match('\\["theatre"\\]\\s*=\\s*"(.+)"');
        if (matchResult && matchResult.length >= 1)
          theatreName = matchResult[1].toLowerCase();
      }
      //if (TRACE) console.log(missionData);
    } catch (err) {
      console.error(err);
      process.exit(-1);
    }

    // set the mission start time
    if (missionStartTime) {
      let matchpos = missionData.regexLastIndexOf(/\["start_time"\] = (\d+)/g);
      console.log(matchpos);
      missionData = missionData.slice(0, matchpos) + missionData.slice(matchpos).replace(/\["start_time"\] = (\d+)/, `["start_time"] = ${missionStartTime}`);
    }

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
      try {
        weatherDataString = await fsPromises.readFile(weatherFileName);
      } catch (err) {
        console.error(err);
        process.exit(-1);
      }

    } else {
      // read it from the real weather on the theatre
      let checkwx = new CheckWX(configuration.checkwx_apikey);
      const theatre = configuration.theatres[theatreName] || configuration.theatres.caucasus;
      let metar = await checkwx.getWeatherForLatLon(theatre.lat, theatre.lon);
      if (TRACE) console.log(metar);

      // process METAR and inject it into the DCS Weather object
      let weatherdata = new DCSCheckWXConvertEnricher(metar);
      if (TRACE) console.log("getStationElevation="+weatherdata.getStationElevation());
      if (TRACE) console.log("getBarometerMMHg="+weatherdata.getBarometerMMHg());
      if (TRACE) console.log("getTemperature="+weatherdata.getTemperature());
      if (TRACE) console.log("getTemperatureASL="+weatherdata.getTemperatureASL());
      if (TRACE) console.log("getWindASL="+weatherdata.getWindASL());
      if (TRACE) console.log("getWind2000="+weatherdata.getWind2000());
      if (TRACE) console.log("getWind8000="+weatherdata.getWind8000());
      if (TRACE) console.log("getGroundTurbulence="+weatherdata.getGroundTurbulence());
      if (TRACE) console.log("getCloudMinMax="+weatherdata.getCloudMinMax());
      if (TRACE) console.log("getCloudBase="+weatherdata.getCloudBase());
      if (TRACE) console.log("getCloudThickness="+weatherdata.getCloudThickness());
      if (TRACE) console.log("getCloudDensity="+weatherdata.getCloudDensity());
      if (TRACE) console.log("getWeatherType="+weatherdata.getWeatherType());
      if (TRACE) console.log("getFogEnabled="+weatherdata.getFogEnabled());
      if (TRACE) console.log("getFogVisibility="+weatherdata.getFogVisibility());
      if (TRACE) console.log("getFogThickness="+weatherdata.getFogThickness());
      if (TRACE) console.log("getVisibility="+weatherdata.getVisibility());

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
            ["speed"] = ${weatherdata.getWindASL()['speed']/2},
          }, -- end of ["atGround"]
        }, -- end of ["wind"]
      }, -- end of ["weather"]     
      `;
    }

    // store the weather in the mission data
    let weatherStartPos = missionData.indexOf('["weather"] = ');
    let weatherEndPos = missionData.lastIndexOf('-- end of ["weather"]')+'-- end of ["weather"]'.length;
    missionData = missionData.slice(0,weatherStartPos) + weatherDataString + missionData.slice(weatherEndPos);

    {
      let writeStream = fs.createWriteStream('mission.lua');
      writeStream.write(missionData, 'utf8');
      writeStream.on('finish', () => {
          console.log('wrote all data to mission.lua');
      });
      writeStream.end();
    }

    // store the mission data back in the DCS mission file
    // open the DCS mission
    try {
      let zippedMissionFile = await fsPromises.readFile(missionFileName);
      let zippedMissionObject = await JSZip.loadAsync(zippedMissionFile);
      zippedMissionObject.file("mission", missionData);
      zippedMissionObject
      .generateNodeStream({type:'nodebuffer',streamFiles:true, compression:"DEFLATE"})
      .pipe(fs.createWriteStream(missionFileName))
      .on('finish', function () {
          console.log(missionFileName + " saved.");
      });
    
    } catch (err) {
      console.error(err);
      process.exit(-1);
    }

  })();
}

injectWeather('test.miz', 85202);