"use strict";

var fs = require("fs");
const fsPromises = fs.promises;
const path = require('path');

String.prototype.regexLastIndexOf = function (regex) {
  var match = this.match(regex);

  return match ? this.lastIndexOf(match.slice(-1)) : -1;
}

function fitsIn(value, parameter) {
  if (!parameter) return true;
  if (!value) return false;

  const list = parameter.split(",");
  if (list && list.length > 1) {
    // this is a list
    return list.includes(value);
  }

  const array = parameter.split("-");
  if (array && array.length == 2) {
    // this is an array
    const min = array[0];
    const max = array[1];
    return (value >= min && value <= max);
  }

  return value == parameter;
}

async function selectMission(parameters) {
  let { sourceFileName, targetFileName, configurationFile, trace, quiet } = parameters;
  if (!quiet) console.log(`DCS server startup mission selector starting`);
  if (trace) console.log(`parameters = ${JSON.stringify(parameters)}`);

  let date = new Date();
  let currentMonth = date.getMonth() + 1;
  let currentDate = date.getDate();
  let currentDay  = date.getUTCDay();
  let currentHour = date.getHours();
  
  if (trace) {
    console.log(`currentMonth = ` + currentMonth);
    console.log(`currentDayOfMonth = ` + currentDate);
    console.log(`currentDayOfWeek = ` + currentDay);
    console.log(`currentHour = ` + currentHour);
  }

  // read the configuration file
  try {
    if (!fs.existsSync(configurationFile)) {
      console.error(`configuration file ${configurationFile} does not exist`);
      process.exit(-1);
    } else {
      //let configurationFolder = path.dirname(configurationFile) + "/";
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
      let selectedMission = data.default;
      for (let i=0; i<data.moments.length; i++) {       
        let { month, dayOfMonth, dayOfWeek, hour, mission } = data.moments[i];
        if (month && !(fitsIn(currentMonth, month))) continue;
        if (dayOfMonth && !(fitsIn(currentDate, dayOfMonth))) continue;
        if (dayOfWeek && !(fitsIn(currentDay, dayOfWeek))) continue;
        if (hour && !(fitsIn(currentHour, hour))) continue;

        // everything fits, select this mission
        selectedMission = mission;
        if (!quiet) console.log(`current date ${date.toISOString()} fits in ` + JSON.stringify(data.moments[i]));
        break;
      }

      // edit the file
      if (trace) console.log(`selecting mission ` + selectedMission);
      let sourceFileData = fs.readFileSync(sourceFileName, {encoding:'utf8', flag:'r'});
      let matchResult = sourceFileData.match(`[^\\[]*\\[(\\d+)\\].*${selectedMission}.*`);
      let missionNumber = "01";
      if (matchResult && matchResult.length >= 1)
        missionNumber = matchResult[1].toLowerCase();

      if (trace) console.log(`setting mission number to ` + missionNumber);

      let matchpos = sourceFileData.regexLastIndexOf(/\["current"\]\s*=\s*(\d+),/g);
      if (matchpos)
        sourceFileData = sourceFileData.slice(0, matchpos) + sourceFileData.slice(matchpos).replace(/\["current"\]\s*=\s*(\d+),/, `["current"] = ${missionNumber},`);
    
      matchpos = sourceFileData.regexLastIndexOf(/\["listStartIndex"\]\s*=\s*(\d+),/g);
      if (matchpos)
        sourceFileData = sourceFileData.slice(0, matchpos) + sourceFileData.slice(matchpos).replace(/\["listStartIndex"\]\s*=\s*(\d+),/, `["listStartIndex"] = ${missionNumber},`);

      let writeStream = fs.createWriteStream(targetFileName);
      writeStream.write(sourceFileData, 'utf8');
      writeStream.on('finish', () => {
        if (!quiet) console.log(`wrote all data to ${targetFileName}`);
      });
      writeStream.end();

    }
  } catch (error) {
    console.error(error);
  }
  if (!quiet) console.log("All done !");
}

module.exports.selectMission = selectMission;
