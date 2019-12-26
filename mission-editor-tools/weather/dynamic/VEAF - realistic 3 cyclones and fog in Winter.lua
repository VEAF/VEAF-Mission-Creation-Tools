vdata = 
{
    wind = 
    {
        at8000 = 
        {
            speed = 15,
            dir = 23,
        }, -- end of at8000
        at2000 = 
        {
            speed = 8,
            dir = 53,
        }, -- end of at2000
        atGround = 
        {
            speed = 2,
            dir = 275,
        }, -- end of atGround
    }, -- end of wind
    enable_fog = true,
    season = 
    {
        temperature = 10.39999961853,
    }, -- end of season
    qnh = 760,
    cyclones = 
    {
        [1] = 
        {
			-- over Serbia
            pressure_spread = 895563.55565682,
            centerZ = -900000,
            groupId = 6576,
            ellipticity = 1,
            rotation = -0.2538764493966,
            pressure_excess = -1311,
            centerX = 300000,
        }, -- end of [1]
        [2] = 
        {
			-- over Iran
            centerZ = 1800000,
            centerX = -1000000,
            pressure_spread = 879834.34389462,
            groupId = 6578,
            ellipticity = 1,
            rotation = -0.2538764493966,
            pressure_excess = -1704,
        }, -- end of [2]
        [3] = 
        {
			-- over Denmark
            centerZ = -2100000,
            centerX = 900000,
            pressure_spread = 879834.34389462,
            groupId = 6580,
            ellipticity = 1,
            rotation = -0.2538764493966,
            pressure_excess = -1704,
        }, -- end of [3]
    }, -- end of cyclones
    name = "VEAF - realistic 3 cyclones and fog in Winter",
    dust_density = 0,
    groundTurbulence = 0,
    enable_dust = false,
    atmosphere_type = 1,
    type_weather = 0,
    fog = 
    {
        thickness = 660,
        visibility = 1350,
    }, -- end of fog
    visibility = 
    {
        distance = 80000,
    }, -- end of visibility
    clouds = 
    {
        thickness = 1600,
        density = 3,
        base = 2100,
        iprecptns = 0,
    }, -- end of clouds
} -- end of vdata
dtime = 
{
    date = 
    {
        Day = 23,
        Year = 2011,
        Month = 12,
    }, -- end of date
    start_time = 35000,
} -- end of dtime
