------------------------------------------------------------------
-- VEAF spawn command and functions for DCS World
-- By zip (2018)
--
-- Features:
-- ---------
-- * Listen to marker change events and execute spawn commands, with optional parameters
-- * Possibilities :
-- *    - spawn a specific ennemy unit or group
-- *    - create a cargo drop to be picked by a helo
--
-- See the documentation : https://veaf.github.io/documentation/
--
-- This file is a proxy that loads the 5 sub-modules:
--   veafSpawnCore.lua     (constants, event handling, drawing, group spawn, mission master)
--   veafSpawnParser.lua   (text parser: convertLaserToFreq, markTextAnalysis)
--   veafSpawnGround.lua   (FARP, FOB, infantry, armored, air defense, convoy)
--   veafSpawnAircraft.lua (aircraft, CAP, AFAC, JTAC)
--   veafSpawnEffects.lua  (cargo, bomb, smoke, flares, destroy, teleport)
--
-- In the concatenated build (veaf-scripts.lua) the sub-modules are already
-- inlined before this file, so the dofile calls are skipped.
------------------------------------------------------------------

if not veafSpawn or not veafSpawn.Id then
  local _dir = ""
  if debug and debug.getinfo then
    local _info = debug.getinfo(1, "S")
    if _info and _info.source then
      -- source is "@<path>" (loadfile) or "<path>" (DCS dynamic loadfile, shown as [string "<path>"])
      local _src = _info.source
      if _src:sub(1, 1) == "@" then
        _src = _src:sub(2)
      end
      _dir = _src:match("^(.+[\\/])") or ""
    end
  end
  dofile(_dir .. "veafSpawnCore.lua")
  dofile(_dir .. "veafSpawnParser.lua")
  dofile(_dir .. "veafSpawnGround.lua")
  dofile(_dir .. "veafSpawnAircraft.lua")
  dofile(_dir .. "veafSpawnEffects.lua")
end
