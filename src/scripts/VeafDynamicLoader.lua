env.info( '*** VEAF-DYNAMICLOADER SCRIPTS DYNAMIC INCLUDE START *** ' )

local base = _G

__Veaf = {}

__Veaf.Include = function( IncludeFile )
	if not __Veaf.Includes[ IncludeFile ] then
		__Veaf.Includes[IncludeFile] = IncludeFile
		local f = assert( base.loadfile( IncludeFile ) )
		if f == nil then
			error ("VEAF-DYNAMICLOADER: Could not load Veaf script file " .. IncludeFile )
		else
			env.info( "VEAF-DYNAMICLOADER: " .. IncludeFile .. " dynamically loaded." )
			return f()
		end
	end
end

__Veaf.Includes = {}

if not VEAF_DYNAMIC_SCRIPTSPATH then
  VEAF_DYNAMIC_SCRIPTSPATH = ""
end

-- load the VEAF scripts
__Veaf.Include( VEAF_DYNAMIC_SCRIPTSPATH .. '/src/scripts/veaf/veaf.lua' )
__Veaf.Include( VEAF_DYNAMIC_SCRIPTSPATH .. '/src/scripts/veaf/veafTime.lua' )
__Veaf.Include( VEAF_DYNAMIC_SCRIPTSPATH .. '/src/scripts/veaf/veafAirbases.lua' )
__Veaf.Include( VEAF_DYNAMIC_SCRIPTSPATH .. '/src/scripts/veaf/veafWeather.lua' )
__Veaf.Include( VEAF_DYNAMIC_SCRIPTSPATH .. '/src/scripts/veaf/veafAssets.lua' )
__Veaf.Include( VEAF_DYNAMIC_SCRIPTSPATH .. '/src/scripts/veaf/veafCarrierOperations.lua' )
__Veaf.Include( VEAF_DYNAMIC_SCRIPTSPATH .. '/src/scripts/veaf/veafCasMission.lua' )
__Veaf.Include( VEAF_DYNAMIC_SCRIPTSPATH .. '/src/scripts/veaf/veafCombatMission.lua' )
__Veaf.Include( VEAF_DYNAMIC_SCRIPTSPATH .. '/src/scripts/veaf/veafCombatZone.lua' )
__Veaf.Include( VEAF_DYNAMIC_SCRIPTSPATH .. '/src/scripts/veaf/veafGrass.lua' )
__Veaf.Include( VEAF_DYNAMIC_SCRIPTSPATH .. '/src/scripts/veaf/veafInterpreter.lua' )
__Veaf.Include( VEAF_DYNAMIC_SCRIPTSPATH .. '/src/scripts/veaf/veafMarkers.lua' )
__Veaf.Include( VEAF_DYNAMIC_SCRIPTSPATH .. '/src/scripts/veaf/veafMove.lua' )
__Veaf.Include( VEAF_DYNAMIC_SCRIPTSPATH .. '/src/scripts/veaf/veafNamedPoints.lua' )
__Veaf.Include( VEAF_DYNAMIC_SCRIPTSPATH .. '/src/scripts/veaf/veafRadio.lua' )
__Veaf.Include( VEAF_DYNAMIC_SCRIPTSPATH .. '/src/scripts/veaf/veafSecurity.lua' )
__Veaf.Include( VEAF_DYNAMIC_SCRIPTSPATH .. '/src/scripts/veaf/veafShortcuts.lua' )
__Veaf.Include( VEAF_DYNAMIC_SCRIPTSPATH .. '/src/scripts/veaf/veafSpawn.lua' )
__Veaf.Include( VEAF_DYNAMIC_SCRIPTSPATH .. '/src/scripts/veaf/veafTransportMission.lua' )
__Veaf.Include( VEAF_DYNAMIC_SCRIPTSPATH .. '/src/scripts/veaf/dcsUnits.lua' )
__Veaf.Include( VEAF_DYNAMIC_SCRIPTSPATH .. '/src/scripts/veaf/veafUnits.lua' )
__Veaf.Include( VEAF_DYNAMIC_SCRIPTSPATH .. '/src/scripts/veaf/veafRemote.lua' )
__Veaf.Include( VEAF_DYNAMIC_SCRIPTSPATH .. '/src/scripts/veaf/veafSkynetIadsHelper.lua' )
__Veaf.Include( VEAF_DYNAMIC_SCRIPTSPATH .. '/src/scripts/veaf/veafSkynetIadsMonitor.lua' ) -- FG 01/04/2023
__Veaf.Include( VEAF_DYNAMIC_SCRIPTSPATH .. '/src/scripts/veaf/veafSanctuary.lua' )
__Veaf.Include( VEAF_DYNAMIC_SCRIPTSPATH .. '/src/scripts/veaf/veafQraManager.lua' )
__Veaf.Include( VEAF_DYNAMIC_SCRIPTSPATH .. '/src/scripts/veaf/veafAirwaves.lua' )
__Veaf.Include( VEAF_DYNAMIC_SCRIPTSPATH .. '/src/scripts/veaf/veafEventHandler.lua' )
__Veaf.Include( VEAF_DYNAMIC_SCRIPTSPATH .. '/src/scripts/veaf/veafCacheManager.lua' )
__Veaf.Include( VEAF_DYNAMIC_SCRIPTSPATH .. '/src/scripts/veaf/veafGroundAI.lua' )

-- set the environment in debug mode
env.info( '*** VEAF-DYNAMICLOADER set the environment in debug mode *** ' )
veaf.Development = true
veaf.loggers.setBaseLevel(veaf.Logger.LEVEL["trace"])
veaf.SecurityDisabled = true
veafSecurity.authenticated = true

--[[ load Witchcraft
if witchcraft then
	env.info( '*** Start Witchcraft *** ' )
	witchcraft.start(_G)
end
]]

env.info( '*** VEAF-DYNAMICLOADER SCRIPTS INCLUDE END *** ' )
