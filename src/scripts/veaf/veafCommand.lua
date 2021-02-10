-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- VEAF specific commands and functions for DCS World
-- By zip (2018)
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- veafCommand Table.
veafCommand = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafCommand.Id = "COMMAND - "

--- Version.
veafCommand.Version = "1.0.0"

-- trace level, specific to this module
veafCommand.Debug = true
veafCommand.Trace = true

--- Key phrase to look for in the mark text which triggers the do command.
veafCommand.DoKeyphrase = "_do"

--- Illumination flare default initial altitude (in meters AGL)
veafCommand.IlluminationFlareAglAltitude = 1000

veafCommand.ShellingInterval = 5 -- seconds between shells, randomized by 30%
veafCommand.IlluminationShellingInterval = 30 -- seconds between illumination shells, randomized by 30%

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Do not change anything below unless you know what you are doing!
-------------------------------------------------------------------------------------------------------------------------------------------------------------

veafCommand.rootPath = nil

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utility methods
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafCommand.logError(message)
    veaf.logError(veafCommand.Id .. message)
end

function veafCommand.logInfo(message)
    veaf.logInfo(veafCommand.Id .. message)
end    

function veafCommand.logDebug(message)
    if message and veafCommand.Debug then
        veaf.logDebug(veafCommand.Id .. message)
    end
end    

function veafCommand.logTrace(message)
    if message and veafCommand.Trace then
        veaf.logTrace(veafCommand.Id .. message)
    end
end    

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Event handler functions.
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Function executed when a mark has changed. This happens when text is entered or changed.
function veafCommand.onEventMarkChange(eventPos, event)
    if veafCommand.executeCommand(eventPos, event.text, event.coalition) then 
        
        -- Delete old mark.
        veafCommand.logTrace(string.format("Removing mark # %d.", event.idx))
        trigger.action.removeMark(event.idx)

    end
end

function veafCommand.executeCommand(eventPos, eventText, eventCoalition, bypassSecurity)
    veafCommand.logDebug(string.format("veafCommand.executeCommand(eventText=[%s])", eventText))
    -- choose by default the coalition opposing the player who triggered the event
    local coalition = 1
    if eventCoalition == 1 then
        coalition = 2
    end

    -- Check if marker has a text and the veafCommand.DoKeyphrase keyphrase.
    if eventText ~= nil and eventText:lower():find(veafCommand.DoKeyphrase) then
        
        -- Analyse the mark point text and extract the keywords.
        local options = veafCommand.markTextAnalysis(eventText)

        if options then
            for i=1,options.multiplier do
                if not options.side then
                    if options.country then
                        -- deduct the side from the country
                        options.side = veaf.getCoalitionForCountry(options.country, true)
                    else
                        options.side = coalition
                    end
                end

                if not options.country then
                    -- deduct the country from the side
                    options.country = veaf.getCountryForCoalition(options.side)    
                end

                veafCommand.logTrace(string.format("options.side=%s",tostring(options.side)))
                veafCommand.logTrace(string.format("options.country=%s",tostring(options.country)))

                local routeDone = false

                -- Check options commands
                if options.destroy then
                    -- check security
                    if not (bypassSecurity or veafSecurity.checkSecurity_L1(options.password)) then return end
                    veafCommand.destroy(eventPos, options.radius, options.unitName)
                elseif options.teleport then
                    -- check security
                    if not (bypassSecurity or veafSecurity.checkSecurity_L1(options.password)) then return end
                    veafCommand.teleport(eventPos, options.radius, options.name, bypassSecurity)
                elseif options.bomb then
                    -- check security
                    if not (bypassSecurity or veafSecurity.checkSecurity_L1(options.password)) then return end
                    veafCommand.bomb(eventPos, options.radius, options.shells, options.bombPower, options.password)
                elseif options.smoke then
                    veafCommand.smoke(eventPos, options.smokeColor, options.radius, options.shells)
                elseif options.flare then
                    veafCommand.lightFlare(eventPos, options.radius, options.shells, options.alt)
                elseif options.signal then
                    veafCommand.signalFlare(eventPos, options.radius, options.shells, options.smokeColor)
                end
            end
            return true
        end
    end
    return false
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Analyse the mark text and extract keywords.
-------------------------------------------------------------------------------------------------------------------------------------------------------------
--- Extract keywords from mark text.
function veafCommand.markTextAnalysis(text)
    veafCommand.logTrace(string.format("veafCommand.markTextAnalysis(text=%s)", text))


    -- Option parameters extracted from the mark text.
    local switch = {}
    switch.smoke = false
    switch.flare = false
    switch.signal = false
    switch.bomb = false
    switch.destroy = false
    switch.teleport = false
    switch.shells = 1
    switch.multiplier = 1
    switch.altitude = 0
    switch.bombPower = 100
    switch.smokeColor = trigger.smokeColor.Red
    switch.radius = 150
    switch.alt = veafCommand.IlluminationFlareAglAltitude
    switch.password = nil

    -- Check for correct keywords.
    if text:lower():find(veafCommand.DoKeyphrase .. " smoke") then
        switch.smoke = true
    elseif text:lower():find(veafCommand.DoKeyphrase .. " flare") then
        switch.flare = true
    elseif text:lower():find(veafCommand.DoKeyphrase .. " signal") then
        switch.signal = true
    elseif text:lower():find(veafCommand.DoKeyphrase .. " bomb") then
        switch.bomb = true
    elseif text:lower():find(veafCommand.DoKeyphrase .. " destroy") then
        switch.destroy = true
    elseif text:lower():find(veafCommand.DoKeyphrase .. " teleport") then
        switch.teleport = true
    else
        return nil
    end

    -- keywords are split by ","
    local keywords = veaf.split(text, ",")

    for _, keyphrase in pairs(keywords) do
        -- Split keyphrase by space. First one is the key and second, ... the parameter(s) until the next comma.
        local str = veaf.breakString(veaf.trim(keyphrase), " ")
        local key = str[1]
        local val = str[2] or ""

        if key:lower() == "radius" then
            -- Set name.
            veafCommand.logTrace(string.format("Keyword radius = %s", tostring(val)))
            local nVal = veaf.getRandomizableNumeric(val)
            switch.radius = nVal
        end

        if key:lower() == "multiplier" then
            -- Set multiplier.
            veafCommand.logTrace(string.format("Keyword multiplier = %s", tostring(val)))
            local nVal = veaf.getRandomizableNumeric(val)
            switch.multiplier = nVal
        end

        if key:lower() == "alt" then
            -- Set altitude.
            veafCommand.logTrace(string.format("Keyword alt = %s", tostring(val)))
            local nVal = veaf.getRandomizableNumeric(val)
            switch.altitude = nVal
        end
        
        if key:lower() == "shells" then
            -- Set altitude.
            veafCommand.logTrace(string.format("Keyword shells = %s", tostring(val)))
            local nVal = veaf.getRandomizableNumeric(val)
            switch.shells = nVal
        end

        if key:lower() == "password" then
            -- Unlock the command
            veafCommand.logTrace(string.format("Keyword password", tostring(val)))
            switch.password = val
        end

        if key:lower() == "power" then
            -- Set bomb power.
            veafCommand.logTrace(string.format("Keyword power = %s", tostring(val)))
            local nVal = veaf.getRandomizableNumeric(val)
            switch.bombPower = nVal
        end
        
        if key:lower() == "color" then
            -- Set smoke color.
            veafCommand.logTrace(string.format("Keyword color = %s", tostring(val)))
            if (val:lower() == "red") then 
                switch.smokeColor = trigger.smokeColor.Red
            elseif (val:lower() == "green") then 
                switch.smokeColor = trigger.smokeColor.Green
            elseif (val:lower() == "orange") then 
                switch.smokeColor = trigger.smokeColor.Orange
            elseif (val:lower() == "blue") then 
                switch.smokeColor = trigger.smokeColor.Blue
            elseif (val:lower() == "white") then 
                switch.smokeColor = trigger.smokeColor.White
            end
        end

        if switch.cargo and key:lower() == "smoke" then
            -- Mark with green smoke.
            veafCommand.logTrace("Keyword smoke is set")
            switch.cargoSmoke = true
        end
    
    end

    return switch
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Smoke and Flare commands
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- trigger an explosion at the marker area
function veafCommand.bomb(markerSpot, radius, shells, power, password)
    veafCommand.logDebug("bomb(power=" .. power ..")")

    local shellTime = 0
    for shell=1,shells do
        local markerSpot = veaf.placePointOnLand(mist.getRandPointInCircle(markerSpot, radius))
        veafCommand.logTrace(string.format("markerSpot=%s", veaf.vecToString(markerSpot)))
        
        local shellDelay = veafCommand.ShellingInterval * (math.random(100) + 30)/100
        local shellPower = power * (math.random(100) + 30)/100
        -- check security
        if not veafSecurity.checkPassword_L0(password) then
            if shellPower > 1000 then shellPower = 1000 end
        end
        shellTime = shellTime + shellDelay
        veafCommand.logTrace(string.format("shell #%d : shellTime=%d, shellDelay=%d, power=%d", shell, shellTime, shellDelay, shellPower))
        mist.scheduleFunction(trigger.action.explosion, {markerSpot, power}, timer.getTime() + shellTime)
    end
end

--- add a smoke marker over the marker area
function veafCommand.smoke(markerSpot, color, radius, shells)
    veafCommand.logDebug("smoke(color = " .. color ..")")
    local radius = radius or 50
    local shells = shells or 1
    
    local shellTime = 0
    for shell=1,shells do
        local markerSpot = veaf.placePointOnLand(mist.getRandPointInCircle(markerSpot, radius))
        veafCommand.logTrace(string.format("markerSpot=%s", veaf.vecToString(markerSpot)))
        
        local shellDelay = veafCommand.ShellingInterval * (math.random(100) + 30)/100
        shellTime = shellTime + shellDelay
        veafCommand.logTrace(string.format("shell #%d : shellTime=%d, shellDelay=%d", shell, shellTime, shellDelay))
        if shells > 1 then
            -- add a small explosion under the smoke to simulate smoke shells
            mist.scheduleFunction(trigger.action.explosion, {markerSpot, 1}, timer.getTime() + shellTime-1)
        end
        mist.scheduleFunction(trigger.action.smoke, {markerSpot, color}, timer.getTime() + shellTime)
    end
end

--- add a signal flare over the marker area
function veafCommand.signalFlare(markerSpot, radius, shells, color)
    veafCommand.logDebug("signalFlare(color = " .. color ..")")
    
    local shellTime = 0
    for shell=1,shells do
        local markerSpot = veaf.placePointOnLand(mist.getRandPointInCircle(markerSpot, radius))
        veafCommand.logTrace(string.format("markerSpot=%s", veaf.vecToString(markerSpot)))
        
        local shellDelay = veafCommand.ShellingInterval * (math.random(100) + 30)/100
        shellTime = shellTime + shellDelay
        local azimuth = math.random(359)
        veafCommand.logTrace(string.format("shell #%d : shellTime=%d, shellDelay=%d", shell, shellTime, shellDelay))
        mist.scheduleFunction(trigger.action.signalFlare, {markerSpot, color, azimuth}, timer.getTime() + shellTime)
    end
end

--- add an illumination flare over the target area
function veafCommand.lightFlare(markerSpot, radius, shells, height)
    if height == nil then height = veafCommand.IlluminationFlareAglAltitude end
    veafCommand.logDebug("lightFlare(height = " .. height ..")")
    
    local shellTime = 0
    for shell=1,shells do
        local markerSpot = veaf.placePointOnLand(mist.getRandPointInCircle(markerSpot, radius))
        veafCommand.logTrace(string.format("markerSpot=%s", veaf.vecToString(markerSpot)))
        
        local shellDelay = veafCommand.IlluminationShellingInterval * (math.random(100) + 30)/100
        shellTime = shellTime + shellDelay
        shellHeight = height * (math.random(100) + 30)/100
        markerSpot.y = veaf.getLandHeight(markerSpot) + height
        veafCommand.logTrace(string.format("shell #%d : shellTime=%d, shellHeight=%d, power=%d", shell, shellTime, shellDelay, shellHeight))
        mist.scheduleFunction(trigger.action.illuminationBomb, {markerSpot}, timer.getTime() + shellTime)
    end
end

--- destroy unit(s)
function veafCommand.destroy(markerSpot, radius, unitName)
    veafCommand.logDebug(string.format("destroy(radius=%s, unitName=%s)", tostring(radius), tostring(unitName)))
    veafCommand.logTrace(string.format("markerSpot=%s", veaf.p(markerSpot)))
    if unitName then
        -- destroy a specific unit
        local c = Unit.getByName(unitName)
        if c then
            veafCommand.logTrace("destroy a specific unit")
            Unit.destroy(c)
        end

        -- or a specific static
        c = StaticObject.getByName(unitName)
        if c then
            veafCommand.logTrace("destroy a specific static")
            StaticObject.destroy(c)
        end

        -- or a specific group
        c = Group.getByName(unitName)
        if c then
            veafCommand.logTrace("destroy a specific group")
            Group.destroy(c)
        end
    else
        -- radius based destruction
        veafCommand.logTrace("radius based destruction")
        local units = veaf.findUnitsInCircle(markerSpot, radius or 150, true)
        veafCommand.logTrace(string.format("units=%s", veaf.p(units)))
        if units then
            for name, _ in pairs(units) do
                -- try and find a  unit
                local unit = Unit.getByName(name)
                if unit then 
                    Unit.destroy(unit)
                else
                    unit = StaticObject.getByName(name)
                    if unit then 
                        StaticObject.destroy(unit)
                    end
                end
            end
        end
    end
end

--- teleport group
function veafCommand.teleport(markerSpot, name, silent)
    veafCommand.logDebug("teleport(name = " .. name ..")")
    local vars = { groupName = name, point = markerSpot, action = "teleport" }
    local grp = mist.teleportToPoint(vars)
    if not silent then 
        if grp then
            trigger.action.outText("Teleported group "..name, 5) 
        else
            trigger.action.outText("Cannot teleport group : "..name, 5) 
        end
    end
end
    
-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- initialisation
-------------------------------------------------------------------------------------------------------------------------------------------------------------

function veafCommand.initialize()
    veafMarkers.registerEventHandler(veafMarkers.MarkerChange, veafCommand.onEventMarkChange)
end

veafCommand.logInfo(string.format("Loading version %s", veafCommand.Version))

