------------------------------------------------------------------
-- VEAF Quick Reaction Alert for DCS World
-- https://en.wikipedia.org/wiki/Quick_Reaction_Alert
-- By Zip (2020) and Rex (2022)
--
-- Features:
-- ---------
-- * Define zones that are defended by an AI flight
-- * Default behavior: when an ennemy aircraft enters the zone, QRA patrol is spawned; then, when it is destroyed, the zone is not defended anymore; when all enemy aircrafts have left the zone, it resets and can respawn a new QRA
--
-- See the documentation : https://veaf.github.io/documentation/
--
-- This file is a proxy that loads the 2 sub-modules:
--   veafQraLogistics.lua  (VeafQRALogistics -- warehousing / resupply chain)
--   veafQraCore.lua       (VeafQRACore -- state, detection, spawn/despawn; veafQraManager table)
--
-- In the concatenated build (veaf-scripts.lua) the sub-modules are already
-- inlined before this file, so the dofile calls are skipped.
------------------------------------------------------------------

if not veafQraManager or not veafQraManager.Id then
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
  dofile(_dir .. "veafQraLogistics.lua")
  dofile(_dir .. "veafQraCore.lua")
end
