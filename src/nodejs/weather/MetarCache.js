"use strict";

var fs = require("fs");
const fsPromises = fs.promises;

class CachedMetar {
  _timestamp;
  _theatre;
  _metar;

  constructor(theatre, metar, timestamp) {
    this._timestamp = timestamp || new Date().getTime();
    this._theatre = theatre;
    this._metar = metar;
  }

  get timestamp() {
    return this._timestamp || new Date().getTime();
  }

  get theatre() {
    return this._theatre || "caucasus";
  }

  get metar() {
    return this._metar;
  } 

  get age() {
    return new Date().getTime() - this.timestamp;
  }

  get datestamp() {
    return new Date(this._timestamp);
  }
}

function _checkCacheFolder(cacheFolder) {
  fs.mkdir(cacheFolder, { recursive: true }, function(err) {
    if (err) {
      console.log(err);
    } 
  });
  return cacheFolder;
}

function getMetarFromCache(cacheFolder, key) {
  return new Promise((resolve, reject) => {
    (async () => {
      try {
        let filename = `${_checkCacheFolder(cacheFolder)}/${key}-cached-metar.json`;
        let json = await fsPromises.readFile(filename);
        if (!json) resolve(null); // no file ?
        let data = JSON.parse(json);
        if (!data) resolve(null); // invalid content ?
        let cachedMetar = new CachedMetar(data._theatre, data._metar, data._timestamp);
        return resolve(cachedMetar);
      } catch(error) {
        resolve(null);
      }
    })();
  });

}

function storeMetarIntoCache(cacheFolder, key, theatre, metar) {
  return new Promise((resolve, reject) => {
    (async () => {
      try {
        let filename = `${_checkCacheFolder(cacheFolder)}/${key}-cached-metar.json`;
        let cachedMetar = new CachedMetar(theatre, metar);
        let json = JSON.stringify(cachedMetar);
        await fsPromises.writeFile(filename, json);
        return resolve(cachedMetar);
      } catch(error) {
        reject(error);
      }
    })();
  });
}

module.exports.CachedMetar = CachedMetar;
module.exports.getMetarFromCache = getMetarFromCache;
module.exports.storeMetarIntoCache = storeMetarIntoCache;