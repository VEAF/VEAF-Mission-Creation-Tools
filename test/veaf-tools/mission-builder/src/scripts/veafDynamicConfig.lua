local scriptsToLoad =
{
    -- load BEFORE missionConfig.lua
    --
    -- missionConfig.lua
    "missionConfig.lua",
    -- load AFTER missionConfig.lua
    --
}

if (VEAF_DYNAMIC_MISSIONPATH) then
    local sMissionScriptsPath = VEAF_DYNAMIC_MISSIONPATH .. [[src\scripts\]]
    for _, script in pairs(scriptsToLoad) do
        local sPathToExec = sMissionScriptsPath .. script
        veaf.loggers.get(veaf.Id):info("DynamicConfig: loading " .. sPathToExec)
        assert(loadfile(sPathToExec))()
    end
else
    veaf.loggers.get(veaf.Id):error("DynamicConfig: cannot load because the VEAF_DYNAMIC_MISSIONPATH is not set")
end