-- demo-delayed-hello.lua
--
-- Demonstrates FEAT-CUSTOM-SCRIPT-LOAD-DELAY: mission.yaml loads this file in a trigger of its own,
-- `delay_seconds` after mission start, instead of with everything else at t=0. A v5 mission could not
-- declare a staggered load — the whole point is that a script inventorying the world (AIEN, say) can
-- wait for the scripts that create groups to have run first.
--
-- This one just logs, so the delay is visible in dcs.log at the timestamp it fires rather than at 0.
if veaf and veaf.loggers then
  veaf.loggers.get(veaf.Id):info("demo: delayed custom script loaded (FEAT-CUSTOM-SCRIPT-LOAD-DELAY)")
end
