import json
import random
import inspect

class DCSCheckWXConvertEnricher(object):
    """
    Enrichment procedures are mostly based on dcs_weather from here https://forums.eagle.ru/showthread.php?t=198402.
    Some other things are new, deterministic randomness, temperature correction for sea level, etc.
    """
    weatherdata = None
    parseddata = None

    def __init__(self, weatherdata):
        self.weatherdata = weatherdata
        self.parseddata = json.loads(weatherdata.text)

    def seedRandom(self):
        """
        Seeds the PRNG deterministically for repeatable same randoms
        :return: None
        """
        callingFunc = inspect.stack()[1].function
        random.seed(self.weatherdata.text + callingFunc)

    def getDeterministicRandomFloat(self, min, max):
        """
        Returns a deterministic random value for a given function calling it and the underlaying weather data.
        :param min: minimum float
        :param max: maximum float
        :return: float between min and max randomly chosen in a repeatable way
        """
        assert max >= min
        randval = random.random()
        return min + ((max-min)*randval)

    def getDeterministicRandomInt(self, min, max):
        """
        Returns a deterministic random value for a given function calling it and the underlaying weather data.
        :param min: minimum int
        :param max: maximum int
        :return: int between min and max randomly chosen in a repeatable way
        """
        return random.randint(min, max)

    def normalizeDegrees(self, angle):
        retangle = angle
        if retangle < 0:
            retangle += 360

        if retangle >= 360:
            retangle -= 360

        return retangle

    def getLastWeather(self):
        return self.weatherdata

    def getClosestResult(self):
        return self.parseddata['data'][0]

    def getStationElevation(self):
        return self.getClosestResult()['elevation']['meters']

    def getBarometerMMHg(self):
        return self.getClosestResult()['barometer']['hg'] * 25.4

    def getTemperature(self):
        return self.getClosestResult()['temperature']['celsius']

    def getTemperatureASL(self):
        """
        The higher the elevation of the reporting station, the higher the sea level temperature really is.
        This is using https://sciencing.com/tutorial-calculate-altitude-temperature-8788701.html as formula
        to adjust the temperature for sea level.
        :return: estimated temperature at sea level
        """
        temperatureDelta = self.getStationElevation() * 0.0065
        return self.getTemperature() + temperatureDelta

    def getWindASL(self):
        self.seedRandom()
        try:
            return {'direction': self.getClosestResult()['wind']['degrees'], 'speed': self.getClosestResult()['wind']['speed_mps'] }
        except:
            return {'direction': self.getDeterministicRandomInt(0, 360), 'speed': self.getDeterministicRandomFloat(0, 1)}

    def getWind2000(self):
        groundWind = self.getWindASL()
        self.seedRandom()
        newDirection = self.normalizeDegrees(groundWind['direction']+self.getDeterministicRandomInt(-10, 10))
        return {'direction': newDirection, 'speed': groundWind['speed']+self.getDeterministicRandomFloat(1, 3)}

    def getWind8000(self):
        groundWind = self.getWindASL()
        self.seedRandom()
        newDirection = self.normalizeDegrees(groundWind['direction'] + self.getDeterministicRandomInt(-20, 20))
        return {'direction': newDirection, 'speed': groundWind['speed']+self.getDeterministicRandomFloat(2, 8)}

    def getGroundTurbulence(self):
        try:
            return self.getClosestResult()['wind']['gust_kts'] / 0.32808398950131233595800524934383
        except:
            self.seedRandom()
            return self.getDeterministicRandomFloat(0, 3) / 0.32808398950131233595800524934383

    def getCloudMinMax(self):
        try:
            clouds = self.getClosestResult()['clouds']
            if len(clouds) == 0:
                return {'min': 5000, 'max': 5000}

            minClouds = None
            maxClouds = None
            for cloud in clouds:
                if not minClouds or cloud['base_meters_agl'] < minClouds:
                    minClouds = cloud['base_meters_agl']
                if not maxClouds or cloud['base_meters_agl'] > maxClouds:
                    maxClouds = cloud['base_meters_agl']
            return {'min': minClouds, 'max': maxClouds}
        except:
            return {'min': 5000, 'max': 5000}

    def getCloudBase(self):
        return max(300, self.getCloudMinMax()['min'])

    def getCloudThickness(self):
        try:
            clouds = self.getClosestResult()['clouds']
            if len(clouds) == 0:
                self.seedRandom()
                return self.getDeterministicRandomInt(200, 300)
            minmaxclouds = self.getCloudMinMax()
            highestclouds = clouds[len(clouds) - 1]
            if highestclouds['code'] in ('OVC'):
                return max(200, minmaxclouds['max'] - minmaxclouds['min'])
            else:
                return minmaxclouds['max']-minmaxclouds['min']
        except:
            self.seedRandom()
            return self.getDeterministicRandomInt(200, 300)

    def containsAnyCondition(self, conditioncodes):
        conditions = self.getClosestResult()['conditions']
        for cond in conditions:
            if cond['code'] in conditioncodes:
                return True
        return False

    def getCloudDensity(self):
        try:
            clouds = self.getClosestResult()['clouds']
            if len(clouds) == 0:
                return 0
            if self.containsAnyCondition(['TS']):
                return 9

            self.seedRandom()
            highestclouds = clouds[len(clouds)-1]
            if highestclouds['code'] in ('CAVOK', 'CLR', 'SKC', 'NCD', 'NSC'):
                return 0
            elif highestclouds['code'] in ('FEW'):
                return self.getDeterministicRandomInt(1, 2)
            elif highestclouds['code'] in ('SCT'):
                return self.getDeterministicRandomInt(3, 4)
            elif highestclouds['code'] in ('BKN'):
                return self.getDeterministicRandomInt(5, 8)
            elif highestclouds['code'] in ('OVC'):
                return 9
            elif highestclouds['code'] in ('VV'):
                return self.getDeterministicRandomInt(2, 8)
            return 0
        except:
            return 0

    def getWeatherType(self):
        if self.containsAnyCondition(['TS']):
            return 2
        elif self.containsAnyCondition(['RA', 'DZ', 'GR', 'UP']):
            return 1
        elif self.containsAnyCondition(['SN', 'SG', 'PL', 'IC', 'PL']):
            if self.getTemperatureASL() < 2:
                if self.getCloudDensity() >= 9:
                    return 4
                else:
                    return 3
            else:
                return 1
        return 0

    def getFogEnabled(self):
        return self.containsAnyCondition(['FG'])

    def getFogVisibility(self):
        if self.getFogEnabled():
            self.seedRandom()
            return self.getDeterministicRandomInt(800, 1000)
        else:
            return 0

    def getFogThickness(self):
        if self.getFogEnabled():
            self.seedRandom()
            return self.getDeterministicRandomInt(100, 300)
        else:
            return 0

    def getVisibility(self):
        try:
            visibility = self.getClosestResult()['visibility']['meters_float']
            if visibility >= 9000:
                return 80000
            else:
                return visibility
        except:
            return 80000
