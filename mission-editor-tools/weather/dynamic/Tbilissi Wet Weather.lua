vdata = 
{
    atmosphere_type = 1,
    wind = 
    {
        at8000 = 
        {
            speed = 0,
            dir = 0,
        }, -- end of at8000
        at2000 = 
        {
            speed = 0,
            dir = 0,
        }, -- end of at2000
        atGround = 
        {
            speed = 0,
            dir = 0,
        }, -- end of atGround
    }, -- end of wind
    enable_fog = false,
    season = 
    {
        temperature = 20,
    }, -- end of season
    type_weather = 0,
    qnh = 760,
    cyclones = 
    {

		
		-- General Weather 1
		  [1] = 
        {
            ellipticity = 3,
            centerZ = 900000,
            groupId = 2073,
            pressure_spread = 300000,
            rotation = -1,
            pressure_excess = -200,
            centerX = -350000,
        }, -- end of [1]
		
				
		-- Storm 1
		  [2] = 
        {
            centerZ = 925000,
            groupId = 2073,
            pressure_spread = 90000,
			      ellipticity = 0.58203634771562,
			      rotation = -0.64882076496654,
            pressure_excess = -150,
            centerX = -370000,
        }, -- end of [2]
		
		-- Storm 2
		  [3] = 
        {
            ellipticity = 1,
            centerZ = 750000,
            groupId = 2073,
            pressure_spread = 50000,
            rotation = 1,
            pressure_excess = -250,
            centerX = -335000,
        }, -- end of [3]
		
    }, -- end of cyclones
    name = "Tbilissi Wet Weather",
    fog = 
    {
        thickness = 0,
        visibility = 25,
        density = 7,
    }, -- end of fog
    groundTurbulence = 15,
    visibility = 
    {
        distance = 60000,
    }, -- end of visibility
    clouds = 
    {
        density = 0,
        thickness = 200,
        base = 1500,
        iprecptns = 0,
    }, -- end of clouds
} -- end of vdata