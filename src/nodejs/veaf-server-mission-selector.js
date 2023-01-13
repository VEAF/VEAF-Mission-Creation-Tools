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
    const result = list.includes(value.toString());
    return result;
  }

  const array = parameter.split("-");
  if (array && array.length == 2) {
    // this is an array
    const min = Number(array[0]);
    const max = Number(array[1]);
    const result =  (value >= min && value <= max);
    return result;
  }

  return value == parameter;
}

// parses a moment in the day into hours 
function parseMomentInDay(moment) {
  if (!moment) return null;
  switch (moment.toLowerCase()) {
    case "morning": return "0-11";
    case "afternoon": return "12-23";
    case "day": return "07-20";
    case "night": return "21-06";
    case "matin": return "0-11";
    case "après-midi": return "12-23";
    case "journée": return "07-20";
    case "nuit": return "21-06";
  }
  return null;
}

// parses a day of week string into a number
function parseDayOfWeek(dayOfWeek) {
  if (!dayOfWeek) return null;
  switch (dayOfWeek.toLowerCase()) {
    case "monday": return "1";
    case "tuesday": return "2";
    case "wednesday": return "3";
    case "thursday": return "4";
    case "friday": return "5";
    case "saturday": return "6";
    case "sunday": return "7";
    case "mon": return "1";
    case "tue": return "2";
    case "wed": return "3";
    case "thu": return "4";
    case "fri": return "5";
    case "sat": return "6";
    case "sun": return "7";
    case "lundi": return "1";
    case "mardi": return "2";
    case "mercredi": return "3";
    case "jeudi": return "4";
    case "vendredi": return "5";
    case "samedi": return "6";
    case "dimanche": return "7";
    case "lun": return "1";
    case "mar": return "2";
    case "mer": return "3";
    case "jeu": return "4";
    case "ven": return "5";
    case "sam": return "6";
    case "dim": return "7";
  }
  return null;
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
        if (!data.moments[i]["//comment"]) {
          let { month, dayOfMonth, dayOfWeek, hour, mission, missions } = data.moments[i];
          let nDayOfWeek = parseDayOfWeek(dayOfWeek);
          let nHour = parseMomentInDay(hour);

          if (month && !(fitsIn(currentMonth, month))) continue;
          if (dayOfMonth && !(fitsIn(currentDate, dayOfMonth))) continue;
          if (nDayOfWeek && !(fitsIn(currentDay, nDayOfWeek))) continue;
          if (nHour && !(fitsIn(currentHour, nHour))) continue;

          // everything fits, select this mission
          if (mission) {
            selectedMission = mission;
          } else if (missions) {
            // select a random mission in the missions list
            selectedMission = missions[Math.floor(Math.random() * missions.length)];
          }
          if (!quiet) console.log(`current date ${date.toISOString()} fits in ` + JSON.stringify(data.moments[i]));
          break;
        }
      }

      // edit the file
      if (!quiet) console.log(`\n********************\nselecting mission ` + selectedMission+ `\n********************\n`);
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
