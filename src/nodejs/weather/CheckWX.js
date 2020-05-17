"use strict";

const request = require('request');

class CheckWX {

  constructor(apiKey) {
    if (!apiKey) {
      console.error("CheckWX API Key not defined; go get one on https://www.checkwx.com/api/newkey");
      process.exit(-1);
    }
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
    });
  }
}
CheckWX.baseURL = "https://api.checkwx.com/";

module.exports = CheckWX;