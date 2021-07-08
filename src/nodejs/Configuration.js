var fs = require("fs");

class Configuration {
  _theatres = {
    "caucasus": {"lat": 42.355691, "lon": 43.323853},
    "persiangulf": {"lat": 26.304151 , "lon": 56.378506},
    "nevada": {"lat": 36.145615, "lon": -115.187618},
    "normandy": {"lat": 49.183336, "lon": -0.365908},
    "marianaislands": {"lat": 14.079866, "lon": 145.15311411102653}
  }
  _checkwx_apikey;
  _cacheFolder;
  _maxAgeInHours;

  constructor(filename) {
    try {
      filename = filename || './configuration.json';
      if (!fs.existsSync(filename)) {
        console.error("configuration file ./configuration.json does not exist ; we'll create it, then you will have to fill the required parts : _checkwx_apikey");
        // save the configuration as a JSON file
        let data = {
          theatres: this.theatres,
          checkwx_apikey: this.checkwx_apikey,
          cacheFolder: this.cacheFolder,
          maxAgeInHours: this.maxAgeInHours
        };
        fs.writeFileSync(filename, JSON.stringify(data, null, 2));
        process.exit(-1);
      } else {
        let json = fs.readFileSync(filename);
        if (!json) {
          console.error("cannot read file "+filename); // no file ?
          return;
        }
        let data = JSON.parse(json);
        if (!data) {
          console.error("cannot parse file content "+filename); // invalid content
          return;
        }
        this._theatres = data.theatres;
        this._checkwx_apikey = data.checkwx_apikey;
        this._cacheFolder = data.cacheFolder;
        this._maxAgeInHours = data.maxAgeInHours;
      }

    } catch(error) {
      console.error(error);
    }
  }

  get theatres() {
    return this._theatres || {};
  }

  get checkwx_apikey() {
    return this._checkwx_apikey || "";
  }

  get cacheFolder() {
    return this._cacheFolder || "./cache";
  }

  get maxAgeInHours() {
    if (this._maxAgeInHours == null) {
      return 24
    } else {
      return this._maxAgeInHours
    }
  }

  get maxAge() {
    return this.maxAgeInHours * 3600 * 1000;
  }
}

module.exports = Configuration;

