env.info( '*** VEAF-Mission-Creation-Tools SCRIPTS DYNAMIC INCLUDE START *** ' )

local base = _G

__Veaf = {}

__Veaf.Include = function( IncludeFile )
	if not __Veaf.Includes[ IncludeFile ] then
		__Veaf.Includes[IncludeFile] = IncludeFile
		local f = assert( base.loadfile( IncludeFile ) )
		if f == nil then
			error ("VEAF-Mission-Creation-Tools: Could not load Veaf script file " .. IncludeFile )
		else
			env.info( "VEAF-Mission-Creation-Tools: " .. IncludeFile .. " dynamically loaded." )
			return f()
		end
	end
end

__Veaf.Includes = {}

if not VEAF_DYNAMIC_PATH then
  VEAF_DYNAMIC_PATH = ""
end

-- load the community scripts
--__Veaf.Include( VEAF_DYNAMIC_PATH .. '/scripts/community/mist.lua' )
--__Veaf.Include( VEAF_DYNAMIC_PATH .. '/scripts/community/Moose.lua' )
--__Veaf.Include( VEAF_DYNAMIC_PATH .. '/scripts/community/WeatherMark.lua' )

-- load the VEAF scripts
__Veaf.Include( VEAF_DYNAMIC_PATH .. '/scripts/veaf/veaf.lua' )
__Veaf.Include( VEAF_DYNAMIC_PATH .. '/scripts/veaf/veafAssets.lua' )
__Veaf.Include( VEAF_DYNAMIC_PATH .. '/scripts/veaf/veafCarrierOperations.lua' )
__Veaf.Include( VEAF_DYNAMIC_PATH .. '/scripts/veaf/veafCarrierOperations2.lua' )
__Veaf.Include( VEAF_DYNAMIC_PATH .. '/scripts/veaf/veafCasMission.lua' )
__Veaf.Include( VEAF_DYNAMIC_PATH .. '/scripts/veaf/veafCombatMission.lua' )
__Veaf.Include( VEAF_DYNAMIC_PATH .. '/scripts/veaf/veafCombatZone.lua' )
__Veaf.Include( VEAF_DYNAMIC_PATH .. '/scripts/veaf/veafGrass.lua' )
__Veaf.Include( VEAF_DYNAMIC_PATH .. '/scripts/veaf/veafInterpreter.lua' )
__Veaf.Include( VEAF_DYNAMIC_PATH .. '/scripts/veaf/veafMarkers.lua' )
__Veaf.Include( VEAF_DYNAMIC_PATH .. '/scripts/veaf/veafMove.lua' )
__Veaf.Include( VEAF_DYNAMIC_PATH .. '/scripts/veaf/veafNamedPoints.lua' )
__Veaf.Include( VEAF_DYNAMIC_PATH .. '/scripts/veaf/veafRadio.lua' )
__Veaf.Include( VEAF_DYNAMIC_PATH .. '/scripts/veaf/veafSecurity.lua' )
__Veaf.Include( VEAF_DYNAMIC_PATH .. '/scripts/veaf/veafShortcuts.lua' )
__Veaf.Include( VEAF_DYNAMIC_PATH .. '/scripts/veaf/veafSpawn.lua' )
__Veaf.Include( VEAF_DYNAMIC_PATH .. '/scripts/veaf/veafTransportMission.lua' )
__Veaf.Include( VEAF_DYNAMIC_PATH .. '/scripts/veaf/dcsUnits.lua' )
__Veaf.Include( VEAF_DYNAMIC_PATH .. '/scripts/veaf/veafUnits.lua' )

-- set the environment in debug mode
env.info( '*** VEAF-Mission-Creation-Tools set the environment in debug mode *** ' )
veaf.Development = true
veaf.Debug = veaf.Development
veaf.Trace = veaf.Development
veaf.SecurityDisabled = veaf.Development
veafSecurity.authenticated = veaf.Development

env.info( '*** VEAF-Mission-Creation-Tools SCRIPTS INCLUDE END *** ' )
