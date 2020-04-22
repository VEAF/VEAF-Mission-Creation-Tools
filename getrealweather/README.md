# DCSWeatherExporter
This script is a fork of [DCSWeatherInjector](https://github.com/destotelhorus/DCS-WeatherInjector) by *destotelhorus*
I heavily modified it to make it export a weather file used in my build pipeline.

## Prerequisites
- install python3
- setup the python libraries with `pip install -r requirements.txt`
- Get an account on https://www.checkwx.com/ and an apikey.
- Enter apikey into config.properties

## Run
`python DCSWeatherExporter.py <terrain name> <weather file>`

## What will it do
It will export the real weather of the terrain default location (hardcoded) into the weather file, ready to be used with the veafMissionNormalizer script