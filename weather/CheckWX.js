const request = require('request');

const TEST = false;
const TESTRESULT = { "results": 5, "data": [{ "wind": { "degrees": 0, "speed_kts": 3, "speed_mph": 3, "speed_mps": 2 }, "temperature": { "celsius": 23, "fahrenheit": 73 }, "dewpoint": { "celsius": 15, "fahrenheit": 59 }, "humidity": { "percent": 61 }, "barometer": { "hg": 30.03, "hpa": 1017, "kpa": 101.69, "mb": 1016.92 }, "visibility": { "meters": "10,000+", "meters_float": 10000 }, "elevation": { "feet": 223, "meters": 68 }, "location": { "coordinates": [42.482601, 42.176701], "type": "Point" }, "radius": { "from": { "latitude": 42.355691, "longitude": 43.323853 }, "miles": 44.806455301041915, "meters": 72109, "bearing": 254 }, "icao": "UGKO", "station": { "name": "Kopitnari" }, "observed": "2020-05-14T16:00:00.000Z", "raw_text": "UGKO 141600Z VRB03KT CAVOK 23/15 Q1017 NOSIG", "flight_category": "VFR", "clouds": [{ "code": "CAVOK", "text": "Clear skies" }], "conditions": [] }, { "wind": { "degrees": 0, "speed_kts": 4, "speed_mph": 5, "speed_mps": 2, "gust_kts": 11, "gust_mph": 13, "gust_mps": 6 }, "temperature": { "celsius": 42, "fahrenheit": 108 }, "dewpoint": { "celsius": 9, "fahrenheit": 48 }, "humidity": { "percent": 14 }, "barometer": { "hg": 29.75, "hpa": 1007, "kpa": 100.74, "mb": 1007.42 }, "visibility": { "meters": "10,000+", "meters_float": 10000 }, "location": { "coordinates": [43.0833, 43.0833], "type": "Point" }, "radius": { "from": { "latitude": 42.355691, "longitude": 43.323853 }, "miles": 51.79253161536626, "meters": 83352, "bearing": 346 }, "icao": "KQND", "station": { "name": "Camp Nothing Hil" }, "observed": "2020-05-14T15:56:00.000Z", "raw_text": "KQND 141556Z AUTO VRB04G11KT 9999 CLR 42/09 A2975 RMK AO2 SLP055 WND DATA ESTMD T04150087", "flight_category": "VFR", "clouds": [{ "code": "CLR", "text": "Clear skies" }], "conditions": [] }, { "wind": { "degrees": 100, "speed_kts": 4, "speed_mph": 5, "speed_mps": 2 }, "temperature": { "celsius": 19, "fahrenheit": 66 }, "dewpoint": { "celsius": 9, "fahrenheit": 48 }, "humidity": { "percent": 52 }, "barometer": { "hg": 30.09, "hpa": 1019, "kpa": 101.89, "mb": 1018.92 }, "visibility": { "meters": "10,000+", "meters_float": 10000 }, "elevation": { "feet": 1460, "meters": 445 }, "location": { "coordinates": [43.6366, 43.512901], "type": "Point" }, "radius": { "from": { "latitude": 42.355691, "longitude": 43.323853 }, "miles": 81.59660085102998, "meters": 131317, "bearing": 11 }, "icao": "URMN", "station": { "name": "Nalchik" }, "observed": "2020-05-14T15:00:00.000Z", "raw_text": "URMN 141500Z 10002MPS 9999 NSC 19/09 Q1019 R24/////// NOSIG RMK QFE727", "flight_category": "VFR", "clouds": [{ "code": "CLR", "text": "Clear skies" }], "conditions": [] }, { "wind": { "degrees": 40, "speed_kts": 10, "speed_mph": 12, "speed_mps": 5 }, "temperature": { "celsius": 18, "fahrenheit": 64 }, "dewpoint": { "celsius": 10, "fahrenheit": 50 }, "humidity": { "percent": 60 }, "barometer": { "hg": 30.12, "hpa": 1020, "kpa": 101.99, "mb": 1019.92 }, "visibility": { "meters": "10,000+", "meters_float": 10000 }, "elevation": { "feet": 1673, "meters": 510 }, "location": { "coordinates": [44.606602, 43.205101], "type": "Point" }, "radius": { "from": { "latitude": 42.355691, "longitude": 43.323853 }, "miles": 87.7084078978764, "meters": 141153, "bearing": 48 }, "icao": "URMO", "station": { "name": "Beslan" }, "observed": "2020-05-14T15:30:00.000Z", "raw_text": "URMO 141530Z AUTO 04005MPS 9999 // NCD 18/10 Q1020 RMK QFE721/0961", "flight_category": "VFR", "clouds": [{ "code": "CLR", "text": "Clear skies" }], "conditions": [] }, { "wind": { "degrees": 320, "speed_kts": 10, "speed_mph": 12, "speed_mps": 5 }, "temperature": { "celsius": 22, "fahrenheit": 72 }, "dewpoint": { "celsius": 8, "fahrenheit": 46 }, "humidity": { "percent": 41 }, "barometer": { "hg": 30.12, "hpa": 1020, "kpa": 101.99, "mb": 1019.92 }, "visibility": { "meters": "10,000+", "meters_float": 10000 }, "elevation": { "feet": 1624, "meters": 495 }, "location": { "coordinates": [44.9547, 41.669201], "type": "Point" }, "radius": { "from": { "latitude": 42.355691, "longitude": 43.323853 }, "miles": 96.32931181897716, "meters": 155027, "bearing": 120 }, "icao": "UGTB", "station": { "name": "Tbilisi International" }, "observed": "2020-05-14T16:00:00.000Z", "raw_text": "UGTB 141600Z 32010KT CAVOK 22/08 Q1020 NOSIG", "flight_category": "VFR", "clouds": [{ "code": "CAVOK", "text": "Clear skies" }], "conditions": [] }] };


class CheckWX {

  constructor(apiKey) {
    this._apiKey = apiKey
  }

  get apiKey() {
    return this._apiKey;
  }

  set apiKey(value) {
    this._apiKey = value;
  }

  getWeatherForLatLon(latitude, longitude) {
    return new Promise((resolve, reject) => {
      const requesturl = `${CheckWX.baseURL}metar/lat/${latitude}/lon/${longitude}/radius/100/decoded`;
      const options = {
        headers: {
          "Accept": "application/json",
          "X-API-Key": this._apiKey
        }
      };
      if (TEST) {
        resolve(TESTRESULT);
      } else {
        request.get(requesturl, {
          headers: {
            "Accept": "application/json",
            "X-API-Key": this._apiKey
          }
        }, function (error, response, body) {
          if (error) {
            console.log("Error: " + error);
            reject(error);
          } else {
            let responseBodyJson = JSON.parse(response.body);
            resolve(responseBodyJson);
          }
        });
      }
    });
  }
}
CheckWX.baseURL = "https://api.checkwx.com/";

module.exports = CheckWX;