"use strict";

const got = require('got');

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
        },
        timeout: {
          lookup: 100,
          connect: 50,
          secureConnect: 50,
          socket: 1000,
          send: 1000,
          response: 1000
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