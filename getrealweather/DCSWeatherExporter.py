import sys
import os
from CheckWX import CheckWX
from DCSCheckWXConvertEnricher import DCSCheckWXConvertEnricher
from libraries.slpp import dcsslpp as lua
import configparser

config = configparser.RawConfigParser()
config.read('config.properties')

WXDATAAPIKEY = config.get('CheckWX', 'apikey')

def getTheatreLatLon(theatre):
    if theatre == 'caucasus':
        return {"lat": 42.355691, "lon": 43.323853}
    elif theatre == 'persiangulf':
        return {"lat": 26.304151 , "lon": 56.378506}
    elif theatre == 'nevada':
        return {"lat": 36.145615, "lon": -115.187618}
    elif theatre == 'normandy':
        return {"lat": 49.183336, "lon": -0.365908}
    else:
        return None

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print('Usage: python DCSWeatherExporter <theatre> <weather file>')
    else:
        theatre=sys.argv[1].lower()
        weatherFile=sys.argv[2]
            
        print('Theatre:', theatre)
        print('Weather file:', weatherFile)

        print('Preparing weather provider')
        weatherprovider = CheckWX(WXDATAAPIKEY)
        theatreLatLong=getTheatreLatLon(theatre)
        weatherdata = DCSCheckWXConvertEnricher(weatherprovider.getWeatherForLatLon(theatreLatLong['lat'], theatreLatLong['lon']))
        #print('Weather for mission:', weatherdata.getLastWeather().text)
        print('Weather was cached:', weatherdata.getLastWeather().from_cache)

        print('Reading weather file')
        weatherfilehandle=open(weatherFile, "r", encoding="utf8")
        weatherFileData = lua.decode('{' + weatherfilehandle.read() + '}')
        weatherfilehandle.close()

        print('Setting weather data')
        weatherAndTime=weatherFileData["weatherAndTime"]
        weather = weatherAndTime["weather"]
        weather['atmosphere_type'] = 0 #Setting static weather
        weather['cyclones'] = []
        weather['season']['temperature'] = weatherdata.getTemperatureASL()
        windASL = weatherdata.getWindASL()
        wind2000 = weatherdata.getWind2000()
        wind8000 = weatherdata.getWind8000()
        weather['wind']['atGround']['speed'] = windASL['speed']
        weather['wind']['atGround']['dir'] = windASL['direction']
        weather['wind']['at2000']['speed'] = wind2000['speed']
        weather['wind']['at2000']['dir'] = wind2000['direction']
        weather['wind']['at8000']['speed'] = wind8000['speed']
        weather['wind']['at8000']['dir'] = wind8000['direction']
        weather['enable_fog'] = weatherdata.getFogEnabled()
        weather['qnh'] = weatherdata.getBarometerMMHg()
        weather['dust_density'] = 0
        weather['enable_dust'] = False
        weather['clouds']['density'] = weatherdata.getCloudDensity()
        weather['clouds']['thickness'] = weatherdata.getCloudThickness()
        weather['clouds']['base'] = weatherdata.getCloudBase()
        weather['clouds']['iprecptns'] = weatherdata.getWeatherType()
        weather['groundTurbulence'] = weatherdata.getGroundTurbulence()
        weather['type_weather'] = 0
        weather['fog']['thickness'] = weatherdata.getFogThickness()
        weather['fog']['visibility'] = weatherdata.getFogVisibility()
        weather['visibility']['distance'] = weatherdata.getVisibility()
        
        print('Writing weather file')
        weatherfilehandle=open(weatherFile, "w", encoding="utf8")
        weatherfilehandle.write("weatherAndTime="+lua.encode(weatherAndTime))
        weatherfilehandle.close()

        print('Saved', weatherFile, 'successfully.')
