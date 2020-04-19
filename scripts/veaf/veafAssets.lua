-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VEAF assets functions for DCS World
-- By zip (2019)
--
-- Features:
-- ---------
-- * manage the assets that roam the map (tankers, awacs, ...)
-- * Works with all current and future maps (Caucasus, NTTR, Normandy, PG, ...)
--
-- Prerequisite:
-- ------------
-- * This script requires DCS 2.5.1 or higher and MIST 4.3.74 or higher.
-- * It also requires the base veaf.lua script library (version 1.0 or higher)
--
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafAssets = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafAssets.Id = "ASSETS - "

--- Version.
veafAssets.Version = "1.3.1"

-- trace level, specific to this module
veafAssets.Trace = false

veafAssets.Assets = {
    -- list the assets common to all missions below
}

veafAssets.RadioMenuName = "ASSETS"

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafAssets.rootPath = nil

veafAssets.assets = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafAssets.logInfo(message)
    veaf.logInfo(veafAssets.Id .. message)
end

function veafAssets.logDebug(message)
    veaf.logDebug(veafAssets.Id .. message)
end

function veafAssets.logTrace(message)
    if message and veafAssets.Trace then
        veaf.logTrace(veafAssets.Id .. message)
    end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Radio menu and help
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafAssets._buildAssetRadioMenu(menu, asset)
    if asset.disposable or asset.information then -- in this case we need a submenu
        local radioMenu = veafRadio.addSubMenu(asset.description, menu)
        veafRadio.addSecuredCommandToSubmenu("Respawn "..asset.description, radioMenu, veafAssets.respawn, asset.name, veafRadio.USAGE_ForAll)
        if asset.information then
            veafRadio.addCommandToSubmenu("Get info on "..asset.description, radioMenu, veafAssets.info, asset.name, veafRadio.USAGE_ForGroup)
        end
        if asset.disposable then
            veafRadio.addSecuredCommandToSubmenu("Dispose of "..asset.description, radioMenu, veafAssets.dispose, asset.name, veafRadio.USAGE_ForAll)
        end
    else
        veafRadio.addSecuredCommandToSubmenu("Respawn "..asset.description, menu, veafAssets.respawn, asset.name, veafRadio.USAGE_ForAll)
    end
end

function veafAssets._buildAssetsRadioMenuPage(menu, names, pageSize, startIndex)
    veafAssets.logTrace(string.format("veafAssets._buildAssetsRadioMenuPage(pageSize=%d, startIndex=%d)",pageSize, startIndex))
    
    local namesCount = #names
    veafAssets.logTrace(string.format("namesCount = %d",namesCount))

    local endIndex = namesCount
    if endIndex - startIndex >= pageSize then
        endIndex = startIndex + pageSize - 2
    end
    veafAssets.logTrace(string.format("endIndex = %d",endIndex))
    veafAssets.logTrace(string.format("adding commands from %d to %d",startIndex, endIndex))
    for index = startIndex, endIndex do
        local name = names[index]
        veafAssets.logTrace(string.format("names[%d] = %s",index, name))
        local asset = veafAssets.assets[name]
        veafAssets._buildAssetRadioMenu(menu, asset)
    end
    if endIndex < namesCount then
        veafAssets.logTrace("adding next page menu")
        local nextPageMenu = veafRadio.addSubMenu("Next page", menu)
        veafAssets._buildAssetsRadioMenuPage(nextPageMenu, names, 10, endIndex+1)
    end
end

--- Build the initial radio menu
function veafAssets.buildRadioMenu()
    veafAssets.rootPath = veafRadio.addSubMenu(veafAssets.RadioMenuName)
    veafRadio.addCommandToSubmenu("HELP", veafAssets.rootPath, veafAssets.help, nil, veafRadio.USAGE_ForGroup)

    names = {}
    sortedAssets = {}
    for _, asset in pairs(veafAssets.assets) do
        table.insert(sortedAssets, {name=asset.name, sort=asset.sort})
    end
    function compare(a,b)
		if not(a) then 
			a = {}
		end
		if not(a["sort"]) then 
			a["sort"] = 0
		end
		if not(b) then 
			b = {}
		end
		if not(b["sort"]) then 
			b["sort"] = 0
		end	
        return a["sort"] < b["sort"]
    end     
    table.sort(sortedAssets, compare)
    for i = 1, #sortedAssets do
        table.insert(names, sortedAssets[i].name)
    end

    veafAssets.logTrace("veafAssets.buildRadioMenu() - dumping names")
    for i = 1, #names do
        veafAssets.logTrace("veafAssets.buildRadioMenu().names -> " .. names[i])
    end

    veafAssets._buildAssetsRadioMenuPage(veafAssets.rootPath, names, 9, 1)
    veafRadio.refreshRadioMenu()
end

function veafAssets.info(parameters)
    local name, unitName = unpack(parameters)
    veafAssets.logDebug("veafAssets.info "..name)
    local theAsset = nil
    for _, asset in pairs(veafAssets.assets) do
        if asset.name == name then
            theAsset = asset
        end
    end
    if theAsset then
        local group = Group.getByName(theAsset.name)
        veafAssets.logTrace(string.format("assets[%s] = '%s'",theAsset.name, theAsset.description))
        local text = theAsset.description .. " is not active nor alive"
        if group then
            veafAssets.logDebug("found asset group")
            local nAlive = 0
            for _, unit in pairs(group:getUnits()) do
                veafAssets.logTrace("unit life = "..unit:getLife())
                if unit:getLife() >= 1 then
                    nAlive = nAlive + 1
                end
            end
            if nAlive > 0 then
                if nAlive == 1 then
                    text = string.format("%s is active ; one unit is alive\n", theAsset.description)
                else
                    text = string.format("%s is active ; %d units are alive\n", theAsset.description, nAlive)
                end
                if theAsset.information then
                    text = text .. theAsset.information
                end
            end
        end 
        veaf.outTextForUnit(unitName, text, 30)
    end
end

function veafAssets.dispose(name)
    veafAssets.logDebug("veafAssets.dispose "..name)
    local theAsset = nil
    for _, asset in pairs(veafAssets.assets) do
        if asset.name == name then
            theAsset = asset
        end
    end
    if theAsset then
        veafAssets.logDebug("veafSpawn.destroy "..theAsset.name)
        local group = Group.getByName(theAsset.name)
        if group then
            for _, unit in pairs(group:getUnits()) do
                Unit.destroy(unit)
            end
        end
        local text = "I've disposed of " .. theAsset.description
        trigger.action.outText(text, 30)
    end
end

function veafAssets.respawn(name)
    veafAssets.logDebug("veafAssets.respawn "..name)
    local theAsset = nil
    for _, asset in pairs(veafAssets.assets) do
        if asset.name == name then
            theAsset = asset
        end
    end
    if theAsset then
        mist.respawnGroup(name, true)
        if theAsset.linked then
            veafAssets.logTrace(string.format("veafAssets[%s].linked=%s",name, veaf.p(theAsset.linked)))
            -- there are linked groups to respawn
            if type(theAsset.linked) == "string" then
                theAsset.linked = {theAsset.linked}
            end
            for _, linkedGroup in pairs(theAsset.linked) do
                veafAssets.logTrace(string.format("respawning linked group [%s]",linkedGroup))
                mist.respawnGroup(linkedGroup, true)
            end
        end
        local text = "I've respawned " .. theAsset.description
        if theAsset.jtac then
            if ctld then 
                ctld.JTACAutoLase(name, theAsset.jtac, false, "vehicle")
                text = text .. " lasing with code " .. theAsset.jtac
            end
        end
        trigger.action.outText(text, 30)
    end
end


function veafAssets.help(unitName)
    veafAssets.logTrace(string.format("help(%s)",unitName or ""))
    local text =
        'The radio menu lists all the assets, friendly or enemy\n' ..
        'Use these menus to respawn the assets when needed\n'
    veaf.outTextForUnit(unitName, text, 30)
end


-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafAssets.buildAssetsDatabase()
    veafAssets.assets = {}
    for _, asset in ipairs(veafAssets.Assets) do
        veafAssets.assets[asset.name] = asset
    end
end


function veafAssets.initialize()
    veafAssets.buildAssetsDatabase()
    veafAssets.buildRadioMenu()
    -- start any action-bound asset (e.g. jtacs)
    for name, asset in pairs(veafAssets.assets) do
        if asset.jtac then
            if ctld then 
                ctld.JTACAutoLase(name, asset.jtac, false, "vehicle")
            end
        end
    end
end

veafAssets.logInfo(string.format("Loading version %s", veafAssets.Version))

--- Enable/Disable error boxes displayed on screen.
env.setErrorMessageBoxEnabled(false)

