env.info( '*** VEAF-Mission-Creation-Tools SCRIPTS LOADER START *** ' )

veafScriptsLoader = {}

local l_os = os
if not l_os and SERVER_CONFIG and SERVER_CONFIG.getModule then
    l_os = SERVER_CONFIG.getModule("os")
end

veafScriptsLoader.tempMissionPath = nil
if l_os then
    veafScriptsLoader.tempMissionPath = l_os.getenv("TEMP")
    if veafScriptsLoader.tempMissionPath then
      veafScriptsLoader.tempMissionPath = veafScriptsLoader.tempMissionPath  .. [[\DCS.openbeta\Mission\l10n\DEFAULT\]] 
      env.info(string.format("veafScriptsLoader.tempMissionPath=%s", veafScriptsLoader.tempMissionPath))
    end
end

if not veafScriptsLoader.tempMissionPath then
  env.error("Cannot get the TEMP mission path and load the VEAF scripts !")
  return
end

local base = _G

veafScriptsLoader.Include = function( IncludeFile )
  if not veafScriptsLoader.Includes[ IncludeFile ] then
    veafScriptsLoader.Includes[IncludeFile] = IncludeFile
    local path = veafScriptsLoader.tempMissionPath .. IncludeFile
    local f = assert( base.loadfile( path ) )
    if f == nil then
      env.error ("VEAF-Mission-Creation-Tools: Could not load VEAF script file " .. IncludeFile )
    else
      env.info( "VEAF-Mission-Creation-Tools: " .. IncludeFile .. " loaded from the SCRIPT LOADER." )
      return f()
    end
  end
end

veafScriptsLoader.Includes = {}

-- load the community scripts
veafScriptsLoader.Include( "mist.lua" )
veafScriptsLoader.Include( "DCS-SimpleTextToSpeech.lua" )
veafScriptsLoader.Include( "CTLD.lua" )
veafScriptsLoader.Include( "WeatherMark.lua" )
veafScriptsLoader.Include( "skynet-iads-compiled.lua" )
veafScriptsLoader.Include( "Hercules_Cargo.lua" )
veafScriptsLoader.Include( "HoundElint.lua" )
-- load the VEAF scripts
veafScriptsLoader.Include( "veaf.lua" )
veafScriptsLoader.Include( "veafAssets.lua" )
veafScriptsLoader.Include( "veafCarrierOperations.lua" )
veafScriptsLoader.Include( "veafCasMission.lua" )
veafScriptsLoader.Include( "veafCombatMission.lua" )
veafScriptsLoader.Include( "veafCombatZone.lua" )
veafScriptsLoader.Include( "veafGrass.lua" )
veafScriptsLoader.Include( "veafInterpreter.lua" )
veafScriptsLoader.Include( "veafMarkers.lua" )
veafScriptsLoader.Include( "veafMove.lua" )
veafScriptsLoader.Include( "veafNamedPoints.lua" )
veafScriptsLoader.Include( "veafRadio.lua" )
veafScriptsLoader.Include( "veafSecurity.lua" )
veafScriptsLoader.Include( "veafShortcuts.lua" )
veafScriptsLoader.Include( "veafSpawn.lua" )
veafScriptsLoader.Include( "veafTransportMission.lua" )
veafScriptsLoader.Include( "dcsUnits.lua" )
veafScriptsLoader.Include( "veafUnits.lua" )
veafScriptsLoader.Include( "veafRemote.lua" )
veafScriptsLoader.Include( "veafSkynetIadsHelper.lua" )
veafScriptsLoader.Include( "veafSanctuary.lua" )
veafScriptsLoader.Include( "veafHoundElintHelper.lua" )
veafScriptsLoader.Include( "veafMissileGuardian.lua" )

env.info( '*** VEAF-Mission-Creation-Tools SCRIPTS LOADER END *** ' )