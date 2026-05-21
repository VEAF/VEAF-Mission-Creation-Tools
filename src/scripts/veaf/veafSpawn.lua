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
-- This file is a proxy that loads the 4 sub-modules:
--   veafSpawnCore.lua     (constants, event handling, parsing, drawing, group spawn, mission master)
--   veafSpawnGround.lua   (FARP, FOB, infantry, armored, air defense, convoy)
--   veafSpawnAircraft.lua (aircraft, CAP, AFAC, JTAC)
--   veafSpawnEffects.lua  (cargo, bomb, smoke, flares, destroy, teleport)
------------------------------------------------------------------

local _dir = ""
if debug and debug.getinfo then
  local _info = debug.getinfo(1, "S")
  if _info and _info.source and _info.source:sub(1, 1) == "@" then
    _dir = _info.source:sub(2):match("^(.+[\\/])") or ""
  end
end
dofile(_dir .. "veafSpawnCore.lua")
dofile(_dir .. "veafSpawnGround.lua")
dofile(_dir .. "veafSpawnAircraft.lua")
dofile(_dir .. "veafSpawnEffects.lua")
