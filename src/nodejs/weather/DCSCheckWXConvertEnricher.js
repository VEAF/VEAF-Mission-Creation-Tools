"use strict";

var parseMETAR = require("metar");

const trace = true;

class DCSCheckWXConvertEnricher {

  _weatherdata = null;
  _closestResult = null;
  _metar = null;
  _trace = false;

  get trace() {
    return this._trace;
  }

  constructor(weatherdata, trace) {
    this._trace = trace;
    if (typeof(weatherdata) == "string") {
      // we've got a text metar to parse
      this._metar = weatherdata;
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
            "hg" : decodedMetar.altimeterInHg || 760
          },
          "wind": {
            "degrees": decodedMetar.wind.direction || 0,
            "speed_mps" : decodedMetar.wind.speed || 0,
            "gust_mps" : decodedMetar.wind.gust || 0,
          },
          "clouds": decodedMetar.clouds.map(cloud => {
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
        console.error("CheckWX API Key not valid ; go get one on https://www.checkwx.com/api/newkey");
        process.exit(-1); 
      }
      this._weatherdata = weatherdata;
      this._metar = this.getClosestResult().raw_text || "";
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

  normalizeDegrees(angle) {
    let retangle = angle;
    if (retangle < 0) retangle = retangle + 360;
    if (retangle >= 360) retangle = retangle - 360;
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
    if (level >= 1 && !data['wind']['speed_mps']) { if (this.trace) console.log("!data['wind']['speed_mps']"); return null; }
    if (level >= 3 && !data['wind']['gust_kts']) { if (this.trace) console.log("!data['wind']['gust_kts']"); return null; }
    if (level >= 2 && !data['clouds']) { if (this.trace) console.log("!data['clouds']"); return null; }
    if (level >= 2 && !data['clouds']['base_meters_agl']) { if (this.trace) console.log("!data['clouds']['base_meters_agl']"); return null; }
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
    return this.getClosestResult()['barometer']['hg'] * 25.4
  }

  getTemperature() {
    return this.getClosestResult()['temperature']['celsius']
  }

  getTemperatureASL() {
    let temperatureDelta = this.getStationElevation() * 0.0065;
    return this.getTemperature() + temperatureDelta;
  }

  getWindASL() {
    try {
      return { 'direction': this.getClosestResult()['wind']['degrees'], 'speed': this.getClosestResult()['wind']['speed_mps'] };
    } catch (err) {
      console.log(err);
      return { 'direction': this.getDeterministicRandomInt(0, 360), 'speed': this.getDeterministicRandomFloat(0, 1) };
    }
  }

  getWind2000() {
    let groundWind = this.getWindASL();
    let newDirection = this.normalizeDegrees(groundWind['direction'] + this.getDeterministicRandomInt(-10, 10));
    return { 'direction': newDirection, 'speed': groundWind['speed'] + this.getDeterministicRandomFloat(1, 3) };
  }

  getWind8000() {
    let groundWind = this.getWindASL()
    let newDirection = this.normalizeDegrees(groundWind['direction'] + this.getDeterministicRandomInt(-20, 20));
    return { 'direction': newDirection, 'speed': groundWind['speed'] + this.getDeterministicRandomFloat(2, 8) };
  }

  getGroundTurbulence() {
    let result = null;
    try {
      if (this.trace) console.log(this.getClosestResult()['wind']);
      if (this.trace) console.log(this.getClosestResult()['wind']['gust_mps']);
      result = this.getClosestResult()['wind']['gust_mps'] / 0.637745;
    } catch {
      console.log(err);
    }
    if (!result)
      result = this.getDeterministicRandomFloat(0, 3) / 0.637745;
    return result;
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
    conditions.forEach((cond) => {
      //if (this.trace) console.log(cloud);
      if (conditioncodes.indexOf(cond) != -1)
        return true;
    });
    return false;
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
    try {
      let visibility = this.getClosestResult()['visibility']['meters_float'];
      if (visibility >= 9000)
        return 80000;
      else
        return visibility;
    } catch (err) {
      console.log(err);
      return 80000;
    }
  }
}
module.exports = DCSCheckWXConvertEnricher;