import requests_cache

class CheckWX(object):
    session = None
    apikey = None
    baseURL = 'https://api.checkwx.com/'

    def __init__(self, apikey):
        self.apikey = apikey
        self.session = requests_cache.CachedSession('checkwx_cache', backend='sqlite', expire_after=900)

    def getWeatherForLatLon(self, latitude, longitude):
        hdr = {'X-API-Key': self.apikey}
        requesturl = self.baseURL+f'metar/lat/{latitude}/lon/{longitude}/radius/100/decoded'
        weatherdata = self.session.get(requesturl, headers=hdr)
        return weatherdata
