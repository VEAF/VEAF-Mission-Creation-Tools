"use strict";

var parseMETAR = require("./metar.js");

const trace = true;

class DCSCheckWXConvertEnricher {

  _weatherdata = null;
  _closestResult = null;
  _metar = null;
  _trace = false;

  get trace() {
    return this._trace;
  }

  constructor(weatherdata, clearsky, trace) {
    this._trace = trace;
    this._cloudPreset = null;
    this._clearsky = clearsky
    if (typeof(weatherdata) == "string") {
      // we've got a text metar to parse
      this._metar = weatherdata;
      if (this._clearsky) {
        this._metar = this._metar.replace("OVC", "FEW");
        this._metar = this._metar.replace("BKN", "FEW");
        this._metar = this._metar.replace("SCT", "FEW");
      }
      let decodedMetar = parseMETAR(weatherdata);
      if (decodedMetar) {
        if (decodedMetar.wind.direction == "VRB") 
          decodedMetar.wind.direction = 0;
        if (decodedMetar.wind.unit == "KT") {
          decodedMetar.wind.speed = decodedMetar.wind.speed * 0.515;
          decodedMetar.wind.gust = decodedMetar.wind.gust * 0.515;
        } else if (decodedMetar.wind.unit != "MPS") {
          console.warn("unknown unit "+decodedMetar.wind.unit);
          process.exit(-1);
        }
        this._closestResult = {
          "temperature": {
            "celsius": decodedMetar.temperature || 20
          },
          "barometer": {
            "hg" : decodedMetar.altimeterInHg || (decodedMetar.altimeterInHpa * 0.02953)
          },
          "wind": {
            "degrees": decodedMetar.wind.direction || 0,
            "speed_mps" : decodedMetar.wind.speed || 0,
            "gust_mps" : decodedMetar.wind.gust || 0,
          },
          "clouds": !decodedMetar.clouds ? "" : decodedMetar.clouds.map(cloud => {
            return {
              "base_meters_agl": cloud.altitude*0.3048 || 5000,
              "code": cloud.abbreviation
            };
          }),
          "conditions": decodedMetar.weather || [],
          "visibility":{
            "meters_float": decodedMetar.visibility || 99999
          }

        };
      }
    } else {
      if (weatherdata.error && weatherdata.error == 'Unauthorized' ) {
        console.error("CheckWX API Key not valid ; go get one on https://www.checkwxapi.com/");
        process.exit(-1); 
      }
      this._weatherdata = weatherdata;
      this._metar = this.getClosestResult().raw_text || "";
      if (this._clearsky) {
        this._metar = this._metar.replace("OVC", "FEW");
        this._metar = this._metar.replace("BKN", "FEW");
        this._metar = this._metar.replace("SCT", "FEW");
      }
    }
  }

  getDeterministicRandomFloat(min, max) {
    min = min || 0;
    max = max || 1;
    let randval = Math.random()
    return min + ((max - min) * randval)
  }

  getDeterministicRandomInt(min, max) {
    return Math.floor(this.getDeterministicRandomFloat(min, max));
  }

  /**
   * convert "from degrees" in "to degrees"
   * @param int angle the wind is going from this direction (like in METAR)
   * @return int angle the wind is going to this direction (like in DCS Mission Editor)
   */
  convertFromTo(angle) {
	return this.normalizeDegrees(angle - 180);
  }

  normalizeDegrees(angle) {
    let retangle = angle;
    if (retangle < 0) retangle = retangle + 360;
    retangle = retangle % 360;
    return retangle;
  }

  get weatherData() {
    return this._weatherdata
  }

  get metar() {
    return this._metar;
  }

  _checkResult(data, level) {
    level = level || 0;
    if (!data) { if (this.trace) console.log("!data"); return null; }
    if (level >= 2 && !data['elevation']) { if (this.trace) console.log("!data['elevation']"); return null; }
    if (level >= 2 && !data['elevation']['meters']) { if (this.trace) console.log("!data['elevation']['meters']"); return null; }
    if (!data['barometer']) { if (this.trace) console.log("!data['barometer']"); return null; }
    if (!data['barometer']['hg']) { if (this.trace) console.log("!data['barometer']['hg']"); return null; }
    if (!data['temperature']) { if (this.trace) console.log("!data['temperature']"); return null; }
    if (!data['temperature']['celsius']) { if (this.trace) console.log("!data['temperature']['celsius']"); return null; }
    if (level >= 1 && !data['wind']) { if (this.trace) console.log("!data['wind']"); return null; }
    if (level >= 1 && !data['wind']['degrees']) { if (this.trace) console.log("!data['wind']['degrees']"); return null; }
    if (level >= 1 && !(data['wind']['speed_mps'] || data['wind']['speed_kts'] || data['wind']['speed_kph'] || data['wind']['speed_mph'])) { if (this.trace) console.log("!data['wind']['speed_mps']"); return null; }
    if (level >= 3 && !data['wind']['gust_kts']) { if (this.trace) console.log("!data['wind']['gust_kts']"); return null; }
    if (level >= 2 && !data['clouds']) { if (this.trace) console.log("!data['clouds']"); return null; }
    if (level >= 2 && data['clouds']) {
      let result = false
      data['clouds'].forEach(cloud => {
        result = result || (cloud['base_meters_agl'] || cloud['base_feet_agl'])
      });
      if (!result) { if (this.trace) console.log("!data['clouds']['base_meters_agl']"); return null; }
    }
    if (!data['conditions']) { if (this.trace) console.log("!data['conditions']"); return null; }
    if (level >= 1 && !data['visibility']) { if (this.trace) console.log("!data['visibility']"); return null; }
    if (level >= 1 && !data['visibility']['meters_float']) { if (this.trace) console.log("!data['visibility']['meters_float']"); return null; }
    if (this.trace) console.log("ALL GOOD !");
    if (this.trace) console.log(data);
    return data;
  }

  getClosestResult() {
    if (!this._closestResult) {
      new Array(3, 2, 1, 0).forEach((level) => {
        this._weatherdata['data'].forEach((data) => {
          if (this.trace) console.log(`checking level=${level}, data#=${this._weatherdata['data'].indexOf(data)}`);
          if (!this._closestResult) {
            this._closestResult = this._checkResult(data, level);
          }
        });
      });
      if (!this._closestResult) {
        if (this.trace) console.log("Still, no perfect result has been found - using [0]")
        this._closestResult = this._weatherdata['data'][0];
      }
    }
    return this._closestResult;
  }

  getStationElevation() {
    if (this.getClosestResult() && this.getClosestResult()['elevation'] && this.getClosestResult()['elevation']['meters'])
      return this.getClosestResult()['elevation']['meters'];
    else
      return 0;
  }

  getBarometerMMHg() {
    if (this.getClosestResult() && this.getClosestResult()['barometer'] && this.getClosestResult()['barometer']['hg'])
      return this.getClosestResult()['barometer']['hg'] * 25.4;
    else
      return 29.92 * 25.4;
  }

  getTemperature() {
    if (this.getClosestResult() && this.getClosestResult()['temperature'] && this.getClosestResult()['temperature']['celsius'])
      return this.getClosestResult()['temperature']['celsius'];
    else
      return 20;
  }

  getTemperatureASL() {
    let temperatureDelta = this.getStationElevation() * 0.0065;
    return this.getTemperature() + temperatureDelta;
  }

  getWindASL() {
    try {
      return { 'direction': this.getClosestResult()['wind'] ? this.convertFromTo(this.getClosestResult()['wind']['degrees']) : 0, 'speed': this.getClosestResult()['wind'] ? this.getClosestResult()['wind']['speed_mps'] : 0};
    } catch (err) {
      console.log(err);
      return { 'direction': this.convertFromTo(this.getDeterministicRandomInt(0, 360)), 'speed': this.getDeterministicRandomFloat(0, 1) };
    }
  }

  getWind2000() {
    let groundWind = this.getWindASL();
    let newDirection = this.normalizeDegrees(groundWind['direction'] + this.getDeterministicRandomInt(-50, 50));
    return { 'direction': newDirection, 'speed': groundWind['speed'] + this.getDeterministicRandomFloat(1, 3) };
  }

  getWind8000() {
    let groundWind = this.getWindASL()
    let newDirection = this.normalizeDegrees(groundWind['direction'] + this.getDeterministicRandomInt(-100, 100));
    return { 'direction': newDirection, 'speed': groundWind['speed'] + this.getDeterministicRandomFloat(2, 8) };
  }

  getGroundTurbulence() {
    try {
      let result = this.getDeterministicRandomFloat(0, 3) / 0.637745;
      if (this.trace) console.log(this.getClosestResult()['wind']);
      if (this.getClosestResult()['wind']) {
        if (this.trace) console.log(this.getClosestResult()['wind']['gust_mps']);
        if (this.getClosestResult()['wind']['gust_mps']) {
          result = this.getClosestResult()['wind']['gust_mps'] / 0.637745;
        }
      }
      return result;
    } catch (err) {
      console.log(err);
      return this.getDeterministicRandomFloat(0, 3) / 0.637745;
    }
  }

  getCloudMinMax() {
    try {
      let clouds = this.getClosestResult()['clouds'];
      if (clouds.length == 0) {
        if (this.trace) console.log("no ['clouds']");
        return { 'min': 5000, 'max': 5000 };
      }

      let minClouds = null;
      let maxClouds = null;
      clouds.forEach((cloud) => {
        if (this.trace) console.log(cloud);
        if (!minClouds || cloud['base_meters_agl'] < minClouds)
          minClouds = cloud['base_meters_agl'];
        if (!maxClouds || cloud['base_meters_agl'] > maxClouds)
          maxClouds = cloud['base_meters_agl'];
      });
      if (!minClouds) minClouds = 5000;
      if (!maxClouds) maxClouds = 5000;
      if (this._clearsky) minClouds = 5000;
      return { 'min': minClouds, 'max': maxClouds };
    } catch (err) {
      console.log(err);
      return { 'min': 5000, 'max': 5000 }
    }
  }

  getCloudBase() {
    return Math.max(300, this.getCloudMinMax()['min']);
  }

  getCloudThickness() {
    try {
      let clouds = this.getClosestResult()['clouds'];
      if (clouds.length == 0) {
        if (this.trace) console.log("no ['clouds']");
        return this.getDeterministicRandomInt(200, 300);
      }
      let minmaxclouds = this.getCloudMinMax();
      let highestclouds = clouds[clouds.length - 1];
      if (highestclouds['code'] == 'OVC')
        return Math.max(200, minmaxclouds['max'] - minmaxclouds['min']);
      else
        return minmaxclouds['max'] - minmaxclouds['min'];
    } catch (err) {
      console.log(err);
      return this.getDeterministicRandomInt(200, 300);
    }
  }

  containsAnyCondition(conditioncodes) {
    let conditions = this.getClosestResult()['conditions'];
    let result = false
    if (conditions) {
      conditions.forEach((cond) => {
        //if (this.trace) console.log(cloud);
        if (conditioncodes.indexOf(cond.abbreviation) != -1) 
          result = true;
      });
    }
    return result;
  }
  
  getCloudPreset() {
/*     const DCS_PRESETS = {
      "Light Scattered 1": "Preset1",
      "Light Scattered 2": "Preset2",
      "High Scattered 1": "Preset3",
      "High Scattered 2": "Preset4",
      "High Scattered 3": "Preset8",
      "Scattered 1": "Preset5",
      "Scattered 2": "Preset6",
      "Scattered 3": "Preset7",
      "Scattered 4": "Preset9",
      "Scattered 5": "Preset10",
      "Scattered 6": "Preset11",
      "Scattered 7": "Preset12",
      "Broken 1": "Preset13",
      "Broken 2": "Preset14",
      "Broken 3": "Preset15",
      "Broken 4": "Preset16",
      "Broken 5": "Preset17",
      "Broken 6": "Preset18",
      "Broken 7": "Preset19",
      "Broken 8": "Preset20",
      "Overcast 1": "Preset21",
      "Overcast 2": "Preset22",
      "Overcast 3": "Preset23",
      "Overcast 4": "Preset24",
      "Overcast 5": "Preset25",
      "Overcast 6": "Preset26",
      "Overcast 7": "Preset27",
      "Overcast And Rain 1": "RainyPreset1",
      "Overcast And Rain 2": "RainyPreset2",
      "Overcast And Rain 3": "RainyPreset3"
  }

    const DCS_PRESETS = {
      "Preset1" : {
        "readableNameShort" : "Light Scattered 1",
        "metar" : "METAR: FEW/SCT 7/8",
      } -- end of Preset1
      "Preset2" : {
        "readableNameShort" : "Light Scattered 2",
        "metar" : "METAR: FEW/SCT 8/10 SCT 23/24",
      } -- end of Preset2
      "Preset3" : {
        "readableNameShort" : "High Scattered 1",
        "metar" : "METAR: SCT 8/9 FEW 21",
      } -- end of Preset3
      "Preset4" : {
        "readableNameShort" : "High Scattered 2",
        "metar" : "METAR: SCT 8/10 FEW/SCT 24/26",
      } -- end of Preset4
      "Preset5" : {
        "readableNameShort" : "Scattered 1",
        "metar" : "METAR: SCT 14/17 FEW 27/29 BKN 40",
      } -- end of Preset5
      "Preset6" : {
        "readableNameShort" : "Scattered 2",
        "metar" : "METAR: SCT/BKN 8/10 FEW 40",
      } -- end of Preset6
      "Preset7" : {
        "readableNameShort" : "Scattered 3",
        "metar" : "METAR: BKN 7.5/12 SCT/BKN 21/23 SCT 40",
      } -- end of Preset7
      "Preset8" : {
        "readableNameShort" : "High Scattered 3",
        "metar" : "METAR: SCT/BKN 18/20 FEW 36/38 FEW 40",
      } -- end of Preset8
      "Preset9" : {
        "readableNameShort" : "Scattered 4",
        "metar" : "METAR: BKN 7.5/10 SCT 20/22 FEW41",
      } -- end of Preset9
      "Preset10" : {
        "readableNameShort" : "Scattered 5",
        "metar" : "METAR: SCT/BKN 18/20 FEW36/38 FEW 40",
      } -- end of Preset10
      "Preset11" : {
        "readableNameShort" : "Scattered 6",
        "metar" : "METAR: BKN 18/20 BKN 32/33 FEW 41",
      } -- end of Preset11
      "Preset12" : {
        "readableNameShort" : "Scattered 7",
        "metar" : "METAR: BKN 12/14 SCT 22/23 FEW 41",
      } -- end of Preset12
      "Preset13" : {
        "readableNameShort" : "Broken 1",
        "metar" : "METAR: BKN 12/14 BKN 26/28 FEW 41",
      } -- end of Preset13
      "Preset14" : {
        "readableNameShort" : "Broken 2",
        "metar" : "METAR: BKN LYR 7/16 FEW 41",
      } -- end of Preset14
      "Preset15" : {
        "readableNameShort" : "Broken 3",
        "metar" : "METAR: SCT/BKN 14/18 BKN 24/27 FEW 40",
      } -- end of Preset15
      "Preset16" : {
        "readableNameShort" : "Broken 4",
        "metar" : "METAR: BKN 14/18 BKN 28/30 FEW 40",
      } -- end of Preset16
      "Preset17" : {
        "readableNameShort" : "Broken 5",
        "metar" : "METAR: BKN/OVC LYR 7/13 20/22 32/34",
      } -- end of Preset17
      "Preset18" : {
        "readableNameShort" : "Broken 6",
        "metar" : "METAR: BKN/OVC LYR 13/15 25/29 38/41",
      } -- end of Preset18
      "Preset19" : {
        "readableNameShort" : "Broken 7",
        "metar" : "METAR: OVC 9/16 BKN/OVC LYR 23/24 31/33",
      } -- end of Preset19
      "Preset20" : {
        "readableNameShort" : "Broken 8",
        "metar" : "METAR: BKN/OVC 13/18 BKN 28/30 SCT FEW 38",
      } -- end of Preset20
      "Preset21" : {
        "readableNameShort" : "Overcast 1",
        "metar" : "METAR: BKN/OVC LYR 7/8 17/19",
      } -- end of Preset21
      "Preset22" : {
        "readableNameShort" : "Overcast 2",
        "metar" : "METAR: BKN LYR 7/10 17/20",
      } -- end of Preset22
      "Preset23" : {
        "readableNameShort" : "Overcast 3",
        "metar" : "METAR: BKN LYR 11/14 18/25 SCT 32/35",
      } -- end of Preset23
      "Preset24" : {
        "readableNameShort" : "Overcast 4",
        "metar" : "METAR: BKN/OVC 3/7 17/22 BKN 34",
      } -- end of Preset24
      "Preset25" : {
        "readableNameShort" : "Overcast 5",
        "metar" : "METAR: OVC LYR 12/14 22/25 40/42",
      } -- end of Preset25
      "Preset26" : {
        "readableNameShort" : "Overcast 6",
        "metar" : "METAR: OVC 9/15 BKN 23/25 SCT 32",
      } -- end of Preset26
      "Preset27" : {
        "readableNameShort" : "Overcast 7",
        "metar" : "METAR: OVC 8/15 SCT/BKN 25/26 34/36",
      } -- end of Preset27
      "RainyPreset1" : {
        "readableNameShort" : "Overcast And Rain 1",
        "metar" : "METAR: VIS 3-5KM RA OVC 3/15 28/30 FEW 40",
      } -- end of RainyPreset1
      "RainyPreset2" : {
        "readableNameShort" : "Overcast And Rain 2",
        "metar" : "METAR: VIS 1-5KM RA BKN/OVC 3/11 SCT 18/29 FEW 40",
      } -- end of RainyPreset2
      "RainyPreset3" : {
        "readableNameShort" : "Overcast And Rain 3",
        "metar" : "METAR: VIS 3-5KM RA OVC LYR 6/18 19/21 SCT 34",
      } -- end of RainyPreset3
    }
 */

    const DCS_CLEARSKY = ["Preset1", "Preset2", "Preset3", "Preset4", "Preset5", "Preset8", "Preset10", "Preset11"];
    const DCS_FEW = ["Preset1", "Preset2", "Preset3", "Preset4", "Preset5", "Preset6"];
    const DCS_SCT = ["Preset1", "Preset2", "Preset3", "Preset4", "Preset5", "Preset6", "Preset8", "Preset10", "Preset15"];
    const DCS_BKN = ["Preset5", "Preset6", "Preset7", "Preset8", "Preset9", "Preset10", "Preset11", "Preset12", "Preset13", "Preset14", "Preset15", "Preset16"];
    const DCS_OVC = ["Preset17", "Preset18", "Preset19", "Preset20", "Preset21", "Preset22", "Preset23", "Preset24", "Preset25", "Preset26", "Preset27"];
    const DCS_RAIN = ["RainyPreset1", "RainyPreset2", "RainyPreset3"];
   
    if (this._cloudPreset)
      return this._cloudPreset;
      
    this._cloudPreset = "Preset3";

    let clouds = this.getClosestResult()['clouds'];
    if (this.trace) console.log('clouds :>> ', clouds);

    if (this.containsAnyCondition(['TS'])) // thunderstorm is not yet implemented - return rainy weather
      this._cloudPreset = DCS_RAIN[Math.floor(Math.random() * DCS_RAIN.length)];

    if (clouds && clouds.length > 0) {

      let highestclouds = clouds[clouds.length - 1];
      if (this.trace) console.log('highestclouds :>> ', highestclouds);
  
      if (highestclouds.code == "OVC") {
        if (this.getWeatherType() > 0) 
          this._cloudPreset = DCS_RAIN[Math.floor(Math.random() * DCS_RAIN.length)]; // make it rain
        else
          this._cloudPreset = DCS_OVC[Math.floor(Math.random() * DCS_OVC.length)]; // overcast
      } else if (highestclouds.code == "BKN") {
        this._cloudPreset = DCS_BKN[Math.floor(Math.random() * DCS_BKN.length)]; // broken
      } else if (highestclouds.code == "SCT") {
        this._cloudPreset = DCS_SCT[Math.floor(Math.random() * DCS_SCT.length)]; // scattered
      } else if (highestclouds.code == "FEW") {
        this._cloudPreset = DCS_FEW[Math.floor(Math.random() * DCS_FEW.length)]; // few
      }
      if (this._clearsky) this._cloudPreset = DCS_CLEARSKY[Math.floor(Math.random() * DCS_CLEARSKY.length)]; // nothing lower than 15000 ft
    }

    return this._cloudPreset;
  }

  getCloudDensity() {
    try {
      let clouds = this.getClosestResult()['clouds'];
      if (this.trace) console.log('clouds :>> ', clouds);
      if (clouds.length == 0)
        return 0;
      if (this.containsAnyCondition(['TS']))
        return 9;

      let highestclouds = clouds[clouds.length - 1];
      if (this.trace) console.log('highestclouds :>> ', highestclouds);
      if (new Array('CAVOK', 'CLR', 'SKC', 'NCD', 'NSC').indexOf(highestclouds['code']) != -1) {
        if (this.trace) console.log(highestclouds['code']);
        return 0;
      } else {
        if (this._clearsky) {
          return 1
        } else {
          switch (highestclouds['code']) {
            case 'FEW': return this.getDeterministicRandomInt(1, 2);
            case 'SCT': return this.getDeterministicRandomInt(3, 4);
            case 'BKN': return this.getDeterministicRandomInt(5, 8);
            case 'OVC': return 9;
            case 'VV': return this.getDeterministicRandomInt(2, 8);
            default: return 0;
          }
        }
      }
    }
    catch (err) {
      console.log(err);
      return 0;
    }
  }

  getWeatherType() {
    if (this.containsAnyCondition(['TS']))
      return 2;
    else if (this.containsAnyCondition(['RA', 'DZ', 'GR', 'UP']))
      return 1;
    else if (this.containsAnyCondition(['SN', 'SG', 'PL', 'IC', 'PL'])) {
      if (this.getTemperatureASL() < 2) {
        if (this.getCloudDensity() >= 9)
          return 4;
        else
          return 3;
      } else
        return 1;
    }
    return 0
  }

  getFogEnabled() {
    return this.containsAnyCondition(['FG']);
  }

  getFogVisibility() {
    if (this.getFogEnabled())
      return this.getDeterministicRandomInt(800, 1000);
    else
      return 0;
  }

  getFogThickness() {
    if (this.getFogEnabled())
      return this.getDeterministicRandomInt(100, 300);
    else
      return 0;
  }

  getVisibility() {
    if (this.getClosestResult() && this.getClosestResult()['visibility'] && this.getClosestResult()['visibility']['meters_float']) {
      let visibility = this.getClosestResult()['visibility']['meters_float'];
      if (visibility >= 9000)
        return 80000;
      else
        return visibility;
    } else {
      return 80000;  
    }
  }
}
module.exports = DCSCheckWXConvertEnricher;