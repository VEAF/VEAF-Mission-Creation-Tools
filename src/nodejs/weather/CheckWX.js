"use strict";

const got = require('got');

class CheckWX {

  constructor(apiKey) {
    if (!apiKey) {
      console.error("CheckWX API Key not defined; go get one on https://www.checkwxapi.com");
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
        },
        timeout: {
          lookup: 1000,
          connect: 500,
          secureConnect: 500,
          socket: 10000,
          send: 10000,
          response: 10000
        }
      };

      (async () => {
        try {
          const response = await got(requesturl, options);
          let responseBodyJson = JSON.parse(response.body);
          resolve(responseBodyJson);
        } catch (error) {
          reject(error);
        }
      })();

    });
  }
}
CheckWX.baseURL = "https://api.checkwx.com/";

module.exports = CheckWX;