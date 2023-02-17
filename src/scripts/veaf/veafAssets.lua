------------------------------------------------------------------
-- VEAF assets (important groups in a mission) management functions for DCS World
-- By zip (2018)
--
-- Features:
-- ---------
-- * Manages the assets that exist the map (tankers, awacs, ...)
--
-- See the documentation : https://veaf.github.io/documentation/
------------------------------------------------------------------

veafAssets = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafAssets.Id = "ASSETS"

--- Version.
veafAssets.Version = "1.8.1"

-- trace level, specific to this module
--veafAssets.LogLevel = "trace"

veaf.loggers.new(veafAssets.Id, veafAssets.LogLevel)

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
-- Radio menu and help
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafAssets._buildAssetRadioMenu(menu, title, element)
    if element.disposable or element.information then -- in this case we need a submenu
        local radioMenu = veafRadio.addSubMenu(element.description, menu)
        veafRadio.addCommandToSubmenu("Respawn "..element.description, radioMenu, veafAssets.respawn, element.name, veafRadio.USAGE_ForAll)
        if element.information then
            veafRadio.addCommandToSubmenu("Get info on "..element.description, radioMenu, veafAssets.info, element.name, veafRadio.USAGE_ForGroup)
        end
        if element.disposable then
            veafRadio.addSecuredCommandToSubmenu("Dispose of "..element.description, radioMenu, veafAssets.dispose, element.name, veafRadio.USAGE_ForAll)
        end
    else
        veafRadio.addCommandToSubmenu("Respawn "..element.description, menu, veafAssets.respawn, element.name, veafRadio.USAGE_ForAll)
    end
end

--- Build the initial radio menu
function veafAssets.buildRadioMenu()
    -- don't create an empty menu
    if veaf.length(veafAssets.assets) == 0 then 
        return
    end

    veafAssets.rootPath = veafRadio.addSubMenu(veafAssets.RadioMenuName)
    if not(veafRadio.skipHelpMenus) then
        veafRadio.addCommandToSubmenu("HELP", veafAssets.rootPath, veafAssets.help, nil, veafRadio.USAGE_ForGroup)
    end
  
    veafRadio.addPaginatedRadioElements(veafAssets.rootPath, veafAssets._buildAssetRadioMenu, veafAssets.assets, "description", "sort")
    veafRadio.refreshRadioMenu()
end

function veafAssets.info(parameters)
    local name, unitName = veaf.safeUnpack(parameters)
    veaf.loggers.get(veafAssets.Id):debug("veafAssets.info "..name)
    local theAsset = nil
    for _, asset in pairs(veafAssets.assets) do
        if asset.name == name then
            theAsset = asset
        end
    end
    if theAsset then
        local group = Group.getByName(theAsset.name)
        veaf.loggers.get(veafAssets.Id):trace(string.format("assets[%s] = '%s'",theAsset.name, theAsset.description))
        local text = theAsset.description .. " is not active nor alive"
        if group then
            veaf.loggers.get(veafAssets.Id):debug("found asset group")
            local nAlive = 0
            for _, unit in pairs(group:getUnits()) do
                veaf.loggers.get(veafAssets.Id):trace("unit life = "..unit:getLife())
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
    veaf.loggers.get(veafAssets.Id):debug("veafAssets.dispose "..name)
    local theAsset = nil
    for _, asset in pairs(veafAssets.assets) do
        if asset.name == name then
            theAsset = asset
        end
    end
    if theAsset then
        veaf.loggers.get(veafAssets.Id):debug("veafSpawn.destroy "..theAsset.name)
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
    veaf.loggers.get(veafAssets.Id):debug("veafAssets.respawn "..name)
    local theAsset = nil
    for _, asset in pairs(veafAssets.assets) do
        if asset.name == name then
            theAsset = asset
        end
    end
    if theAsset then
        mist.respawnGroup(name, true)
        if theAsset.linked then
            veaf.loggers.get(veafAssets.Id):trace(string.format("veafAssets[%s].linked=%s",name, veaf.p(theAsset.linked)))
            -- there are linked groups to respawn
            if type(theAsset.linked) == "string" then
                theAsset.linked = {theAsset.linked}
            end
            for _, linkedGroup in pairs(theAsset.linked) do
                veaf.loggers.get(veafAssets.Id):trace(string.format("respawning linked group [%s]",linkedGroup))
                mist.respawnGroup(linkedGroup, true)
            end
        end
        local text = "I've respawned " .. theAsset.description
        if theAsset.jtac then
            if ctld then 
                veafSpawn.JTACAutoLase(name, theAsset.jtac, theAsset)
                text = text .. " lasing with code " .. theAsset.jtac
            end
        end
        trigger.action.outText(text, 30)
    end
end


function veafAssets.help(unitName)
    veaf.loggers.get(veafAssets.Id):trace(string.format("help(%s)",unitName or ""))
    local text =
        'The radio menu lists all the assets, friendly or enemy\n' ..
        'Use these menus to respawn the assets when needed\n'
    veaf.outTextForUnit(unitName, text, 30)
end

function veafAssets.get(assetName)
    return veafAssets.assets[assetName]
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
                veafSpawn.JTACAutoLase(name, asset.jtac, asset)
            end
        end
    end
end

veaf.loggers.get(veafAssets.Id):info(string.format("Loading version %s", veafAssets.Version))

--- Enable/Disable error boxes displayed on screen.
env.setErrorMessageBoxEnabled(false)

