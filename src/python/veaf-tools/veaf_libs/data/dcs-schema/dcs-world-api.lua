--[[ DCS World Lua Type Definitions
Generated from schema: dcs-world-api-schema.json
DO NOT MODIFY - AUTO-GENERATED FILE
--]]

---@meta

-- Global Namespaces and Classes
--- Provides functions for measuring mission time and scheduling deferred function execution in the DCS World environment.
---@class timer
timer = timer or {}
--- Returns the elapsed mission time in seconds since mission start, which pauses when the game is paused.
--- Since DCS 1.2.0.
---@return number
--- ### Examples
--- ```lua
--- if timer.getTime() > 20 then
---  doWhatever()
--- end
--- 
--- ```
function timer.getTime() end

--- Returns `true` if the simulation is currently paused, otherwise returns `false`.
--- Since DCS 2.5.0.
---@return boolean
function timer.getPause() end

--- Returns the game world time in seconds, based on the mission start time and continuously increasing regardless of pause state.
--- Since DCS 1.2.0.
---@return number
--- ### Examples
--- ```lua
--- if timer.getAbsTime() + 20 > env.mission.start_time then
---  doWhatever()
--- end
--- 
--- ```
function timer.getAbsTime() end

--- Returns the mission start time in seconds, for calculating total elapsed mission time when combined with `getAbsTime()`.
--- Since DCS 1.2.0.
---@return number
--- ### Examples
--- ```lua
--- if timer.getAbsTime() - timer.getTime0() > 20 then
---  doWhatever()
--- end
--- 
--- ```
function timer.getTime0() end

--- Schedules a function to execute at a specific mission time, with optional repetition if the function returns a future time value.
--- Since DCS 1.2.0.
---@param functionToCall function Function to be executed at the scheduled time.
---@param anyFunctionArguement any Parameters to pass to the scheduled function.
---@param modelTime number Mission time in seconds when the function should execute.
---@return number
--- ### Examples
--- --- The following will run a function named "main" 120 seconds from one the code would run.
--- ```lua
--- timer.scheduleFunction(main, {}, timer.getTime() + 120)
--- 
--- ```
--- --- The following example sets up a repetitive call loop where function CheckStatus is called every 5 seconds or.
--- ```lua
--- function CheckStatus(ourArgument, time)
---  -- Do things to check, use ourArgument (which is the scheduleFunction's second argument)
---  if ourArgument == 53 and someExternalCondition then
---    -- Keep going
---    return time + 5
---  else
---    -- That's it we're done looping
---    return nil
---  end
--- end
--- timer.scheduleFunction(CheckStatus, 53, timer.getTime() + 5)
--- 
--- ```
--- --- This function will check if any red coalition units are in a trigger zone named "anyReds" and will set the flag "zoneOccupied" to true. This function will schedule itself to run every 60 seconds.
--- ```lua
--- local function checkZone(zoneName)
---    timer.scheduleFunction(checkZone, zoneName, timer.getTime() + 60)
---    local zone = trigger.misc.getZone(zoneName)
---    local groups = coalition.getGroups(1)
---    local count = 0 
---    for i = 1, #groups do
---       local units = groups[i]:getUnits()
---       for j = 1, #units do
---           local unitPos = units[j]:getpoint()
---            if math.sqrt((zone.point.x - unitPos.x)^2 + (zone.point.z - unitPos.z)^2) < zone.radius then
---                count = count + 1
---            end
---       end
---    end
---    if count > 0 then
---        trigger.action.setUserFlag("zoneOccupied", true)
---    else 
---       trigger.action.setUserFlag("zoneOccupied", false)
---    end
---  end
---  checkZone("anyReds")
--- 
--- ```
function timer.scheduleFunction(functionToCall, anyFunctionArguement, modelTime) end

--- Cancels a previously scheduled function, preventing it from executing.
--- Since DCS 1.2.0.
---@param functionId number Identifier returned by `scheduleFunction()` for the function to cancel.
--- ### Examples
--- --- The following will run a function named "main" 120 seconds from one the code would run.
--- ```lua
--- local id = timer.scheduleFunction(main, {}, timer.getTime() + 120)
--- 
--- ```
--- --- If further down in the code it was decided to stop main() from running it may look like this.
--- ```lua
--- if abort == true then  
---   timer.removeFunction(id)
--- end
--- 
--- ```
function timer.removeFunction(functionId) end

--- Modifies the execution time of a previously scheduled function.
--- Since DCS 1.2.0.
---@param functionId number Identifier returned by `scheduleFunction()` for the function to reschedule.
---@param modelTime number New mission time in seconds when the function should execute.
--- ### Examples
--- --- The following will run a function named "main" 120 seconds from one the code would run.
--- ```lua
--- local id = timer.scheduleFunction(main, {}, timer.getTime() + 120)
--- 
--- ```
--- --- If further down in the code it was decided to run the main() function sooner it could look like this.
--- ```lua
--- if mustGoFaster == true then  
---   timer.setFunctionTime(id, timer.getTime() + 1)
--- end
--- 
--- ```
function timer.setFunctionTime(functionId, modelTime) end


--- Provides functions for multiplayer networking, including chat, player management, and server administration.
---@class net
---@field CHAT_ALL number #READONLY Constant for targeting chat messages to all players.
---@field CHAT_TEAM number #READONLY Constant for targeting chat messages to team members only.
---@field ERR_BAD_CALLSIGN number #READONLY Error code indicating an invalid player callsign.
---@field ERR_BANNED number #READONLY Error code indicating a banned player.
---@field ERR_CONNECT_FAILED number #READONLY Error code indicating a connection failure.
---@field ERR_DENIED_TRIAL_ONLY number #READONLY Error code indicating denial due to trial version limitations.
---@field ERR_INVALID_ADDRESS number #READONLY Error code indicating an invalid network address.
---@field ERR_INVALID_PASSWORD number #READONLY Error code indicating an incorrect password.
---@field ERR_KICKED number #READONLY Error code indicating a player was kicked.
---@field ERR_NOT_ALLOWED number #READONLY Error code indicating an operation is not permitted.
---@field ERR_PROTOCOL_ERROR number #READONLY Error code indicating a network protocol error.
---@field ERR_REFUSED number #READONLY Error code indicating a connection was refused.
---@field ERR_SERVER_FULL number #READONLY Error code indicating the server has reached capacity.
---@field ERR_TAINTED_CLIENT number #READONLY Error code indicating a client with modified files.
---@field ERR_THATS_OKAY number #READONLY Error code indicating a successful operation.
---@field ERR_TIMEOUT number #READONLY Error code indicating a network timeout.
---@field ERR_WRONG_VERSION number #READONLY Error code indicating incompatible DCS versions.
---@field GAME_MODE_CONQUEST number #READONLY Game mode constant for Conquest missions.
---@field GAME_MODE_LAST_MAN_STANDING number #READONLY Game mode constant for Last Man Standing missions.
---@field GAME_MODE_MISSION number #READONLY Game mode constant for standard missions.
---@field GAME_MODE_TEAM_DEATH_MATCH number #READONLY Game mode constant for Team Deathmatch missions.
---@field PS_CAR number #READONLY Statistic ID for counting player's ground vehicle kills.
---@field PS_CRASH number #READONLY Statistic ID for counting player's crashes.
---@field PS_EJECT number #READONLY Statistic ID for counting player's ejections.
---@field PS_EXTRA_ALLY_AAA number #READONLY Statistic ID for counting player's friendly AAA kills.
---@field PS_EXTRA_ALLY_FIGHTERS number #READONLY Statistic ID for counting player's friendly fighter kills.
---@field PS_EXTRA_ALLY_SAM number #READONLY Statistic ID for counting player's friendly SAM kills.
---@field PS_EXTRA_ALLY_TRANSPORTS number #READONLY Statistic ID for counting player's friendly transport kills.
---@field PS_EXTRA_ALLY_TROOPS number #READONLY Statistic ID for counting player's friendly ground troop kills.
---@field PS_EXTRA_ENEMY_AAA number #READONLY Statistic ID for counting player's enemy AAA kills.
---@field PS_EXTRA_ENEMY_FIGHTERS number #READONLY Statistic ID for counting player's enemy fighter kills.
---@field PS_EXTRA_ENEMY_SAM number #READONLY Statistic ID for counting player's enemy SAM kills.
---@field PS_EXTRA_ENEMY_TRANSPORTS number #READONLY Statistic ID for counting player's enemy transport kills.
---@field PS_EXTRA_ENEMY_TROOPS number #READONLY Statistic ID for counting player's enemy ground troop kills.
---@field PS_LAND number #READONLY Statistic ID for counting player's successful landings.
---@field PS_PING number #READONLY Statistic ID for player's network latency in milliseconds.
---@field PS_PLANE number #READONLY Statistic ID for counting player's aircraft kills.
---@field PS_SCORE number #READONLY Statistic ID for player's total mission score.
---@field PS_SHIP number #READONLY Statistic ID for counting player's naval vessel kills.
---@field RESUME_MANUAL number #READONLY Constant for manual mission resumption control.
---@field RESUME_ON_LOAD number #READONLY Constant for automatic mission resumption on load.
---@field RESUME_WITH_CLIENTS number #READONLY Constant for mission resumption when clients connect.
net = net or {}
--- Sends a chat message to players in the multiplayer session.
--- Since DCS 2.5.0.
---@param message string Text content of the message.
---@param all boolean When `true`, sends to all players; when `false`, sends to current coalition only.
function net.send_chat(message, all) end

--- Sends a targeted chat message to a specific player, optionally appearing from another player.
--- Since DCS 2.5.0.
---@param message string Text content of the message.
---@param playerId number Target player's unique identifier.
---@param fromId? number Source player's ID that the message will appear to come from.
function net.send_chat_to(message, playerId, fromId) end

--- Returns a numerically indexed table of player IDs currently connected to the server.
--- Since DCS 2.5.0.
---@return table
function net.get_player_list() end

--- Returns the current player's unique identifier (always 1 for server scripts).
--- Since DCS 2.5.0.
---@return number
function net.get_my_player_id() end

--- Returns the server's player ID, which is always 1.
--- Since DCS 2.5.0.
---@return number
function net.get_server_id() end

--- Returns information about a player, either as a complete table or a specific attribute value.
--- Since DCS 2.5.0.
---@param playerId number Target player's unique identifier.
---@param attribute? string Specific attribute name to return (e.g., `'name'`, `'ucid'`, `'ping'`).
---@return table
function net.get_player_info(playerId, attribute) end

--- Removes a player from the server with an optional displayed message.
--- Since DCS 2.5.0.
---@param playerId number Target player's unique identifier.
---@param message string Explanation message displayed to the kicked player.
---@return boolean
function net.kick(playerId, message) end

--- Returns a specific statistical value for a player (e.g., kills, deaths).
--- Since DCS 2.5.0.
---@param playerId number Target player's unique identifier.
---@param statID number Statistic identifier (one of the `net.PS_*` constants).
---@return number
function net.get_stat(playerId, statID) end

--- Returns a player's display name (equivalent to `net.get_player_info(playerID, 'name')`).
--- Since DCS 2.5.0.
---@param playerId number Target player's unique identifier.
---@return string
function net.get_name(playerId) end

--- Returns a player's coalition ID and slot ID as two separate values.
--- Since DCS 2.5.0.
---@param playerId number Target player's unique identifier.
---@return number
function net.get_slot(playerId) end

--- Moves a player to a specified coalition and aircraft/vehicle slot.
--- Since DCS 2.5.0.
---@param playerID number Target player's unique identifier.
---@param sideId number Coalition ID (0 for spectators, 1 for Red, 2 for Blue).
---@param slotId string Unit ID or `UnitID_Seat` for multicrew positions.
---@return boolean
function net.force_player_slot(playerID, sideId, slotId) end

--- Serializes a Lua value into a JSON string.
--- Since DCS 2.5.0.
---@param lua_value any Lua value to convert to JSON.
---@return string
function net.lua2json(lua_value) end

--- Parses a JSON string into equivalent Lua data.
--- Since DCS 2.5.0.
---@param json_string string JSON string to convert to Lua.
---@return any
function net.json2lua(json_string) end

--- Executes a Lua code string in a specific DCS World environment context.
--- Since DCS 2.5.0.
---@param state string Target environment (`'config'`, `'mission'`, or `'export'`).
---@param dostring string Lua code to execute.
---@return string
function net.dostring_in(state, dostring) end

--- Writes a message to the DCS server log file.
--- Since DCS 2.5.0.
---@param message string Text to write to the log.
function net.log(message) end

--- Likely retrieves the server host information (undocumented in DCS API).
---@param unknown? any Unknown parameter(s).
---@return any
function net.get_server_host(unknown) end

--- Likely checks if an IP address is a loopback address (undocumented in DCS API).
---@param unknown? any Unknown parameter(s).
---@return any
function net.is_loopback_address(unknown) end

--- Likely checks if an IP address is in a private range (undocumented in DCS API).
---@param unknown? any Unknown parameter(s).
---@return any
function net.is_private_address(unknown) end

--- Likely provides chat message reception functionality (undocumented in DCS API).
---@param unknown? any Unknown parameter(s).
---@return any
function net.recv_chat(unknown) end

--- Likely sets a player's name (undocumented in DCS API).
---@param unknown? any Unknown parameter(s).
---@return any
function net.set_name(unknown) end

--- Likely changes a player's slot (undocumented in DCS API).
---@param unknown? any Unknown parameter(s).
---@return any
function net.set_slot(unknown) end

--- Likely outputs debug trace information (undocumented in DCS API).
---@param unknown? any Unknown parameter(s).
---@return any
function net.trace(unknown) end


--- Provides functions for logging and accessing mission environment data in the DCS World scripting environment. All logging messages are written to the dcs.log file in the user's Saved Games folder.
---@class env
---@field mission table Table containing the complete mission data structure as defined in the mission file.
---@field warehouses table Table containing the complete warehouse inventory data structure for the current mission.
env = env or {}
--- Writes an informational message to the DCS log file, with an optional in-game notification popup.
---@param message string Text content to write to the log file.
---@param showMessageBox? boolean `true` to display an in-game popup with the message, `false` to log silently.
function env.info(message, showMessageBox) end

--- Writes a warning message to the DCS log file, with an optional in-game notification popup.
---@param message string Text content to write to the log file.
---@param showMessageBox? boolean `true` to display an in-game popup with the message, `false` to log silently.
function env.warning(message, showMessageBox) end

--- Writes an error message to the DCS log file, with an optional in-game notification popup.
---@param message string Text content to write to the log file.
---@param showMessageBox? boolean `true` to display an in-game popup with the message, `false` to log silently.
function env.error(message, showMessageBox) end

--- Configures whether Lua runtime errors generate in-game popup notifications.
---@param enabled boolean `true` to display error message boxes for Lua errors, `false` to suppress them.
function env.setErrorMessageBoxEnabled(enabled) end

--- Retrieves a value from the mission dictionary using the specified key.
---@param key string Dictionary key to look up in the mission environment.
---@return any
function env.getValueDictByKey(key) end

--- Shows the training interface. Note: Undocumented function in the DCS API.
function env.showTraining() end


--- Provides functions for mission triggers, flags, messaging, special effects, and F10 map interface in the DCS World environment.
--- Since DCS 1.2.0.
---@class trigger
---@field action trigger.action Contains functions that perform mission actions equivalent to Mission Editor trigger actions.
---@field misc trigger.misc Contains utility functions for trigger operations and flag management.
trigger = trigger or {}
--- Contains functions that perform mission actions equivalent to Mission Editor trigger actions.
---@class trigger.action
trigger.action = trigger.action or {}
--- Activates a group configured for late activation in the mission.
--- Since DCS 1.2.5.
---@param group Group The group object to activate.
function trigger.action.activateGroup(group) end

--- Adds a command to the 'F10 Other' radio menu for all coalitions, setting a flag when selected.
--- Since DCS 1.2.4.
---@param name string Text displayed in the menu.
---@param userFlagName string User flag name to set when selected.
---@param userFlagValue number Value to set the user flag to.
function trigger.action.addOtherCommand(name, userFlagName, userFlagValue) end

--- Adds a command to the 'F10 Other' radio menu for a specific coalition.
--- Since DCS 1.2.4.
---@param coalition coalition.side Target coalition for the command.
---@param name string Text displayed in the menu.
---@param userFlagName string User flag name to set when selected.
---@param userFlagValue string Value to set the user flag to.
function trigger.action.addOtherCommandForCoalition(coalition, name, userFlagName, userFlagValue) end

--- Adds a command to the 'F10 Other' radio menu for a specific group.
--- Since DCS 1.2.4.
---@param groupId number ID of the group for the command.
---@param name string Text displayed in the menu.
---@param userFlagName string User flag name to set when selected.
---@param userFlagValue number Value to set the user flag to.
function trigger.action.addOtherCommandForGroup(groupId, name, userFlagName, userFlagValue) end

--- Creates an arrow shape on the F10 map visible to a specific coalition.
--- Since DCS 2.5.5.
---@param coalition coalition.side Coalition that can see the arrow.
---@param id number Unique identifier for the markup.
---@param startPoint Vec3 Starting point (tail) of the arrow in the DCS World coordinate system.
---@param endPoint Vec3 Ending point (head) of the arrow in the DCS World coordinate system.
---@param color ColorRGBA Outline color of the arrow.
---@param fillColor ColorRGBA Fill color of the arrow.
---@param lineType MarkupLineType Line style for the arrow outline.
---@param readOnly? boolean When `true`, prevents clients from editing the shape.
---@param message? string Message displayed when the shape is added.
function trigger.action.arrowToAll(coalition, id, startPoint, endPoint, color, fillColor, lineType, readOnly, message) end

--- Creates a circle shape on the F10 map visible to a specific coalition.
--- Since DCS 2.5.5.
---@param coalition coalition.side Coalition that can see the circle.
---@param id number Unique identifier for the markup.
---@param center Vec3 Center point of the circle in the DCS World coordinate system.
---@param radius number Radius of the circle in meters.
---@param color ColorRGBA Outline color of the circle.
---@param fillColor ColorRGBA Fill color of the circle.
---@param lineType MarkupLineType Line style for the circle outline.
---@param readOnly? boolean When `true`, prevents clients from editing the shape.
---@param message? string Message displayed when the shape is added.
function trigger.action.circleToAll(coalition, id, center, radius, color, fillColor, lineType, readOnly, message) end

--- Attaches a smoke plume behind an aircraft, with color values offset by +1 from the `smokeColor` enum.
--- Since DCS 2.5.6.
---@param unitName string Name of the unit to attach smoke to.
---@param smokeColorId trigger.smokeColor Color of the smoke plume.
function trigger.action.ctfColorTag(unitName, smokeColorId) end

--- Deactivates and removes a group from the mission.
--- Since DCS 1.2.5.
---@param group Group Group object to deactivate.
function trigger.action.deactivateGroup(group) end

--- Creates a large persistent smoke effect at a specific location.
--- Since DCS 2.5.1.
---@param point Vec3 Position of the smoke effect in the DCS World coordinate system.
---@param smoke_preset BigSmokeType Type of smoke effect to create.
---@param density number Density of the smoke (0 to 1).
---@param name? string Unique identifier for the effect, used for stopping it.
function trigger.action.effectSmokeBig(point, smoke_preset, density, name) end

--- Stops a large smoke effect previously created with `effectSmokeBig`.
--- Since DCS 2.7.10.
---@param name string Identifier of the smoke effect to stop.
function trigger.action.effectSmokeStop(name) end

--- Creates an explosion effect at a specific location.
--- Since DCS 1.2.0.
---@param point Vec3 Position of the explosion in the DCS World coordinate system.
---@param power number Power of the explosion.
function trigger.action.explosion(point, power) end

--- Orders a ground group to resume movement along its route.
--- Since DCS 1.2.5.
---@param group Group Ground group to order to continue moving.
function trigger.action.groupContinueMoving(group) end

--- Orders a ground group to stop movement and hold position.
--- Since DCS 1.2.5.
---@param group Group Ground group to order to stop.
function trigger.action.groupStopMoving(group) end

--- Creates an illumination bomb effect at a specific location.
--- Since DCS 1.2.0.
---@param point Vec3 Position of the illumination bomb in the DCS World coordinate system.
---@param power number Power of the illumination (1 to 1000000).
function trigger.action.illuminationBomb(point, power) end

--- Creates a line shape on the F10 map visible to a specific coalition.
--- Since DCS 2.5.5.
---@param coalition coalition.side Coalition that can see the line.
---@param id number Unique identifier for the markup.
---@param startPoint Vec3 Starting point of the line in the DCS World coordinate system.
---@param endPoint Vec3 Ending point of the line in the DCS World coordinate system.
---@param color ColorRGBA Color of the line.
---@param lineType MarkupLineType Line style for the shape.
---@param readOnly? boolean When `true`, prevents clients from editing the shape.
---@param message? string Message displayed when the shape is added.
function trigger.action.lineToAll(coalition, id, startPoint, endPoint, color, lineType, readOnly, message) end

--- Adds a mark point with text to the F10 map for all coalitions.
--- Since DCS 1.5.1.
---@param id number Unique identifier for the mark point.
---@param text string Text displayed with the mark.
---@param point Vec3 Position of the mark in the DCS World coordinate system.
---@param readOnly? boolean When `true`, prevents clients from removing the mark.
---@param message? string Message displayed when the mark is added.
function trigger.action.markToAll(id, text, point, readOnly, message) end

--- Adds a mark point with text to the F10 map for a specific coalition.
--- Since DCS 2.1.0.
---@param id number Unique identifier for the mark point.
---@param text string Text displayed with the mark.
---@param point Vec3 Position of the mark in the DCS World coordinate system.
---@param coalitionId coalition.side Coalition that can see the mark.
---@param readOnly? boolean When `true`, prevents clients from removing the mark.
---@param message? string Message displayed when the mark is added.
function trigger.action.markToCoalition(id, text, point, coalitionId, readOnly, message) end

--- Adds a mark point to the F10 map for a specific group.
--- Since DCS 2.1.0.
---@param id number Unique ID for the mark point.
---@param text string Text to display with the mark.
---@param point Vec3 Position of the mark point.
---@param groupId number The ID of the group to show the mark to.
---@param readOnly? boolean If true, clients cannot remove the mark.
---@param message? string Message to display when the mark is added.
function trigger.action.markToGroup(id, text, point, groupId, readOnly, message) end

--- Plays a sound file to all players in the mission.
--- Since DCS 1.2.0.
---@param soundfile string Path to the sound file in the mission package.
function trigger.action.outSound(soundfile) end

--- Plays a sound file to all players of a specific coalition.
--- Since DCS 1.2.0.
---@param coalition coalition.side Coalition to play the sound for.
---@param soundfile string Path to the sound file in the mission package.
function trigger.action.outSoundForCoalition(coalition, soundfile) end

--- Plays a sound file to all players of a specific country.
--- Since DCS 1.2.0.
---@param country country.id Country to play the sound for.
---@param soundfile string Path to the sound file in the mission package.
function trigger.action.outSoundForCountry(country, soundfile) end

--- Plays a sound file to all players in a specific group.
--- Since DCS 1.2.0.
---@param groupId number ID of the group to play the sound for.
---@param soundfile string Path to the sound file in the mission package.
function trigger.action.outSoundForGroup(groupId, soundfile) end

--- Plays a sound file to the player in a specific unit.
--- Since DCS 2.7.12.
---@param unitId number ID of the unit to play the sound for.
---@param soundfile string Path to the sound file in the mission package.
function trigger.action.outSoundForUnit(unitId, soundfile) end

--- Displays a text message to all players in the mission.
--- Since DCS 1.2.0.
---@param text string Text content to display.
---@param displayTime number Duration in seconds to show the message.
---@param clearview? boolean When `true`, uses the legacy display format that overwrites existing messages.
function trigger.action.outText(text, displayTime, clearview) end

--- Displays a text message to all players of a specific coalition.
--- Since DCS 1.2.0.
---@param coalition coalition.side Coalition to show the message to.
---@param text string Text content to display.
---@param displayTime number Duration in seconds to show the message.
---@param clearview? boolean When `true`, uses the legacy display format that overwrites existing messages.
function trigger.action.outTextForCoalition(coalition, text, displayTime, clearview) end

--- Displays text to all players of a specific country.
--- Since DCS 1.2.0.
---@param country country.id The country to display the text for.
---@param text string The text to display.
---@param displayTime number Duration in seconds.
---@param clearview? boolean If true, uses the old message display format.
function trigger.action.outTextForCountry(country, text, displayTime, clearview) end

--- Displays text to all players in a specific group.
--- Since DCS 1.2.0.
---@param groupId number The ID of the group to display the text for.
---@param text string The text to display.
---@param displayTime number Duration in seconds.
---@param clearview? boolean If true, uses the old message display format.
function trigger.action.outTextForGroup(groupId, text, displayTime, clearview) end

--- Displays text to the player in the specified unit.
--- Since DCS 2.7.12.
---@param unitId number The ID of the unit to display the text for.
---@param text string The text to display.
---@param displayTime number Duration in seconds.
---@param clearview? boolean If true, uses the old message display format.
function trigger.action.outTextForUnit(unitId, text, displayTime, clearview) end

--- Pushes the task of the specified index to the front of the AI tasking queue for the group.
--- Since DCS 1.2.4.
---@param group Group The group object.
---@param taskIndex number The index of the task in the group's triggered actions list.
function trigger.action.pushAITask(group, taskIndex) end

--- Creates a quadrilateral shape on the F10 map for all coalitions.
--- Since DCS 2.5.5.
---@param coalition coalition.side Which coalition to show the shape to.
---@param id number Unique ID for the markup object.
---@param point1 Vec3 First vertex of the quadrilateral.
---@param point2 Vec3 Second vertex of the quadrilateral.
---@param point3 Vec3 Third vertex of the quadrilateral.
---@param point4 Vec3 Fourth vertex of the quadrilateral.
---@param color ColorRGBA Color of the shape outline.
---@param fillColor ColorRGBA Fill color of the shape.
---@param lineType MarkupLineType Style of the shape outline.
---@param readOnly? boolean If true, clients cannot edit or remove the shape.
---@param message? string Message to display when the shape is added.
function trigger.action.quadToAll(coalition, id, point1, point2, point3, point4, color, fillColor, lineType, readOnly, message) end

--- Transmits an audio file over a specified frequency from a point in the mission.
--- Since DCS 1.2.0.
---@param filename string Path to the sound file in the mission package.
---@param point Vec3 Origin point of the transmission in the DCS World coordinate system.
---@param modulation RadioModulation Radio modulation type (`AM` or `FM`).
---@param loop boolean When `true`, the transmission will repeat continuously.
---@param frequency number Frequency in Hz (e.g., 124000000 for 124 MHz).
---@param power number Transmission power in watts.
---@param name? string Unique identifier for the transmission, used for stopping it.
function trigger.action.radioTransmission(filename, point, modulation, loop, frequency, power, name) end

--- Creates a rectangle shape on the F10 map visible to a specific coalition.
--- Since DCS 2.5.5.
---@param coalition coalition.side Coalition that can see the rectangle.
---@param id number Unique identifier for the markup.
---@param startPoint Vec3 One corner of the rectangle in the DCS World coordinate system.
---@param endPoint Vec3 Opposite corner of the rectangle in the DCS World coordinate system.
---@param color ColorRGBA Outline color of the rectangle.
---@param fillColor ColorRGBA Fill color of the rectangle.
---@param lineType MarkupLineType Line style for the rectangle outline.
---@param readOnly? boolean When `true`, prevents clients from editing the shape.
---@param message? string Message displayed when the shape is added.
function trigger.action.rectToAll(coalition, id, startPoint, endPoint, color, fillColor, lineType, readOnly, message) end

--- Removes a mark panel or markup shape from the F10 map.
--- Since DCS 2.1.0.
---@param id number ID of the mark to remove.
function trigger.action.removeMark(id) end

--- Removes a command from the 'F10 Other' radio menu for all.
--- Since DCS 1.2.4.
---@param name string The name of the command to remove.
function trigger.action.removeOtherCommand(name) end

--- Removes a command from the 'F10 Other' radio menu for a specific coalition.
--- Since DCS 1.2.4.
---@param coalitionId coalition.side The coalition to remove the command from.
---@param name string The name of the command to remove.
function trigger.action.removeOtherCommandForCoalition(coalitionId, name) end

--- Removes a command from the 'F10 Other' radio menu for a specific group.
--- Since DCS 1.2.4.
---@param groupId number The ID of the group to remove the command from.
---@param name string The name of the command to remove.
function trigger.action.removeOtherCommandForGroup(groupId, name) end

--- Sets the AI task for the specified group, clearing any existing task queue.
--- Since DCS 1.2.4.
---@param group Group The group object.
---@param taskIndex number The index of the task in the group's triggered actions list.
function trigger.action.setAITask(group, taskIndex) end

--- Turns the specified group's AI off. Only works with ground and ship groups.
--- Since DCS 1.2.5.
---@param group Group The group object.
function trigger.action.setGroupAIOff(group) end

--- Turns the specified group's AI on. Only works with ground and ship groups.
--- Since DCS 1.2.5.
---@param group Group The group object.
function trigger.action.setGroupAIOn(group) end

--- Updates the color of the specified markup object.
--- Since DCS 2.5.5.
---@param id number ID of the markup object.
---@param color ColorRGBA New color for the markup.
function trigger.action.setMarkupColor(id, color) end

--- Updates the fill color of the specified markup object.
--- Since DCS 2.5.5.
---@param id number ID of the markup object.
---@param colorFill ColorRGBA New fill color for the markup.
function trigger.action.setMarkupColorFill(id, colorFill) end

--- Updates the font size of the specified text markup object.
--- Since DCS 2.5.5.
---@param id number ID of the text markup object.
---@param fontSize number New font size.
function trigger.action.setMarkupFontSize(id, fontSize) end

--- Updates the end position of a line or arrow markup object, or a defining point of other shapes.
--- Since DCS 2.5.5.
---@param id number ID of the markup object.
---@param point Vec3 New end position.
function trigger.action.setMarkupPositionEnd(id, point) end

--- Updates the start position of a line or arrow markup object, or the primary point of other shapes.
--- Since DCS 2.5.5.
---@param id number ID of the markup object.
---@param point Vec3 New start position.
function trigger.action.setMarkupPositionStart(id, point) end

--- Updates the radius of the specified circle markup object.
--- Since DCS 2.5.5.
---@param id number ID of the circle markup object.
---@param radius number New radius in meters.
function trigger.action.setMarkupRadius(id, radius) end

--- Updates the text of the specified text markup object.
--- Since DCS 2.5.5.
---@param id number ID of the text markup object.
---@param text string New text.
function trigger.action.setMarkupText(id, text) end

--- Updates the line style of the specified markup object.
--- Since DCS 2.5.5.
---@param id number ID of the markup object.
---@param lineType MarkupLineType New line style.
function trigger.action.setMarkupTypeLine(id, lineType) end

--- Sets the internal cargo mass for a specified unit (aircraft/helicopter).
--- Since DCS 2.5.6.
---@param unitName string Name of the unit.
---@param mass number Cargo mass in kilograms.
function trigger.action.setUnitInternalCargo(unitName, mass) end

--- Creates a signal flare at a given point.
--- Since DCS 1.2.0.
---@param point Vec3 Position of the flare.
---@param color trigger.flareColor Color of the flare.
---@param azimuth number Azimuth (direction) in which the flare is launched (degrees).
function trigger.action.signalFlare(point, color, azimuth) end

--- Creates a colored smoke marker at a given point.
--- Since DCS 1.2.0.
---@param point Vec3 Position of the smoke marker.
---@param color trigger.smokeColor Color of the smoke.
function trigger.action.smoke(point, color) end

--- Stops a radio transmission started with trigger.action.radioTransmission.
--- Since DCS 2.5.
---@param name string Name of the radio transmission to stop.
function trigger.action.stopRadioTransmission(name) end

--- Creates text on the F10 map for all coalitions.
--- Since DCS 2.5.5.
---@param coalition coalition.side Which coalition to show the text to.
---@param id number Unique ID for the markup object.
---@param point Vec3 Position of the text.
---@param color ColorRGBA Color of the text.
---@param fillColor ColorRGBA Background fill color for the text area.
---@param fontSize number Font size of the text.
---@param readOnly? boolean If true, clients cannot edit or remove the shape.
---@param text string The text to display.
function trigger.action.textToAll(coalition, id, point, color, fillColor, fontSize, readOnly, text) end

--- Creates the defined shape on the F10 map. Uses the same definitions as the specific functions to create different shapes with the only difference being the first parameter is used to define the shape. This function does have an additional type of shape of 'freeform' which allows you to create an 3+ vertices shape in any format you wish. Shape Ids: 1 Line, 2 Circle, 3 Rect, 4 Arrow, 5 Text, 6 Quad, 7 Freeform. Coalition Ids: -1 All, 0 Neutral, 1 Red, 2 Blue. LineTypes: 0 No Line, 1 Solid, 2 Dashed, 3 Dotted, 4 Dot Dash, 5 Long Dash, 6 Two Dash.
--- Since DCS 2.5.6.
---@param shapeId MarkupShapeId ID of the shape type (1-7).
---@param coalition coalition.side Coalition ID (-1, 0, 1, 2).
---@param id number Unique ID for the markup object.
---@param point1 Vec3 First point defining the shape.
---@param points? Vec3[] Variable number of additional points for shapes like 'freeform'.
---@param color ColorRGBA Outline color {r,g,b,a}.
---@param fillColor ColorRGBA Fill color {r,g,b,a}.
---@param lineType MarkupLineType Line style ID (0-6).
---@param readOnly? boolean If true, clients cannot edit or remove the shape.
---@param message? string Message to display when the shape is added.
function trigger.action.markupToAll(shapeId, coalition, id, point1, points, color, fillColor, lineType, readOnly, message) end

--- Stops a sound previously played with an outSound* function.
--- Since DCS 1.2.0.
---@param soundfile string Path to the sound file that was originally played.
function trigger.action.outSoundStop(soundfile) end

--- Sets the value of a mission user flag.
--- Since DCS 1.2.0.
---@param flagNameOrId number|string Name or numeric ID of the flag.
---@param value number Value to set the flag to.
function trigger.action.setUserFlag(flagNameOrId, value) end

--- Present in DCS 2.9.29. Signature probed (DCS 2.9.29.27468): no arguments; returned nothing; extra arguments not probed.
function trigger.action.userEvent() end

--- Contains utility functions for trigger operations and flag management.
---@class trigger.misc
trigger.misc = trigger.misc or {}
--- (Placeholder) Adds a new trigger dynamically during the mission.
--- Since DCS 1.2.0.
---@param name string Name of the new trigger.
---@param condition string Lua code string or function defining the trigger condition.
---@param action string Lua code string or function defining the trigger action.
function trigger.misc.addTrigger(name, condition, action) end

--- (Placeholder) Adds a new trigger zone dynamically.
--- Since DCS 1.2.0.
---@param zoneName string Name for the new zone.
---@param point Vec3 Center point of the zone.
---@param radius number Radius of the zone in meters.
---@param zoneType? number Type of zone (e.g., 0 for circular).
---@param hidden? boolean Whether the zone is hidden on the map.
function trigger.misc.addZone(zoneName, point, radius, zoneType, hidden) end

--- Returns the current value of a mission user flag.
--- Since DCS 1.2.0.
---@param flagNameOrId number|string Name or numeric ID of the flag.
---@return number
function trigger.misc.getUserFlag(flagNameOrId) end

--- Returns information about a trigger zone defined in the mission editor.
--- Since DCS 1.2.0.
---@param zoneName string Name of the trigger zone.
---@return TriggerZoneCircular
function trigger.misc.getZone(zoneName) end


--- Provides functions for creating and managing voice chat rooms in multiplayer missions.
---@class VoiceChat
---@field RadioHandlers VoiceChat.RadioHandlers Enumerator for radio functionality constants used in voice communications.
---@field RadioHandlersSingletons VoiceChat.RadioHandlersSingletons Enumerator for intercom functionality constants used in voice communications.
---@field Side VoiceChat.Side Enumerator for coalition sides (NEUTRAL, RED, BLUE, ALL) in voice chat rooms.
---@field RoomType VoiceChat.RoomType Enumerator for voice chat room types (PERSISTENT, MULTICREW, MANAGEABLE).
VoiceChat = VoiceChat or {}
--- Creates a voice chat room for players in a multiplayer mission.
--- Since DCS 2.5.6.
---@param roomName string
---@param side VoiceChat.Side
---@param roomType VoiceChat.RoomType
--- ### Examples
--- ```lua
--- VoiceChat.CreateRoom("SRSIsBetter", 2, 0)
--- ```
function VoiceChat.createRoom(roomName, side, roomType) end

--- Adds a user to a voice chat room.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.addUser(unknown) end

--- Changes a user's slot in a voice chat room.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.changeSlot(unknown) end

--- Modifies voice chat options for a room or user.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.changeVoiceChatOption(unknown) end

--- Removes a voice chat room from the mission.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.deleteRoom(unknown) end

--- Returns a list of peers with access to a voice chat room.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.getAccessPeersList(unknown) end

--- Returns the currently active voice chat room for a user.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.getActiveRoom(unknown) end

--- Returns the radio currently being used for transmission.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.getCurrentTransmittingRadio(unknown) end

--- Returns `true` if voice encryption is enabled, `false` otherwise.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.getEncryptionEnabled(unknown) end

--- Returns data about the intercom system.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.getIntercomData(unknown) end

--- Returns information about the intercom's status indicators.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.getIntercomIndication(unknown) end

--- Returns the current microphone mode for the intercom.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.getIntercomMicMode(unknown) end

--- Returns the current volume level for the intercom.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.getIntercomVolume(unknown) end

--- Returns `true` if voice chat is controlled by an external system, `false` otherwise.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.getIsExternallyControlled(unknown) end

--- Returns information about the most recently used transmitting radio.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.getLastTransmittingRadio(unknown) end

--- Returns the current microphone activation mode.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.getMicMode(unknown) end

--- Returns current voice chat system options.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.getOptions(unknown) end

--- Returns audio state information for a specified peer.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.getPeerAudioState(unknown) end

--- Returns a list of all peers in voice chat.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.getPeersList(unknown) end

--- Returns the currently selected radio channel.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.getRadioChannel(unknown) end

--- Returns the encryption key for a specified radio.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.getRadioEncryptionKey(unknown) end

--- Returns the frequency of a specified radio.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.getRadioFrequency(unknown) end

--- Returns radio frequencies for specified units.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.getRadioFrequencyByUnits(unknown) end

--- Returns the frequency of the guard receiver on a specified radio.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.getRadioGuardReceiverFrequency(unknown) end

--- Returns the modulation type of the guard receiver on a specified radio.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.getRadioGuardReceiverModulation(unknown) end

--- Returns the on/off state of the guard receiver on a specified radio.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.getRadioGuardReceiverOnOff(unknown) end

--- Returns status indicator information for a specified radio.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.getRadioIndication(unknown) end

--- Returns a list of available radios for the current unit.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.getRadioList(unknown) end

--- Returns the modulation type for a specified radio.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.getRadioModulation(unknown) end

--- Returns the on/off state of a specified radio.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.getRadioOnOff(unknown) end

--- Returns the power setting of a specified radio.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.getRadioPower(unknown) end

--- Returns the squelch on/off state for a specified radio.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.getRadioSquelchOnOff(unknown) end

--- Returns the volume level for a specified radio.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.getRadioVolume(unknown) end

--- Returns a list of all voice chat rooms in the mission.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.getRooms(unknown) end

--- Returns the coalition side of a voice chat room or user.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.getSide(unknown) end

--- Returns the current voice chat operating mode.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.getVoiceChatMode(unknown) end

--- Returns `true` if a player is in a unit with voice chat capabilities, `false` otherwise.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.isInUnit(unknown) end

--- Returns `true` if an intercom system is available, `false` otherwise.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.isIntercom(unknown) end

--- Returns `true` if a specified radio can transmit, `false` otherwise.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.isRadioAvailableForTransmission(unknown) end

--- Removes a user from a voice chat room.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.leaveRoom(unknown) end

--- Handles peer connection events in voice chat.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.onPeerConnect(unknown) end

--- Handles peer disconnection events in voice chat.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.onPeerDisconnect(unknown) end

--- Handles state processing events in voice chat.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.onProcessState(unknown) end

--- Handles RTC connection change events.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.onRtcConnectionChange(unknown) end

--- Handles RTC failure events.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.onRtcFailure(unknown) end

--- Handles RTC signaling change events.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.onRtcSignalingChange(unknown) end

--- Enables or disables voice for a specific peer.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.peerVoiceEnable(unknown) end

--- Toggles encryption for a specified radio.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.radioEncryptionOnOff(unknown) end

--- Attempts to reconnect to the voice chat system.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.reconnect(unknown) end

--- Removes a user from the voice chat system.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.removeUser(unknown) end

--- Sets the active voice chat room for a user.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.setActiveRoom(unknown) end

--- Enables or disables voice encryption.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.setEncryptionEnabled(unknown) end

--- Sets the microphone mode for the intercom system.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.setIntercomMicMode(unknown) end

--- Enables or disables external control of the voice chat system.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.setIsExternallyControlled(unknown) end

--- Sets the microphone activation mode.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.setMicMode(unknown) end

--- Configures voice chat system options.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.setOptions(unknown) end

--- Sets the active channel on a specified radio.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.setRadioChannel(unknown) end

--- Sets the encryption key for a specified radio.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.setRadioEncryptionKey(unknown) end

--- Sets the frequency for a specified radio.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.setRadioFrequency(unknown) end

--- Sets the guard receiver frequency for a specified radio.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.setRadioGuardReceiverFrequency(unknown) end

--- Sets the guard receiver modulation type for a specified radio.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.setRadioGuardReceiverModulation(unknown) end

--- Enables or disables the guard receiver for a specified radio.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.setRadioGuardReceiverOnOff(unknown) end

--- Sets the modulation type for a specified radio.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.setRadioModulation(unknown) end

--- Turns a specified radio on or off.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.setRadioOnOff(unknown) end

--- Sets the power level for a specified radio.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.setRadioPower(unknown) end

--- Enables or disables squelch for a specified radio.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.setRadioSquelchOnOff(unknown) end

--- Sets the volume level for a specified radio.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.setRadioVolume(unknown) end

--- Sets the volume level for audio tracks in voice chat.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.setTrackAudioVolume(unknown) end

--- Sets the operating mode for voice chat.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.setVoiceChatMode(unknown) end

--- Starts or stops a test of sound filter options.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.startStopTestSoundFilterOptions(unknown) end

--- Starts a voice stream for a specified user or room.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.startStream(unknown) end

--- Starts the audio level test meter.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.startTestPeekMeter(unknown) end

--- Stops a voice stream for a specified user or room.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.stopStream(unknown) end

--- Stops the audio level test meter.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.stopTestPeekMeter(unknown) end

--- Tests the peak meter functionality.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.testCallPeekMeterFunc(unknown) end

--- Updates the volume levels for crew communications.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.updateCrewVolume(unknown) end

--- Updates the parameters for sound filtering in voice chat.
---@param unknown? any Unknown parameter(s).
---@return any
function VoiceChat.updateSoundFilterParameters(unknown) end


--- Provides functions for querying atmospheric conditions in the DCS World environment, including wind, temperature, and pressure data.
---@class atmosphere
atmosphere = atmosphere or {}
--- Returns a `Vec3` representing the wind velocity vector at the specified position in the DCS World coordinate system.
--- Since DCS 1.2.6.
---@param vec3 Vec3
---@return Vec3
function atmosphere.getWind(vec3) end

--- Returns a `Vec3` representing the wind velocity vector with turbulence effects at the specified position in the DCS World coordinate system.
--- Since DCS 1.2.6.
---@param vec3 Vec3
---@return Vec3
function atmosphere.getWindWithTurbulence(vec3) end

--- Returns two `number` values representing the temperature (in Kelvins) and pressure (in Pascals) at the specified position in the DCS World coordinate system.
--- Since DCS 2.0.6.
---@param vec3 Vec3
---@return number
function atmosphere.getTemperatureAndPressure(vec3) end


--- Provides functions and constants for controlling artificial intelligence behavior in the DCS World environment.
---@class AI
---@field Option table Provides a hierarchical structure of options for configuring AI unit and group behavior, including engagement rules, formation patterns, and reaction settings.
---@field Task table Provides constants and table structures for creating and assigning mission tasks to AI-controlled units and groups.
---@field Skill AI.Skill Provides enumerator values for setting AI proficiency levels, affecting decision-making, accuracy, and tactical behavior.
AI = AI or {}

--- Provides functions for converting between different coordinate systems in the DCS World environment, including Latitude/Longitude, Local (XYZ), and Military Grid Reference System (MGRS).
---@class coord
coord = coord or {}
--- Converts geographical coordinates (Latitude/Longitude) to DCS World local coordinates, returning a Vec2 position vector.
--- Since DCS 1.2.0.
---@param lat LatLon|number Latitude value in decimal degrees, or a LatLon structure. If a LatLon is provided, the lon parameter is ignored.
---@param lon? number Longitude value in decimal degrees. Ignored if lat parameter is a LatLon structure.
---@return Vec2
function coord.LLtoLO(lat, lon) end

--- Converts DCS World local coordinates to geographical coordinates, returning a LatLon structure.
--- Since DCS 1.2.0.
---@param x number X coordinate in the DCS World coordinate system.
---@param y number Y coordinate (not Z) in the DCS World coordinate system.
---@return LatLon
function coord.LOtoLL(x, y) end

--- Converts geographical coordinates (Latitude/Longitude) to Military Grid Reference System (MGRS) coordinates.
--- Since DCS 1.2.0.
---@param lat LatLon|number Latitude value in decimal degrees, or a LatLon structure. If a LatLon is provided, the lon parameter is ignored.
---@param lon number Longitude value in decimal degrees. Ignored if lat parameter is a LatLon structure.
---@return MGRS
function coord.LLtoMGRS(lat, lon) end

--- Converts Military Grid Reference System (MGRS) coordinates to geographical coordinates, returning a LatLon structure.
--- Since DCS 1.2.0.
---@param mgrs MGRS MGRS coordinate object with UTMZone, MGRSDigraph, Easting, and Northing fields.
---@return LatLon
function coord.MGRStoLL(mgrs) end


--- Holds the radio modulation constants of the mission scripting environment.
---@class radio
---@field modulation radio.modulation Provides access to the radio modulation enumerator.
radio = radio or {}

--- Provides functions and constants for controlling core DCS World simulation behavior and accessing mission data. Note: Only available in server environment.
---@class dcs
---@field UNIT_NAME string #READONLY Constant string identifier for accessing a unit's name property.
---@field UNIT_TYPE string #READONLY Constant string identifier for accessing a unit's type property.
---@field UNIT_HEADING string #READONLY Constant string identifier for accessing a unit's heading/direction property (in radians).
---@field UNIT_CATEGORY string #READONLY Constant string identifier for accessing a unit's category property.
---@field UNIT_GROUPNAME string #READONLY Constant string identifier for accessing a unit's group name property.
---@field UNIT_GROUPID string #READONLY Constant string identifier for accessing a unit's group ID property.
---@field UNIT_CALLSIGN string #READONLY Constant string identifier for accessing a unit's callsign property.
---@field UNIT_HIDDEN string #READONLY Constant string identifier for accessing a unit's visibility status in the Mission Editor.
---@field UNIT_COALITION string #READONLY Constant string identifier for accessing a unit's coalition affiliation (e.g., 'blue', 'red', 'unknown').
---@field UNIT_COUNTRY_ID string #READONLY Constant string identifier for accessing a unit's country ID property.
---@field UNIT_TASK string #READONLY Constant string identifier for accessing a unit's group task property.
---@field UNIT_PLAYER_NAME string #READONLY Constant string identifier for accessing the player name controlling a unit, applicable only to player-controllable units.
---@field UNIT_ROLE string #READONLY Constant string identifier for accessing a unit's role property (e.g., 'artillery_commander', 'instructor').
---@field UNIT_INVISIBLE_MAP_ICON string #READONLY Constant string identifier for accessing a unit's map icon visibility status in the Mission Editor.
dcs = dcs or {}
--- Returns a table representing the current mission data structure as stored in the mission file.
--- Since DCS 2.5.0.
---@return table
function dcs.getCurrentMission() end

--- Pauses or resumes the simulation, affecting all connected clients in multiplayer.
--- Since DCS 2.5.0.
---@param action boolean `true` to pause the simulation, `false` to resume it.
function dcs.setPause(action) end

--- Returns a `boolean` indicating whether the simulation is currently paused.
--- Since DCS 2.5.0.
---@return boolean
function dcs.getPause() end

--- Terminates the current mission and returns to the mission selection screen.
--- Since DCS 2.5.0.
function dcs.stopMission() end

--- Closes the DCS World application completely, terminating all processes.
--- Since DCS 2.5.0.
function dcs.exitProcess() end

--- Returns `true` if the current simulation is in multiplayer mode, `false` if in single-player mode.
--- Since DCS 2.5.0.
---@return boolean
function dcs.isMultiplayer() end

--- Returns `true` if the current instance is running as a dedicated server or single player host, `false` otherwise.
--- Since DCS 2.5.0.
---@return boolean
function dcs.isServer() end

--- Returns a `number` representing the total simulation time in seconds since the DCS application was launched.
--- Since DCS 2.5.0.
---@return number
function dcs.getModelTime() end

--- Returns a `number` representing the elapsed time in seconds since the current mission started.
--- Since DCS 2.5.0.
---@return number
function dcs.getRealTime() end

--- Returns a table containing the mission options as stored in the options.lua file within the mission package.
--- Since DCS 2.5.0.
---@return table
function dcs.getMissionOptions() end

--- Returns a map-like table where keys are coalition IDs and values are tables containing information about coalitions with available player slots.
--- Since DCS 2.5.0.
---@return table
function dcs.getAvailableCoalitions() end

--- Returns a numerically indexed table of tables containing information about player slots available in the specified coalition.
--- Since DCS 2.5.0.
---@param coaId number|string Coalition identifier (numeric ID or string name).
---@return DCSAvailableSlotInfo[]
function dcs.getAvailableSlots(coaId) end

--- Returns a table containing information about all player-controllable slots available in the current mission.
---@return DCSAvailableSlotInfo
function dcs.getAvailableSlotsAll() end


--- Provides functions for manipulating positions, terrain queries, and random number generation within the DCS World. **Warning:** This class is not formally documented by ED and descriptions and params may be incorrect.
---@class Disposition
Disposition = Disposition or {}
--- Unknown use case, possibly related to route drift or movement.
--- Since DCS 0.0.0.
---@param pos1 Vec3 First position vector.
---@param pos2 Vec3 Second position vector.
---@param coalitionId coalition.side Coalition side enumeration value.
---@return table
function Disposition.DriftRoute(pos1, pos2, coalitionId) end

--- Returns zones around runway strips in an elliptical pattern.
--- Since DCS 0.0.0.
---@param numAreas number Unknown.
---@param numPositions number Unknown.
---@param perim table Unknown.
---@param degrees number Unknown.
---@param radiusRatio number Unknown.
---@return table
function Disposition.getElipsSideZones(numAreas, numPositions, perim, degrees, radiusRatio) end

--- Returns the terrain height at the specified position in the DCS World coordinate system? See: land.getHeight().
--- Since DCS 0.0.0.
---@param pos Vec3 Position vector in the DCS World coordinate system.
---@return number
function Disposition.getPointHeight(pos) end

--- Checks if water exists at the specified position within given parameters? See: land.getSurfaceType().
--- Since DCS 0.0.0.
---@param pos Vec3 3D Position.
---@param a number Unknown.
---@param b number Unknown.
---@return boolean
function Disposition.getPointWater(pos, a, b) end

--- Generates a random number within the specified range.
--- Since DCS 0.0.0.
---@param isFloat boolean If true, returns a floating-point number; otherwise, returns an integer.
---@param min number Minimum value of the random range.
---@param max number Maximum value of the random range.
---@return number
function Disposition.getRandom(isFloat, min, max) end

--- Unknown function, likely related to random selection within a specified range or container.
--- Since DCS 0.0.0.
---@return any
function Disposition.getRandomIn() end

--- Randomly shuffles the elements of the input table.
--- Since DCS 0.0.0.
---@param t table Table to be randomly shuffled.
---@return table
function Disposition.getRandomSort(t) end

--- Unknown function.
--- Since DCS 0.0.0.
---@param thresholdPos Vec3 Unknown.
---@param pos Vec3 Unknown.
---@param a number Unknown.
---@param b number Unknown.
---@return boolean
function Disposition.getRouteAwayWater(thresholdPos, pos, a, b) end

--- Returns the perimeter of a runway defined by runway data? See: airbase.getRunways().
--- Since DCS 0.0.0.
---@param runway table Runway data table obtained from airbase:getRunways().
---@return table
function Disposition.getRunwayPerimetr(runway) end

--- Finds clear positions within an area for placing units. Assumed behavior.
--- Since DCS 0.0.0.
---@param pos Vec3 Center position vector for the search area.
---@param radius number Radius of the search area.
---@param posRadius number Required clear radius around each position.
---@param numPositions number Number of positions to find.
---@return table
function Disposition.getSimpleZones(pos, radius, posRadius, numPositions) end

--- Returns zones along runway edges based on the provided perimeter.
--- Since DCS 0.0.0.
---@param numPositions number Number of positions to generate.
---@param perim table Perimeter table defining the runway edges.
---@return table
function Disposition.getThresholdFourZones(numPositions, perim) end

--- Unknown function, likely related to setting a marker at a specific point. May be related to world and trigger functions.
--- Since DCS 0.0.0.
---@return any
function Disposition.setMarkerPoint() end


--- Provides functions for creating and managing interactive menu commands in the F10 radio menu.
---@class missionCommands
missionCommands = missionCommands or {}
--- Adds an interactive command to the F10 radio menu for all players that executes a specified Lua function when selected.
--- Since DCS 1.2.4.
---@param name string Display text for the menu command.
---@param path? nil|table Path to parent menu as a sequence table of menu names. If `nil`, command is added to root menu.
---@param functionToRun function Function to execute when command is selected.
---@param anyArguement? any Optional value passed to `functionToRun` when executed.
---@return table
function missionCommands.addCommand(name, path, functionToRun, anyArguement) end

--- Creates a submenu in the F10 radio menu for all players, which can contain additional commands or nested submenus.
--- Since DCS 1.2.4.
---@param name string Display text for the submenu.
---@param path? table Path to parent menu as a sequence table of menu names. If `nil`, submenu is added to root menu.
---@return table
function missionCommands.addSubMenu(name, path) end

--- Removes a menu item or entire submenu from the F10 radio menu for all players.
--- Since DCS 1.2.4.
---@param path? nil|table Path to the menu item as a sequence table of menu names. If `nil`, removes all items.
function missionCommands.removeItem(path) end

--- Adds an interactive command to the F10 radio menu for players of a specific coalition.
--- Since DCS 1.2.4.
---@param coalition_side coalition.side Target coalition (`coalition.side.NEUTRAL`, `coalition.side.RED`, or `coalition.side.BLUE`).
---@param name string Display text for the menu command.
---@param path? nil|table Path to parent menu as a sequence table of menu names. If `nil`, command is added to root menu.
---@param functionToRun function Function to execute when command is selected.
---@param anyArguement? any Optional value passed to `functionToRun` when executed.
---@return table
function missionCommands.addCommandForCoalition(coalition_side, name, path, functionToRun, anyArguement) end

--- Creates a submenu in the F10 radio menu for players of a specific coalition.
--- Since DCS 1.2.4.
---@param coalitionSide number Target coalition as a `coalition.side` enum value.
---@param name string Display text for the submenu.
---@param path? table Path to parent menu as a sequence table of menu names. If `nil`, submenu is added to root menu.
---@return table
function missionCommands.addSubMenuForCoalition(coalitionSide, name, path) end

--- Removes a menu item or entire submenu from the F10 radio menu for a specific coalition.
--- Since DCS 1.2.4.
---@param coalitionSide number Target coalition as a `coalition.side` enum value.
---@param path? nil|table Path to the menu item as a sequence table of menu names. If `nil`, removes all items for the coalition.
function missionCommands.removeItemForCoalition(coalitionSide, path) end

--- Adds an interactive command to the F10 radio menu for players in a specific group.
--- Since DCS 1.2.4.
---@param groupId number ID of the target group.
---@param name string Display text for the menu command.
---@param path? nil|table Path to parent menu as a sequence table of menu names. If `nil`, command is added to root menu.
---@param functionToRun function Function to execute when command is selected.
---@param anyArguement? any Optional value passed to `functionToRun` when executed.
---@return table
function missionCommands.addCommandForGroup(groupId, name, path, functionToRun, anyArguement) end

--- Creates a submenu in the F10 radio menu for players in a specific group.
--- Since DCS 1.2.4.
---@param groupId number ID of the target group.
---@param name string Display text for the submenu.
---@param path? table Path to parent menu as a sequence table of menu names. If `nil`, submenu is added to root menu.
---@return table
function missionCommands.addSubMenuForGroup(groupId, name, path) end

--- Removes a menu item or entire submenu from the F10 radio menu for a specific group.
--- Since DCS 1.2.4.
---@param groupId number ID of the target group.
---@param path? nil|table Path to the menu item as a sequence table of menu names. If `nil`, removes all items for the group.
function missionCommands.removeItemForGroup(groupId, path) end

--- Executes a radio menu action programmatically without user interaction.
--- Since DCS 2.5.0.
---@param path table Path to the menu command as a sequence table of menu names.
function missionCommands.doAction(path) end


--- Represents a physical entity in the DCS World with position, orientation, and identity properties.
---@class Object
Object = Object or {}
--- Returns `true` if this object currently exists in the mission environment.
---@return boolean
function Object:isExist() end

--- Removes this object from the mission without generating events, causing it to immediately disappear.
---@return function
function Object:destroy() end

--- Returns two `Object.Category` values indicating this object's primary and secondary classification.
---@return Object.Category
function Object:getCategory() end

--- Returns the type name of this object as defined in the DCS database.
---@return string
function Object:getTypeName() end

--- Returns `true` if this object possesses the specified attribute as defined in the DCS database.
---@param attribute DcsId.Attribute|string Attribute name to check for (`DcsId.Attribute` lists DCS's).
---@return boolean
function Object:hasAttribute(attribute) end

--- Returns this object's name identifier, which may be either its mission editor name or runtime ID depending on context.
---@return string
function Object:getName() end

--- Returns a `Vec3` representing this object's position in the DCS World coordinate system.
---@return Vec3
function Object:getPoint() end

--- Returns a `Position3` containing both this object's location and orientation vectors in the DCS World coordinate system.
---@return Position3
function Object:getPosition() end

--- Returns a `Vec3` representing this object's velocity components in the DCS World coordinate system.
---@return Vec3
function Object:getVelocity() end

--- Returns `true` if this object is currently airborne rather than on the ground.
---@return boolean
function Object:inAir() end

--- Returns a table containing all attributes this object possesses as defined in the DCS database.
--- Since DCS 1.2.0.
---@return ObjectAttributes
function Object:getAttributes() end

--- Aborts the current cargo selection operation for this object.
--- Since DCS 2.5.0.
function Object:cancelChoosingCargo() end


--- Provides functions for querying terrain geometry in the mission environment.
---@class land
land = land or {}
--- Returns terrain height (distance from sea level) at the specified point.
--- Since DCS 1.2.0.
---@param point Vec2 Position coordinates to check.
---@return number
function land.getHeight(point) end

--- Returns both terrain height and seabed depth at the specified point as `{number, number}` where the first value is height above sea level and the second is seabed depth.
--- Since DCS 1.2.0.
---@param point Vec2 Position coordinates to check.
---@return table
function land.getSurfaceHeightWithSeabed(point) end

--- Returns the surface type enum at the specified point.
--- Since DCS 1.2.0.
---@param point Vec2 Position coordinates to check.
---@return land.SurfaceType
function land.getSurfaceType(point) end

--- Performs line-of-sight check between two points, returning whether terrain obstructs visibility.
--- 
--- Note: This only tests terrain collision - buildings and other objects are not considered.
--- When working with ground objects, offset the Y-value (height) to prevent false negatives from the origin point clipping into terrain.
--- Since DCS 1.2.0.
---@param origin Vec3 Starting point of the line-of-sight check.
---@param destination Vec3 Ending point of the line-of-sight check.
---@return boolean
function land.isVisible(origin, destination) end

--- Returns the intersection point where a ray originating from `origin` in the given direction intersects terrain, or `nil` if no intersection within specified distance.
--- Since DCS 1.2.0.
---@param origin Vec3 Starting point of the ray.
---@param direction Vec3 Normalized direction vector of the ray.
---@param distance number Maximum distance to check for intersection.
---@return Vec3|nil
function land.getIP(origin, direction, distance) end

--- Returns a table of `Vec3` points representing the terrain profile between two points.
--- Since DCS 1.2.0.
---@param origin Vec3 Starting point of the profile.
---@param destination Vec3 Ending point of the profile.
---@return Vec3Array
function land.profile(origin, destination) end

--- Returns X and Y coordinates of the nearest point on a road from the given position.
--- 
--- Note: This function accepts individual X/Y coordinates rather than `Vec2` or `Vec3` objects.
--- Since DCS 2.5.
---@param roadType "railroads"|"roads" Road type to search. Valid values: `'roads'`, `'railroads'`.
---@param xCoord number X-coordinate (map X) of reference point.
---@param yCoord number Y-coordinate (map Z) of reference point.
---@return Vec2
function land.getClosestPointOnRoads(roadType, xCoord, yCoord) end

--- Returns a route as a sequence of points along roads between start and destination.
--- 
--- The result is a numerically-indexed table of `Vec2` points from start to destination.
--- 
--- Note: When using railroad paths, the parameter value should be `'rails'` (not `'railroads'`).
--- Since DCS 2.5.
---@param roadType "rails"|"roads" Road type to use. Valid values: `'roads'`, `'rails'`.
---@param xCoord number X-coordinate (map X) of starting point.
---@param yCoord number Y-coordinate (map Z) of starting point.
---@param destX number X-coordinate (map X) of destination point.
---@param destY number Y-coordinate (map Z) of destination point.
---@return Vec2Array
function land.findPathOnRoads(roadType, xCoord, yCoord, destX, destY) end


--- Represents static environmental structures in the DCS World mission area, such as buildings, bridges, and terrain objects.
---@class SceneryObject : Object
SceneryObject = SceneryObject or {}
--- Returns the current health value of this scenery object, where 0 indicates destruction.
--- Since DCS 1.2.0.
---@return number
function SceneryObject:getLife() end

--- Returns a table containing detailed properties of this scenery object based on its type.
--- Since DCS 1.2.0.
---@return SceneryObjectDesc
function SceneryObject:getDesc() end

--- Returns a table containing detailed properties of a scenery object type without requiring an instance.
--- Since DCS 1.2.0.
---@param typeName string Type name of the scenery object to retrieve information about.
---@return SceneryObjectDesc
function SceneryObject.getDescByName(typeName) end


--- Represents a targeting designation beam (laser or infrared) used for marking targets in the DCS World environment.
---@class Spot
Spot = Spot or {}
--- Removes this spot from the mission, immediately terminating the targeting beam.
--- Since DCS 1.2.0.
function Spot:destroy() end

--- Returns two category enumerator values identifying this spot's primary and secondary classifications.
--- Since DCS 1.2.0.
---@return Object.Category
---@return Spot.Category
function Spot:getCategory() end

--- Returns a `Spot.Category` enumerator value indicating whether this spot is infrared or laser.
--- Since DCS 2.9.2.
---@return Spot.Category
function Spot:getCategoryEx() end

--- Returns a `Vec3` representing the target point of this beam in the DCS World coordinate system.
--- Since DCS 1.2.0.
---@return Vec3
function Spot:getPoint() end

--- Changes the target endpoint of this beam to a new position in the DCS World coordinate system.
--- Since DCS 1.2.6.
---@param point Vec3 New target position in the DCS World coordinate system.
function Spot:setPoint(point) end

--- Returns the 4-digit laser code number used for target designation with this beam.
--- Since DCS 1.2.6.
---@return number
function Spot:getCode() end

--- Sets a new 4-digit laser code (1111-1788) for this beam, determining which guided weapons can track it.
--- Since DCS 1.2.6.
---@param code number New laser code value between 1111 and 1788.
function Spot:setCode(code) end

--- Creates an infrared targeting beam from a source object to a specified point, visible only through night vision devices.
--- Since DCS 1.2.6.
---@param source Object Source object that will emit the infrared beam.
---@param localRef? Vec3|nil Optional local reference point on the source object. If `nil`, uses the object's center.
---@param point Vec3 Target point for the infrared beam in the DCS World coordinate system.
---@return Spot
function Spot.createInfraRed(source, localRef, point) end

--- Creates a laser targeting beam from a source object to a specified point in the DCS World coordinate system.
--- Since DCS 1.2.6.
---@param source Object Source object that will emit the laser beam.
---@param localRef? Vec3|nil Optional local reference point on the source object. If `nil`, uses the object's center.
---@param point Vec3 Target point for the laser beam in the DCS World coordinate system.
---@param laserCode? number Optional 4-digit laser code between 1111 and 1788. If omitted, creates an infrared beam.
---@return Spot
function Spot.createLaser(source, localRef, point, laserCode) end


--- Represents non-moving structures and objects placed in the DCS World mission environment.
---@class StaticObject : Object, CoalitionObject
StaticObject = StaticObject or {}
--- Returns the static object's type name as defined in the DCS database.
--- Since DCS 1.2.0.
---@return DcsId.StaticType|string
function StaticObject:getTypeName() end

--- Returns the current health value of this static object, where values below 1 indicate destruction.
--- Since DCS 1.2.0.
---@return number
function StaticObject:getLife() end

--- Returns a table containing detailed properties of this static object based on its type.
--- Since DCS 1.2.0.
---@return StaticObjectDesc
function StaticObject:getDesc() end

--- Returns a `number` representing the unique mission identifier of this static object.
--- Since DCS 1.2.0.
---@return number
function StaticObject:getID() end

--- Returns a `coalition.side` enumerator value indicating which faction this static object belongs to.
--- Since DCS 1.2.0.
---@return coalition.side
function StaticObject:getCoalition() end

--- Returns a `country.id` enumerator value identifying the nation this static object belongs to.
--- Since DCS 1.2.0.
---@return country.id
function StaticObject:getCountry() end

--- Returns a `string` name of the force group this static object belongs to, or `nil` if not assigned.
--- Since DCS 1.2.0.
---@return nil|string
function StaticObject:getForcesName() end

--- Returns the current animation parameter value for a specific argument on this static object's 3D model.
--- Since DCS 1.2.0.
---@param arg number Animation argument identifier to query.
---@return number
function StaticObject:getDrawArgumentValue(arg) end

--- Initiates the cargo selection process for this static object.
--- Since DCS 2.5.0.
function StaticObject:chooseCargo() end

--- Returns a `string` containing the human-readable name of the cargo attached to this static object.
--- Since DCS 2.5.0.
---@return string
function StaticObject:getCargoDisplayName() end

--- Returns a `number` representing the weight of the cargo attached to this static object.
--- Since DCS 2.5.0.
---@return number
function StaticObject:getCargoWeight() end

--- Returns a `StaticObject` with the specified name, or `nil` if no such object exists.
--- Since DCS 1.2.0.
---@param name string Unique identifier of the static object to retrieve.
---@return StaticObject|nil
function StaticObject.getByName(name) end

--- Returns a table containing detailed properties of a static object type without requiring an instance.
--- Since DCS 1.2.0.
---@param typeName DcsId.StaticType|string Type name of the static object to retrieve information about.
---@return StaticObjectDesc
function StaticObject.getDescByName(typeName) end


--- Provides functions for managing faction-based entities in the DCS World environment, including unit information retrieval, group spawning, and static object creation.
---@class coalition
---@field side coalition.side Provides access to the coalition side enumerator for faction identification.
---@field service coalition.service Provides access to the service type enumerator for communications services.
---@field NEUTRAL number #READONLY Neutral coalition, value 0. Same value as `coalition.side.NEUTRAL`.
---@field RED number #READONLY Red coalition, value 1. Same value as `coalition.side.RED`.
---@field BLUE number #READONLY Blue coalition, value 2. Same value as `coalition.side.BLUE`.
coalition = coalition or {}
--- Adds a new group to the mission for the specified coalition and country, returning a `function` that can be called to complete the spawn process.
--- Since DCS 1.2.0.
---@param coalition coalition.side Coalition side enumeration value.
---@param country country.id Country identifier within the coalition.
---@param groupData GroupSpawnData Table defining the group configuration to be spawned.
---@return function
function coalition.addGroup(coalition, country, groupData) end

--- Adds a dynamic (runtime-created) group to the mission for the specified coalition and country, returning a `function` that finalizes the spawn process.
--- Since DCS 2.8.0.
---@param coalition coalition.side Coalition side enumeration value.
---@param country country.id Country identifier within the coalition.
---@param groupData GroupSpawnData Table defining the dynamic group configuration to be spawned.
---@return function
function coalition.add_dyn_group(coalition, country, groupData) end

--- Removes a previously added dynamic group from the mission, returning `true` if successful.
--- Since DCS 2.8.0.
---@param groupName string Name of the dynamic group to remove from the mission.
---@return boolean
function coalition.remove_dyn_group(groupName) end

--- Adds a new static object to the mission for the specified country, returning a `StaticObject`. The coalition is automatically determined from the country identifier.
--- Since DCS 1.2.0.
---@param country country.id Country identifier that determines which coalition the static object will belong to.
---@param staticData StaticObjectSpawnData Table defining the static object configuration to be spawned.
---@return StaticObject
function coalition.addStaticObject(country, staticData) end

--- Returns a numerically indexed table of `Group` objects belonging to the specified coalition and country.
--- Since DCS 1.2.0.
---@param coalition coalition.side Coalition side enumeration value.
---@param country country.id Country identifier within the coalition.
---@return table
function coalition.getGroups(coalition, country) end

--- Returns a numerically indexed table of `StaticObject` objects belonging to the specified coalition and country.
--- Since DCS 1.2.0.
---@param coalition coalition.side Coalition side enumeration value.
---@param country country.id Country identifier within the coalition.
---@return table
function coalition.getStaticObjects(coalition, country) end

--- Returns a numerically indexed table of `Airbase` objects belonging to the specified coalition and country.
--- Since DCS 1.2.0.
---@param coalition coalition.side Coalition side enumeration value.
---@param country country.id Country identifier within the coalition.
---@return table
function coalition.getAirbases(coalition, country) end

--- Returns a numerically indexed table of `Unit` objects representing player-controlled units in the specified coalition.
--- Since DCS 1.2.0.
---@param coalition coalition.side Coalition side enumeration value.
---@return table
function coalition.getPlayers(coalition) end

--- Returns a numerically indexed table of `Unit` objects providing the specified service type within the coalition.
--- Since DCS 1.2.0.
---@param coalition coalition.side Coalition side enumeration value.
---@param service coalition.service Service type enumeration value (e.g., ATC, AWACS, TANKER, FAC).
---@return table
function coalition.getServiceProviders(coalition, service) end

--- Adds a reference point for the specified coalition, returning a `function` that finalizes the addition.
--- Since DCS 1.2.0.
---@param coalition coalition.side Coalition side enumeration value.
---@param refPoint RefPoint Table defining the reference point to be added.
---@return function
function coalition.addRefPoint(coalition, refPoint) end

--- Returns a table of reference points defined for the specified coalition.
--- Since DCS 1.2.0.
---@param coalition coalition.side Coalition side enumeration value.
---@return table
function coalition.getRefPoints(coalition) end

--- Returns a table representing the primary reference point for the specified coalition.
--- Since DCS 1.2.0.
---@param coalition coalition.side Coalition side enumeration value.
---@return table
function coalition.getMainRefPoint(coalition) end

--- Returns a `number` representing the coalition identifier that the specified country belongs to.
--- Since DCS 1.2.0.
---@param country country.id Country identifier to query.
---@return number
function coalition.getCountryCoalition(country) end

--- Returns `true` if cargo selection is possible for the specified unit within the coalition.
--- Since DCS 2.8.0.
---@param coalition coalition.side Coalition side enumeration value.
---@param unitId number Unique identifier of the unit to check.
---@return boolean
function coalition.checkChooseCargo(coalition, unitId) end

--- Returns `true` if a descent operation (e.g., paratrooper drop) is possible for the specified unit.
--- Since DCS 2.8.0.
---@param coalition coalition.side Coalition side enumeration value.
---@param unitId number Unique identifier of the unit to check.
---@return boolean
function coalition.checkDescent(coalition, unitId) end

--- Returns a table of all available descent operations (e.g., paratroopers, cargo) for the specified coalition.
--- Since DCS 2.8.0.
---@param coalition coalition.side Coalition side enumeration value.
---@return table
function coalition.getAllDescents(coalition) end

--- Returns a table of all descent operations (e.g., paratroopers, cargo) currently loaded on the specified unit.
--- Since DCS 2.8.0.
---@param unitId number Unique identifier of the unit to query.
---@return table
function coalition.getDescentsOnBoard(unitId) end


--- Represents an AI behavior controller that manages tasking, commands, and detection capabilities for units and groups in the DCS World environment.
---@class Controller
Controller = Controller or {}
--- Assigns a task to this controller's associated units or groups, replacing any current task in the queue.
---@param task ComboTask|ControlledTask|DcsTask.AnyEnrouteTask|DcsTask.AnyTask|DcsTask.WrappedAction|Mission Task table: a task, en-route task, wrapped command or option, or a ComboTask, ControlledTask or Mission; ids in DCS casing.
function Controller:setTask(task) end

--- Clears all tasks from this controller's task queue, causing controlled units to cease their current activity.
function Controller:resetTask() end

--- Adds a task to the front of this controller's task queue, making it the highest priority task to execute.
---@param task ComboTask|ControlledTask|DcsTask.AnyEnrouteTask|DcsTask.AnyTask|DcsTask.WrappedAction|Mission Task table: a task, en-route task, wrapped command or option, or a ComboTask, ControlledTask or Mission; ids in DCS casing.
function Controller:pushTask(task) end

--- Removes the highest priority task from this controller's task queue.
function Controller:popTask() end

--- Returns `true` if this controller currently has at least one task in its queue.
---@return boolean
function Controller:hasTask() end

--- Issues an immediate command to this controller that executes instantly and does not affect the current task queue.
---@param command DcsTask.AnyCommand Command table; id in DCS casing.
function Controller:setCommand(command) end

--- Configures a behavior option for this controller that affects how it performs all tasks and commands.
---@param optionId AIOptionId|DcsTask.OptionName Option number: AI.Option.Air.id, AI.Option.Ground.id or AI.Option.Naval.id, or the Mission Editor's DcsTask.OptionName.
---@param optionValue AIOptionValue|boolean|number|string Option value (the AI.Option.*.val and DcsTask.OptionValue.* enums list known values).
function Controller:setOption(optionId, optionValue) end

--- Enables or disables the AI behavior for this controller's ground or naval units. Note: Does not work with aircraft or helicopters.
---@param value boolean `true` to enable AI behavior, `false` to disable.
function Controller:setOnOff(value) end

--- Sets the altitude for this controller's aircraft group, with options to maintain across waypoints and specify altitude type.
---@param altitude number Target altitude in meters.
---@param keep? boolean `true` to maintain altitude across waypoints, `false` to return to route-defined altitudes.
---@param altType? AI.Task.AltitudeType Altitude reference type: "BARO" (barometric) or "RADIO" (radar).
function Controller:setAltitude(altitude, keep, altType) end

--- Sets the movement speed for this controller's group, with option to maintain across waypoints.
---@param speed number Target speed in meters per second.
---@param keep? boolean `true` to maintain speed across waypoints, `false` to return to route-defined speeds.
function Controller:setSpeed(speed, keep) end

--- Forces a unit-level controller to have awareness of a specific target without natural detection. Note: Does not work at group level.
---@param object Object Target object to become aware of.
---@param _type boolean `true` to know the target type, `false` otherwise.
---@param distance boolean `true` to know the target distance, `false` otherwise.
function Controller:knowTarget(object, _type, distance) end

--- Returns multiple values indicating whether and how the specified target is detected by this controller's unit or group.
---@param Target Object Target object to check detection status.
---@param detectionType1? Controller.Detection First detection method to check.
---@param detectionType2? Controller.Detection Second detection method to check.
---@param detectionType3? Controller.Detection Third detection method to check.
---@return boolean
---@return number
---@return Vec3
function Controller:isTargetDetected(Target, detectionType1, detectionType2, detectionType3) end

--- Returns a numerically indexed table of tables containing detection information about targets detected by this controller, optionally filtered by detection methods.
---@param detectionType1? Controller.Detection First detection method to filter by.
---@param detectionType2? Controller.Detection Second detection method to filter by.
---@param detectionType3? Controller.Detection Third detection method to filter by.
---@return ControllerDetectedTargetArray
function Controller:getDetectedTargets(detectionType1, detectionType2, detectionType3) end


--- Represents airport and carrier facilities in the DCS World environment.
---@class Airbase : Object, CoalitionObject
Airbase = Airbase or {}
--- Returns a `string` representing the localized callsign of this airbase.
---@return string
function Airbase:getCallsign() end

--- Returns a `Unit` object, a `StaticObject`, or `nil` if no object exists at the specified index.
---@param UnitIndex number
---@return StaticObject|Unit|nil
function Airbase:getUnit(UnitIndex) end

--- Returns a `number` representing the unique mission ID of this airbase.
---@return number
function Airbase:getID() end

--- Returns an `Object.Category` enumerator value indicating the general category of this object.
--- Since DCS 1.2.0.
---@return Object.Category
function Airbase:getCategory() end

--- Returns an `Airbase.Category` enumerator value indicating the specific type of this airbase.
---@return Airbase.Category
function Airbase:getCategoryEx() end

--- Returns a numerically indexed table where each element is a table detailing an airbase parking spot, optionally filtered by availability.
---@param available? boolean
---@return AirbaseParking[]
function Airbase:getParking(available) end

--- Returns a numerically indexed table where each element is a table detailing runway information, including dimensions, course, and name. At fields with several runways (DCS 2.9.29), element k carries its own position and course but the length, width and Name of runway ceil(k / 2).
---@return AirbaseRunway[]
function Airbase:getRunways() end

--- Returns a `Vec3` representing the position of the airbase's dispatcher tower in the DCS World coordinate system, or `nil` if not available.
---@return Vec3|nil
function Airbase:getDispatcherTowerPos() end

--- Returns a `boolean` indicating whether the ATC for this airbase is in silent mode.
---@return boolean
function Airbase:getRadioSilentMode() end

--- Sets the silent mode status for the airbase's ATC, determining if it responds to radio communications from aircraft.
---@param silent boolean
function Airbase:setRadioSilentMode(silent) end

--- Enables or disables the auto-capture mechanic for this airbase, affecting how control can change between coalitions.
---@param setting boolean
function Airbase:autoCapture(setting) end

--- Returns a `boolean` indicating whether the auto-capture feature is enabled for this airbase.
---@return boolean
function Airbase:autoCaptureIsOn() end

--- Changes this airbase's coalition to the specified side, affecting which faction controls it.
---@param coa coalition.side
function Airbase:setCoalition(coa) end

--- Returns a `Warehouse` object associated with this airbase, used to manage its inventory.
---@return Warehouse
function Airbase:getWarehouse() end

--- Returns a `string` representing the name of this airbase.
--- Since DCS 1.2.0.
---@return string
function Airbase:getName() end

--- Returns a `string` representing the type name of this airbase.
--- Since DCS 1.2.0.
---@return string
function Airbase:getTypeName() end

--- Returns a `Vec3` representing the position of this airbase in the DCS World coordinate system.
--- Since DCS 1.2.0.
---@return Vec3
function Airbase:getPoint() end

--- Returns a `Position3` representing the precise position and orientation of this airbase in the DCS World coordinate system.
--- Since DCS 1.2.0.
---@return Position3
function Airbase:getPosition() end

--- Returns a `Vec3` representing the velocity of this airbase in the DCS World coordinate system.
--- Since DCS 1.2.0.
---@return Vec3
function Airbase:getVelocity() end

--- Returns a table containing a detailed description of this airbase, including its ID, callsign, category, and operational data.
--- Since DCS 1.2.0.
---@return AirbaseDesc
function Airbase:getDesc() end

--- Returns a `coalition.side` enumerator value indicating which coalition controls this airbase.
--- Since DCS 1.2.0.
---@return coalition.side
function Airbase:getCoalition() end

--- Returns an `Airbase` object corresponding to the airbase with the specified name, or `nil` if no such airbase exists.
---@param name DcsId.AirbaseName|string Airfield name (`DcsId.AirbaseName`), or the unit name of a FARP or ship.
---@return Airbase|nil
function Airbase.getByName(name) end

--- Returns a communicator object for the specified airbase.
---@param airbase Airbase
---@return unknown
function Airbase.getCommunicator(airbase) end

--- Returns a country ID for the specified airbase.
---@param airbase Airbase
---@return number
function Airbase.getCountry(airbase) end

--- Returns a table containing detailed information about the airbase with the specified name.
---@param name string
---@return AirbaseDesc|nil
function Airbase.getDescByName(name) end

--- Returns a string representing the forces name for the airbase.
---@param airbase Airbase
---@return string
function Airbase.getForcesName(airbase) end

--- Returns the current life/health value of the specified airbase.
---@param airbase Airbase
---@return number
function Airbase.getLife(airbase) end

--- Returns the nearest airbase object to the specified point.
---@param point Vec3
---@return Airbase|nil
function Airbase.getNearest(point) end

--- Returns the world ID of the specified airbase.
---@param airbase Airbase
---@return number
function Airbase.getWorldID(airbase) end


--- Represents a collection of related units that operate together as a tactical entity in the DCS World environment.
---@class Group : CoalitionObject
Group = Group or {}
--- Returns `true` if this group currently exists in the mission environment.
--- Since DCS 1.2.0.
---@return boolean
function Group:isExist() end

--- Activates this group if it has delayed start or late activation settings, making it appear in the mission.
--- Since DCS 1.2.0.
---@return function
function Group:activate() end

--- Removes this group and all its units from the game world without triggering events, causing them to completely disappear.
--- Since DCS 1.2.0.
---@return function
function Group:destroy() end

--- Returns an enumerator value indicating both the generic object category and specific group type for this group.
--- Since DCS 1.2.0.
---@return Object.Category
---@return Group.Category
function Group:getCategory() end

--- Returns a `Group.Category` enumerator value indicating the specific type of this group (e.g., AIRPLANE, HELICOPTER, GROUND).
--- Since DCS 2.9.2.
---@return Group.Category
function Group:getCategoryEx() end

--- Returns a `coalition.side` enumerator value indicating which faction this group belongs to.
--- Since DCS 1.2.4.
---@return coalition.side
function Group:getCoalition() end

--- Returns a `string` representing the unique name identifier of this group.
--- Since DCS 1.2.0.
---@return string
function Group:getName() end

--- Returns a `number` representing the unique mission ID of this group.
--- Since DCS 1.2.0.
---@return number
function Group:getID() end

--- Returns a `Unit` object at the specified index within this group, or `nil` if no unit exists at that index.
--- Since DCS 1.2.0.
---@param UnitIndex number Numeric index of the unit to retrieve, starting from 1.
---@return Unit|nil
function Group:getUnit(UnitIndex) end

--- Returns a numerically indexed table of `Unit` objects belonging to this group, ordered by their position in the group.
--- Since DCS 1.2.0.
---@return Unit[]
function Group:getUnits() end

--- Returns a `number` representing the current count of units in this group, which decreases as units are destroyed.
--- Since DCS 1.2.0.
---@return number
function Group:getSize() end

--- Returns a `number` representing the original count of units in this group as defined at creation, which remains constant regardless of unit losses.
--- Since DCS 1.2.6.
---@return number
function Group:getInitialSize() end

--- Returns a `Controller` object that can be used to manage AI behavior for this group. Note: Ship and ground groups can only be controlled at group level.
--- Since DCS 1.2.0.
---@return Controller
function Group:getController() end

--- Sets the radar emission status for all applicable units in this group, allowing control of detection signatures without changing AI behavior.
--- Since DCS 2.7.0.
---@param setting boolean `true` to enable radar emissions, `false` to disable them.
function Group:enableEmission(setting) end

--- Returns `true` if any unit in this group is currently in the process of loading cargo.
--- Since DCS 2.5.5.
---@return boolean
function Group:embarking() end

--- Creates a map marker visible to this group at the specified position with optional text label.
--- Since DCS 2.5.0.
---@param point Vec3 Position in the DCS World coordinate system where the marker will appear.
---@param text? string Optional text to display with the marker.
function Group:markGroup(point, text) end

--- Returns a `Group` object with the specified name, or `nil` if no such group exists. Works with both active and inactive groups.
--- Since DCS 1.2.0.
---@param name string Unique identifier of the group to retrieve.
---@return Group|nil
function Group.getByName(name) end


--- Represents a unit entity in the DCS World, including airplanes, helicopters, vehicles, ships, and armed ground structures.
---@class Unit : Object, CoalitionObject
Unit = Unit or {}
--- Returns the unit's type name as defined in the DCS database.
--- Since DCS 1.2.0.
---@return DcsId.UnitType|string
function Unit:getTypeName() end

--- Returns `true` if the unit is activated in the mission, `false` otherwise.
--- Since DCS 1.2.0.
---@return boolean
function Unit:isActive() end

--- Present in DCS 2.9.29. Signature probed (DCS 2.9.29.27468): no arguments besides self; returns from one call; accepts an extra argument.
---@return boolean
function Unit:isAlive() end

--- Present in DCS 2.9.29. Signature probed (DCS 2.9.29.27468): no arguments besides self; returns from one call; accepts an extra argument.
---@return boolean
function Unit:isBroken() end

--- Present in DCS 2.9.29. Signature probed (DCS 2.9.29.27468): no arguments besides self; returns from one call; accepts an extra argument.
---@return boolean
function Unit:isDead() end

--- Present in DCS 2.9.29. Signature probed (DCS 2.9.29.27468): no arguments besides self; returns from one call; accepts an extra argument.
---@return boolean
function Unit:isEffective() end

--- Returns the `string` name of the player controlling this unit, or `nil` if AI-controlled.
--- Since DCS 1.2.4.
---@return nil|string
function Unit:getPlayerName() end

--- Returns the `number` representing the unique mission ID of the unit.
--- Since DCS 1.2.0.
---@return number
function Unit:getID() end

--- Returns the `number` representing the index of the unit within its group. This index persists even as other units in the group are destroyed.
--- Since DCS 1.2.0.
---@return number
function Unit:getNumber() end

--- Returns a `Unit.Category` enumerator representing the specific category of the unit.
--- Since DCS 2.9.2.
---@return Unit.Category
function Unit:getCategoryEx() end

--- Returns the `number` representing the runtime object ID of the unit. Every simulation object has a unique objectID.
--- Since DCS 1.2.4.
---@return number
function Unit:getObjectID() end

--- Returns the `Controller` object for this unit. Note: Ships and ground units are only controllable at a group level.
--- Since DCS 1.2.0.
---@return Controller
function Unit:getController() end

--- Returns the `Group` object that this unit belongs to.
--- Since DCS 1.2.0.
---@return Group
function Unit:getGroup() end

--- Returns a `string` representing the localized callsign of the unit.
--- Since DCS 1.2.6.
---@return string
function Unit:getCallsign() end

--- Returns a `number` representing the current hit points of the unit. Values below 1 indicate the unit is destroyed.
--- Since DCS 1.2.0.
---@return number
function Unit:getLife() end

--- Returns a `number` representing the maximum hit points of the unit. This value never changes during a mission.
--- Since DCS 1.2.0.
---@return number
function Unit:getLife0() end

--- Returns a `number` representing the remaining fuel percentage (0.0 to 1.0+). Values above 1.0 indicate external fuel tanks.
--- Since DCS 1.2.3.
---@return number
function Unit:getFuel() end

--- Returns a numerically indexed table of ammunition data for all weapons loaded on the unit.
--- Since DCS 1.2.4.
---@return UnitAmmoItem[]
function Unit:getAmmo() end

--- Returns a numerically indexed table containing all sensors available on the unit.
--- Since DCS 1.2.0.
---@return UnitSensor[]
function Unit:getSensors() end

--- Returns `true` if the unit has the specified sensor type and subcategory, `false` otherwise.
--- Since DCS 1.2.0.
---@param sensorType Unit.SensorType Type of sensor to check for.
---@param subCategory number Subcategory of the sensor type to check for.
---@return boolean
function Unit:hasSensors(sensorType, subCategory) end

--- Returns information about the unit's radar status: operational state and tracked object (if any).
--- Since DCS 1.2.0.
---@return boolean
---@return Object|nil
function Unit:getRadar() end

--- Returns a `number` representing the current value of a specified animation parameter on the unit's 3D model.
--- Since DCS 1.2.0.
---@param arg number The argument number for the animation parameter.
---@return number
function Unit:getDrawArgumentValue(arg) end

--- Returns a numerically indexed table of nearby friendly cargo objects sorted by distance, or `nil` if not applicable.
--- Since DCS 2.5.5.
---@return Object[]|nil
function Unit:getNearestCargos() end

--- Enables or disables the unit's emissions, affecting radar and other detectable systems without changing AI state.
--- Since DCS 2.7.0.
---@param setting boolean True to enable emissions, false to disable.
function Unit:enableEmission(setting) end

--- Returns a `number` representing the infantry capacity of an aircraft, or `nil` for non-aircraft units.
--- Since DCS 2.5.6.
---@return nil|number
function Unit:getDescentCapacity() end

--- Returns a table containing detailed technical specifications of the unit. The exact type of descriptor returned depends on the unit's category: AIRPLANE units return UnitDescAirplane, HELICOPTER units return UnitDescHelicopter, GROUND_UNIT units return UnitDescVehicle, SHIP units return UnitDescShip, and other types return the base UnitDesc.
--- Since DCS 1.2.0.
---@return UnitDesc|UnitDescAircraft|UnitDescAirplane|UnitDescHelicopter|UnitDescShip|UnitDescVehicle
function Unit:getDesc() end

--- Returns the `Airbase` object where the unit is stationed or landed, or `nil` if not at an airbase.
--- Since DCS unknown.
---@return Airbase|nil
function Unit:getAirbase() end

--- Returns `true` if the unit can land on a ship, `false` otherwise.
--- Since DCS unknown.
---@return boolean
function Unit:canShipLanding() end

--- Returns `true` if the unit's ramp is currently open, `false` otherwise.
--- Since DCS unknown.
---@return boolean
function Unit:checkOpenRamp() end

--- Initiates the disembarkation process for troops or cargo from this transport unit.
--- Since DCS unknown.
function Unit:disembarking() end

--- Returns a numerically indexed table of cargo objects currently loaded on the unit.
--- Since DCS unknown.
---@return Object[]
function Unit:getCargosOnBoard() end

--- Returns a `coalition.side` enumerator representing the unit's coalition alignment.
--- Since DCS 1.2.4.
---@return coalition.side
function Unit:getCoalition() end

--- Returns the communication system object for this unit.
--- Since DCS unknown.
---@return unknown
function Unit:getCommunicator() end

--- Returns a `country.id` enumerator representing the unit's country affiliation.
--- Since DCS 1.2.0.
---@return country.id
function Unit:getCountry() end

--- Returns information about troops currently loaded on the unit.
--- Since DCS unknown.
---@return unknown
function Unit:getDescentOnBoard() end

--- Returns a `string` name of the military force this unit belongs to, or `nil` if not specified.
--- Since DCS unknown.
---@return nil|string
function Unit:getForcesName() end

--- Returns a `number` representing the low fuel threshold for this unit, or `nil` if not applicable.
--- Since DCS unknown.
---@return nil|number
function Unit:getFuelLowState() end

--- Returns a numerically indexed table of nearby cargo objects suitable for aircraft loading, or `nil` if not applicable.
--- Since DCS unknown.
---@return Object[]|nil
function Unit:getNearestCargosForAircraft() end

--- Returns information about available seating in the unit.
--- Since DCS unknown.
---@return unknown
function Unit:getSeats() end

--- Returns `true` if the unit is or has aircraft carrier capabilities, `false` otherwise.
--- Since DCS unknown.
---@return boolean
function Unit:hasCarrier() end

--- Loads specified cargo or troops onto this transport unit.
--- Since DCS unknown.
function Unit:LoadOnBoard() end

--- Marks a task for disembarking troops or cargo from this unit.
--- Since DCS unknown.
function Unit:markDisembarkingTask() end

--- Displays the legacy carrier operations menu for this unit.
--- Since DCS unknown.
function Unit:OldCarrierMenuShow() end

--- Opens the cargo ramp on this transport unit to allow loading/unloading.
--- Since DCS unknown.
function Unit:openRamp() end

--- Initiates the unloading process for cargo carried by this unit.
--- Since DCS unknown.
function Unit:UnloadCargo() end

--- Returns `true` if the unit has VTOL landing capabilities, `false` otherwise.
--- Since DCS unknown.
---@return boolean
function Unit:vtolableLA() end

--- Returns a `Unit` object with the specified name, or `nil` if not found. Provides access to both activated and non-activated units.
--- Since DCS 1.2.0.
---@param name string Name of the unit as defined in the mission editor or mission.
---@return Unit|nil
function Unit.getByName(name) end

--- Returns a table containing detailed description of the specified unit type. The exact type of descriptor returned depends on the unit's category: AIRPLANE units return UnitDescAirplane, HELICOPTER units return UnitDescHelicopter, GROUND_UNIT units return UnitDescVehicle, SHIP units return UnitDescShip, and other types return the base UnitDesc. Functions even for unit types not present in the current mission.
--- Since DCS 1.2.4.
---@param typeName DcsId.UnitType|string Internal type name of the unit, e.g. 'FA-18C_hornet'.
---@return UnitDesc|UnitDescAircraft|UnitDescAirplane|UnitDescHelicopter|UnitDescShip|UnitDescVehicle
function Unit.getDescByName(typeName) end


--- Represents a storage facility at airbases that manages aircraft, munitions, and fuel resources available to coalition forces.
---@class Warehouse
Warehouse = Warehouse or {}
--- Adds the specified quantity of an item to the warehouse inventory.
---@param itemName_or_wsType string|table
---@param count number
function Warehouse:addItem(itemName_or_wsType, count) end

--- Returns a `number` representing the quantity of the specified item in the warehouse.
---@param itemName_or_wsType string|table
---@return number
function Warehouse:getItemCount(itemName_or_wsType) end

--- Sets the exact quantity of an item in the warehouse inventory, replacing any existing amount.
---@param itemName_or_wsType string|table
---@param count number
function Warehouse:setItem(itemName_or_wsType, count) end

--- Removes the specified quantity of an item from the warehouse inventory.
---@param itemName_or_wsType string|table
---@param count number
function Warehouse:removeItem(itemName_or_wsType, count) end

--- Adds the specified amount of liquid fuel to the warehouse inventory.
---@param liquidType LiquidType
---@param count number
function Warehouse:addLiquid(liquidType, count) end

--- Returns a `number` representing the quantity of the specified liquid fuel in the warehouse.
---@param liquidType LiquidType
---@return number
function Warehouse:getLiquidAmount(liquidType) end

--- Sets the exact amount of a liquid fuel in the warehouse inventory, replacing any existing amount.
---@param liquidType LiquidType
---@param count number
function Warehouse:setLiquidAmount(liquidType, count) end

--- Removes the specified amount of liquid fuel from the warehouse inventory.
---@param liquidType LiquidType
---@param count number
function Warehouse:removeLiquid(liquidType, count) end

--- Returns the `Airbase` object that owns this warehouse.
---@return Airbase
function Warehouse:getOwner() end

--- Returns a table containing a complete inventory of all items in the warehouse.
---@param itemName_or_wsType string|table
---@return table
function Warehouse:getInventory(itemName_or_wsType) end

--- Returns a `Warehouse` object with the specified name, or `nil` if not found.
--- Since DCS 2.8.8.
---@param name string The name of the warehouse.
---@return Warehouse|nil
function Warehouse.getByName(name) end

--- Returns a `Warehouse` object associated with a cargo static object, or `nil` if not applicable.
--- Since DCS 2.8.8.
---@param cargo StaticObject The cargo static object.
---@return Warehouse|nil
function Warehouse.getCargoAsWarehouse(cargo) end

--- Returns a table of all warehouses in the mission, indexed by warehouse name.
--- Since DCS 2.8.8.
---@return table
function Warehouse.getResourceMap() end


--- Represents a weapon entity in the DCS World, including shells, rockets, missiles, and bombs.
---@class Weapon : Object, CoalitionObject
Weapon = Weapon or {}
--- Returns an `Object.Category` enumerator and a `Weapon.Category` enumerator representing the weapon's classification.
--- Since DCS 1.2.0.
---@return Object.Category
---@return Weapon.Category
function Weapon:getCategory() end

--- Returns a `Vec3` representing the weapon's position in the DCS World coordinate system.
--- Since DCS 1.2.0.
---@return Vec3
function Weapon:getPoint() end

--- Returns a `Vec3` representing the weapon's velocity vector in the DCS World coordinate system.
--- Since DCS 1.2.0.
---@return Vec3
function Weapon:getVelocity() end

--- Returns a `coalition.side` enumerator representing the weapon's coalition alignment.
--- Since DCS 1.2.0.
---@return coalition.side
function Weapon:getCoalition() end

--- Returns a `string` representing the weapon's name in the mission.
--- Since DCS 1.2.0.
---@return string
function Weapon:getName() end

--- Returns a `string` representing the weapon's type designation.
--- Since DCS 1.2.0.
---@return DcsId.WeaponType|string
function Weapon:getTypeName() end

--- Returns a table containing detailed technical specifications of the weapon. The exact structure depends on the weapon category.
--- Since DCS 1.2.0.
---@return WeaponDesc|WeaponDescBomb|WeaponDescMissile|WeaponDescRocket
function Weapon:getDesc() end

--- Removes the weapon from the mission without generating destruction events.
--- Since DCS 1.2.0.
function Weapon:destroy() end

--- Returns `true` if the weapon exists in the mission, `false` otherwise.
--- Since DCS 1.2.0.
---@return boolean
function Weapon:isExist() end

--- Returns a `Position3` representing the weapon's position and orientation in the DCS World coordinate system.
--- Since DCS 1.2.0.
---@return Position3
function Weapon:getPosition() end

--- Returns the `Unit` object that launched this weapon.
--- Since DCS 1.2.4.
---@return Unit
function Weapon:getLauncher() end

--- Returns the `Object` that this guided weapon is targeting, or `nil` for unguided weapons or ground-targeted weapons.
--- Since DCS 1.2.4.
---@return Object|nil
function Weapon:getTarget() end

--- Returns a `Weapon.Category` enumerator representing the specific weapon classification (SHELL, MISSILE, ROCKET, BOMB).
--- Since DCS 1.2.4.
---@return Weapon.Category
function Weapon:getCategoryEx() end

--- Returns a `country.id` enumerator representing the country that owns this weapon (via its launcher).
--- Since DCS 1.2.0.
---@return country.id
function Weapon:getCountry() end

--- Returns a `string` representing the force name this weapon belongs to, or `nil` if not assigned to a specific force.
---@return nil|string
function Weapon:getForcesName() end


--- Provides functions for managing events, accessing game world information, and controlling weather conditions in the DCS World.
---@class world
---@field weather world.weather Provides functions for controlling fog and weather conditions in the mission. Since DCS 2.9.10.
---@field event world.event #READONLY Enumerator for event types that can occur in the DCS World simulation.
---@field BirthPlace world.BirthPlace #READONLY Enumerator for spawn locations of aircraft and helicopters.
---@field VolumeType world.VolumeType #READONLY Enumerator for 3D volume types used in spatial queries.
---@field eventHandlers table #READONLY Table of all registered event handler functions.
---@field persistenceHandlers table #READONLY Table of registered persistence handler functions keyed by persistence name, filled by `world.setPersistenceHandler`. Defined in `Scripts/World/PersistenceHandlers.lua`.
world = world or {}
--- Registers an event handler table to be called when simulator events occur. The table must contain an onEvent method.
--- Since DCS 1.2.0.
---@param handler EventHandlerTable A table containing an onEvent method that will be called with event data when events occur.
function world.addEventHandler(handler) end

--- Unregisters a previously added event handler table.
--- Since DCS 1.2.0.
---@param handler EventHandlerTable The event handler table to remove. Must be the same table that was passed to addEventHandler.
function world.removeEventHandler(handler) end

--- Handles simulator events internally for the DCS Mission environment. Different event types produce different event data structures.
---@param eventData EventData Event data containing information about the triggered event. The specific event type determines which fields are available.
function world.onEvent(eventData) end

--- Returns the `Unit` controlled by the player, or `nil` if no unit is directly controlled.
--- Since DCS 1.2.4.
---@return Unit|nil
function world.getPlayer() end

--- Returns a numerically indexed table of all airbase objects in the mission.
--- Since DCS 1.2.4.
---@return AirbaseArray
function world.getAirbases() end

--- Returns objects within a specified 3D volume, optionally applying a handler function to each found object.
--- Since DCS 1.2.4.
---@param category Object.Category|ObjectCategoryArray The category or categories of objects to search for.
---@param searchVolume table A table defining the search volume.
---@param Handler? function An optional handler function to run on each found object.
---@param data? any Optional data to pass to the handler function.
---@return ObjectArray
function world.searchObjects(category, searchVolume, Handler, data) end

--- Returns a table of all active map markers and drawn shapes in the mission.
--- Since DCS 2.5.1.
---@return table
function world.getMarkPanels() end

--- Removes debris within a specified volume, returning the number of items cleared.
--- Since DCS 2.8.4.
---@param searchVolume table A table defining the volume from which to remove junk.
---@return number
function world.removeJunk(searchVolume) end

--- Returns the persisted value stored under `name`. Signature documented in `Scripts/World/PersistenceHandlers.lua` as `world.getPersistenceData(name) -> value`. Not found on `world` in DCS 2.9.29.27468 (mission start, dedicated server).
---@param name string Name the value was stored under by a persistence handler.
---@return any
function world.getPersistenceData(name) end

--- Calls every handler in `world.persistenceHandlers` and passes each handler's name and return value to `storageFunc`. Defined in `Scripts/World/PersistenceHandlers.lua`.
---@param storageFunc function Called as `storageFunc(name, value)` for each registered handler.
function world.runPersistenceHandlers(storageFunc) end

--- Registers `handler` in `world.persistenceHandlers` under `name`; its return value is stored when persistence handlers run. Raises an error if `name` contains characters other than letters, digits, underscore, space or hyphen. Defined in `Scripts/World/PersistenceHandlers.lua`.
---@param name string Persistence name, matching `[a-zA-Z0-9_ -]+`.
---@param handler function Function called with no arguments that returns the value to persist.
function world.setPersistenceHandler(name, handler) end

--- Provides functions for controlling fog and weather conditions in the mission.
--- Since DCS 2.9.10.
---@class world.weather
world.weather = world.weather or {}
--- Returns a `number` representing the current fog thickness in meters.
--- Since DCS 2.9.10.
---@return number
function world.weather.getFogThickness() end

--- Sets the fog thickness at sea level in meters, canceling any active fog animation.
--- Since DCS 2.9.10.
---@param thickness number Fog thickness in meters (0 or 100-5000).
function world.weather.setFogThickness(thickness) end

--- Returns a `number` representing the current fog visibility distance in meters.
--- Since DCS 2.9.10.
---@return number
function world.weather.getFogVisibilityDistance() end

--- Sets the maximum visibility at sea level in meters, canceling any active fog animation.
--- Since DCS 2.9.10.
---@param visibility number Visibility distance in meters (0 or 100-100000).
function world.weather.setFogVisibilityDistance(visibility) end

--- Configures fog to change dynamically over time based on provided keyframes.
--- Since DCS 2.9.10.
---@param fogAnimationKeys nil|table Table of animation keys or nil to discard animation.
function world.weather.setFogAnimation(fogAnimationKeys) end



-- Type Definitions (Enums, Aliases, Records/Classes)
--- Defines the structure of a Lua table representing geographical coordinates using latitude and longitude values.
--- (Data structure definition for LatLon. Not a globally accessible table.)
--- Since DCS 1.2.0.
---@class LatLon
---@field lat number Latitude value in decimal degrees, with positive values representing north of the equator and negative values representing south.
---@field lon number Longitude value in decimal degrees, with positive values representing east of the prime meridian and negative values representing west.

--- Enumerator for Joint Terminal Attack Controller (JTAC) callsigns, used to identify JTAC units in communications and mission planning.
--- Since DCS 1.2.4.
---@alias Callsigns_JTAC
---| 1 # Axeman
---| 2 # Darknight
---| 3 # Warrior
---| 4 # Pointer
---| 5 # Eyeball
---| 6 # Moonbeam
---| 7 # Whiplash
---| 8 # Finger
---| 9 # Pinpoint
---| 10 # Ferret
---| 11 # Shaba
---| 12 # Playboy
---| 13 # Hammer
---| 14 # Jaguar
---| 15 # Deathstar
---| 16 # Anvil
---| 17 # Firefly
---| 18 # Mantis
---| 19 # Badger

--- Defines the structure of a Lua table representing a color with red, green, blue, and alpha components, each normalized between 0.0 and 1.0.
--- (Data structure definition for ColorRGBA. Not a globally accessible table.)
--- ### Examples
--- ```lua
--- {r = 1.0, g = 0.0, b = 0.0, a = 1.0} -- Solid Red
--- ```
--- ```lua
--- {r = 0.0, g = 1.0, b = 0.0, a = 0.5} -- Semi-transparent Green
--- ```
---@class ColorRGBA
---@field r number Red component value between 0.0 (no red) and 1.0 (maximum red intensity).
---@field g number Green component value between 0.0 (no green) and 1.0 (maximum green intensity).
---@field b number Blue component value between 0.0 (no blue) and 1.0 (maximum blue intensity).
---@field a number Alpha (transparency) component value between 0.0 (fully transparent) and 1.0 (fully opaque).

VoiceChat.Side = VoiceChat.Side or {}
--- Enumerator for coalition sides, used to define which players have access to specific voice chat rooms.
--- Since DCS 2.5.6.
---@enum VoiceChat.Side
VoiceChat.Side = {
    NEUTRAL = 0,
    RED = 1,
    BLUE = 2,
    ALL = 3
}

VoiceChat.RoomType = VoiceChat.RoomType or {}
--- Enumerator for voice chat room categories, used to specify the behavior and persistence of communication channels. Note: Only PERSISTENT (0) is reliable for scripted room creation.
--- Since DCS 2.5.6.
---@enum VoiceChat.RoomType
VoiceChat.RoomType = {
    PERSISTENT = 0,
    MULTICREW = 1,
    MANAGEABLE = 2
}

VoiceChat.RadioHandlers = VoiceChat.RadioHandlers or {}
--- Enumerator for radio control properties, used to access and modify aircraft radio communication settings through the VoiceChat API.
--- Since DCS 2.8.0.
---@enum VoiceChat.RadioHandlers
VoiceChat.RadioHandlers = {
    ON_OFF_STATUS = 0,
    FREQUENCY = 1,
    SOUND_VOLUME = 2,
    CHANNEL = 3,
    MODULATION = 4,
    GUARD_STATUS = 5,
    ENCRYPTION_STATUS = 6,
    CRYPTO_KEY = 7,
    SQUELCH_STATUS = 8,
    TRANSMITTER_PWR = 9,
    IS_TRANSMITTING = 10,
    TRANSMISSION_ENABLED = 11,
    EXTERNALLY_CONTROLLED = 12,
    CURRENT_RECEIVING_RADIO = 13
}

VoiceChat.RadioHandlersSingletons = VoiceChat.RadioHandlersSingletons or {}
--- Enumerator for intercom system properties, used to access and modify aircraft internal communication settings through the VoiceChat API.
--- Since DCS 2.8.0.
---@enum VoiceChat.RadioHandlersSingletons
VoiceChat.RadioHandlersSingletons = {
    INTERCOM_SOUND_VOLUME = 0,
    INTERCOM_HOT_MIKE_STATUS = 1,
    INITIALIZATION_COMPLETE = 3
}

--- Represents a 2D vector or point, typically used for map coordinates in the DCS World coordinate system. It is a Lua table with `x` and `y` keys.
--- (Data structure definition for Vec2. Not a globally accessible table.)
---@class Vec2
---@field x number X coordinate, which represents the north-south direction in the DCS World coordinate system. North is positive, South is negative.
---@field y number Y coordinate, which represents the east-west direction in the DCS World coordinate system. East is positive, West is negative.

--- Represents a 3D vector or point, typically used for positions or velocities in the DCS World coordinate system. It is a Lua table with `x`, `y`, and `z` keys.
--- (Data structure definition for Vec3. Not a globally accessible table.)
---@class Vec3
---@field x number X coordinate, which represents the north-south direction in the DCS World coordinate system. North is positive, South is negative.
---@field y number Y coordinate, which represents the elevation direction in the DCS World coordinate system. Up is positive, Down is negative.
---@field z number Z coordinate, which represents the east-west direction in the DCS World coordinate system. East is positive, West is negative.

--- Defines the structure of a Lua table representing an event handler object that can be registered with world.addEventHandler.
--- (Data structure definition for EventHandlerTable. Not a globally accessible table.)
---@class EventHandlerTable
---@field onEvent? function Function that handles simulator events when they occur. Called with (self, event) parameters where event is of type EventData.

Weapon.Category = Weapon.Category or {}
--- Enumerator for weapon class classifications, used to categorize different types of munitions by their fundamental operational characteristics.
---@enum Weapon.Category
Weapon.Category = {
    SHELL = 0,
    MISSILE = 1,
    ROCKET = 2,
    BOMB = 3,
    TORPEDO = 4
}

Weapon.GuidanceType = Weapon.GuidanceType or {}
--- Enumerator for weapon guidance technologies, used to specify the targeting and course correction mechanisms of guided munitions.
---@enum Weapon.GuidanceType
Weapon.GuidanceType = {
    INS = 1,
    IR = 2,
    RADAR_ACTIVE = 3,
    RADAR_SEMI_ACTIVE = 4,
    RADAR_PASSIVE = 5,
    TV = 6,
    LASER = 7,
    TELE = 8
}

Weapon.MissileCategory = Weapon.MissileCategory or {}
--- Enumerator for missile operational roles, used to classify missiles by their intended target types and operational domains.
---@enum Weapon.MissileCategory
Weapon.MissileCategory = {
    AAM = 1,
    SAM = 2,
    BM = 3,
    ANTI_SHIP = 4,
    CRUISE = 5,
    OTHER = 6
}

Weapon.WarheadType = Weapon.WarheadType or {}
--- Enumerator for warhead mechanisms, used to specify the damage-producing method employed by a weapon's terminal effect component.
---@enum Weapon.WarheadType
Weapon.WarheadType = {
    AP = 0,
    HE = 1,
    SHAPED_EXPLOSIVE = 2
}

Weapon.flag = Weapon.flag or {}
--- Enumerator for weapon capability flags, used to identify specific weapon properties and subtypes through bit field values.
---@enum Weapon.flag
Weapon.flag = {
    NoWeapon = 0,
    LGB = 2,
    TvGB = 4,
    SNSGB = 8,
    HEBomb = 16,
    Penetrator = 32,
    NapalmBomb = 64,
    FAEBomb = 128,
    ClusterBomb = 256,
    Dispencer = 512,
    CandleBomb = 1024,
    ParachuteBomb = 2147483648,
    GuidedBomb = 14,
    AnyBomb = 2147485694,
    AnyUnguidedBomb = 2147485680,
    LightRocket = 2048,
    CandleRocket = 8192,
    HeavyRocket = 16384,
    MarkerRocket = 4096,
    AnyRocket = 30720,
    SAR_AAM = 67108864,
    AR_AAM = 134217728,
    IR_AAM = 33554432,
    SRAAM = 4194304,
    MRAAM = 8388608,
    LRAAM = 16777216,
    AnyAAM = 264241152,
    AnyAAWeapon = 1069547520,
    AntiRadarMissile = 32768,
    AntiRadarMissile2 = 1073741824,
    AntiShipMissile = 65536,
    AntiTankMissile = 131072,
    FireAndForgetASM = 262144,
    LaserASM = 524288,
    TeleASM = 1048576,
    CruiseMissile = 2097152,
    GuidedASM = 1572864,
    TacticASM = 1835008,
    AnyASM = 4161536,
    AnyAutonomousMissile = 36012032,
    AnyMissile = 268402688,
    AnyAGWeapon = 2956984318,
    Torpedo = 4294967296,
    AnyTorpedo = 4294967296,
    GUN_POD = 268435456,
    BuiltInCannon = 536870912,
    Cannons = 805306368,
    AnyShell = 258503344128,
    ConventionalShell = 206963736576,
    GuidedShell = 137438953472,
    IlluminationShell = 34359738368,
    MarkerShell = 51539607552,
    SmokeShell = 17179869184,
    SubmunitionDispenserShell = 68719476736,
    Decoys = 8589934592,
    ArmWeapon = 213674609662,
    GuidedWeapon = 137707356174,
    MarkerWeapon = 51539620864,
    UnguidedWeapon = 2952822768,
    AnyWeapon = 265214230526,
    AllWeapon = -1
}

--- Beacon types (`ActivateBeacon` `type`), per Scripts/World/Radio/BeaconTypes.lua. Generated by tools/datamine/extract.py from the DCS install scripts; do not edit.
---@alias BeaconType
---| 0 # BEACON_TYPE_NULL
---| 1 # BEACON_TYPE_VOR
---| 2 # BEACON_TYPE_DME
---| 3 # BEACON_TYPE_VOR_DME
---| 4 # BEACON_TYPE_TACAN
---| 5 # BEACON_TYPE_VORTAC
---| 8 # BEACON_TYPE_HOMER
---| 128 # BEACON_TYPE_RSBN
---| 1024 # BEACON_TYPE_BROADCAST_STATION
---| 4104 # BEACON_TYPE_AIRPORT_HOMER
---| 4136 # BEACON_TYPE_AIRPORT_HOMER_WITH_MARKER
---| 16408 # BEACON_TYPE_ILS_FAR_HOMER
---| 16424 # BEACON_TYPE_ILS_NEAR_HOMER
---| 16640 # BEACON_TYPE_ILS_LOCALIZER
---| 16896 # BEACON_TYPE_ILS_GLIDESLOPE
---| 33024 # BEACON_TYPE_PRMG_LOCALIZER
---| 33280 # BEACON_TYPE_PRMG_GLIDESLOPE
---| 65536 # BEACON_TYPE_NAUTICAL_HOMER
---| 131328 # BEACON_TYPE_ICLS_LOCALIZER
---| 131584 # BEACON_TYPE_ICLS_GLIDESLOPE
---| 262144 # BEACON_TYPE_TACAN_RANGE

--- Beacon systems (`ActivateBeacon` `system`): transmitter power, antenna pattern and signal, per Scripts/World/Radio/BeaconSites.lua. Generated by tools/datamine/extract.py from the DCS install scripts; do not edit.
---@alias BeaconSystemName
---| 1 # PAR_10
---| 2 # RSBN_4H
---| 3 # TACAN
---| 4 # TACAN_TANKER_MODE_X
---| 5 # TACAN_TANKER_MODE_Y
---| 6 # VOR
---| 7 # ILS_LOCALIZER
---| 8 # ILS_GLIDESLOPE
---| 9 # PRMG_LOCALIZER
---| 10 # PRMG_GLIDESLOPE
---| 11 # BROADCAST_STATION
---| 12 # VORTAC
---| 13 # TACAN_AA_MODE_X
---| 14 # TACAN_AA_MODE_Y
---| 15 # VORDME
---| 16 # ICLS_LOCALIZER
---| 17 # ICLS_GLIDESLOPE
---| 18 # TACAN_MOBILE_MODE_X
---| 19 # TACAN_MOBILE_MODE_Y
---| 20 # TACAN_AA_MODE_X_AND_BRG
---| 21 # TACAN_AA_MODE_Y_AND_BRG

AI.Task = AI.Task or {}
AI.Task.WeaponExpend = AI.Task.WeaponExpend or {}
--- Enumerator for ammunition expenditure levels per attack run, used in AI task assignments.
--- Since DCS 1.2.4.
---@enum AI.Task.WeaponExpend
AI.Task.WeaponExpend = {
    QUARTER = "Quarter",
    TWO = "Two",
    ONE = "One",
    FOUR = "Four",
    HALF = "Half",
    ALL = "All"
}

AI.Task.Designation = AI.Task.Designation or {}
--- Enumerator for target designation methods used by Forward Air Controllers (FAC) and Joint Terminal Attack Controllers (JTAC).
--- Since DCS 1.2.4.
---@enum AI.Task.Designation
AI.Task.Designation = {
    NO = "No",
    WP = "WP",
    IR_POINTER = "IR-Pointer",
    LASER = "Laser",
    AUTO = "Auto"
}

AI.Task.OrbitPattern = AI.Task.OrbitPattern or {}
--- Enumerator for aircraft orbit patterns used in patrol and surveillance tasks.
--- Since DCS 1.2.4.
---@enum AI.Task.OrbitPattern
AI.Task.OrbitPattern = {
    RACE_TRACK = "Race-Track",
    CIRCLE = "Circle"
}

AI.Task.TurnMethod = AI.Task.TurnMethod or {}
--- Enumerator for waypoint turn methods used in AI navigation.
--- Since DCS 1.1.
---@enum AI.Task.TurnMethod
AI.Task.TurnMethod = {
    FLY_OVER_POINT = "Fly Over Point",
    FIN_POINT = "Fin Point"
}

AI.Task.VehicleFormation = AI.Task.VehicleFormation or {}
--- Enumerator for ground vehicle formation patterns used in group movement.
--- Since DCS 1.2.0.
---@enum AI.Task.VehicleFormation
AI.Task.VehicleFormation = {
    VEE = "Vee",
    ECHELON_RIGHT = "EchelonR",
    OFF_ROAD = "Off Road",
    RANK = "Rank",
    ECHELON_LEFT = "EchelonL",
    ON_ROAD = "On Road",
    CONE = "Cone",
    DIAMOND = "Diamond"
}

AI.Task.AltitudeType = AI.Task.AltitudeType or {}
--- Enumerator for altitude reference systems used in AI flight tasks.
--- Since DCS 1.2.0.
---@enum AI.Task.AltitudeType
AI.Task.AltitudeType = {
    RADIO = "RADIO",
    BARO = "BARO"
}

AI.Task.WaypointType = AI.Task.WaypointType or {}
--- Enumerator for waypoint types used in AI flight planning.
--- Since DCS 1.1.
---@enum AI.Task.WaypointType
AI.Task.WaypointType = {
    TAKEOFF = "TakeOff",
    TAKEOFF_PARKING = "TakeOffParking",
    TURNING_POINT = "Turning Point",
    TAKEOFF_PARKING_HOT = "TakeOffParkingHot",
    LAND = "Land"
}

AI.Skill = AI.Skill or {}
--- Enumerator for AI difficulty and competence levels assigned to units.
--- Since DCS 1.2.0.
---@enum AI.Skill
AI.Skill = {
    PLAYER = "Player",
    CLIENT = "Client",
    AVERAGE = "Average",
    GOOD = "Good",
    HIGH = "High",
    EXCELLENT = "Excellent"
}

--- Defines the structure of options applicable to AI-controlled aircraft.
--- Since DCS 1.2.0.
---@class AI.Option.Air
AI.Option = AI.Option or {}
AI.Option.Air = AI.Option.Air or {}

AI.Option.Air.id = AI.Option.Air.id or {}
--- Enumerator for option identifiers applicable to AI-controlled aircraft.
--- Since DCS 1.2.0.
---@enum AI.Option.Air.id
AI.Option.Air.id = {
    NO_OPTION = -1,
    ROE = 0,
    REACTION_ON_THREAT = 1,
    RADAR_USING = 3,
    FLARE_USING = 4,
    FORMATION = 5,
    RTB_ON_BINGO = 6,
    SILENCE = 7,
    RTB_ON_OUT_OF_AMMO = 10,
    ECM_USING = 13,
    PROHIBIT_AA = 14,
    PROHIBIT_JETT = 15,
    PROHIBIT_AB = 16,
    PROHIBIT_AG = 17,
    MISSILE_ATTACK = 18,
    PROHIBIT_WP_PASS_REPORT = 19,
    OPTION_RADIO_USAGE_CONTACT = 21,
    OPTION_RADIO_USAGE_ENGAGE = 22,
    OPTION_RADIO_USAGE_KILL = 23,
    JETT_TANKS_IF_EMPTY = 25,
    FORCED_ATTACK = 26,
    PREFER_VERTICAL = 32,
    ALLOW_FORMATION_SIDE_SWAP = 35,
    LANDING_OPTIONS = 36,
    ALLOW_LINE_UP_RW = 37,
    DISENGAGE_AND_RTB = 38
}

--- Defines the structure of option values for AI-controlled aircraft settings.
--- Since DCS 1.2.0.
---@class AI.Option.Air.val
AI.Option.Air.val = AI.Option.Air.val or {}

AI.Option.Air.val.ROE = AI.Option.Air.val.ROE or {}
--- Enumerator for Rules of Engagement settings available to AI-controlled aircraft.
--- Since DCS 1.2.4.
---@enum AI.Option.Air.val.ROE
AI.Option.Air.val.ROE = {
    WEAPON_FREE = 0,
    OPEN_FIRE_WEAPON_FREE = 1,
    OPEN_FIRE = 2,
    RETURN_FIRE = 3,
    WEAPON_HOLD = 4
}

AI.Option.Air.val.REACTION_ON_THREAT = AI.Option.Air.val.REACTION_ON_THREAT or {}
--- Enumerator for threat response behaviors available to AI-controlled aircraft.
--- Since DCS 1.2.4.
---@enum AI.Option.Air.val.REACTION_ON_THREAT
AI.Option.Air.val.REACTION_ON_THREAT = {
    NO_REACTION = 0,
    PASSIVE_DEFENCE = 1,
    EVADE_FIRE = 2,
    BYPASS_AND_ESCAPE = 3,
    ALLOW_ABORT_MISSION = 4
}

AI.Option.Air.val.RADAR_USING = AI.Option.Air.val.RADAR_USING or {}
--- Enumerator for radar usage policies available to AI-controlled aircraft.
--- Since DCS 1.2.4.
---@enum AI.Option.Air.val.RADAR_USING
AI.Option.Air.val.RADAR_USING = {
    NEVER = 0,
    FOR_ATTACK_ONLY = 1,
    FOR_SEARCH_IF_REQUIRED = 2,
    FOR_CONTINUOUS_SEARCH = 3
}

AI.Option.Air.val.FLARE_USING = AI.Option.Air.val.FLARE_USING or {}
--- Enumerator for flare countermeasure usage policies available to AI-controlled aircraft.
--- Since DCS 1.2.4.
---@enum AI.Option.Air.val.FLARE_USING
AI.Option.Air.val.FLARE_USING = {
    NEVER = 0,
    AGAINST_FIRED_MISSILE = 1,
    WHEN_FLYING_IN_SAM_WEZ = 2,
    WHEN_FLYING_NEAR_ENEMIES = 3
}

AI.Option.Air.val.ECM_USING = AI.Option.Air.val.ECM_USING or {}
--- Enumerator for electronic countermeasure usage policies available to AI-controlled aircraft.
--- Since DCS 1.5.0.
---@enum AI.Option.Air.val.ECM_USING
AI.Option.Air.val.ECM_USING = {
    NEVER_USE = 0,
    USE_IF_ONLY_LOCK_BY_RADAR = 1,
    USE_IF_DETECTED_LOCK_BY_RADAR = 2,
    ALWAYS_USE = 3
}

AI.Option.Air.val.MISSILE_ATTACK = AI.Option.Air.val.MISSILE_ATTACK or {}
--- Enumerator for missile engagement range policies available to AI-controlled aircraft.
--- Since DCS 1.5.0.
---@enum AI.Option.Air.val.MISSILE_ATTACK
AI.Option.Air.val.MISSILE_ATTACK = {
    MAX_RANGE = 0,
    NEZ_RANGE = 1,
    HALF_WAY_RMAX_NEZ = 2,
    TARGET_THREAT_EST = 3,
    RANDOM_RANGE = 4
}

--- Defines the structure of options applicable to AI-controlled ground units.
--- Since DCS 1.2.0.
---@class AI.Option.Ground
AI.Option.Ground = AI.Option.Ground or {}

AI.Option.Ground.id = AI.Option.Ground.id or {}
--- Enumerator for option identifiers applicable to AI-controlled ground units.
--- Since DCS 1.2.0.
---@enum AI.Option.Ground.id
AI.Option.Ground.id = {
    NO_OPTION = -1,
    ROE = 0,
    FORMATION = 5,
    DISPERSE_ON_ATTACK = 8,
    ALARM_STATE = 9,
    ENGAGE_AIR_WEAPONS = 20,
    AC_ENGAGEMENT_RANGE_RESTRICTION = 24,
    EVASION_OF_ARM = 31
}

--- Defines the structure of option values for AI-controlled ground unit settings.
--- Since DCS 1.2.0.
---@class AI.Option.Ground.val
AI.Option.Ground.val = AI.Option.Ground.val or {}

AI.Option.Ground.val.ALARM_STATE = AI.Option.Ground.val.ALARM_STATE or {}
--- Enumerator for alert readiness levels available to AI-controlled ground units.
--- Since DCS 1.2.4.
---@enum AI.Option.Ground.val.ALARM_STATE
AI.Option.Ground.val.ALARM_STATE = {
    AUTO = 0,
    GREEN = 1,
    RED = 2
}

AI.Option.Ground.val.ROE = AI.Option.Ground.val.ROE or {}
--- Enumerator for Rules of Engagement settings available to AI-controlled ground units.
--- Since DCS 1.2.4.
---@enum AI.Option.Ground.val.ROE
AI.Option.Ground.val.ROE = {
    OPEN_FIRE = 2,
    RETURN_FIRE = 3,
    WEAPON_HOLD = 4
}

--- Defines the structure of options applicable to AI-controlled naval units.
--- Since DCS 1.2.0.
---@class AI.Option.Naval
AI.Option.Naval = AI.Option.Naval or {}

AI.Option.Naval.id = AI.Option.Naval.id or {}
--- Enumerator for option identifiers applicable to AI-controlled naval units.
--- Since DCS 1.2.0.
---@enum AI.Option.Naval.id
AI.Option.Naval.id = {
    NO_OPTION = -1,
    ROE = 0
}

--- Defines the structure of option values for AI-controlled naval unit settings.
--- Since DCS 1.2.0.
---@class AI.Option.Naval.val
AI.Option.Naval.val = AI.Option.Naval.val or {}

AI.Option.Naval.val.ROE = AI.Option.Naval.val.ROE or {}
--- Enumerator for Rules of Engagement settings available to AI-controlled naval units.
--- Since DCS 1.2.4.
---@enum AI.Option.Naval.val.ROE
AI.Option.Naval.val.ROE = {
    OPEN_FIRE = 2,
    RETURN_FIRE = 3,
    WEAPON_HOLD = 4
}

--- Defines the structure of a Lua table representing a Military Grid Reference System (MGRS) coordinate used for precise position referencing in the DCS World.
--- (Data structure definition for MGRS. Not a globally accessible table.)
--- Since DCS 1.2.0.
---@class MGRS
---@field UTMZone string The Universal Transverse Mercator (UTM) zone designation indicating the longitude zone.
---@field MGRSDigraph string The MGRS grid square designator consisting of two letters identifying a specific 100km square.
---@field Easting number Easting coordinate in meters, measuring the distance eastward from the zone's central meridian.
---@field Northing number Northing coordinate in meters, measuring the distance northward from the equator.

--- Defines the structure of a Lua table representing the store on one aircraft station.
--- (Data structure definition for UnitPylon. Not a globally accessible table.)
---@class UnitPylon
---@field CLSID string Store CLSID (a `stores` record id of the reference data).
---@field settings? table Store settings such as fuzes, as the Mission Editor writes them.

country = country or {}
country.id = country.id or {}
--- Enumerator for country identifiers, used to specify nation affiliation for units and coalition forces in the DCS World. Generated by tools/datamine/extract.py from DCS constants (_G dump); do not edit.
---@enum country.id
country.id = {
    RUSSIA = 0,
    UKRAINE = 1,
    USA = 2,
    TURKEY = 3,
    UK = 4,
    FRANCE = 5,
    GERMANY = 6,
    AGGRESSORS = 7,
    CANADA = 8,
    SPAIN = 9,
    THE_NETHERLANDS = 10,
    BELGIUM = 11,
    NORWAY = 12,
    DENMARK = 13,
    ISRAEL = 15,
    GEORGIA = 16,
    INSURGENTS = 17,
    ABKHAZIA = 18,
    SOUTH_OSETIA = 19,
    ITALY = 20,
    AUSTRALIA = 21,
    SWITZERLAND = 22,
    AUSTRIA = 23,
    BELARUS = 24,
    BULGARIA = 25,
    CHEZH_REPUBLIC = 26,
    CHINA = 27,
    CROATIA = 28,
    EGYPT = 29,
    FINLAND = 30,
    GREECE = 31,
    HUNGARY = 32,
    INDIA = 33,
    IRAN = 34,
    IRAQ = 35,
    JAPAN = 36,
    KAZAKHSTAN = 37,
    NORTH_KOREA = 38,
    PAKISTAN = 39,
    POLAND = 40,
    ROMANIA = 41,
    SAUDI_ARABIA = 42,
    SERBIA = 43,
    SLOVAKIA = 44,
    SOUTH_KOREA = 45,
    SWEDEN = 46,
    SYRIA = 47,
    YEMEN = 48,
    VIETNAM = 49,
    VENEZUELA = 50,
    TUNISIA = 51,
    THAILAND = 52,
    SUDAN = 53,
    PHILIPPINES = 54,
    MOROCCO = 55,
    MEXICO = 56,
    MALAYSIA = 57,
    LIBYA = 58,
    JORDAN = 59,
    INDONESIA = 60,
    HONDURAS = 61,
    ETHIOPIA = 62,
    CHILE = 63,
    BRAZIL = 64,
    BAHRAIN = 65,
    THIRDREICH = 66,
    YUGOSLAVIA = 67,
    USSR = 68,
    ITALIAN_SOCIAL_REPUBLIC = 69,
    ALGERIA = 70,
    KUWAIT = 71,
    QATAR = 72,
    OMAN = 73,
    UNITED_ARAB_EMIRATES = 74,
    SOUTH_AFRICA = 75,
    CUBA = 76,
    PORTUGAL = 77,
    GDR = 78,
    LEBANON = 79,
    CJTF_BLUE = 80,
    CJTF_RED = 81,
    UN_PEACEKEEPERS = 82,
    ARGENTINA = 83,
    CYPRUS = 84,
    SLOVENIA = 85,
    BOLIVIA = 86,
    GHANA = 87,
    NIGERIA = 88,
    PERU = 89,
    ECUADOR = 90,
    AFGHANISTAN = 91,
    ["NEW ZEALAND"] = 92
}

country.name = country.name or {}
--- Enumerator for retrieving country names from numeric identifiers, providing a reverse lookup of country.id values. Generated by tools/datamine/extract.py from DCS constants (_G dump); do not edit.
---@enum country.name
country.name = {
    ["0"] = "RUSSIA",
    ["1"] = "UKRAINE",
    ["2"] = "USA",
    ["3"] = "TURKEY",
    ["4"] = "UK",
    ["5"] = "FRANCE",
    ["6"] = "GERMANY",
    ["7"] = "AGGRESSORS",
    ["8"] = "CANADA",
    ["9"] = "SPAIN",
    ["10"] = "THE_NETHERLANDS",
    ["11"] = "BELGIUM",
    ["12"] = "NORWAY",
    ["13"] = "DENMARK",
    ["15"] = "ISRAEL",
    ["16"] = "GEORGIA",
    ["17"] = "INSURGENTS",
    ["18"] = "ABKHAZIA",
    ["19"] = "SOUTH_OSETIA",
    ["20"] = "ITALY",
    ["21"] = "AUSTRALIA",
    ["22"] = "SWITZERLAND",
    ["23"] = "AUSTRIA",
    ["24"] = "BELARUS",
    ["25"] = "BULGARIA",
    ["26"] = "CHEZH_REPUBLIC",
    ["27"] = "CHINA",
    ["28"] = "CROATIA",
    ["29"] = "EGYPT",
    ["30"] = "FINLAND",
    ["31"] = "GREECE",
    ["32"] = "HUNGARY",
    ["33"] = "INDIA",
    ["34"] = "IRAN",
    ["35"] = "IRAQ",
    ["36"] = "JAPAN",
    ["37"] = "KAZAKHSTAN",
    ["38"] = "NORTH_KOREA",
    ["39"] = "PAKISTAN",
    ["40"] = "POLAND",
    ["41"] = "ROMANIA",
    ["42"] = "SAUDI_ARABIA",
    ["43"] = "SERBIA",
    ["44"] = "SLOVAKIA",
    ["45"] = "SOUTH_KOREA",
    ["46"] = "SWEDEN",
    ["47"] = "SYRIA",
    ["48"] = "YEMEN",
    ["49"] = "VIETNAM",
    ["50"] = "VENEZUELA",
    ["51"] = "TUNISIA",
    ["52"] = "THAILAND",
    ["53"] = "SUDAN",
    ["54"] = "PHILIPPINES",
    ["55"] = "MOROCCO",
    ["56"] = "MEXICO",
    ["57"] = "MALAYSIA",
    ["58"] = "LIBYA",
    ["59"] = "JORDAN",
    ["60"] = "INDONESIA",
    ["61"] = "HONDURAS",
    ["62"] = "ETHIOPIA",
    ["63"] = "CHILE",
    ["64"] = "BRAZIL",
    ["65"] = "BAHRAIN",
    ["66"] = "THIRDREICH",
    ["67"] = "YUGOSLAVIA",
    ["68"] = "USSR",
    ["69"] = "ITALIAN_SOCIAL_REPUBLIC",
    ["70"] = "ALGERIA",
    ["71"] = "KUWAIT",
    ["72"] = "QATAR",
    ["73"] = "OMAN",
    ["74"] = "UNITED_ARAB_EMIRATES",
    ["75"] = "SOUTH_AFRICA",
    ["76"] = "CUBA",
    ["77"] = "PORTUGAL",
    ["78"] = "GDR",
    ["79"] = "LEBANON",
    ["80"] = "CJTF_BLUE",
    ["81"] = "CJTF_RED",
    ["82"] = "UN_PEACEKEEPERS",
    ["83"] = "ARGENTINA",
    ["84"] = "CYPRUS",
    ["85"] = "SLOVENIA",
    ["86"] = "BOLIVIA",
    ["87"] = "GHANA",
    ["88"] = "NIGERIA",
    ["89"] = "PERU",
    ["90"] = "ECUADOR",
    ["91"] = "AFGHANISTAN",
    ["92"] = "NEW ZEALAND"
}

trigger.smokeColor = trigger.smokeColor or {}
--- Enumerator for smoke colors, used to specify colored smoke effects in trigger actions.
--- Since DCS 1.2.0.
---@enum trigger.smokeColor
trigger.smokeColor = {
    Green = 0,
    Red = 1,
    White = 2,
    Orange = 3,
    Blue = 4
}

trigger.flareColor = trigger.flareColor or {}
--- Enumerator for flare colors, used to specify colored illumination flares in trigger actions.
--- Since DCS 1.2.0.
---@enum trigger.flareColor
trigger.flareColor = {
    Green = 0,
    Red = 1,
    White = 2,
    Yellow = 3
}

--- Enumerator for markup geometric shape types, used with trigger.action.markupToAll to create map annotations.
--- Since DCS 2.5.6.
---@alias MarkupShapeId
---| 1 # Line
---| 2 # Circle
---| 3 # Rect
---| 4 # Arrow
---| 5 # Text
---| 6 # Quad
---| 7 # Freeform

--- Enumerator for line style patterns, used to customize map markup line appearances in trigger actions.
--- Since DCS 2.5.5.
---@alias MarkupLineType
---| 0 # NoLine
---| 1 # Solid
---| 2 # Dashed
---| 3 # Dotted
---| 4 # DotDash
---| 5 # LongDash
---| 6 # TwoDash

--- Enumerator for smoke and fire effect variants, used to specify visual effect intensity and characteristics in trigger actions.
--- Since DCS 1.2.0.
---@alias BigSmokeType
---| 1 # SmallSmokeAndFire
---| 2 # MediumSmokeAndFire
---| 3 # LargeSmokeAndFire
---| 4 # HugeSmokeAndFire
---| 5 # SmallSmoke
---| 6 # MediumSmoke
---| 7 # LargeSmoke
---| 8 # HugeSmoke

--- Enumerator for radio transmission modulation types, used to specify signal modulation in trigger communication actions.
--- Since DCS 1.2.0.
---@alias RadioModulation
---| 0 # AM
---| 1 # FM
---| 2 # AM_AND_FM

Unit.Category = Unit.Category or {}
--- Enumerator for unit categories, used to classify entities by their basic type and operational domain.
---@enum Unit.Category
Unit.Category = {
    AIRPLANE = 0,
    HELICOPTER = 1,
    GROUND_UNIT = 2,
    SHIP = 3,
    STRUCTURE = 4
}

Unit.RefuelingSystem = Unit.RefuelingSystem or {}
--- Enumerator for aerial refueling system types, used to specify compatible air-to-air refueling equipment configurations.
---@enum Unit.RefuelingSystem
Unit.RefuelingSystem = {
    BOOM_AND_RECEPTACLE = 0,
    PROBE_AND_DROGUE = 1
}

Unit.SensorType = Unit.SensorType or {}
--- Enumerator for sensor system categories, used to classify detection and targeting equipment on units.
---@enum Unit.SensorType
Unit.SensorType = {
    OPTIC = 0,
    RADAR = 1,
    IRST = 2,
    RWR = 3
}

Unit.OpticType = Unit.OpticType or {}
--- Enumerator for optical sensor technologies, used to specify visual detection capabilities of units.
---@enum Unit.OpticType
Unit.OpticType = {
    TV = 0,
    LLTV = 1,
    IR = 2
}

Unit.RadarType = Unit.RadarType or {}
--- Enumerator for radar system classifications, used to differentiate between air search and surface search capabilities.
---@enum Unit.RadarType
Unit.RadarType = {
    AS = 0,
    SS = 1
}

--- A table of capability and characteristic flags that define the features and abilities of a unit. Fields correspond to `DcsId.Attribute` names.
--- (Data structure definition for UnitAttributes. Not a globally accessible table.)
---@class UnitAttributes

--- Defines the structure of a Lua table representing detection ranges based on aspect angle within a hemisphere.
--- (Data structure definition for UnitSensorHemisphereDistance. Not a globally accessible table.)
---@class UnitSensorHemisphereDistance
---@field tailOn? number A numeric value representing the maximum detection distance in meters when facing the rear of the target.
---@field headOn? number A numeric value representing the maximum detection distance in meters when facing the front of the target.

--- Defines the structure of a Lua table representing performance characteristics specific to fixed-wing aircraft in the DCS World. Includes all fields from UnitDesc and UnitDescAircraft plus the following airplane-specific fields.
--- (Data structure definition for UnitDescAirplane. Not a globally accessible table.)
---@class UnitDescAirplane
---@field speedMax0? number A numeric value representing the maximum true airspeed in meters per second at sea level.
---@field speedMax10K? number A numeric value representing the maximum true airspeed in meters per second at 10,000 meters altitude.

--- Defines the structure of a Lua table representing performance characteristics specific to rotary-wing aircraft in the DCS World. Includes all fields from UnitDesc and UnitDescAircraft plus the following helicopter-specific fields.
--- (Data structure definition for UnitDescHelicopter. Not a globally accessible table.)
---@class UnitDescHelicopter
---@field HmaxStat? number A numeric value representing the maximum hover ceiling in meters (altitude at which the helicopter can maintain a stable hover).

--- Defines the structure of a Lua table representing performance characteristics specific to ground vehicles in the DCS World. Includes all fields from UnitDesc plus the following vehicle-specific fields.
--- (Data structure definition for UnitDescVehicle. Not a globally accessible table.)
---@class UnitDescVehicle
---@field maxSlopeAngle? number A numeric value representing the maximum terrain slope angle in radians that the vehicle can traverse.
---@field riverCrossing? boolean A boolean value indicating whether the vehicle has amphibious capabilities to cross water obstacles.
---@field speedMaxOffRoad? number A numeric value representing the maximum speed in meters per second when traveling on unpaved terrain.

--- Defines the structure of a Lua table representing performance characteristics specific to naval vessels in the DCS World. Includes all fields from UnitDesc plus any ship-specific fields.
--- (Data structure definition for UnitDescShip. Not a globally accessible table.)
---@class UnitDescShip

--- Airplane unit types (`Unit:getTypeName()`, a mission unit's `type`). Keyed by display name.
---@alias DcsId.AircraftType
---| "A-10A"
---| "A-10C"
---| "A-10C_2" # A-10C II
---| "A-20G"
---| "A-50"
---| "A6E" # A-6E
---| "AJS37"
---| "An-26B"
---| "An-30M"
---| "AV8BNA" # AV-8B N/A
---| "B-17G"
---| "B-1B"
---| "B-52H"
---| "Bf-109K-4" # Bf 109 K-4
---| "C-101CC"
---| "C-101EB"
---| "C-130"
---| "C-130J-30"
---| "C-17A"
---| "C-47"
---| "Christen Eagle II"
---| "E-2C" # E-2D
---| "E-3A"
---| "F-100D"
---| "F-117A"
---| "F-14A"
---| "F-14A-135-GR-Early"
---| "F-14A-95-GR" # F-14A Export
---| "F-14A-135-GR" # F-14A Late
---| "F-14B"
---| "F-14BU" # F-14B(U)
---| "F-15C"
---| "F-15E"
---| "F-15ESE" # F-15E S4+
---| "F-16A"
---| "F-16A MLU"
---| "F-16C bl.50"
---| "F-16C bl.52d"
---| "F-16C_50" # F-16CM bl.50
---| "F-4E"
---| "F-4E-45MC"
---| "F-5E"
---| "F-5E-3_FC" # F-5E FC
---| "F-5E-3"
---| "F-86F Sabre" # F-86F
---| "F-86F_FC" # F-86F FC
---| "F/A-18A"
---| "F/A-18C"
---| "FA-18C_hornet" # F/A-18C Lot 20
---| "F4U-1D"
---| "F4U-1D_CW" # F4U-1D Mk.IV
---| "Falcon_Gyrocopter" # Falcon Assault Gyrocopter
---| "FW-190A8" # Fw 190 A-8
---| "FW-190D9" # Fw 190 D-9
---| "H-6J"
---| "Hawk"
---| "I-16"
---| "IL-76MD"
---| "IL-78M"
---| "J-11A"
---| "JF-17"
---| "Ju-88A4" # Ju 88 A-4
---| "KC130" # KC-130
---| "KC-135"
---| "KC135MPRS" # KC-135MPRS
---| "KJ-2000"
---| "L-39C"
---| "L-39ZA"
---| "La-7"
---| "M-2000C"
---| "MB-339A"
---| "MB-339APAN" # MB-339A/PAN
---| "MiG-15bis"
---| "MiG-15bis_FC" # MiG-15bis FC
---| "MiG-19P"
---| "MiG-21Bis"
---| "MiG-23MLD"
---| "MiG-25PD"
---| "MiG-25RBT"
---| "MiG-27K"
---| "MiG-29A"
---| "MiG-29 Fulcrum" # MiG-29A  Fulcrum
---| "MiG-29G"
---| "MiG-29S"
---| "MiG-31"
---| "Mirage 2000-5"
---| "Mirage-F1AD" # Mirage F1AD
---| "Mirage-F1AZ" # Mirage F1AZ
---| "Mirage-F1B" # Mirage F1B
---| "Mirage-F1BD" # Mirage F1BD
---| "Mirage-F1BE" # Mirage F1BE
---| "Mirage-F1BQ" # Mirage F1BQ
---| "Mirage-F1C" # Mirage F1C
---| "Mirage-F1C-200" # Mirage F1C-200
---| "Mirage-F1CE" # Mirage F1CE
---| "Mirage-F1CG" # Mirage F1CG
---| "Mirage-F1CH" # Mirage F1CH
---| "Mirage-F1CJ" # Mirage F1CJ
---| "Mirage-F1CK" # Mirage F1CK
---| "Mirage-F1CR" # Mirage F1CR
---| "Mirage-F1CT" # Mirage F1CT
---| "Mirage-F1CZ" # Mirage F1CZ
---| "Mirage-F1DDA" # Mirage F1DDA
---| "Mirage-F1ED" # Mirage F1ED
---| "Mirage-F1EDA" # Mirage F1EDA
---| "Mirage-F1EE" # Mirage F1EE
---| "Mirage-F1EH" # Mirage F1EH
---| "Mirage-F1EQ" # Mirage F1EQ
---| "Mirage-F1JA" # Mirage F1JA
---| "Mirage-F1M-CE" # Mirage F1M (C.14 1-25/32-51)
---| "Mirage-F1M-EE" # Mirage F1M (C.14 52-73)
---| "MosquitoFBMkVI" # Mosquito FB Mk. VI
---| "RQ-1A Predator" # MQ-1A Predator
---| "MQ-9 Reaper"
---| "P-47D-30"
---| "P-47D-30bl1" # P-47D-30 (Early)
---| "P-47D-40"
---| "P-51D" # P-51D-25-NA
---| "P-51D-30-NA"
---| "QF-4E"
---| "S-3B"
---| "S-3B Tanker"
---| "SpitfireLFMkIX" # Spitfire LF Mk. IX
---| "SpitfireLFMkIXCW" # Spitfire LF Mk. IX CW
---| "Su-17M4"
---| "Su-24M"
---| "Su-24MR"
---| "Su-25"
---| "Su-25T"
---| "Su-25TM"
---| "Su-27"
---| "Su-30"
---| "Su-33"
---| "Su-34"
---| "TF-51D"
---| "Tornado GR4"
---| "Tornado IDS"
---| "Tu-142"
---| "Tu-160"
---| "Tu-22M3"
---| "Tu-95MS" # Tu-95MS [CH]
---| "WingLoong-I"
---| "Yak-40"
---| "Yak-52"

--- Helicopter unit types. Keyed by display name.
---@alias DcsId.HelicopterType
---| "AH-1W"
---| "AH-64A"
---| "AH-64D"
---| "AH-64D_BLK_II" # AH-64D BLK.II
---| "CH-47D"
---| "CH-47Fbl1" # CH-47F
---| "CH-53E"
---| "CHAP_TigerUHT" # EC-665 Tiger UHT [CH]
---| "Ka-27"
---| "Ka-50"
---| "Ka-50_3" # Ka-50 III
---| "Mi-24P"
---| "Mi-24V"
---| "Mi-26"
---| "Mi-28N" # Mi-28N [CH]
---| "Mi-8MT" # Mi-8MTV2
---| "OH-58D"
---| "OH58D" # OH-58D(R)
---| "SA342L"
---| "SA342M"
---| "SA342Minigun"
---| "SA342Mistral"
---| "SH-3W"
---| "SH-60B"
---| "UH-1H"
---| "UH-60A"

--- Ground unit types. Keyed by display name.
---@alias DcsId.GroundUnitType
---| "Type_94_25mm_AA_Truck" # AAA 25mm x 2 Type 94 Truck
---| "Type_96_25mm_AA" # AAA 25mm x 2 Type 96
---| "Type_88_75mm_AA" # AAA 75mm Type 88 Flak
---| "flak18" # AAA 8,8cm Flak 18
---| "flak36" # AAA 8,8cm Flak 36
---| "flak37" # AAA 8,8cm Flak 37
---| "flak41" # AAA 8,8cm Flak 41
---| "Type_3_80mm_AA" # AAA 80mm Type 3 Flak
---| "bofors40" # AAA Bofors 40mm
---| "SON_9" # AAA Fire Can SON-9
---| "flak30" # AAA Flak 38 20mm
---| "flak38" # AAA Flak-Vierling 38 Quad 20mm
---| "KDO_Mod40" # AAA Kdo.G.40
---| "KS-19" # AAA KS-19 100mm
---| "M1_37mm" # AAA M1 37mm
---| "M45_Quadmount" # AAA M45 Quadmount HB 12.7mm
---| "QF_37_AA" # AAA QF 3.7"
---| "S-60_Type59_Artillery" # AAA S-60 57mm
---| "ZU-23 Emplacement Closed" # AAA ZU-23 Closed Emplacement
---| "ZU-23 Emplacement" # AAA ZU-23 Emplacement
---| "ZU-23 Closed Insurgent" # AAA ZU-23 Insurgent Closed Emplacement
---| "ZU-23 Insurgent" # AAA ZU-23 Insurgent Emplacement
---| "Ural-375 ZU-23" # AAA ZU-23 on Ural-4320
---| "Ural-375 ZU-23 Insurgent" # AAA ZU-23 on Ural-4320 Insurgent
---| "Allies_Director" # Allies Rangefinder (DRT)
---| "M30_CC" # Ammo M30 Cargo Carrier
---| "AAV7" # APC AAV-7 Amphibious
---| "BTR-60" # APC BTR-60
---| "BTR-70" # APC BTR-70
---| "BTR-80" # APC BTR-80
---| "BTR_D" # APC BTR-RD
---| "M-113" # APC M113
---| "M2A1_halftrack" # APC M2A1 Halftrack
---| "CHAP_MATV" # APC MRAP M-ATV [CH]
---| "MaxxPro_MRAP" # APC MRAP MaxxPro
---| "MTLB" # APC MTLB
---| "Sd_Kfz_251" # APC Sd.Kfz.251 Halftrack
---| "TPZ" # APC TPz Fuchs 
---| "Type_98_So_Da" # APC Type 98 So Da
---| "Silkworm_SR" # AShM Silkworm SR
---| "hy_launcher" # AShM SS-N-2 Silkworm
---| "BRDM-2_malyutka" # ATGM AT-3 Sagger 9P133
---| "M1045 HMMWV TOW" # ATGM HMMWV
---| "M1134 Stryker ATGM" # ATGM Stryker
---| "VAB_Mephisto" # ATGM VAB Mephisto
---| "house1arm" # Barracks armed
---| "TACAN_beacon" # Beacon TACAN Portable TTS 3030
---| "houseA_arm" # Building armed
---| "Sandbox" # Bunker 1
---| "Bunker" # Bunker 2
---| "fire_control" # Bunker with Fire Control Center
---| "IKARUS Bus" # Bus IKARUS-280
---| "LAZ Bus" # Bus LAZ-695
---| "LiAZ Bus" # Bus LiAZ-677
---| "Daimler_AC" # Car Daimler Armored
---| "VAZ Car" # Car VAZ-2109
---| "Willys_MB" # Car Willys Jeep
---| "generator_5i57" # Diesel Power Station 5I57A
---| "DR_50Ton_Flat_Wagon" # DR 50-ton flat wagon
---| "1L13 EWR" # EWR 1L13
---| "55G6 EWR" # EWR 55G6
---| "FPS-117 ECS" # EWR AN/FPS-117 ECS
---| "FPS-117" # EWR AN/FPS-117 Radar
---| "FPS-117 Dome" # EWR AN/FPS-117 Radar (domed)
---| "FuMG-401" # EWR FuMG-401 Freya LZ
---| "FuSe-65" # EWR FuSe-65 Würzburg-Riese
---| "LeFH_18-40-105" # FH LeFH-18 105mm
---| "M2A1-105" # FH M2A1 105mm
---| "Pak40" # FH Pak 40 75mm
---| "HEMTT TFFT" # Firefighter HEMMT TFFT
---| "tacr2a" # Firefighter RAF Rescue
---| "Ural ATsP-6" # Firefighter Ural ATsP-6
---| "AA8" # Firefighter Vehicle AA-7.2/60
---| "GCI_station_MiG29" # GCI station (KRU)
---| "GD-20" # GD-20 Lift Truck
---| "Ural-4320 APA-5D" # GPU APA-5D on Ural 4320
---| "ZiL-131 APA-80" # GPU APA-80 on ZIL-131
---| "Grad_FDDM" # Grad MRL FDDM (FC)
---| "SK_C_28_naval_gun" # Gun 15cm SK C/28 Naval in Bunker
---| "HQ-7_LN_P" # HQ-7 SHORAD TELAR (Player)
---| "HQ-7_STR_SP" # HQ-7B SHORAD SR
---| "HQ-7_LN_SP" # HQ-7B SHORAD TELAR
---| "BMD-1" # IFV BMD-1
---| "BMP-1" # IFV BMP-1
---| "BMP-2" # IFV BMP-2
---| "BMP-3" # IFV BMP-3 [CH]
---| "CHAP_BMP3_ERA" # IFV BMP-3 ERA [CH]
---| "CHAP_BMPT" # IFV BMPT Terminator [CH]
---| "BTR-82A" # IFV BTR-82A
---| "LAV-25" # IFV LAV-25
---| "M1126 Stryker ICV" # IFV M1126 Stryker ICV
---| "CHAP_M1130" # IFV M1130 Stryker CV [CH]
---| "CHAP_M1296" # IFV M1296 Dragoon [CH]
---| "M-2 Bradley" # IFV M2A2 Bradley
---| "Marder" # IFV Marder
---| "MCV-80" # IFV Warrior 
---| "Soldier AK" # Infantry AK-74
---| "Infantry AK" # Infantry AK-74 Rus ver1
---| "Infantry AK ver2" # Infantry AK-74 Rus ver2
---| "Infantry AK ver3" # Infantry AK-74 Rus ver3
---| "soldier_wwii_us" # Infantry M1 Garand
---| "Soldier M249" # Infantry M249
---| "Soldier M4" # Infantry M4
---| "Soldier M4 GRG" # Infantry M4 Georgia
---| "soldier_mauser98" # Infantry Mauser 98
---| "Soldier RPG" # Infantry RPG
---| "soldier_wwii_br_01" # Infantry SMLE No.4 Mk-1
---| "Infantry AK Ins" # Insurgent AKM
---| "JTAC"
---| "L118_Unit" # L118 Light Artillery Gun
---| "HEMTT_C-RAM_Phalanx" # LPWS C-RAM
---| "CHAP_FV101" # LT FV101 Scorpion [CH]
---| "PT_76" # LT PT-76
---| "Hummer" # LUV HMMWV Jeep
---| "Horch_901_typ_40_kfz_21" # LUV Horch 901 Staff Car
---| "Sd_Kfz_2" # LUV Kettenrad
---| "Kubelwagen_82" # LUV Kubelwagen Jeep
---| "Land_Rover_109_S3" # LUV Land Rover 109
---| "Tigr_233036" # LUV Tigr
---| "UAZ-469" # LUV UAZ-469 Jeep
---| "B600_drivable" # M92 B600 drivable
---| "MJ-1_drivable" # M92 MJ-1 drivable
---| "P20_drivable" # M92 P20 drivable
---| "r11_volvo_drivable" # M92 R11 Volvo drivable
---| "TugHarlan_drivable" # M92 Tug Harlan drivable
---| "SA-18 Igla manpad" # MANPADS SA-18 Igla "Grouse"
---| "SA-18 Igla comm" # MANPADS SA-18 Igla "Grouse" C2
---| "Igla manpad INS" # MANPADS SA-18 Igla "Grouse" Ins
---| "SA-18 Igla-S manpad" # MANPADS SA-18 Igla-S "Grouse"
---| "SA-18 Igla-S comm" # MANPADS SA-18 Igla-S "Grouse" C2
---| "Soldier stinger" # MANPADS Stinger
---| "Stinger comm" # MANPADS Stinger C2
---| "Stinger comm dsr" # MANPADS Stinger C2 Desert
---| "Maschinensatz_33" # Maschinensatz 33 Gen
---| "Challenger2" # MBT Challenger II
---| "Chieftain_mk3" # MBT Chieftain Mk.3
---| "Leclerc" # MBT Leclerc
---| "Leopard1A3" # MBT Leopard 1A3
---| "leopard-2A4" # MBT Leopard-2A4
---| "leopard-2A4_trs" # MBT Leopard-2A4 Trs
---| "Leopard-2A5" # MBT Leopard-2A5
---| "Leopard-2" # MBT Leopard-2A6M
---| "M-1 Abrams" # MBT M1A2 Abrams
---| "M1A2C_SEP_V3" # MBT M1A2C SEP v3 Abrams
---| "M-60" # MBT M60A3 Patton
---| "Merkava_Mk4" # MBT Merkava IV
---| "T-55" # MBT T-55
---| "T62M" # MBT T-62M
---| "CHAP_T64BV" # MBT T-64BV Type 2017 [CH]
---| "T-72B" # MBT T-72B
---| "T-72B3" # MBT T-72B3
---| "T-80B" # MBT T-80B
---| "T-80UD" # MBT T-80U
---| "CHAP_T84OplotM" # MBT T-84 Oplot-M [CH]
---| "T-90" # MBT T-90A [CH]
---| "CHAP_T90M" # MBT T-90M [CH]
---| "Predator GCS" # MCC Predator UAV CP & GCS
---| "Predator TrojanSpirit" # MCC-COMM Predator UAV CL
---| "Dog Ear radar" # MCC-SR Sborka "Dog Ear" SR
---| "Smerch" # MLRS 9A52 Smerch CM 300mm
---| "Smerch_HE" # MLRS 9A52 Smerch HE 300mm
---| "Uragan_BM-27" # MLRS 9K57 Uragan BM-27 220mm
---| "Grad-URAL" # MLRS BM-21 Grad 122mm
---| "HL_B8M1" # MLRS HL with B8M1 80mm
---| "tt_B8M1" # MLRS LC with B8M1 80mm
---| "CHAP_M142_ATACMS_M39A1" # MLRS M142 HIMARS ATACMS CM [CH]
---| "CHAP_M142_ATACMS_M48" # MLRS M142 HIMARS ATACMS HE [CH]
---| "CHAP_M142_GMLRS_M30" # MLRS M142 HIMARS GMLRS CM [CH]
---| "CHAP_M142_GMLRS_M31" # MLRS M142 HIMARS GMLRS HE [CH]
---| "MLRS" # MLRS M270 227mm
---| "CHAP_TOS1A" # MLRS TOS-1A Solntsepyok [CH]
---| "2B11 mortar" # Mortar 2B11 120mm
---| "CHAP_Titan" # MRAP ZA-SpN Titan [CH]
---| "MLRS FDDM" # MRLS FDDM (FC)
---| "TYPE-59" # MT Type 59
---| "outpost" # Outpost
---| "Paratrooper AKS-74" # Paratrooper AKS
---| "Paratrooper RPG-16"
---| "PL5EII Loadout" # Payload PL-5EII
---| "PL8 Loadout" # Payload PL-8
---| "SD10 Loadout" # Payload SD-10
---| "PLZ05" # PLZ-05
---| "prmg_gp_beacon" # PRMG Glidepath car
---| "prmg_loc_beacon" # PRMG Localizer car
---| "GPS_Spoofer_Blue"
---| "GPS_Spoofer_Red"
---| "ATMZ-5" # Refueler ATMZ-5
---| "ATZ-10" # Refueler ATZ-10
---| "ATZ-5" # Refueler ATZ-5
---| "ural_atz5_civil" # Refueler ATZ-5 civil
---| "ATZ-60_TANK" # Refueler ATZ-60 Tank
---| "ATZ-60_Maz" # Refueler ATZ-60 Tractor (MAZ-7410)
---| "M978 HEMTT Tanker" # Refueler M978 HEMTT
---| "TZ-22_TANK" # Refueler TZ-22 Tank
---| "TZ-22_KrAZ" # Refueler TZ-22 Tractor (KrAZ-258B1)
---| "outpost_road" # Road outpost
---| "outpost_road_r" # Road outpost-R
---| "outpost_road_l" # Road outpost_L
---| "rsbn_beacon" # RSBN car
---| "Coach a platform" # Rwy. Coach Platform
---| "Boxcartrinity" # Rwy. Flat Car
---| "Coach cargo" # Rwy. Freight Van
---| "Locomotive" # Rwy. Loco CHME3T
---| "DRG_Class_86" # Rwy. Loco DRG Class 86 (Germany, WWII)
---| "ES44AH" # Rwy. Loco ES44AH
---| "Electric locomotive" # Rwy. Loco VL80 Electric
---| "Coach cargo open" # Rwy. Open Wagon
---| "Coach a passenger" # Rwy. Passenger Car
---| "German_tank_wagon" # Rwy. Tank Car (Germany, WWII)
---| "Coach a tank blue" # Rwy. Tank Car blue
---| "Coach a tank yellow" # Rwy. Tank Car yellow
---| "Tankcartrinity" # Rwy. Tank Cartrinity
---| "German_covered_wagon_G10" # Rwy. Wagon G10 (Germany, WWII)
---| "Wellcarnsc" # Rwy. Well Car
---| "S_75_ZIL" # S-75 Tractor (ZIL-131)
---| "S_75_Zil_Trailer" # S-75 Trailer
---| "M1097 Avenger" # SAM Avenger (Stinger)
---| "M48 Chaparral" # SAM Chaparral M48
---| "Hawk cwar" # SAM Hawk CWAR AN/MPQ-55
---| "Hawk ln" # SAM Hawk LN M192
---| "Hawk pcp" # SAM Hawk Platoon Command Post (PCP)
---| "Hawk sr" # SAM Hawk SR (AN/MPQ-50)
---| "Hawk tr" # SAM Hawk TR (AN/MPQ-46)
---| "CHAP_IRISTSLM_CP" # SAM IRIS-T SLM C2 [CH]
---| "CHAP_IRISTSLM_LN" # SAM IRIS-T SLM LN [CH]
---| "CHAP_IRISTSLM_STR" # SAM IRIS-T SLM STR [CH]
---| "M6 Linebacker" # SAM Linebacker - Bradley M6
---| "NASAMS_Command_Post" # SAM NASAMS C2
---| "NASAMS_LN_B" # SAM NASAMS LN AIM-120B
---| "NASAMS_LN_C" # SAM NASAMS LN AIM-120C
---| "NASAMS_Radar_MPQ64F1" # SAM NASAMS SR MPQ64F1
---| "Patriot cp" # SAM Patriot C2 ICC
---| "Patriot AMG" # SAM Patriot CR (AMG AN/MRC-137)
---| "Patriot ECS" # SAM Patriot ECS
---| "Patriot EPP" # SAM Patriot EPP-III
---| "Patriot ln" # SAM Patriot LN
---| "Patriot str" # SAM Patriot STR
---| "rapier_fsa_blindfire_radar" # SAM Rapier Blindfire TR
---| "rapier_fsa_launcher" # SAM Rapier LN
---| "rapier_fsa_optical_tracker_unit" # SAM Rapier Tracker
---| "Roland ADS" # SAM Roland ADS
---| "Roland Radar" # SAM Roland EWR
---| "S-300PS 64H6E sr" # SAM SA-10 S-300 "Grumble" Big Bird SR
---| "S-300PS 54K6 cp" # SAM SA-10 S-300 "Grumble" C2
---| "S-300PS 40B6MD sr" # SAM SA-10 S-300 "Grumble" Clam Shell SR
---| "S-300PS 40B6M tr" # SAM SA-10 S-300 "Grumble" Flap Lid-A TR
---| "S-300PS 5H63C 30H6_tr" # SAM SA-10 S-300 "Grumble" Flap Lid-B TR
---| "S-300PS 5P85C ln" # SAM SA-10 S-300 "Grumble" TEL C
---| "S-300PS 5P85D ln" # SAM SA-10 S-300 "Grumble" TEL D
---| "S-300PS 40B6MD sr_19J6" # SAM SA-10 S-300 "Grumble" Tin Shield SR
---| "SA-11 Buk CC 9S470M1" # SAM SA-11 Buk "Gadfly" C2 
---| "SA-11 Buk LN 9A310M1" # SAM SA-11 Buk "Gadfly" Fire Dome TEL
---| "SA-11 Buk SR 9S18M1" # SAM SA-11 Buk "Gadfly" Snow Drift SR
---| "Strela-10M3" # SAM SA-13 Strela 10M3 "Gopher" TEL
---| "Tor 9A331" # SAM SA-15 Tor "Gauntlet"
---| "CHAP_TorM2" # SAM SA-15 Tor M2 "Gauntlet" [CH]
---| "2S6 Tunguska" # SAM SA-19 Tunguska "Grison" 
---| "SNR_75V" # SAM SA-2 S-75 "Fan Song" TR
---| "S_75M_Volhov" # SAM SA-2 S-75 "Guideline" LN
---| "RD_75" # SAM SA-2 S-75 RD-75 Amazonka RF
---| "p-19 s-125 sr" # SAM SA-2/3/5 P19 "Flat Face" SR 
---| "CHAP_PantsirS1" # SAM SA-22 Pantsir-S1 "Greyhound" [CH]
---| "5p73 s-125 ln" # SAM SA-3 S-125 "Goa" LN
---| "snr s-125 tr" # SAM SA-3 S-125 "Low Blow" TR
---| "S-200_Launcher" # SAM SA-5 S-200 "Gammon" LN
---| "RPC_5N62V" # SAM SA-5 S-200 "Square Pair" TR
---| "P14_SR" # SAM SA-5 S-200 P-14 'Tall king' SR
---| "RLS_19J6" # SAM SA-5 S-200 ST-68U "Tin Shield" SR
---| "Kub 2P25 ln" # SAM SA-6 Kub "Gainful" TEL
---| "Kub 1S91 str" # SAM SA-6 Kub "Straight Flush" STR
---| "Osa 9A33 ln" # SAM SA-8 Osa "Gecko" TEL
---| "Strela-1 9P31" # SAM SA-9 Strela 1 "Gaskin" TEL
---| "BRDM-2" # Scout BRDM-2
---| "Cobra" # Scout Cobra
---| "CHAP_FV107" # Scout FV107 Scimitar [CH]
---| "HL_DSHK" # Scout HL with DSHK 12.7mm
---| "HL_KORD" # Scout HL with KORD 12.7mm
---| "M1043 HMMWV Armament" # Scout HMMWV
---| "tt_DSHK" # Scout LC with DSHK 12.7mm
---| "tt_KORD" # Scout LC with KORD 12.7mm
---| "M8_Greyhound" # Scout M8 Greyhound AC
---| "Sd_Kfz_234_2_Puma" # Scout Puma AC
---| "Flakscheinwerfer_37" # SL Flakscheinwerfer 37
---| "Gepard" # SPAAA Gepard
---| "HL_ZU-23" # SPAAA HL with ZU-23
---| "tt_ZU-23" # SPAAA LC with ZU-23
---| "Vulcan" # SPAAA Vulcan M163
---| "ZSU-23-4 Shilka" # SPAAA ZSU-23-4 Shilka "Gun Dish"
---| "ZSU_57_2" # SPAAA ZSU-57-2
---| "SturmPzIV" # SPG Brummbaer AG
---| "Elefant_SdKfz_184" # SPG Elefant TD
---| "Jagdpanther_G1" # SPG Jagdpanther TD
---| "JagdPz_IV" # SPG Jagdpanzer IV TD
---| "M10_GMC" # SPG M10 GMC TD
---| "M1128 Stryker MGS" # SPG Stryker MGS
---| "Stug_III" # SPG StuG III G AG
---| "Stug_IV" # SPG StuG IV AG
---| "SAU Gvozdika" # SPH 2S1 Gvozdika 122mm
---| "SAU Msta" # SPH 2S19 Msta 152mm
---| "SAU Akatsia" # SPH 2S3 Akatsia 152mm
---| "SpGH_Dana" # SPH Dana vz77 152mm
---| "M-109" # SPH M109 Paladin 155mm
---| "M12_GMC" # SPH M12 GMC 155mm
---| "Wespe124" # SPH Sd.Kfz.124 Wespe 105mm
---| "T155_Firtina" # SPH T155 Firtina 155mm
---| "SAU 2-C9" # SPM 2S9 Nona 120mm M
---| "CHAP_9K720_Cluster" # SRBM 9K720 Iskander CM [CH]
---| "CHAP_9K720_HE" # SRBM 9K720 Iskander HE [CH]
---| "Scud_B" # SSM SS-1C Scud-B
---| "Suidae"
---| "Centaur_IV" # Tk Centaur IV CS
---| "Churchill_VII" # Tk Churchill VII
---| "Cromwell_IV" # Tk Cromwell IV
---| "M4_Sherman" # Tk M4 Sherman
---| "M4A4_Sherman_FF" # Tk M4A4 Sherman Firefly
---| "Pz_V_Panther_G" # Tk Panther G (Pz V)
---| "Pz_IV_H" # Tk PzIV H
---| "T-34-85" # Tk T-34-85
---| "Tetrarch" # Tk Tetrach
---| "Tiger_I" # Tk Tiger 1
---| "Tiger_II_H" # Tk Tiger II
---| "Type_89_I_Go" # Tk Type 89 I Go
---| "Type_98_Ke_Ni" # Tk Type 98 Ke Ni
---| "CHAP_HX81_Tractor" # Tractor HX81 [CH]
---| "M4_Tractor" # Tractor M4 High Speed
---| "Sd_Kfz_7" # Tractor Sd.Kfz.7 Art'y Tractor
---| "CHAP_SLT50_Tractor" # Tractor SLT-50 [CH]
---| "CHAP_SLT50_Trailer" # Trailer SLT-50 [CH]
---| "Train" # Train_loc
---| "Bedford_MWD" # Truck Bedford
---| "GAZ-3307" # Truck GAZ-3307
---| "GAZ-3308" # Truck GAZ-3308
---| "GAZ-66" # Truck GAZ-66
---| "gaz-66_civil" # Truck GAZ-66 civil
---| "CCKW_353" # Truck GMC "Jimmy" 6x6
---| "CHAP_HX77" # Truck HX77 [CH]
---| "KAMAZ Truck" # Truck KAMAZ 43101
---| "kamaz_tent_civil" # Truck KAMAZ-43101 civil
---| "KrAZ6322" # Truck KrAZ-6322 6x6
---| "Land_Rover_101_FC" # Truck Land Rover 101 FC
---| "LARC-V" # Truck LARC-V
---| "CHAP_M1083" # Truck M1083 A1P2 MTV [CH]
---| "M 818" # Truck M939 Heavy
---| "MAZ-6303" # Truck MAZ-6303
---| "Blitz_36-6700A" # Truck Opel Blitz
---| "SKP-11" # Truck SKP-11 Mobile ATC
---| "Type_94_Truck" # Truck Type 94
---| "Ural-375" # Truck Ural-4320
---| "ural_4230_civil_b" # Truck Ural-4320 civil
---| "Ural-375 PBU" # Truck Ural-4320 MCC
---| "Ural-4320-31" # Truck Ural-4320-31 Arm'd
---| "Ural-4320T" # Truck Ural-4320T
---| "ural_4230_civil_t" # Truck Ural-4320T civil
---| "ZIL-131 KUNG" # Truck ZIL-131 (C2)
---| "zil-131_civil" # Truck ZiL-131 civil
---| "ZIL-135" # Truck ZIL-135
---| "ZIL-4331" # Truck ZIL-4331
---| "v1_launcher" # V-1 Launch Ramp
---| "house2arm" # Watch tower armed
---| "ZBD04A" # ZBD-04A
---| "Trolley bus" # ZIU-9 Trolley
---| "ZTZ96B" # ZTZ-96B

--- Ship unit types. Keyed by display name.
---@alias DcsId.ShipType
---| "santafe" # ARA Santa Fe S-21
---| "ara_vdm" # ARA Veinticinco de Mayo
---| "PIOTR" # Battlecruiser 1144.2 Pyotr Velikiy
---| "speedboat" # Boat Armed Hi-speed
---| "Higgins_boat" # Boat LCVP Higgins
---| "Schnellboot_type_S130" # Boat Schnellboot type S130
---| "ZWEZDNY" # Boat Zvezdny type
---| "HandyWind" # Bulker Handy Wind
---| "Dry-cargo ship-1" # Bulker Yakushev
---| "Dry-cargo ship-2" # Cargo Ivanov
---| "CastleClass_01" # Castle Class
---| "TICONDEROG" # CG Ticonderoga
---| "leander-gun-condell" # CNS Almirante Condell (PFG-06)
---| "leander-gun-lynch" # CNS Almirante Lynch (PFG-07)
---| "ALBATROS" # Corvette 1124M Grisha [CH]
---| "MOLNIYA" # Corvette 1241.1 Molniya
---| "MOSCOW" # Cruiser 1164 Moskva
---| "KUZNECOW" # CV 1143.5 Admiral Kuznetsov
---| "CV_1143_5" # CV 1143.5 Admiral Kuznetsov(2017)
---| "Forrestal" # CV-59 Forrestal
---| "VINSON" # CVN-70 Carl Vinson
---| "CVN_71" # CVN-71 Theodore Roosevelt
---| "CVN_72" # CVN-72 Abraham Lincoln
---| "CVN_73" # CVN-73 George Washington
---| "Stennis" # CVN-74 John C. Stennis
---| "CVN_75" # CVN-75 Harry S. Truman
---| "USS_Arleigh_Burke_IIa" # DDG Arleigh Burke IIa
---| "Essex" # Essex Class Carrier 1944
---| "La_Combattante_II" # FAC La Combattante IIa
---| "PERRY" # FFG Oliver Hazard Perry
---| "REZKY" # Frigate 1135M Rezky
---| "NEUSTRASH" # Frigate 11540 Neustrashimy
---| "HarborTug" # Harbor Tug
---| "leander-gun-achilles" # HMS Achilles (F12)
---| "leander-gun-andromeda" # HMS Andromeda (F57)
---| "leander-gun-ariadne" # HMS Ariadne (F72)
---| "hms_invincible" # HMS Invincible (R05)
---| "LHA_Tarawa" # LHA-1 Tarawa
---| "BDK-775" # LS Ropucha
---| "USS_Samuel_Chase" # LS Samuel Chase
---| "LST_Mk2" # LST Mk.II
---| "CHAP_Project22160" # Patrol Ship 22160 Vasily Bykov [CH]
---| "CHAP_Project22160_TorM2KM" # Patrol ship 22160 Vasily Bykov with Tor M2KM [CH]
---| "atconveyor" # SS Atlantic Conveyor
---| "IMPROVED_KILO" # SSK 636 Improved Kilo
---| "SOM" # SSK 641B Tango
---| "KILO" # SSK 877V Kilo
---| "Ship_Tilde_Supply" # Supply Ship MV Tilde
---| "ELNYA" # Tanker Elnya 160
---| "Seawise_Giant" # Tanker Seawise Giant
---| "Type_021_1" # Type 021-1 Missile Boat
---| "Type_052B" # Type 052B Destroyer
---| "Type_052C" # Type 052C Destroyer
---| "Type_054A" # Type 054A Frigate
---| "Type_071" # Type 071 Amphibious Transport Dock
---| "Type_093" # Type 093 Attack Submarine
---| "Uboat_VIIC" # U-boat VIIC U-flak

--- Static-only object types: structures, cargos, FARPs and the like. Keyed by display name.
---@alias DcsId.StructureType
---| "M92_10Ft_Container" # 10ft Container
---| "463_Pallet" # 463 Pallet
---| "Airshow_Cone" # Airshow cone
---| "Airshow_Crowd" # Airshow Crowd
---| "ammo_cargo" # Ammo
---| "M92_Ammo_Pallet" # Ammo Pallet
---| ".Ammunition depot" # Ammunition depot
---| "AS32-31A"
---| "AS32-32A"
---| "AS32-36A"
---| "AS32-p25" # AS32-P25
---| "Barracks 2"
---| "Beer Bomb" # Barrel
---| "barrels_cargo" # Barrels
---| "Belgian gate"
---| "big_smoke" # Big smoke
---| "billboard_motorized" # Billboard Motorized
---| "Boiler-house A"
---| "Bridge"
---| "Building"
---| "Cafe"
---| "cds_barrels" # CDS Barrels
---| "cds_crate" # CDS Crate
---| "Chemical tank A"
---| ".Command Center" # Command Center
---| "Comms tower M"
---| "Concertina wire"
---| "M92_Concrete_Barrier_Cargo" # Concrete Barrier
---| "container_cargo" # Container
---| "container_20ft" # Container 20ft
---| "container_40ft" # Container 40ft
---| "Container brown"
---| "Container red 1"
---| "Container red 2"
---| "Container red 3"
---| "Container white"
---| "Cow"
---| "CV_59_H60" # CV-59 Hyster 60
---| "CV_59_Large_Forklift" # CV-59 Large Forklift
---| "CV_59_MD3" # CV-59 MD-3 Mule (Early)
---| "CV_59_NS60" # CV-59 NS-60 Tilly
---| "Czech hedgehogs 1"
---| "Czech hedgehogs 2"
---| "Dragonteeth 1"
---| "Dragonteeth 2"
---| "Dragonteeth 3"
---| "Dragonteeth 4"
---| "Dragonteeth 5"
---| "Drop Zone Marker A"
---| "Drop Zone Marker B"
---| "Drop Zone Marker C"
---| "Drop Zone Marker D"
---| "Drop Zone Marker E"
---| "Electric power box"
---| "345 Excavator" # Excavator
---| "Zell" # F-100D ZELL
---| "f_bar_cargo" # F-shape barrier
---| "Farm A"
---| "Farm B"
---| "FARP"
---| "FARP Ammo Dump Coating" # FARP Ammo Storage
---| "FARP CP Blindage" # FARP Command Post
---| "FARP Fuel Depot"
---| "FarpHide_Dmed" # FARP Hide Double Med
---| "FarpHide_Dsmall" # FARP Hide Double Small
---| "FarpHide_Med" # FARP Hide Single Med
---| "FarpHide_small" # FARP Hide Single Small
---| "FARP Tent"
---| "Fire Control Bunker" # Fire control bunker
---| "FlagPole" # Flag Pole
---| "Freya_Shelter_Brick" # Freya Shelter Brick
---| "Freya_Shelter_Concrete" # Freya Shelter Concrete
---| "Fuel tank"
---| "fueltank_cargo" # Fueltank
---| "Garage A"
---| "Garage B"
---| "Garage small A"
---| "Garage small B"
---| "Gas platform"
---| "gbu_43b_airdrop" # GBU-43 MOAB
---| "GeneratorF"
---| "GrassAirfield" # Grass Airfield
---| "Hangar A"
---| "Hangar B"
---| "Haystack 1"
---| "Haystack 2"
---| "Haystack 3"
---| "Haystack 4"
---| "SINGLE_HELIPAD" # Helipad Single
---| "Hemmkurvenhindernis"
---| "af_hq" # HQ Building
---| "Invisible FARP"
---| "ip_tower" # IP Tower
---| "iso_container" # ISO container
---| "iso_container_small" # ISO container small
---| "l118" # L118 Light Artillery
---| "Landmine"
---| "Log posts 1"
---| "Log posts 2"
---| "Log posts 3"
---| "Log ramps 1"
---| "Log ramps 2"
---| "Log ramps 3"
---| "m1_vla" # M1 barrage balloon
---| "m117_cargo" # M117 bombs
---| "AM32a-60_01" # M92 AM32a-60-01
---| "AM32a-60_02" # M92 AM32a-60-02
---| "APFC fuel" # M92 APFC fuel
---| "B600" # M92 B600
---| "Barrier A" # M92 Barrier A
---| "Barrier B" # M92 Barrier B
---| "Barrier C" # M92 Barrier C
---| "Barrier D" # M92 Barrier D
---| "BoomBarrier_closed" # M92 Boom Barrier closed
---| "BoomBarrier_open" # M92 Boom Barrier open
---| "Building01_PBR" # M92 Building01 PBR
---| "Building02_PBR" # M92 Building02 PBR
---| "Building03_PBR" # M92 Building03 PBR
---| "Building04_PBR" # M92 Building04 PBR
---| "Building05_PBR" # M92 Building05 PBR
---| "Building06_PBR" # M92 Building06 PBR
---| "Building07_PBR" # M92 Building07 PBR
---| "Building08_PBR" # M92 Building08 PBR
---| "Camouflage01" # M92 Camouflage 01
---| "Camouflage02" # M92 Camouflage 02
---| "Camouflage03" # M92 Camouflage 03
---| "Camouflage04" # M92 Camouflage 04
---| "Camouflage05" # M92 Camouflage 05
---| "Camouflage06" # M92 Camouflage 06
---| "Camouflage07" # M92 Camouflage 07
---| "Cargo01" # M92 Cargo 01
---| "Cargo02" # M92 Cargo 02
---| "Cargo03" # M92 Cargo 03
---| "Cargo04" # M92 Cargo 04
---| "Cargo05" # M92 Cargo 05
---| "Cargo06" # M92 Cargo 06
---| "Cone01" # M92 Cone 01
---| "Cone02" # M92 Cone 02
---| "Container_10ft" # M92 Container 10ft
---| "Container_20ft" # M92 Container 20ft
---| "Container_40ft" # M92 Container 40ft
---| "Container_generator" # M92 Container generator
---| "Container_office" # M92 Container office
---| "Container_watchtower" # M92 Container watchtower
---| "Container_watchtower_lights" # M92 Container watchtower lights
---| "ElevatedPlatform_down" # M92 Elevated Platform down
---| "ElevatedPlatform_up" # M92 Elevated Platform up
---| "FireExtinguisher01" # M92 Fire Extinguisher 01
---| "FireExtinguisher02" # M92 Fire Extinguisher 02
---| "FireExtinguisher03" # M92 Fire Extinguisher 03
---| "HESCO_generator" # M92 HESCO generator
---| "HESCO_post_1" # M92 HESCO post 1
---| "HESCO_wallperimeter_1" # M92 HESCO wallperimeter 1
---| "HESCO_wallperimeter_2" # M92 HESCO wallperimeter 2
---| "HESCO_wallperimeter_3" # M92 HESCO wallperimeter 3
---| "HESCO_wallperimeter_4" # M92 HESCO wallperimeter 4
---| "HESCO_wallperimeter_5" # M92 HESCO wallperimeter 5
---| "HESCO_watchtower_1" # M92 HESCO watchtower 1
---| "HESCO_watchtower_2" # M92 HESCO watchtower 2
---| "HESCO_watchtower_3" # M92 HESCO watchtower 3
---| "Jerrycan" # M92 Jerrycan
---| "Ladder" # M92 Ladder
---| "LHD_LHA" # M92 LHD LHA
---| "M32-10C_01" # M92 M32-10C 01
---| "M32-10C_02" # M92 M32-10C 02
---| "M32-10C_03" # M92 M32-10C 03
---| "M32-10C_04" # M92 M32-10C 04
---| "MJ-1_01" # M92 MJ-1 01
---| "MJ-1_02" # M92 MJ-1 02
---| "NF-2_LightOff01" # M92 NF-2 LightOff 01
---| "NF-2_LightOff02" # M92 NF-2 LightOff 02
---| "NF-2_LightOn" # M92 NF-2 LightOn
---| "Oil Barrel" # M92 Oil barrel
---| "P20_01" # M92 P20 01
---| "Pile of Woods" # M92 Pile of woods
---| "r11_volvo" # M92 R11 Volvo
---| "Revetment_x4" # M92 Revetment x4
---| "Revetment_x8" # M92 Revetment x8
---| "Sandbag_01" # M92 Sandbag 01
---| "Sandbag_02" # M92 Sandbag 02
---| "Sandbag_03" # M92 Sandbag 03
---| "Sandbag_04" # M92 Sandbag 04
---| "Sandbag_05" # M92 Sandbag 05
---| "Sandbag_06" # M92 Sandbag 06
---| "Sandbag_07" # M92 Sandbag 07
---| "Sandbag_08" # M92 Sandbag 08
---| "Sandbag_09" # M92 Sandbag 09
---| "Sandbag_10" # M92 Sandbag 10
---| "Sandbag_11" # M92 Sandbag 11
---| "Sandbag_12" # M92 Sandbag 12
---| "Sandbag_13" # M92 Sandbag 13
---| "Sandbag_15" # M92 Sandbag 15
---| "Sandbag_16" # M92 Sandbag 16
---| "Sandbag_17" # M92 Sandbag 17
---| "Shelter01" # M92 Shelter 01
---| "Shelter02" # M92 Shelter 02
---| "Tent01" # M92 Tent 01
---| "Tent02" # M92 Tent 02
---| "Tent03" # M92 Tent 03
---| "Tent04" # M92 Tent 04
---| "Tent05" # M92 Tent 05
---| "Toolbox01" # M92 Toolbox 01
---| "Toolbox02" # M92 Toolbox 02
---| "TugHarlan" # M92 Tug Harlan
---| "Twall_x1" # M92 Twall x1
---| "Twall_x6" # M92 Twall x6
---| "Twall_x6_3mts" # M92 Twall x6 3mts
---| "Red_Flag" # Mark Flag Red
---| "White_Flag" # Mark Flag White
---| "Black_Tyre" # Mark Tyre Black
---| "White_Tyre" # Mark Tyre White
---| "Black_Tyre_RF" # Mark Tyre with Red Flag
---| "Black_Tyre_WF" # Mark Tyre with White Flag
---| "Military staff"
---| "M92_MRE_Pallet" # MRE Pallet
---| "Nodding_Donkey_Pump" # Nodding Donkey Pump
---| "offshore WindTurbine" # Offshore Wind Turbine
---| "offshore WindTurbine2" # Offshore Wind Turbine 2
---| "Oil derrick"
---| "Oil platform"
---| "Oil rig"
---| "oiltank_cargo" # Oiltank
---| "Orca" # Orca Whale
---| "FARP_SINGLE_01" # PAD Single
---| "pipes_big_cargo" # Pipes big
---| "pipes_small_cargo" # Pipes small
---| "Pump station"
---| "Railway crossing A"
---| "Railway crossing B"
---| "Railway station"
---| "Repair workshop"
---| "Restaurant 1"
---| "Shelter"
---| "Shelter B"
---| "Shop"
---| "Siegfried Line" # Siegfried line
---| "Ski Ramp" # Skiramp
---| "SA Ski Ramp" # Skiramp02
---| "Small house 1A"
---| "Small house 1A area"
---| "Small house 1B"
---| "Small house 1B area"
---| "Small house 1C area"
---| "Small house 2C"
---| "Small werehouse 1" # Small warehouse 1
---| "Small werehouse 2" # Small warehouse 2
---| "Small werehouse 3" # Small warehouse 3
---| "Small werehouse 4" # Small warehouse 4
---| "Small_LightHouse"
---| "Stanley_LightHouse" # Stanley LightHouse
---| "Subsidiary structure 1"
---| "Subsidiary structure 2"
---| "Subsidiary structure 3"
---| "Subsidiary structure A"
---| "Subsidiary structure B"
---| "Subsidiary structure C"
---| "Subsidiary structure D"
---| "Subsidiary structure E"
---| "Subsidiary structure F"
---| "Subsidiary structure G"
---| "Supermarket A"
---| "Tank" # Tank 1
---| "Tank 2"
---| "Tank 3"
---| "Tech combine"
---| "Tech hangar A"
---| "Tetrahydra"
---| "tetrapod_cargo" # Tetrapod
---| "Tower Crane" # TowerCrane
---| "Train"
---| "Transport"
---| "trunks_long_cargo" # Trunks long
---| "trunks_small_cargo" # Trunks short
---| "TV tower"
---| "uh1h_cargo" # UH-1H cargo
---| "Warehouse"
---| "warning_board_b" # Warning Board: Catch Spy!
---| "warning_board_a" # Warning Board: Spy Cannot Escape!
---| "Water tower A"
---| "WC"
---| "WindTurbine" # Wind Turbine
---| "WindTurbine_11" # Wind Turbine 2
---| "Windsock"
---| "Workshop A"
---| "wp_marker" # WP Marker

--- Static-only personnel types (deck crew and the like). Keyed by display name.
---@alias DcsId.PersonnelType
---| "Carrier Airboss"
---| "Carrier LSO Personell" # Carrier LSO 1
---| "Carrier LSO Personell 1" # Carrier LSO 2
---| "Carrier LSO Personell 2" # Carrier LSO 3
---| "Carrier LSO Personell 3" # Carrier LSO 4
---| "Carrier LSO Personell 4" # Carrier LSO 5
---| "Carrier LSO Personell 5" # Carrier LSO 6
---| "Carrier Seaman"
---| "us carrier shooter" # Carrier Shooter
---| "us carrier tech" # Carrier Technician

--- Weapon and gun shell types (`Weapon:getTypeName()`). Keyed by display name.
---@alias DcsId.WeaponType
---| "BEER_BOMB" # "Beer Bomb"
---| "Br303"
---| "Br303_tr"
---| "PJ87_100_PFHE" # 100 mm PFHE
---| "AK100_100" # 100mm HE
---| "M20_50_aero_APIT"
---| "M2_12_7"
---| "M2_12_7_T"
---| "M2_50_aero_AP"
---| "Utes_12_7x108"
---| "Utes_12_7x108_T"
---| "YakB_12_7"
---| "YakB_12_7_T"
---| "120_EXPL_F1_120mm_HE" # 120 EXPL F1 (120mm HE)
---| "ZTZ_125_AP" # 125mm AP
---| "ZTZ_125_HE" # 125mm HE
---| "MK45_127" # 127mm HE
---| "A222_130" # 130mm HE
---| "MG_13x64_API" # 13mm API
---| "MG_13x64_APT" # 13mm APT
---| "KPVT_14_5_T" # 14.5mm AP
---| "DANA_152" # 152-EOF (152mm HE)
---| "PLZ_155_HE" # 155mm HE
---| "RM_15cm_HE" # 15cm HE
---| "M61_20_AP"
---| "M61_20_AP_gr"
---| "F100_M39_20_API"
---| "M39_20_API"
---| "MG_20x82_API"
---| "M197_20"
---| "M61_20_HE"
---| "M61_20_HE_gr"
---| "F100_M39_20_HEI"
---| "M39_20_HEI"
---| "F100_M39_20_HEI_T"
---| "M39_20_HEI_T"
---| "MG_20x82_HEI_T"
---| "MG_20x82_MGsch" # 20mm MGsch
---| "M61_20_HEIT_RED" # 20mm red tracer
---| "F100_M39_20_TP"
---| "M39_20_TP"
---| "F100_M39_20_TP_T"
---| "M39_20_TP_T"
---| "M53_APT_RED" # 20mm tracer
---| "20x138B_AP"
---| "20x138B_HE"
---| "20x99R_AP"
---| "20x99R_HE_T"
---| "2A7_23_AP"
---| "GSH23_23_AP"
---| "NR23_23x115_API" # 23mm API
---| "2A7_23_HE"
---| "GSH23_23_HE"
---| "GSH23_23_HE_T"
---| "NR23_23x115_HEI_T" # 23mm HEI T
---| "British_GP_250LB_Bomb_Mk1" # 250 lb GP Mk.I
---| "British_GP_250LB_Bomb_Mk4" # 250 lb GP Mk.IV
---| "British_GP_250LB_Bomb_Mk5" # 250 lb GP Mk.V
---| "British_MC_250LB_Bomb_Mk1" # 250 lb MC Mk.I
---| "British_MC_250LB_Bomb_Mk2" # 250 lb MC Mk.II
---| "British_SAP_250LB_Bomb_Mk5" # 250 lb S.A.P.
---| "250-2" # 250-2 - 250kg GP Bombs HD
---| "250-3" # 250-3 - 250kg GP Bombs LD
---| "25mm_AA_JAP" # 25mm AA JAP
---| "BK_27" # 27mm HE
---| "2A38_30_AP"
---| "AK630_30_AP"
---| "GAU8_30_AP"
---| "GSH301_30_AP"
---| "HP30_30_AP"
---| "2A38_30_HE"
---| "AK630_30_HE"
---| "DEFA552_30"
---| "DEFA554_30_HE"
---| "GAU8_30_HE"
---| "GSH301_30_HE"
---| "M230_30"
---| "VOG17"
---| "DEFA554_30_HE_TRACERS" # 30mm HE tracers
---| "MK_108_HEI" # 30mm HEI
---| "MK_108_MGsch" # 30mm MGsch
---| "MK_108_MGsch_T" # 30mm MGsch T
---| "GAU8_30_TP" # 30mm TP
---| "KDA_35_HE" # 35mm HE
---| "M1_37mm_37AP-T" # 37mm APC-T
---| "N37_37x155_API_T" # 37mm API T 
---| "N37_37x155_HEI_T" # 37mm HEI T
---| "37mm_Type_100_JAP" # 37mm T100 JAP
---| "M1_37mm_HE-T" # 37mm_HE-T
---| "M51_37AP" # 37x223 APCBC-T
---| "M63_37HE" # 37x223 HE
---| "37x263_AP"
---| "37x263_HE"
---| "2A20_115mm_AP" # 3BM3
---| "2A46M_125_AP" # 3BM42 (125mm APFSDS-T)
---| "3BM59_125_AP" # 3BM59 (125mm APFSDS-T)
---| "SA3M9M" # 3M9M Kub (SA-6 Gainful)
---| "2A20_115mm_HE" # 3OF11
---| "2A46M_125_HE" # 3OF26 (125mm HE)
---| "2A64_152" # 3OF45 (152mm HE)
---| "2A60_120" # 3OF49 (120mm HE)
---| "2A18_122" # 3OF56 (122mm HE)
---| "3UBM11_100mm_AP" # 3UBM11 (100mm APFSDS-T)
---| "2A42_30_AP" # 3UBR6 (30mm APBC-T)
---| "UOF_17_100HE" # 3UOF17 (100mm HE)
---| "2A42_30_HE" # 3UOF8 (30mm HE-T)
---| "M8rocket" # 4.5-Inch M8
---| "AP_T_MkI_40mm" # 40x304 Mk I (40mm APCBC-T)
---| "HE_T_MkII_40mm" # 40x304 Mk II (40mmHE-T)
---| "SA48H6E2" # 48N6 S-300F (SA-N-6 Grumble)
---| "5_45x39" # 5.45mm
---| "5_56x45" # 5.56mm
---| "British_GP_500LB_Bomb_Mk1" # 500 lb GP Mk.I
---| "British_GP_500LB_Bomb_Mk4" # 500 lb GP Mk.IV
---| "British_GP_500LB_Bomb_Mk5" # 500 lb GP Mk.V
---| "British_GP_500LB_Bomb_Mk4_Short" # 500 lb GP Short tail
---| "British_MC_500LB_Bomb_Mk2" # 500 lb MC Mk.II
---| "British_MC_500LB_Bomb_Mk1_Short" # 500 lb MC Short tail
---| "British_SAP_500LB_Bomb_Mk5" # 500 lb S.A.P.
---| "50Browning_AP_M2"
---| "50Browning_AP_M2_Corsair"
---| "50Browning_API_M8"
---| "50Browning_API_M8_Corsair"
---| "50Browning_APIT_M20"
---| "50Browning_APIT_M20_Corsair"
---| "50Browning_Ball_M2"
---| "50Browning_Ball_M2_Corsair"
---| "50Browning_I_M1"
---| "50Browning_T_M1"
---| "2A33_152" # 53OF540 (152mm HE)
---| "SA57E6" # 57E6 Pantsir
---| "57mm_Type_90_JAP" # 57mm T90 JAP
---| "5_45x39_NOtr"
---| "5_56x45_NOtr"
---| "SA5B27" # 5V27 S-125 Neva (SA-3 Goa)
---| "SA5V28" # 5V28 (SA-5 Gammon)
---| "SA5B55" # 5V55 S-300PS (SA-10B Grumble)
---| "6_5mm_Type_91_JAP" # 6_5mm T91 JAP
---| "7_62x51"
---| "7_62x51tr"
---| "7_62x54"
---| "7_62x54_NOTRACER"
---| "M134_7_62_T"
---| "PKT_7_62"
---| "PKT_7_62_T"
---| "British303_Ball_Mk1c"
---| "British303_Ball_Mk6"
---| "British303_Ball_Mk7"
---| "British303_Ball_Mk8"
---| "British303_W_Mk1z" # 7.7mm AP
---| "British303_B_Mk4z"
---| "British303_B_Mk6z"
---| "British303_O_Mk1" # 7.7mm O
---| "British303_G_Mk1"
---| "British303_G_Mk2"
---| "British303_G_Mk3"
---| "British303_G_Mk4"
---| "British303_G_Mk5"
---| "British303_G_Mk6z"
---| "7_92x57_Smkl" # 7.92x57 S.m.K.L'Spur
---| "7_92x57sS" # 7.92x57 s.S
---| "75mm_AA_JAP" # 75mm AA JAP
---| "CHAP_76_HE_T" # 76 mm HE-T
---| "CHAP_76_HESH_T" # 76 mm HESH-T
---| "CHAP_76_PFHE" # 76 mm PFHE
---| "76mm_AA_JAP" # 76mm AA JAP
---| "AK176_76"
---| "MK75_76"
---| "PJ26_76_PFHE" # 76mm PFHE
---| "7_7mm_Type_97_JAP" # 7_7mm T97 JAP
---| "Flak41_Sprgr_39" # 8.8-cm Sprgr.Flak 41
---| "Rkt_90-1_HE" # 90-1 90mm Rocket (HE)
---| "AT_6" # 9M114 Shturm (AT-6 Spiral)
---| "Ataka_9M120" # 9M120 Ataka (AT-9 Spiral-2)
---| "Ataka_9M120F" # 9M120F Ataka (AT-9 Spiral-2)
---| "Vikhr_M" # 9M127 Vikhr
---| "Ataka_9M220" # 9M220O Ataka (AT-9 Spiral-2)
---| "GRAD_9M22U" # 9M22U (122mm HE)
---| "URAGAN_9M27F" # 9M27F (220mm HE)
---| "SA9M31" # 9M31 Strela-1 (SA-9 Gaskin)
---| "SA9M311" # 9M311 Tunguska (SA-19 Grison)
---| "9M317"
---| "SA9M33" # 9M33 Osa (SA-8 Gecko)
---| "SA9M330" # 9M330 Tor (SA-15 Gauntlet)
---| "SA9M333" # 9M333 Strela-10 (SA-13 Gopher)
---| "SA9M338K" # 9M338K (SA-15B Gauntlet)
---| "SA9M38M1" # 9M38M1 Buk-M1 (SA-11 Gadfly)
---| "Igla_1E" # 9M39 Igla
---| "SMERCH_9M55F" # 9M55F (300mm HE)
---| "SMERCH_9M55K" # 9M55K (300mm CM-AP)
---| "9M723"
---| "9M723_HE" # 9M723 HE
---| "9x19_m882"
---| "AB_250_2_SD_10A" # AB 250-2 SD-10A
---| "AB_250_2_SD_2" # AB 250-2 SD-2
---| "AB_500_1_SD_10A" # AB 500-1 SD-10A
---| "ADM_141A" # ADM-141A
---| "ADM_141B" # ADM-141B
---| "AGM_114K" # AGM-114K
---| "AGM_114" # AGM-114L
---| "AGM_119" # AGM-119B Penguin
---| "AGM_122" # AGM-122A Sidearm
---| "AGM_12A" # AGM-12A
---| "AGM_12B" # AGM-12B
---| "AGM_12C_ED" # AGM-12C Bullpup
---| "AGM_130" # AGM-130C-9
---| "AGM_154A" # AGM-154A
---| "AGM_154B" # AGM-154B
---| "AGM_154" # AGM-154C
---| "AGM_45A" # AGM-45A Shrike ARM
---| "AGM_45B" # AGM-45B Shrike ARM
---| "AGM_62_I" # AGM-62 Walleye I
---| "AGM_62" # AGM-62 Walleye II
---| "AGM_65A" # AGM-65A
---| "AGM_65B" # AGM-65B
---| "AGM_65D" # AGM-65D
---| "AGM_65E" # AGM-65E
---| "AGM_65F" # AGM-65F
---| "AGM_65G" # AGM-65G
---| "AGM_65H" # AGM-65H
---| "AGM_65K" # AGM-65K
---| "AGM_65L" # AGM-65L
---| "AGM_78A" # AGM-78A Standard ARM
---| "AGM_78B" # AGM-78B Standard ARM
---| "AGM_84A" # AGM-84A Harpoon
---| "AGM_84D" # AGM-84D
---| "AGM_84E" # AGM-84E
---| "AGM_84H" # AGM-84H
---| "AGM_86C" # AGM-86C
---| "AGM_86" # AGM-86D
---| "AGM_88" # AGM-88C
---| "AIM_120" # AIM-120B
---| "AIM_120C" # AIM-120C
---| "AIM_54A_Mk47" # AIM-54A-Mk47
---| "AIM_54A_Mk60" # AIM-54A-Mk60
---| "AIM_54" # AIM-54C
---| "AIM_54C_Mk47" # AIM-54C-Mk47
---| "AIM_54C_Mk60" # AIM-54C-Mk60
---| "AIM-7E"
---| "HB-AIM-7E"
---| "AIM-7E-2"
---| "HB-AIM-7E-2"
---| "AIM-7F"
---| "AIM_7" # AIM-7M
---| "AIM-7MH"
---| "AIM-7P"
---| "GAR-8" # AIM-9B
---| "AIM-9E"
---| "AIM-9J"
---| "AIM-9JULI"
---| "AIM-9L"
---| "AIM_9" # AIM-9M
---| "AIM-9P"
---| "AIM-9P3"
---| "AIM-9P5"
---| "AIM_9X" # AIM-9X
---| "AKD-10"
---| "ALARM"
---| "AM39"
---| "AN_M30A1" # AN-M30A1
---| "AN_M57" # AN-M57
---| "AN_M64" # AN-M64
---| "AN_M65" # AN-M65
---| "AN_M66" # AN-M66
---| "AO-2-5"
---| "AO_2_5RT" # AO-2.5RT
---| "AO_25SL" # AO-25SL
---| "APCBC" # APCBC (76mm APCBC-T)
---| "AGR_20_M151_unguided" # APKWS M151 unguided
---| "AGR_20_M282_unguided" # APKWS M282 unguided
---| "ARAKM70BAP"
---| "ARAKM70BAPPX"
---| "ARAKM70BHE"
---| "ARF8M3API" # ARF-8/M3 API
---| "ARF8M3HEI" # ARF-8/M3 HEI Heavy
---| "ARF8M3TPSM" # ARF-8/M3 TP-SM
---| "Kormoran" # AS.34 Kormoran
---| "ASM_N_2" # ASM-N-2 Bat, radar guided glide bomb
---| "P_9M117" # AT-10 Stabber
---| "REFLEX"
---| "SVIR"
---| "P_9M133" # AT-14 Spriggan
---| "MALUTKA" # AT-3 Sagger
---| "KONKURS" # AT-5 Spandrel
---| "BAP-100"
---| "BAP_100"
---| "BAT-120" # BAT-120 ABL
---| "BDU_33" # BDU-33
---| "BDU_45" # BDU-45
---| "BDU_45B" # BDU-45B
---| "BDU_45LGB" # BDU-45LGB
---| "BDU_50HD" # BDU-50HD
---| "BDU_50LD" # BDU-50LD
---| "BDU_50LGB" # BDU-50LGB
---| "Besa7_92x57" # Besa 7.92x57
---| "Besa7_92x57T" # Besa 7.92x57T
---| "BetAB_500" # BetAB-500
---| "BETAB-500M" # BETAB-500M - 479 kg, bomb, penetrating
---| "BETAB-500S" # BETAB-500S - 425 kg, bomb, penetrating
---| "BetAB_500ShP" # BetAB-500ShP
---| "BGM_109B" # BGM-109C Tomahawk
---| "TOW2" # BGM-71 TOW
---| "TOW" # BGM-71D TOW
---| "BIN_200" # BIN-200 - 200kg Napalm Incendiary Bomb
---| "BK90_MJ1" # BK90 MJ1
---| "BK90_MJ1_MJ2" # BK90 MJ1-MJ2
---| "BK90_MJ2" # BK90 MJ2
---| "BKF_AO2_5RT" # BKF - 12 x AO-2.5RT
---| "BKF_PTAB2_5KO" # BKF - 12 x PTAB-2.5KO
---| "BL_755" # BL755
---| "BLG66_BELOUGA" # BLG-66 Belouga
---| "BLG66" # BLG-66 Belouga AC
---| "BLG66_EG" # BLG-66 Belouga EG
---| "Durandal" # BLU-107/B Durandal
---| "BLU-49/B"
---| "OH58D_Blue_Smoke_Grenade" # Blue Smoke Grenade
---| "Bofors_40mm_Essex" # Bofors 40mm Essex
---| "Bofors_40mm_HE"
---| "BOLT-117"
---| "BLU-18/B_GROUP" # Bomblets - BLU-18/B x 30, HE
---| "BLU-3_R_GROUP_R" # Bomblets - BLU-3 x 19, HE
---| "BLU-3B_R_GROUP_R" # Bomblets - BLU-3B x 22, HE
---| "BLU-4B_R_GROUP_R" # Bomblets - BLU-4B x 27, HE
---| "BLU-3_GROUP" # Bomblets BLU-3B x 19, HE
---| "BLU-3B_GROUP" # Bomblets BLU-3B x 22, HE
---| "BLU-4B_GROUP" # Bomblets BLU-3B x 27, HE
---| "NR30_30x155_APHE" # BR 30x155 APHE
---| "BR_250" # BR-250 - 250kg GP Bomb LD
---| "BR_354N" # BR-354N
---| "BR_500" # BR-500 - 500kg GP Bomb LD
---| "BRM-1_90MM" # BRM-1 90mm Laser-guided Rocket
---| "BRM1_90MM_UG"
---| "NR30_30x155_APT" # BT 30x155 AP-T
---| "C_701IR" # C-701IR
---| "C_701T" # C-701T
---| "C_802AK" # C-802AK
---| "CATM_65K" # CATM-65K
---| "CATM_9M" # CATM-9M
---| "CBU_103" # CBU-103
---| "CBU_105" # CBU-105
---| "CBU_52B" # CBU-52B
---| "CBU_87" # CBU-87
---| "CBU_97" # CBU-97
---| "CBU_99" # CBU-99 - 490lbs, 247 x HEAT Bomblets
---| "CM-400AKG"
---| "CM_802AKG" # CM-802AKG
---| "CM-802AKG" # CM802AKG
---| "DEFA553_30AP" # DEFA553 30mm AP
---| "DEFA553_30APIT" # DEFA553 30mm API-T
---| "DEFA553_30HE" # DEFA553 30mm HE
---| "DM12_120mm_HEAT_MP_T"
---| "DM12_L55_120mm_HEAT_MP_T"
---| "DM33_120_AP" # DM33 (120mm APFSDS-T)
---| "DM53_120_AP" # DM53 (120mm APFSDS-T)
---| "Rh202_20_AP" # DM63 (20mm APDS-T)
---| "Rh202_20_HE" # DM81 (20mm HE-T)
---| "DWS39_MJ1" # DWS39 MJ1
---| "DWS39_MJ1_MJ2" # DWS39 MJ1-MJ2
---| "DWS39_MJ2" # DWS39 MJ2
---| "FAB_100M" # FAB-100M - 100kg GP Bomb LD
---| "FAB_100SV" # FAB-100SV
---| "FAB_1500" # FAB-1500 M-54
---| "FAB-250M54" # FAB-250 M54 - 235 kg, bomb, parachute
---| "FAB-250M54TU" # FAB-250 M54 TU - 235 kg, bomb, parachute
---| "FAB-250-M62" # FAB-250M-62 GP
---| "FAB_50" # FAB-50 - 50kg GP Bomb LD
---| "FAB-500M54" # FAB-500 M54 - 474 kg, bomb, free-fall
---| "FAB-500M54TU" # FAB-500 M54 TU - 480 kg, bomb, parachute
---| "FAB-500SL" # FAB-500 SL - 515 kg, bomb, parachute
---| "FAB-500TA" # FAB-500 TA - 477 kg, bomb, free-fall
---| "FAB_500" # FAB-500M-62
---| "CHAP_AIM92"
---| "OH58D_FIM_92"
---| "FIM_92C" # FIM-92C Stinger
---| "QF95_206R_fixed" # Fixed QF95 206R (95mm HE)
---| "G7A_T1"
---| "GB-6"
---| "GB-6-HE"
---| "GB-6-SFW"
---| "GBU_10" # GBU-10
---| "GBU_11" # GBU-11
---| "GBU_12" # GBU-12
---| "GBU_15_V_1_B" # GBU-15(V)1/B
---| "GBU_15_V_31_B" # GBU-15(V)31/B
---| "HB_F4E_GBU15V1" # GBU-15-V1
---| "GBU_16" # GBU-16
---| "GBU_17" # GBU-17
---| "GBU_24" # GBU-24A/B Paveway III
---| "GBU_24E" # GBU-24E/B Enhanced Paveway III
---| "GBU_27" # GBU-27
---| "GBU_28" # GBU-28
---| "GBU_29" # GBU-29
---| "GBU_30" # GBU-30
---| "GBU_31" # GBU-31(V)1/B
---| "GBU_31_V_2B" # GBU-31(V)2/B
---| "GBU_31_V_3B" # GBU-31(V)3/B
---| "GBU_31_V_4B" # GBU-31(V)4/B
---| "GBU_32_V_2B" # GBU-32(V)2/B
---| "GBU_38" # GBU-38(V)1/B
---| "GBU_39" # GBU-39
---| "GBU_43" # GBU-43
---| "GBU_54_V_1B" # GBU-54(V)1/B
---| "GBU_8_B" # GBU-8/B
---| "M30" # GMLRS M30
---| "M31" # GMLRS M31
---| "OH58D_Green_Smoke_Grenade" # Green Smoke Grenade
---| "GSH_23_AP" # GSH 23 AP
---| "GSH_23_HE" # GSH 23 HE
---| "GSh_30_2K_AP" # GSh-30-2K AP
---| "GSh_30_2K_AP_Tr" # GSh-30-2K AP Tracer
---| "GSh_30_2K_HE" # GSh-30-2K HE
---| "GSh_30_2K_HE_Tr" # GSh-30-2K HE Tracer
---| "Sea_Cat" # GWS-22 Mod. 1 Sea Cat
---| "Sea_Wolf" # GWS-25 Sea Wolf
---| "Sea_Dart" # GWS-30 Sea Dart
---| "HB_AGM_78" # HB-AGM-78
---| "HE_M1_Shell" # HE M1 Shell
---| "HEDPM430" # HEDP M430
---| "HHQ-9"
---| "Hispano_Mk_II_AP/T"
---| "Hispano_Mk_II_Mk_Z_Ball"
---| "Hispano_Mk_II_MKI_HE/I"
---| "Hispano_Mk_II_MKIIZ_AP"
---| "Hispano_Mk_II_SAP/I"
---| "Hispano_Mk_II_Tracer_G"
---| "HJ-12"
---| "HOT3_MBDA" # HOT-3
---| "HOT2"
---| "HQ-16"
---| "HQ-7B"
---| "HVAR"
---| "HVAR USN Mk28 Mod4" # HVAR USN Mk28 Mod4 (Corsair) - 64 kg, unguided rocket
---| "HY-2" # HY-2 (SS-N-2 Styx)
---| "HYDRA_70_M151" # Hydra 70 M151 HE
---| "AGR_20A" # Hydra 70 M151 HE APKWS
---| "HYDRA_70_M151_M433" # Hydra 70 M151 HE, M433 RC Fuze
---| "HYDRA_70_M156" # Hydra 70 M156 SM
---| "HYDRA_70_M229" # Hydra 70 M229 HE
---| "HYDRA_70_M257" # Hydra 70 M257 IL
---| "HYDRA_70_M259" # Hydra 70 M259 SM
---| "HYDRA_70_M274" # Hydra 70 M274 TP-SM
---| "HYDRA_70_M282" # Hydra 70 M282 MPP
---| "AGR_20_M282" # Hydra 70 M282 MPP APKWS
---| "HYDRA_70_MK1" # Hydra 70 Mk 1 HE
---| "HYDRA_70_MK5" # Hydra 70 Mk 5 HEAT
---| "HYDRA_70_MK61" # Hydra 70 Mk 61 TP
---| "HYDRA_70_WTU1B" # Hydra 70 WTU-1/B TP
---| "I_Gr_33" # I.Gr. 33 (150mm HE)
---| "IAB-500" # IAB-500 - 470 kg, bomb, free fall
---| "SA_IRIS_T_SL" # IRIS-T-SL
---| "K307_155HE" # K307 (155mm HE)
---| "KAB_1500T" # KAB-1500Kr
---| "KAB_1500Kr"
---| "KAB_1500LG"
---| "KAB_500" # KAB-500
---| "KAB_500Kr" # KAB-500Kr
---| "KAB_500KrOD" # KAB-500Kr-OD
---| "KAB_500S" # KAB-500S
---| "KD_20" # KD-20
---| "KD_63" # KD-63
---| "KD_63B" # KD-63B
---| "X_101" # Kh-101
---| "X_22" # Kh-22 (AS-4 Kitchen)
---| "X_25ML" # Kh-25ML
---| "Kh25MP_PRGS1VP" # Kh-25MP (AS-12 Kegler)
---| "X_25MP" # Kh-25MPU (Updated AS-12 Kegler)
---| "X_25MR" # Kh-25MR
---| "X_28" # Kh-28
---| "X_29L" # Kh-29L
---| "X_29T" # Kh-29T
---| "X_29TE" # Kh-29TE
---| "X_31A" # Kh-31A
---| "X_31P" # Kh-31P
---| "X_35" # Kh-35 (AS-20 Kayak)
---| "X_41" # Kh-41 (SS-N-22-Sunburn)
---| "X_555" # Kh-555
---| "X_58" # Kh-58U
---| "X_59M" # Kh-59M (AS-18 Kazoo)
---| "X_65" # Kh-65
---| "Kh-66_Grom" # Kh-66 Grom (21) - AGM, radar guided
---| "KPVT_14_5"
---| "L21A1_30_HE" # L13A1 (30mm HE-T)
---| "L14A2_30_APDS" # L14A2 (30mm APDS-T)
---| "L23_120_AP" # L23 (120mm APFSDS-T)
---| "L23A1_APFSDS" # L23A1 (120mm APFSDS-T)
---| "L31_120mm_HESH" # L31 (120mm HESH)
---| "L31A7_HESH" # L31A7 (120mm HESH)
---| "LD-10"
---| "leFH18_105HE"
---| "LS_6_100" # LS-6-100
---| "LS_6" # LS-6-250
---| "LS_6_500" # LS-6-500
---| "LTF_5B" # LTF 5b
---| "LUU_19" # LUU-19
---| "LUU_2AB" # LUU-2AB
---| "LUU_2B" # LUU-2B Flare
---| "LUU_2BB" # LUU-2BB
---| "LYSBOMB 11086"
---| "LYSBOMB 11087"
---| "LYSBOMB 11088"
---| "LYSBOMB 11089"
---| "LYSBOMB_CANDLE" # LYSBOMB_CANDLE whatever
---| "HEBOMB" # M/71 HE-Bomb
---| "HEBOMBD" # M/71 HE-Bomb w chute
---| "M101" # M101 (155mm HE)
---| "M_117" # M117
---| "M230_HEDP M789"
---| "M230_TP M788"
---| "M246_20_HE_gr" # M246_20_HE
---| "M257_FLARE" # M257 Flare
---| "M26" # M26 (270mm DPICM)
---| "M26HE"
---| "M322_120_AP" # M322 (120mm APFSDS-T)
---| "M339_120mm_HEAT_MP_T" # M339 (120mm HEAT-MP-T)
---| "M68_105_HE" # M393 (105mm HEP)
---| "HESH_105" # M393 (105mm HESH)
---| "F100_M39_20_API_T" # M39_20_API_T
---| "M42A1_HE" # M42A1 (76mm HE)
---| "M46"
---| "M485_FLARE" # M485 IL
---| "M53_AP_RED" # M53 20mm API
---| "M55A2_TP_RED" # M55A2 20mm TP
---| "M56A3_HE_RED" # M56A3 20mm HEI
---| "M61" # M61 (75mm APCBC-HE-T)
---| "M61_20_HE_INVIS"
---| "M61_20_TP"
---| "M61_20_TP_T"
---| "M62_APC" # M62 (76mm APCBC-T)
---| "M242_25_AP_M791" # M791 (25mm APDS-T)
---| "M242_25_HE_M792" # M792 (25mm HEI-T)
---| "M185_155" # M795 (155mm HE)
---| "M256_120_AP" # M829A2 (120mm APFSDS-T)
---| "M256_120_HE" # M830 (120mm HEAT-MP-T)
---| "M68_105_AP" # M833 (105mm APFSDS-T)
---| "Mark_46" # Mark 46
---| "MMagicII" # Matra Magic II
---| "Mauser7.92x57_B."
---| "Mauser7.92x57_P.m.K."
---| "Mauser7.92x57_S.m.K."
---| "Mauser7.92x57_S.m.K._L'spur(gelb)"
---| "Mauser7.92x57_S.m.K._L'spur(weiss)"
---| "Mauser7.92x57_S.m.K._Ub.m.Zerl."
---| "Mauser7.92x57_S.m.K.H."
---| "MG_13x64_HE"
---| "MG_13x64_HEI_T"
---| "MG_13x64_I"
---| "MG_13x64_I_T"
---| "M39A1" # MGM-140B M39A1
---| "M48" # MGM-140E M48
---| "MICA_T" # MICA-IR
---| "MICA_R" # MICA-RF
---| "MIM_104" # MIM-104 Patriot
---| "HAWK_RAKETA" # MIM-23K Hawk
---| "MIM_72G" # MIM-72G Chaparrel
---| "MINGR55"
---| "MINGR55_NO_TRC"
---| "Mistral"
---| "MK106" # Mk 106
---| "Mk_12_HE_shell" # Mk 12 HE
---| "Mk_20_HE_shell" # Mk 20 HE
---| "FFAR M156 WP" # Mk 4 FFAR M156 SM
---| "FFAR Mk1 HE" # Mk 4 FFAR Mk 1 HE
---| "FFAR Mk5 HEAT" # Mk 4 FFAR Mk 5 HEAT
---| "FFAR_Mk61" # Mk 4 FFAR Mk 61 TP
---| "MK76" # Mk 76
---| "ROCKEYE" # Mk-20 Rockeye
---| "Mk_81" # Mk-81
---| "Mk_82" # Mk-82
---| "MK_82SNAKEYE" # Mk-82 Snakeye
---| "MK_82AIR" # Mk-82AIR
---| "Mk_82Y" # Mk-82Y - 500lb GP Chute Retarded HD
---| "Mk_83" # Mk-83
---| "Mk_83AIR" # Mk-83 AIR GP HD
---| "Mk_83CT" # Mk-83CT
---| "Mk_84" # Mk-84
---| "Mk_84AIR_GP" # Mk-84 AIR GP HD
---| "Mk_84AIR_TP" # Mk-84 AIR TP HD
---| "CHAP_30_MK258_APFSDS_T" # Mk258 30x173mm APFSDS-T
---| "CHAP_30_MK266_HEI_T" # Mk266 30x173mm HEI-T
---| "MK45_127mm_AP_Essex" # MK45 127mm AP Essex 
---| "MK45_127mm_Essex" # MK45 127mm Essex
---| "mk46torp_name" # MK46 Torpedo
---| "MO_10104M" # MO.1.01.04M HE
---| "ODAB-500PM" # ODAB-500PM - 525 kg, bomb, parachute, simulated aerosol
---| "Oerlikon_20mm_Essex" # Oerlikon 20mm Essex
---| "Oerlikon_20mm_HE" # Oerlikon 20mm HE
---| "OF_350"
---| "OFAB-100-120TU" # OFAB 100-120 TU - 123 kg, bomb, parachute
---| "OFAB-100 Jupiter" # OFAB-100 Jupiter - 100kg GP Bomb HD
---| "FAB_100" # OFAB-100-120
---| "FAB_250" # OFAB-250-270
---| "OFL_120F2_AP" # OFL 120F2 (120mm APFSDS-T)
---| "NR30_30x155_HEI_T" # OFZT 30x155 HEI-T
---| "P_500" # P-500 (SS-N-12 Sandbox)
---| "P-50T" # P-50T - 50kg Practice Bomb LD
---| "P_700" # P-700 (SS-N-19 Shipwreck)
---| "2A28_73" # PG-15 (73mm HEAT)
---| "PG_16V" # PG-16 HEAT
---| "PG_9V" # PG-9 HEAT
---| "M61_20_PGU27" # PGU-27/B TP
---| "M61_20_PGU28" # PGU-28/B SAPHEI
---| "M61_20_PGU30" # PGU-30/B TP-T
---| "PGU32_SAPHEI_T" # PGU-32/U SAPHEI-T
---| "PL-12" # PL-12 AAM
---| "PL-5EII"
---| "PL-8A"
---| "PL-8B"
---| "PTAB-2-5"
---| "PTAB_2_5KO" # PTAB-2.5KO
---| "Pzgr_39_5cm" # Pz.Gr. 39 (50mm APCBC-HE-T)
---| "Pzgr_39" # Pz.Gr. 39 (88mm APCBC-HE-T)
---| "Pzgr_39/40"
---| "Pzgr_39/42"
---| "Pzgr_39/43"
---| "QF94_AA_HE" # QF 3,7inch HE
---| "QF17_HE" # QF17 (76mm HE)
---| "R-13M"
---| "R-13M1"
---| "P_24R" # R-24R (AA-7 Apex SA)
---| "P_24T" # R-24T (AA-7 Apex IR)
---| "P_27PE" # R-27ER
---| "P_27TE" # R-27ET
---| "P_27P" # R-27R
---| "P_27T" # R-27T
---| "P_33E" # R-33 (AA-9 Amos)
---| "R-3R"
---| "R-3S"
---| "P_40R" # R-40RD (AA-6 Acrid)
---| "P_40T" # R-40TD (AA-6 Acrid)
---| "R-55" # R-55 - AAM, IR guided
---| "R-60"
---| "P_60" # R-60M
---| "P_73" # R-73 (AA-11 Archer)
---| "P_77" # R-77 (AA-12 Adder)
---| "R4M" # R4M 3.2kg UnGd air-to-air rocket
---| "R_530F_EM" # R530F EM
---| "R_530F_IR" # R530F IR
---| "R_550_M1" # R550 Magic 1
---| "R_550" # R550 Magic 2
---| "Rapier"
---| "Rb 04E"
---| "Rb_04"
---| "Rb 04E (for A.I.)" # RB-04E (for A.I.)
---| "Rb 05A" # RB-05A
---| "Rb 15F" # RB-15F
---| "Rb 15F (for A.I.)" # RB-15F (for A.I.)
---| "Rb 24" # RB-24
---| "Rb 24J" # RB-24J
---| "Rb 74" # RB-74
---| "RB75" # RB-75A
---| "RB75B" # RB-75B
---| "RB75T" # RB-75T
---| "RBK_250" # RBK-250 PTAB-2.5M
---| "RBK_250_275_AO_1SCH" # RBK-250-275 - 150 x AO-1SCh, 250kg CBU HE/Frag
---| "RBK_250S" # RBK-250SHOAB
---| "RBK_500U" # RBK-500 PTAB-1M
---| "RBK_500AO" # RBK-500-255 PTAB-10-5
---| "RBK_500SOAB" # RBK-500SHOAB
---| "RBK_500U_BETAB_M" # RBK-500U - 10 x BETAB-M, 500kg Bunker Buster CBU HE/Frag
---| "RBK_500U_OAB_2_5RT" # RBK-500U - 126 x OAB-2.5RT, 500kg CBU HE/Frag
---| "OH58D_Red_Smoke_Grenade" # Red Smoke Grenade
---| "AGM_84S" # RGM-84D Harpoon
---| "RIM_116A" # RIM-116A
---| "SeaSparrow" # RIM-7M
---| "RN-24" # RN-24 - 470kg, nuclear bomb, free fall
---| "RN-28" # RN-28 - 260 kg, nuclear bomb, free fall
---| "British_AP_25LBNo1_3INCHNo1" # RP-3 AP
---| "British_HE_60LBFNo1_3INCHNo1" # RP-3 HE
---| "British_HE_60LBSAPNo2_3INCHNo1" # RP-3 SAP
---| "RS-82"
---| "RS2US" # RS2US - AAM, beam-rider
---| "C_13" # S-13OF Blast/Fragmentation
---| "S-24A" # S-24A (21) - 180 kg, cumulative unguided rocket
---| "C_24" # S-24B
---| "S-24B" # S-24B (21) - 180 kg, fragmented unguided rocket
---| "S-25-O" # S-25-O Fragmentation
---| "C_25" # S-25-OFM Hardened Target Penetrator
---| "S_25L" # S-25L
---| "C_5" # S-5KO HEAT/Frag
---| "S_5KP" # S-5KP HEAT/Frag
---| "S-5M" # S-5M - unguided rocket 57mm
---| "S_5M" # S-5M HE
---| "S5M1_HEFRAG_FFAR" # S-5M1 HE-FRAG FFAR
---| "S5MO_HEFRAG_FFAR" # S-5MO HE-FRAG FFAR
---| "C_8" # S-8KOM HEAT/Frag
---| "C_8OFP2" # S-8OFP2 MPP
---| "S_8OM_FLARE" # S-8OM Flare
---| "C_8OM" # S-8OM IL
---| "C_8CM_BU" # S-8TsM SM Blue
---| "C_8CM_GN" # S-8TsM SM Green
---| "C_8CM" # S-8TsM SM Orange
---| "C_8CM_RD" # S-8TsM SM Red
---| "C_8CM_VT" # S-8TsM SM Violet
---| "C_8CM_WH" # S-8TsM SM White
---| "C_8CM_YE" # S-8TsM SM Yellow
---| "Super_530D" # S530D
---| "Super_530F" # S530F
---| "SAB_100MN" # SAB-100MN
---| "SAB_100_FLARE" # SAB-100MN Flare
---| "SAB_250_FLARE" # SAB-250 Flare
---| "SAB_250_200" # SAB-250-200
---| "SAMP125LD" # SAMP-125 LD
---| "SAMP250HD" # SAMP-250 HD
---| "SAMP250LD" # SAMP-250 LD
---| "SAMP400HD" # SAMP-400 HD
---| "SAMP400LD" # SAMP-400 LD
---| "SC_250_T1_L2" # SC 250 Type 1 L2
---| "SC_250_T3_J" # SC 250 Type 3 J
---| "SC_50" # SC 50
---| "SC_500_J" # SC 500 J
---| "SC_500_L2" # SC 500 L2
---| "SCUD_RAKETA" # Scud R-17
---| "SD_250_Stg" # SD 250 Stg
---| "SD_500_A" # SD 500 A
---| "SD-10" # SD-10A AAM
---| "Sea_Eagle" # Sea Eagle
---| "ship_Bofors_40mm_HE"
---| "SM_1" # SM-1
---| "SM_2" # SM-2
---| "SM_2ER" # SM-2ER
---| "SM_6" # SM-6
---| "SNEB_TYPE250_F1B" # SNEB Type 250 F1B TP-SM
---| "SNEB_TYPE251_F1B" # SNEB Type 251 F1B HE
---| "SNEB_TYPE251_H1" # SNEB Type 251 H1 HE
---| "SNEB_TYPE252_F1B" # SNEB Type 252 F1B TP
---| "SNEB_TYPE252_H1" # SNEB Type 252 H1 TP
---| "SNEB_TYPE253_F1B" # SNEB Type 253 F1B HEAT
---| "SNEB_TYPE253_H1" # SNEB Type 253 H1 HEAT
---| "SNEB_TYPE254_F1B_GREEN" # SNEB Type 254 F1B SM Green
---| "SNEB_TYPE254_F1B_RED" # SNEB Type 254 F1B SM Red
---| "SNEB_TYPE254_F1B_YELLOW" # SNEB Type 254 F1B SM Yellow
---| "SNEB_TYPE254_H1_GREEN" # SNEB Type 254 H1 SM Green
---| "SNEB_TYPE254_H1_RED" # SNEB Type 254 H1 SM Red
---| "SNEB_TYPE254_H1_YELLOW" # SNEB Type 254 H1 SM Yellow
---| "SNEB_TYPE256_F1B" # SNEB Type 256 F1B HE/Frag
---| "SNEB_TYPE256_H1" # SNEB Type 256 H1 HE/Frag
---| "SNEB_TYPE257_F1B" # SNEB Type 257 F1B HE/Frag Lg Whd
---| "SNEB_TYPE257_H1" # SNEB Type 257 H1 HE/Frag Lg Whd
---| "SNEB_TYPE259E_F1B" # SNEB Type 259E F1B IL
---| "SNEB_TYPE259E_H1" # SNEB Type 259E H1 IL
---| "SPIKE_ER" # SPIKE-ER
---| "SPIKE_ERA" # SPIKE-ER/A
---| "SPIKE_ER2" # SPIKE-ER2
---| "Sprgr_34_L48"
---| "Sprgr_34_L70"
---| "Sprgr_38" # Spr.Gr.39 (50mm HE)
---| "Sprgr_39" # Spr.Gr.39 (88mm HE)
---| "Sprgr_43_L71" # Spr.Gr.43 (88mm HE)
---| "Flak18_Sprgr_39" # Sprgr. L/4.5 Kz.
---| "Matra Super 530D" # Super 530D
---| "TGM_65D" # TGM-65D
---| "TGM_65G" # TGM-65G
---| "TGM_65H" # TGM-65H
---| "Tiny Tim" # Tiny Tim (Corsair) - 569 kg, unguided rocket
---| "Type_200A" # TYPE-200A
---| "53-UBR-281U" # UBR-281 (57mm APCBC-HE-T)
---| "KS19_100AP" # UBR412 (100mm AP)
---| "UBR_365_85AP"
---| "UO_365K_85HE" # UO_365K_100HE
---| "KS19_100HE"
---| "UOF412_100HE"
---| "53-UOR-281U" # UOR-281 (57mm HE-T)
---| "V-1"
---| "SA2V755" # V755 S-75
---| "OH58D_Violet_Smoke_Grenade" # Violet Smoke Grenade
---| "WGr21" # Werfer-Granate 21
---| "OH58D_White_Smoke_Grenade" # White Smoke Grenade
---| "ROLAND_R" # XMIM-115 Roland
---| "OH58D_Yellow_Smoke_Grenade" # Yellow Smoke Grenade
---| "YJ-12"
---| "YJ-62"
---| "YJ-82"
---| "YJ-83"
---| "YJ-83K"
---| "YU-6"
---| "Zuni_127" # Zuni Mk. 24 Mod. 1 HE

--- Airfield names of Afghanistan (`Airbase.getByName`).
---@alias DcsId.Theatre.Afghanistan.AirbaseName
---| "Bagram"
---| "Bamyan"
---| "Bost"
---| "Camp Bastion"
---| "Camp Bastion Heliport"
---| "Chaghcharan"
---| "Dwyer"
---| "FOB Camp Dubs"
---| "FOB Clark"
---| "FOB Salerno"
---| "FOB Thunder"
---| "Farah"
---| "Gardez"
---| "Ghazni Heliport"
---| "Herat"
---| "Jalalabad"
---| "Kabul"
---| "Kandahar"
---| "Kandahar Heliport"
---| "Khost"
---| "Maymana Zahiraddin Faryabi"
---| "Nimroz"
---| "Qala i Naw"
---| "Sharana"
---| "Shindand"
---| "Shindand Heliport"
---| "Tarinkot"
---| "Urgoon Heliport"
---| "Zaranj"

--- Airfield ids of Afghanistan (a mission waypoint's `airdromeId`), keyed by name.
---@alias DcsId.Theatre.Afghanistan.AirdromeId
---| 1 # Herat
---| 2 # Farah
---| 3 # Shindand
---| 4 # Maymana Zahiraddin Faryabi
---| 5 # Chaghcharan
---| 6 # Qala i Naw
---| 7 # Kandahar
---| 8 # Bost
---| 9 # Tarinkot
---| 10 # Camp Bastion
---| 11 # Dwyer
---| 12 # Nimroz
---| 13 # Camp Bastion Heliport
---| 14 # Shindand Heliport
---| 15 # Kandahar Heliport
---| 16 # Bagram
---| 17 # Kabul
---| 18 # Bamyan
---| 19 # Jalalabad
---| 20 # Gardez
---| 21 # Ghazni Heliport
---| 22 # Sharana
---| 23 # FOB Salerno
---| 24 # Urgoon Heliport
---| 25 # Khost
---| 26 # FOB Thunder
---| 27 # FOB Camp Dubs
---| 28 # FOB Clark
---| 37 # Zaranj

--- Airfield names of Caucasus (`Airbase.getByName`).
---@alias DcsId.Theatre.Caucasus.AirbaseName
---| "Anapa-Vityazevo"
---| "Batumi"
---| "Beslan"
---| "Gelendzhik"
---| "Gudauta"
---| "Kobuleti"
---| "Krasnodar-Center"
---| "Krasnodar-Pashkovsky"
---| "Krymsk"
---| "Kutaisi"
---| "Maykop-Khanskaya"
---| "Mineralnye Vody"
---| "Mozdok"
---| "Nalchik"
---| "Novorossiysk"
---| "Senaki-Kolkhi"
---| "Sochi-Adler"
---| "Soganlug"
---| "Sukhumi-Babushara"
---| "Tbilisi-Lochini"
---| "Vaziani"

--- Airfield ids of Caucasus (a mission waypoint's `airdromeId`), keyed by name.
---@alias DcsId.Theatre.Caucasus.AirdromeId
---| 12 # Anapa-Vityazevo
---| 13 # Krasnodar-Center
---| 14 # Novorossiysk
---| 15 # Krymsk
---| 16 # Maykop-Khanskaya
---| 17 # Gelendzhik
---| 18 # Sochi-Adler
---| 19 # Krasnodar-Pashkovsky
---| 20 # Sukhumi-Babushara
---| 21 # Gudauta
---| 22 # Batumi
---| 23 # Senaki-Kolkhi
---| 24 # Kobuleti
---| 25 # Kutaisi
---| 26 # Mineralnye Vody
---| 27 # Nalchik
---| 28 # Mozdok
---| 29 # Tbilisi-Lochini
---| 30 # Soganlug
---| 31 # Vaziani
---| 32 # Beslan

--- Airfield names of Falklands (`Airbase.getByName`).
---@alias DcsId.Theatre.Falklands.AirbaseName
---| "Almirante Schroeders"
---| "Comandante Luis Piedrabuena"
---| "Cullen"
---| "El Calafate"
---| "Franco Bianco"
---| "Gobernador Gregores"
---| "Goose Green"
---| "Gull Point"
---| "Hipico Flying Club"
---| "Mount Pleasant"
---| "O'Higgins"
---| "Pampa Guanaco"
---| "Port Stanley"
---| "Porvenir"
---| "Puerto Natales"
---| "Puerto Santa Cruz"
---| "Puerto Williams"
---| "Punta Arenas"
---| "Rio Chico"
---| "Rio Gallegos"
---| "Rio Grande"
---| "Rio Turbio"
---| "San Carlos FOB"
---| "San Julian"
---| "Tolhuin"
---| "Ushuaia"
---| "Ushuaia Helo Port"

--- Airfield ids of Falklands (a mission waypoint's `airdromeId`), keyed by name.
---@alias DcsId.Theatre.Falklands.AirdromeId
---| 1 # Port Stanley
---| 2 # Mount Pleasant
---| 3 # San Carlos FOB
---| 5 # Rio Gallegos
---| 6 # Rio Grande
---| 7 # Ushuaia
---| 8 # Ushuaia Helo Port
---| 9 # Punta Arenas
---| 10 # Pampa Guanaco
---| 11 # San Julian
---| 12 # Puerto Williams
---| 13 # Puerto Natales
---| 14 # El Calafate
---| 15 # Puerto Santa Cruz
---| 16 # Comandante Luis Piedrabuena
---| 17 # Tolhuin
---| 18 # Porvenir
---| 19 # Almirante Schroeders
---| 20 # Rio Turbio
---| 21 # Rio Chico
---| 23 # Franco Bianco
---| 24 # Goose Green
---| 25 # Hipico Flying Club
---| 26 # Gobernador Gregores
---| 27 # O'Higgins
---| 28 # Cullen
---| 29 # Gull Point

--- Airfield names of GermanyCW (`Airbase.getByName`).
---@alias DcsId.Theatre.GermanyCW.AirbaseName
---| "Adelsheim"
---| "Airracing Frankfurt"
---| "Airracing Koblenz"
---| "Airracing Lubeck"
---| "Allstedt"
---| "Altes Lager"
---| "Bad Durkheim"
---| "Barth"
---| "Bienenfarm"
---| "Bindersleben"
---| "Bitburg"
---| "Bornholm"
---| "Brand"
---| "Brandis"
---| "Braunschweig"
---| "Bremen"
---| "Briest"
---| "Buchel"
---| "Buckeburg"
---| "Celle"
---| "Chojna"
---| "Cochstedt"
---| "Cologne"
---| "Damgarten"
---| "Dedelow"
---| "Dessau"
---| "Dusseldorf"
---| "Falkenberg"
---| "Fassberg"
---| "Finow"
---| "Frankfurt"
---| "Fritzlar"
---| "Fulda"
---| "Gardelegen"
---| "Garz"
---| "Gatow"
---| "Gelnhausen"
---| "Giebelstadt"
---| "Glindbruchkippe"
---| "Gross Mohrdorf"
---| "Grosse Wiese"
---| "Gutersloh"
---| "H FRG 01"
---| "H FRG 02"
---| "H FRG 03"
---| "H FRG 04"
---| "H FRG 05"
---| "H FRG 06"
---| "H FRG 07"
---| "H FRG 08"
---| "H FRG 09"
---| "H FRG 10"
---| "H FRG 11"
---| "H FRG 12"
---| "H FRG 13"
---| "H FRG 14"
---| "H FRG 15"
---| "H FRG 16"
---| "H FRG 17"
---| "H FRG 18"
---| "H FRG 19"
---| "H FRG 20"
---| "H FRG 21"
---| "H FRG 23"
---| "H FRG 25"
---| "H FRG 27"
---| "H FRG 30"
---| "H FRG 31"
---| "H FRG 32"
---| "H FRG 34"
---| "H FRG 38"
---| "H FRG 39"
---| "H FRG 40"
---| "H FRG 41"
---| "H FRG 42"
---| "H FRG 43"
---| "H FRG 44"
---| "H FRG 45"
---| "H FRG 46"
---| "H FRG 47"
---| "H FRG 48"
---| "H FRG 49"
---| "H FRG 50"
---| "H FRG 51"
---| "H GDR 01"
---| "H GDR 02"
---| "H GDR 03"
---| "H GDR 04"
---| "H GDR 05"
---| "H GDR 06"
---| "H GDR 07"
---| "H GDR 08"
---| "H GDR 09"
---| "H GDR 10"
---| "H GDR 11"
---| "H GDR 12"
---| "H GDR 13"
---| "H GDR 14"
---| "H GDR 15"
---| "H GDR 16"
---| "H GDR 17"
---| "H GDR 18"
---| "H GDR 19"
---| "H GDR 21"
---| "H GDR 22"
---| "H GDR 24"
---| "H GDR 25"
---| "H GDR 26"
---| "H GDR 30"
---| "H GDR 31"
---| "H GDR 32"
---| "H GDR 33"
---| "H GDR 34"
---| "H Med FRG 01"
---| "H Med FRG 02"
---| "H Med FRG 04"
---| "H Med FRG 06"
---| "H Med FRG 11"
---| "H Med FRG 12"
---| "H Med FRG 13"
---| "H Med FRG 14"
---| "H Med FRG 15"
---| "H Med FRG 16"
---| "H Med FRG 17"
---| "H Med FRG 21"
---| "H Med FRG 24"
---| "H Med FRG 26"
---| "H Med FRG 27"
---| "H Med FRG 29"
---| "H Med GDR 01"
---| "H Med GDR 02"
---| "H Med GDR 03"
---| "H Med GDR 08"
---| "H Med GDR 09"
---| "H Med GDR 10"
---| "H Med GDR 11"
---| "H Med GDR 12"
---| "H Med GDR 13"
---| "H Med GDR 14"
---| "H Med GDR 16"
---| "H Radar FRG 02"
---| "H Radar GDR 01"
---| "H Radar GDR 02"
---| "H Radar GDR 03"
---| "H Radar GDR 04"
---| "H Radar GDR 05"
---| "H Radar GDR 06"
---| "H Radar GDR 07"
---| "H Radar GDR 08"
---| "H Radar GDR 09"
---| "Hahn"
---| "Haina"
---| "Hamburg"
---| "Hamburg Finkenwerder"
---| "Hannover"
---| "Hasselfelde"
---| "Heidelberg"
---| "Herrenteich"
---| "Hildesheim"
---| "Hockenheim"
---| "Holzdorf"
---| "Kammermark"
---| "Kastrup"
---| "Kiel"
---| "Kothen"
---| "Laage"
---| "Landstuhl"
---| "Langenselbold"
---| "Larz"
---| "Leipzig Mockau"
---| "Lubeck"
---| "Luneburg"
---| "Mahlwinkel"
---| "Mainz Finthen"
---| "Marxwalde"
---| "Mendig"
---| "Merseburg"
---| "Neubrandenburg"
---| "Neuruppin"
---| "Nordholz"
---| "Northeim"
---| "Norvenich"
---| "Ober-Morlen"
---| "Obermehler Schlotheim"
---| "Oranienburg"
---| "Parchim"
---| "Peenemunde"
---| "Perwenitz"
---| "Pferdsfeld"
---| "Pinnow"
---| "Pottschutthohe"
---| "Ramstein"
---| "Revinge"
---| "Rinteln"
---| "Schkeuditz"
---| "Schonefeld"
---| "Schweinfurt"
---| "Sembach"
---| "Sittensen"
---| "Spangdahlem"
---| "Sperenberg"
---| "Sprendlingen"
---| "Stendal"
---| "Sturup"
---| "Szczecin-Goleniow"
---| "Tagra"
---| "Tegel"
---| "Tempelhof"
---| "Templin"
---| "Thurland"
---| "Tutow"
---| "Uelzen"
---| "Uetersen"
---| "Ummern"
---| "Verden-Scharnhorst"
---| "Walldorf"
---| "Waren Vielist"
---| "Werneuchen"
---| "Weser Wumme"
---| "Wiesbaden"
---| "Wismar"
---| "Wittstock"
---| "Worms"
---| "Wunstorf"
---| "Zerbst"
---| "Zollschen"
---| "Zweibrucken"

--- Airfield ids of GermanyCW (a mission waypoint's `airdromeId`), keyed by name.
---@alias DcsId.Theatre.GermanyCW.AirdromeId
---| 1 # Wittstock
---| 2 # Altes Lager
---| 3 # Barth
---| 4 # Zerbst
---| 5 # Bremen
---| 6 # Briest
---| 7 # Buckeburg
---| 8 # Celle
---| 9 # Cochstedt
---| 10 # Damgarten
---| 11 # Fassberg
---| 12 # Finow
---| 13 # Garz
---| 14 # Gatow
---| 15 # Templin
---| 16 # Gutersloh
---| 17 # Hamburg
---| 18 # Hamburg Finkenwerder
---| 19 # Hannover
---| 20 # Laage
---| 21 # Larz
---| 22 # Mahlwinkel
---| 23 # Neubrandenburg
---| 24 # Neuruppin
---| 25 # Peenemunde
---| 26 # Schonefeld
---| 27 # Stendal
---| 28 # Tegel
---| 29 # Tempelhof
---| 30 # Tutow
---| 31 # Werneuchen
---| 32 # Wunstorf
---| 33 # Bornholm
---| 34 # Brand
---| 35 # Brandis
---| 36 # Chojna
---| 37 # Cologne
---| 38 # Dusseldorf
---| 39 # Falkenberg
---| 40 # Heidelberg
---| 41 # Kastrup
---| 42 # Kiel
---| 43 # Landstuhl
---| 44 # Mainz Finthen
---| 45 # Sturup
---| 46 # Marxwalde
---| 47 # Nordholz
---| 48 # Norvenich
---| 49 # Oranienburg
---| 50 # Szczecin-Goleniow
---| 51 # Obermehler Schlotheim
---| 52 # Adelsheim
---| 53 # H FRG 01
---| 54 # H FRG 02
---| 55 # H FRG 03
---| 56 # H FRG 04
---| 57 # H FRG 05
---| 58 # H FRG 06
---| 59 # H FRG 07
---| 60 # H FRG 08
---| 61 # H FRG 09
---| 62 # H FRG 10
---| 64 # H FRG 12
---| 65 # H FRG 13
---| 66 # H FRG 14
---| 67 # H GDR 01
---| 68 # H GDR 02
---| 69 # H GDR 03
---| 70 # H GDR 04
---| 71 # H GDR 05
---| 72 # H GDR 06
---| 73 # H GDR 07
---| 74 # H GDR 08
---| 75 # H GDR 09
---| 76 # H GDR 10
---| 77 # H GDR 11
---| 78 # H FRG 15
---| 79 # Revinge
---| 80 # Gross Mohrdorf
---| 81 # Lubeck
---| 82 # Kothen
---| 83 # Dessau
---| 84 # Parchim
---| 85 # H GDR 12
---| 86 # Uetersen
---| 87 # Tagra
---| 89 # Luneburg
---| 90 # Northeim
---| 91 # H GDR 13
---| 92 # H GDR 14
---| 93 # H GDR 15
---| 94 # H GDR 16
---| 95 # H GDR 17
---| 96 # H FRG 16
---| 97 # H FRG 17
---| 98 # H FRG 18
---| 99 # H FRG 19
---| 100 # H FRG 11
---| 101 # Sperenberg
---| 102 # Uelzen
---| 103 # Dedelow
---| 104 # Kammermark
---| 106 # Weser Wumme
---| 107 # Braunschweig
---| 108 # Wismar
---| 109 # Waren Vielist
---| 110 # Bienenfarm
---| 111 # Pinnow
---| 112 # Gardelegen
---| 113 # Glindbruchkippe
---| 114 # Ummern
---| 115 # Hildesheim
---| 116 # Verden-Scharnhorst
---| 117 # Rinteln
---| 118 # Holzdorf
---| 119 # H Med GDR 01
---| 120 # H Med GDR 02
---| 121 # H Med GDR 03
---| 122 # H GDR 33
---| 123 # Airracing Koblenz
---| 124 # H GDR 34
---| 125 # Perwenitz
---| 126 # H Med GDR 08
---| 127 # H Med GDR 09
---| 128 # H Med GDR 10
---| 129 # H Med FRG 01
---| 130 # H Med FRG 02
---| 131 # Sittensen
---| 132 # H Med FRG 04
---| 134 # H Med FRG 06
---| 135 # Sprendlingen
---| 136 # Thurland
---| 137 # Zollschen
---| 139 # H Med FRG 11
---| 140 # Hasselfelde
---| 141 # Grosse Wiese
---| 142 # H GDR 18
---| 143 # H FRG 20
---| 144 # H Med FRG 12
---| 145 # H GDR 19
---| 146 # H GDR 30
---| 147 # H Med GDR 11
---| 148 # H FRG 21
---| 149 # H FRG 50
---| 150 # H FRG 23
---| 151 # H FRG 39
---| 152 # H GDR 21
---| 153 # H GDR 22
---| 154 # Fritzlar
---| 155 # Hahn
---| 156 # Sembach
---| 157 # Allstedt
---| 158 # Zweibrucken
---| 159 # Giebelstadt
---| 160 # Schweinfurt
---| 161 # Haina
---| 162 # Spangdahlem
---| 163 # Frankfurt
---| 164 # Bindersleben
---| 165 # Ramstein
---| 166 # Fulda
---| 168 # Mendig
---| 169 # Merseburg
---| 170 # Wiesbaden
---| 171 # Schkeuditz
---| 180 # H Med GDR 12
---| 181 # H Med GDR 13
---| 182 # H Med GDR 14
---| 184 # H Med GDR 16
---| 185 # H GDR 24
---| 186 # H Med FRG 13
---| 187 # H Med FRG 14
---| 188 # H Med FRG 15
---| 189 # H Med FRG 16
---| 190 # H Med FRG 17
---| 191 # H FRG 25
---| 193 # H Radar GDR 01
---| 194 # H Radar GDR 02
---| 195 # H Radar GDR 03
---| 196 # H Radar GDR 04
---| 197 # H Radar GDR 05
---| 198 # H Radar GDR 06
---| 199 # H Radar GDR 07
---| 200 # Bitburg
---| 201 # Airracing Lubeck
---| 202 # H FRG 27
---| 204 # Airracing Frankfurt
---| 208 # H Med FRG 21
---| 211 # H FRG 30
---| 212 # H FRG 31
---| 213 # H FRG 32
---| 215 # H FRG 34
---| 218 # H FRG 51
---| 219 # H FRG 38
---| 220 # H FRG 48
---| 221 # H FRG 49
---| 222 # H Med FRG 24
---| 223 # H Radar FRG 02
---| 225 # H Med FRG 26
---| 226 # H GDR 25
---| 227 # H GDR 26
---| 229 # H GDR 31
---| 230 # H GDR 32
---| 231 # H Med FRG 27
---| 232 # Pferdsfeld
---| 233 # H Med FRG 29
---| 234 # H FRG 40
---| 235 # Buchel
---| 236 # Leipzig Mockau
---| 237 # H FRG 43
---| 238 # H FRG 44
---| 239 # H FRG 45
---| 240 # H FRG 46
---| 241 # H FRG 47
---| 242 # Bad Durkheim
---| 243 # Gelnhausen
---| 244 # Herrenteich
---| 245 # Hockenheim
---| 246 # Langenselbold
---| 247 # Walldorf
---| 248 # Ober-Morlen
---| 249 # Pottschutthohe
---| 250 # Worms
---| 251 # H Radar GDR 09
---| 252 # H Radar GDR 08
---| 253 # H FRG 41
---| 254 # H FRG 42

--- Airfield names of Iraq (`Airbase.getByName`).
---@alias DcsId.Theatre.Iraq.AirbaseName
---| "Al-Asad Airbase"
---| "Al-Kut Airport"
---| "Al-Sahra Airport"
---| "Al-Salam Airbase"
---| "Al-Taji Airport"
---| "Al-Taquddum Airport"
---| "Baghdad International Airport"
---| "Balad Airbase"
---| "Bashur Airport"
---| "Erbil International Airport"
---| "H-2 Airbase"
---| "H-3 Main Airbase"
---| "H-3 Northwest Airbase"
---| "H-3 Southwest Airbase"
---| "K1 Base"
---| "Kharg Airfield"
---| "Kirkuk International Airport"
---| "Mosul International Airport"
---| "Qayyarah Airfield West"
---| "Sulaimaniyah International Airport"

--- Airfield ids of Iraq (a mission waypoint's `airdromeId`), keyed by name.
---@alias DcsId.Theatre.Iraq.AirdromeId
---| 1 # Al-Asad Airbase
---| 2 # Baghdad International Airport
---| 3 # Mosul International Airport
---| 4 # Erbil International Airport
---| 5 # Bashur Airport
---| 6 # Qayyarah Airfield West
---| 7 # Sulaimaniyah International Airport
---| 8 # Balad Airbase
---| 9 # Al-Taji Airport
---| 10 # Kirkuk International Airport
---| 11 # K1 Base
---| 12 # Al-Sahra Airport
---| 13 # Al-Taquddum Airport
---| 14 # Al-Salam Airbase
---| 15 # H-2 Airbase
---| 16 # H-3 Main Airbase
---| 17 # H-3 Southwest Airbase
---| 18 # H-3 Northwest Airbase
---| 19 # Al-Kut Airport
---| 20 # Kharg Airfield

--- Airfield names of Kola (`Airbase.getByName`).
---@alias DcsId.Theatre.Kola.AirbaseName
---| "Afrikanda"
---| "Alakurtti"
---| "Alta"
---| "Andoya"
---| "Arvidsjaur"
---| "Banak"
---| "Bardufoss"
---| "Boden Heli Base"
---| "Bodo"
---| "Enontekio"
---| "Evenes"
---| "Hemavan"
---| "Hosio"
---| "Ivalo"
---| "Jokkmokk"
---| "Kalevala"
---| "Kalixfors"
---| "Kallax"
---| "Kemi Tornio"
---| "Kilpyavr"
---| "Kirkenes"
---| "Kiruna"
---| "Kittila"
---| "Koshka Yavr"
---| "Kuusamo"
---| "Luostari Pechenga"
---| "Monchegorsk"
---| "Murmansk International"
---| "Olenya"
---| "Poduzhemye"
---| "Rovaniemi"
---| "Severomorsk-1"
---| "Severomorsk-3"
---| "Sodankyla"
---| "Tromso"
---| "Vidsel"
---| "Vuojarvi"

--- Airfield ids of Kola (a mission waypoint's `airdromeId`), keyed by name.
---@alias DcsId.Theatre.Kola.AirdromeId
---| 1 # Banak
---| 2 # Rovaniemi
---| 3 # Kemi Tornio
---| 4 # Vuojarvi
---| 5 # Kiruna
---| 6 # Severomorsk-3
---| 7 # Bodo
---| 8 # Severomorsk-1
---| 9 # Olenya
---| 10 # Monchegorsk
---| 11 # Jokkmokk
---| 12 # Murmansk International
---| 13 # Kalixfors
---| 14 # Kirkenes
---| 15 # Kallax
---| 16 # Kuusamo
---| 17 # Vidsel
---| 18 # Ivalo
---| 19 # Alakurtti
---| 20 # Andoya
---| 21 # Bardufoss
---| 22 # Kittila
---| 23 # Hosio
---| 24 # Alta
---| 25 # Evenes
---| 26 # Enontekio
---| 27 # Sodankyla
---| 28 # Kilpyavr
---| 29 # Luostari Pechenga
---| 30 # Koshka Yavr
---| 31 # Poduzhemye
---| 32 # Kalevala
---| 33 # Afrikanda
---| 34 # Boden Heli Base
---| 35 # Hemavan
---| 36 # Arvidsjaur
---| 37 # Tromso

--- Airfield names of MarianaIslands (`Airbase.getByName`).
---@alias DcsId.Theatre.MarianaIslands.AirbaseName
---| "Andersen AFB"
---| "Antonio B. Won Pat Intl"
---| "North West Field"
---| "Olf Orote"
---| "Pagan Airstrip"
---| "Rota Intl"
---| "Saipan Intl"
---| "Tinian Intl"

--- Airfield ids of MarianaIslands (a mission waypoint's `airdromeId`), keyed by name.
---@alias DcsId.Theatre.MarianaIslands.AirdromeId
---| 1 # Rota Intl
---| 2 # Saipan Intl
---| 3 # Tinian Intl
---| 4 # Antonio B. Won Pat Intl
---| 5 # Olf Orote
---| 6 # Andersen AFB
---| 7 # Pagan Airstrip
---| 8 # North West Field

--- Airfield names of MarianaIslandsWWII (`Airbase.getByName`).
---@alias DcsId.Theatre.MarianaIslandsWWII.AirbaseName
---| "Agana"
---| "Airfield 3"
---| "Charon Kanoa"
---| "Gurguan Point"
---| "Isley"
---| "Kagman"
---| "Marpi"
---| "Orote"
---| "Pagan"
---| "Rota"
---| "Ushi"

--- Airfield ids of MarianaIslandsWWII (a mission waypoint's `airdromeId`), keyed by name.
---@alias DcsId.Theatre.MarianaIslandsWWII.AirdromeId
---| 1 # Agana
---| 2 # Orote
---| 3 # Airfield 3
---| 4 # Charon Kanoa
---| 5 # Gurguan Point
---| 6 # Isley
---| 7 # Kagman
---| 8 # Marpi
---| 9 # Rota
---| 10 # Ushi
---| 11 # Pagan

--- Airfield names of Nevada (`Airbase.getByName`).
---@alias DcsId.Theatre.Nevada.AirbaseName
---| "Beatty"
---| "Boulder City"
---| "Creech"
---| "Echo Bay"
---| "Groom Lake"
---| "Henderson Executive"
---| "Jean"
---| "Laughlin"
---| "Lincoln County"
---| "McCarran International"
---| "Mesquite"
---| "Mina"
---| "Nellis"
---| "North Las Vegas"
---| "Pahute Mesa"
---| "Tonopah"
---| "Tonopah Test Range"

--- Airfield ids of Nevada (a mission waypoint's `airdromeId`), keyed by name.
---@alias DcsId.Theatre.Nevada.AirdromeId
---| 1 # Creech
---| 2 # Groom Lake
---| 3 # McCarran International
---| 4 # Nellis
---| 5 # Beatty
---| 6 # Boulder City
---| 7 # Echo Bay
---| 8 # Henderson Executive
---| 9 # Jean
---| 10 # Laughlin
---| 11 # Lincoln County
---| 13 # Mesquite
---| 14 # Mina
---| 15 # North Las Vegas
---| 16 # Pahute Mesa
---| 17 # Tonopah
---| 18 # Tonopah Test Range

--- Airfield names of Normandy (`Airbase.getByName`).
---@alias DcsId.Theatre.Normandy.AirbaseName
---| "Abbeville Drucat"
---| "Alderney"
---| "Amiens-Glisy"
---| "Argentan"
---| "Avranches Le Val-Saint-Pere"
---| "Azeville"
---| "Barville"
---| "Bazenville"
---| "Beaumont-le-Roger"
---| "Beauvais-Tille"
---| "Bembridg"
---| "Beny-sur-Mer"
---| "Bernay Saint Martin"
---| "Beuzeville"
---| "Biggin Hill"
---| "Biniville"
---| "Broglie"
---| "Brucheville"
---| "Cardonville"
---| "Carpiquet"
---| "Chailey"
---| "Chippelle"
---| "Conches"
---| "Cormeilles-en-Vexin"
---| "Creil"
---| "Cretteville"
---| "Cricqueville-en-Bessin"
---| "Deanland"
---| "Deauville"
---| "Detling"
---| "Deux Jumeaux"
---| "Dinan-Trelivan"
---| "Dunkirk-Mardyck"
---| "Eastchurch"
---| "Essay"
---| "Evreux"
---| "Farnborough"
---| "Fecamp-Benouville"
---| "Flers"
---| "Ford"
---| "Friston"
---| "Funtington"
---| "Goulet"
---| "Gravesend"
---| "Guernsey"
---| "Guyancourt"
---| "Hauterive"
---| "Hawkinge"
---| "Headcorn"
---| "Heathrow"
---| "High Halden"
---| "Holmsley South"
---| "Jersey"
---| "Kenley"
---| "Lantheuil"
---| "Lashenden"
---| "Le Molay"
---| "Lessay"
---| "Lignerolles"
---| "Longues-sur-Mer"
---| "Lonrai"
---| "Lymington"
---| "Lympne"
---| "Manston"
---| "Maupertus"
---| "Meautis"
---| "Merville Calonne"
---| "Needs Oar Point"
---| "Northolt"
---| "Odiham"
---| "Orly"
---| "Picauville"
---| "Poix"
---| "Ronai"
---| "Rouen-Boos"
---| "Rucqueville"
---| "Saint Pierre du Mont"
---| "Saint-Andre-de-lEure"
---| "Saint-Aubin"
---| "Saint-Omer Wizernes"
---| "Saint-Pol-Bryas"
---| "Sainte-Croix-sur-Mer"
---| "Sainte-Laurent-sur-Mer"
---| "Sommervieu"
---| "Stoney Cross"
---| "Tangmere"
---| "Triqueville"
---| "Villacoublay"
---| "Vrigny"
---| "West Malling"

--- Airfield ids of Normandy (a mission waypoint's `airdromeId`), keyed by name.
---@alias DcsId.Theatre.Normandy.AirdromeId
---| 1 # Saint Pierre du Mont
---| 2 # Lignerolles
---| 3 # Cretteville
---| 4 # Maupertus
---| 5 # Brucheville
---| 6 # Meautis
---| 7 # Cricqueville-en-Bessin
---| 8 # Lessay
---| 9 # Sainte-Laurent-sur-Mer
---| 10 # Biniville
---| 11 # Cardonville
---| 12 # Deux Jumeaux
---| 13 # Chippelle
---| 14 # Beuzeville
---| 15 # Azeville
---| 16 # Picauville
---| 17 # Le Molay
---| 18 # Longues-sur-Mer
---| 19 # Carpiquet
---| 20 # Bazenville
---| 21 # Sainte-Croix-sur-Mer
---| 22 # Beny-sur-Mer
---| 23 # Rucqueville
---| 24 # Sommervieu
---| 25 # Lantheuil
---| 26 # Evreux
---| 27 # Chailey
---| 28 # Needs Oar Point
---| 29 # Funtington
---| 30 # Tangmere
---| 31 # Ford
---| 32 # Argentan
---| 33 # Goulet
---| 34 # Barville
---| 35 # Essay
---| 36 # Hauterive
---| 37 # Lymington
---| 38 # Vrigny
---| 39 # Odiham
---| 40 # Conches
---| 41 # West Malling
---| 42 # Villacoublay
---| 43 # Kenley
---| 44 # Beauvais-Tille
---| 45 # Cormeilles-en-Vexin
---| 46 # Creil
---| 47 # Guyancourt
---| 48 # Lonrai
---| 49 # Dinan-Trelivan
---| 50 # Heathrow
---| 51 # Fecamp-Benouville
---| 52 # Farnborough
---| 53 # Friston
---| 54 # Deanland
---| 55 # Triqueville
---| 56 # Poix
---| 57 # Orly
---| 58 # Stoney Cross
---| 59 # Amiens-Glisy
---| 60 # Ronai
---| 61 # Rouen-Boos
---| 62 # Deauville
---| 63 # Saint-Aubin
---| 64 # Flers
---| 65 # Avranches Le Val-Saint-Pere
---| 66 # Gravesend
---| 67 # Beaumont-le-Roger
---| 68 # Broglie
---| 69 # Bernay Saint Martin
---| 70 # Saint-Andre-de-lEure
---| 71 # Biggin Hill
---| 72 # Manston
---| 73 # Detling
---| 74 # Lympne
---| 75 # Abbeville Drucat
---| 76 # Saint-Omer Wizernes
---| 77 # Merville Calonne
---| 78 # High Halden
---| 79 # Dunkirk-Mardyck
---| 80 # Lashenden
---| 81 # Eastchurch
---| 82 # Hawkinge
---| 83 # Guernsey
---| 84 # Jersey
---| 85 # Alderney
---| 86 # Headcorn
---| 87 # Saint-Pol-Bryas
---| 88 # Northolt
---| 89 # Holmsley South
---| 90 # Bembridg

--- Airfield names of PersianGulf (`Airbase.getByName`).
---@alias DcsId.Theatre.PersianGulf.AirbaseName
---| "Abu Dhabi Intl"
---| "Abu Musa Island"
---| "Al Ain Intl"
---| "Al Dhafra AFB"
---| "Al Maktoum Intl"
---| "Al Minhad AFB"
---| "Al-Bateen"
---| "Bandar Abbas Intl"
---| "Bandar Lengeh"
---| "Bandar-e-Jask"
---| "Dubai Intl"
---| "Fujairah Intl"
---| "Havadarya"
---| "Jiroft"
---| "Kerman"
---| "Khasab"
---| "Kish Intl"
---| "Lar"
---| "Lavan Island"
---| "Liwa AFB"
---| "Qeshm Island"
---| "Quasoura_airport"
---| "Ras Al Khaimah Intl"
---| "Sas Al Nakheel"
---| "Sharjah Intl"
---| "Shiraz Intl"
---| "Sir Abu Nuayr"
---| "Sirri Island"
---| "Tunb Island AFB"
---| "Tunb Kochak"

--- Airfield ids of PersianGulf (a mission waypoint's `airdromeId`), keyed by name.
---@alias DcsId.Theatre.PersianGulf.AirdromeId
---| 1 # Abu Musa Island
---| 2 # Bandar Abbas Intl
---| 3 # Bandar Lengeh
---| 4 # Al Dhafra AFB
---| 5 # Dubai Intl
---| 6 # Al Maktoum Intl
---| 7 # Fujairah Intl
---| 8 # Tunb Island AFB
---| 9 # Havadarya
---| 10 # Khasab
---| 11 # Lar
---| 12 # Al Minhad AFB
---| 13 # Qeshm Island
---| 14 # Sharjah Intl
---| 15 # Sirri Island
---| 16 # Tunb Kochak
---| 17 # Sir Abu Nuayr
---| 18 # Kerman
---| 19 # Shiraz Intl
---| 20 # Sas Al Nakheel
---| 21 # Bandar-e-Jask
---| 22 # Abu Dhabi Intl
---| 23 # Al-Bateen
---| 24 # Kish Intl
---| 25 # Al Ain Intl
---| 26 # Lavan Island
---| 27 # Jiroft
---| 28 # Ras Al Khaimah Intl
---| 29 # Liwa AFB
---| 30 # Quasoura_airport

--- Airfield names of SinaiMap (`Airbase.getByName`).
---@alias DcsId.Theatre.SinaiMap.AirbaseName
---| "Abu Rudeis"
---| "Abu Suwayr"
---| "Al Bahr al Ahmar"
---| "Al Ismailiyah"
---| "Al Khatatbah"
---| "Al Mansurah"
---| "Al Rahmaniyah Air Base"
---| "As Salihiyah"
---| "AzZaqaziq"
---| "Baluza"
---| "Ben-Gurion"
---| "Beni Suef"
---| "Bilbeis Air Base"
---| "Bir Hasanah"
---| "Birma Air Base"
---| "Borg El Arab International Airport"
---| "Cairo International Airport"
---| "Cairo West"
---| "Damascus Intl"
---| "Difarsuwar Airfield"
---| "Ein Shamer"
---| "El Arish"
---| "El Gora"
---| "El Minya"
---| "Fayed"
---| "Gebel El Basur Air Base"
---| "Hatzerim"
---| "Hatzor"
---| "Hurghada International Airport"
---| "Inshas Airbase"
---| "Jiyanklis Air Base"
---| "Kedem"
---| "Khalkhalah Air Base"
---| "Kibrit Air Base"
---| "King Feisal Air Base"
---| "Kom Awshim"
---| "Megiddo"
---| "Melez"
---| "Mezzeh Air Base"
---| "Nevatim"
---| "Ovda"
---| "Palmachim"
---| "Quwaysina"
---| "Rafic Hariri Intl"
---| "Ramat David"
---| "Ramon Airbase"
---| "Ramon International Airport"
---| "Sde Dov"
---| "Sharm El Sheikh International Airport"
---| "St Catherine"
---| "Taba International Airport"
---| "Tabuk"
---| "TabukHeliBase"
---| "Tel Nof"
---| "Wadi Abu Rish"
---| "Wadi al Jandali"

--- Airfield ids of SinaiMap (a mission waypoint's `airdromeId`), keyed by name.
---@alias DcsId.Theatre.SinaiMap.AirdromeId
---| 1 # Difarsuwar Airfield
---| 2 # Abu Suwayr
---| 3 # As Salihiyah
---| 4 # Al Ismailiyah
---| 5 # Melez
---| 6 # Fayed
---| 7 # Hatzerim
---| 8 # Nevatim
---| 9 # Ramon Airbase
---| 10 # Ovda
---| 11 # Kibrit Air Base
---| 12 # Kedem
---| 13 # Wadi al Jandali
---| 14 # Al Mansurah
---| 15 # AzZaqaziq
---| 16 # Bilbeis Air Base
---| 17 # Cairo International Airport
---| 18 # Cairo West
---| 19 # Inshas Airbase
---| 20 # Hatzor
---| 21 # Palmachim
---| 22 # Sde Dov
---| 23 # Tel Nof
---| 24 # Ben-Gurion
---| 25 # St Catherine
---| 26 # Abu Rudeis
---| 27 # Baluza
---| 28 # Bir Hasanah
---| 29 # El Arish
---| 30 # El Gora
---| 31 # Al Khatatbah
---| 32 # Al Rahmaniyah Air Base
---| 33 # Beni Suef
---| 34 # Birma Air Base
---| 35 # Borg El Arab International Airport
---| 36 # El Minya
---| 37 # Gebel El Basur Air Base
---| 38 # Hurghada International Airport
---| 39 # Jiyanklis Air Base
---| 40 # Kom Awshim
---| 41 # Ramon International Airport
---| 42 # Sharm El Sheikh International Airport
---| 43 # Wadi Abu Rish
---| 44 # Al Bahr al Ahmar
---| 45 # Quwaysina
---| 46 # Rafic Hariri Intl
---| 47 # Tabuk
---| 48 # Damascus Intl
---| 49 # Mezzeh Air Base
---| 50 # Ramat David
---| 51 # Megiddo
---| 52 # Ein Shamer
---| 53 # Taba International Airport
---| 54 # King Feisal Air Base
---| 55 # Khalkhalah Air Base
---| 56 # TabukHeliBase

--- Airfield names of Syria (`Airbase.getByName`).
---@alias DcsId.Theatre.Syria.AirbaseName
---| "Abu al-Duhur"
---| "Adana Sakirpasa"
---| "Adiyaman"
---| "Akrotiri"
---| "Al Qusayr"
---| "Al-Dumayr"
---| "Aleppo"
---| "An Nasiriyah"
---| "At Tanf"
---| "Bassel Al-Assad"
---| "Beirut-Rafic Hariri"
---| "Ben Gurion"
---| "Chukurova"
---| "Damascus"
---| "Deir ez-Zor"
---| "Diyarbakir"
---| "Ercan"
---| "Eyn Shemer"
---| "Gaziantep"
---| "Gazipasa"
---| "Gecitkale"
---| "Gulechoba"
---| "H3"
---| "H3 Northwest"
---| "H3 Southwest"
---| "H4"
---| "H4 Emergency"
---| "HC01"
---| "HC02"
---| "HC03"
---| "HC04"
---| "HC05"
---| "HC06"
---| "HI01"
---| "HI02"
---| "HI03"
---| "HI05"
---| "HI06"
---| "HI07"
---| "HI08"
---| "HI09"
---| "HI11"
---| "HI12"
---| "HI13"
---| "HI14"
---| "HI15"
---| "HI16"
---| "HI17"
---| "HI18"
---| "HI20"
---| "HI21"
---| "HI22"
---| "HI23"
---| "HI24"
---| "HI25"
---| "HI26"
---| "HJ01"
---| "HJ02"
---| "HJ03"
---| "HJ04"
---| "HL01"
---| "HL02"
---| "HL03"
---| "HL04"
---| "HL05"
---| "HL06"
---| "HL07"
---| "HL08"
---| "HL09"
---| "HL10"
---| "HL11"
---| "HL12"
---| "HL13"
---| "HMed00"
---| "HMed01"
---| "HMed02"
---| "HMed03"
---| "HMed04"
---| "HMed05"
---| "HMed06"
---| "HMed07"
---| "HMed08"
---| "HMed09"
---| "HMed10"
---| "HMed11"
---| "HMed12"
---| "HMed13"
---| "HMed14"
---| "HMed15"
---| "HMed16"
---| "HMed17"
---| "HMed18"
---| "HMed19"
---| "HMed20"
---| "HMed21"
---| "HMed22"
---| "HMed23"
---| "HMed24"
---| "HMed25"
---| "HMed26"
---| "HMed27"
---| "HMed28"
---| "HMed29"
---| "HMed30"
---| "HOil01"
---| "HOil02"
---| "HOil03"
---| "HOil04"
---| "HOil05"
---| "HOil06"
---| "HS02"
---| "HS03"
---| "HS04"
---| "HS05"
---| "HS06"
---| "HS07"
---| "HS08"
---| "HS09"
---| "HS10"
---| "HS11"
---| "HS12"
---| "HS13"
---| "HS14"
---| "HS15"
---| "HS16"
---| "HS17"
---| "HS18"
---| "HS19"
---| "HS20"
---| "HS21"
---| "HS22"
---| "HS23"
---| "HS24"
---| "HS25"
---| "HS26"
---| "HS27"
---| "HS28"
---| "HS29"
---| "HS30"
---| "HS31"
---| "HS32"
---| "HS33"
---| "HS34"
---| "HS35"
---| "HS36"
---| "HS37"
---| "HS38"
---| "HS39"
---| "HS40"
---| "HS41"
---| "HS42"
---| "HStad01"
---| "HStad02"
---| "HStad03"
---| "HStad04"
---| "HStad05"
---| "HStad06"
---| "HT01"
---| "HT02"
---| "H_med_orig_01"
---| "H_med_orig_02"
---| "H_med_orig_03"
---| "H_med_orig_04"
---| "H_med_orig_05"
---| "H_med_orig_06"
---| "H_med_orig_07"
---| "H_med_orig_08"
---| "H_med_orig_09"
---| "Haifa"
---| "Hama"
---| "Hatay"
---| "Hatzerim"
---| "Hatzor"
---| "Herzliya"
---| "Incirlik"
---| "Jirah"
---| "Kahramanmaras"
---| "Kedem"
---| "Khalkhalah"
---| "Kharab Ishk"
---| "King Abdullah II"
---| "King Hussein Air College"
---| "Kingsfield"
---| "Kiryat Shmona"
---| "Konya"
---| "Kuweires"
---| "Lakatamia"
---| "Larnaca"
---| "Marj Ruhayyil"
---| "Marj as Sultan North"
---| "Marj as Sultan South"
---| "Marka"
---| "Megiddo"
---| "Mezzeh"
---| "Minakh"
---| "Muwaffaq Salti"
---| "Naqoura"
---| "Nevatim"
---| "Nicosia"
---| "Palmachim"
---| "Palmyra"
---| "Paphos"
---| "Pinarbashi"
---| "Prince Hassan"
---| "Qabr as Sitt"
---| "Ramat David"
---| "Rayak"
---| "Rene Mouawad"
---| "Rosh Pina"
---| "Ruwayshid"
---| "Sanliurfa"
---| "Sanliurfa Heliport"
---| "Sayqal"
---| "Shayrat"
---| "T2"
---| "T3"
---| "Tabqa"
---| "Taftanaz"
---| "Tal Siman"
---| "Tel Nof"
---| "Teyman"
---| "Tha'lah"
---| "Tiyas"
---| "Wujah Al Hajar"
---| "Zarqa"

--- Airfield ids of Syria (a mission waypoint's `airdromeId`), keyed by name.
---@alias DcsId.Theatre.Syria.AirdromeId
---| 1 # Abu al-Duhur
---| 2 # Adana Sakirpasa
---| 3 # Al Qusayr
---| 4 # An Nasiriyah
---| 5 # Tha'lah
---| 6 # Beirut-Rafic Hariri
---| 7 # Damascus
---| 8 # Marj as Sultan South
---| 9 # Al-Dumayr
---| 10 # Eyn Shemer
---| 11 # Gaziantep
---| 12 # H4
---| 13 # Haifa
---| 14 # Hama
---| 15 # Hatay
---| 16 # Incirlik
---| 17 # Jirah
---| 18 # Khalkhalah
---| 19 # King Hussein Air College
---| 20 # Kiryat Shmona
---| 21 # Bassel Al-Assad
---| 22 # Marj as Sultan North
---| 23 # Marj Ruhayyil
---| 24 # Megiddo
---| 25 # Mezzeh
---| 26 # Minakh
---| 27 # Aleppo
---| 28 # Palmyra
---| 29 # Qabr as Sitt
---| 30 # Ramat David
---| 31 # Kuweires
---| 32 # Rayak
---| 33 # Rene Mouawad
---| 34 # Rosh Pina
---| 35 # Sayqal
---| 36 # Shayrat
---| 37 # Tabqa
---| 38 # Taftanaz
---| 39 # Tiyas
---| 40 # Wujah Al Hajar
---| 41 # Gazipasa
---| 42 # Deir ez-Zor
---| 43 # Nicosia
---| 44 # Akrotiri
---| 45 # Kingsfield
---| 46 # Paphos
---| 47 # Larnaca
---| 48 # Lakatamia
---| 49 # Ercan
---| 50 # Gecitkale
---| 51 # Pinarbashi
---| 52 # Naqoura
---| 53 # H3
---| 54 # H3 Northwest
---| 55 # H3 Southwest
---| 56 # Zarqa
---| 57 # Ruwayshid
---| 58 # Sanliurfa
---| 59 # Kharab Ishk
---| 60 # Tal Siman
---| 61 # H4 Emergency
---| 62 # Nevatim
---| 63 # At Tanf
---| 64 # Prince Hassan
---| 65 # King Abdullah II
---| 66 # Herzliya
---| 67 # Marka
---| 68 # Muwaffaq Salti
---| 69 # HC01
---| 70 # HC02
---| 71 # HC03
---| 72 # HC04
---| 73 # HC05
---| 74 # HC06
---| 75 # Kahramanmaras
---| 76 # HI08
---| 77 # HI09
---| 79 # HI01
---| 80 # HI02
---| 81 # Hatzerim
---| 82 # HI03
---| 83 # HI05
---| 84 # HI06
---| 85 # HI07
---| 86 # HI11
---| 87 # HI12
---| 88 # Kedem
---| 89 # HS02
---| 90 # Chukurova
---| 91 # Teyman
---| 92 # HS05
---| 93 # HS06
---| 94 # HS08
---| 95 # HS09
---| 96 # HS10
---| 97 # HS11
---| 98 # HS19
---| 99 # HS18
---| 100 # HS17
---| 101 # HS16
---| 102 # HS15
---| 103 # HS14
---| 104 # HS13
---| 105 # HS12
---| 106 # HS25
---| 107 # HS24
---| 108 # HS23
---| 109 # HS22
---| 110 # HS21
---| 111 # HS20
---| 112 # HI17
---| 113 # HI16
---| 114 # HI15
---| 115 # HI14
---| 116 # HI13
---| 117 # HT01
---| 118 # HS33
---| 119 # HMed10
---| 120 # HMed09
---| 121 # HMed08
---| 122 # HMed07
---| 123 # HMed06
---| 124 # HMed05
---| 125 # HMed04
---| 126 # HMed03
---| 127 # HMed02
---| 128 # HMed01
---| 129 # HMed00
---| 130 # HMed11
---| 131 # H_med_orig_08
---| 132 # H_med_orig_07
---| 133 # H_med_orig_06
---| 134 # H_med_orig_05
---| 135 # H_med_orig_04
---| 136 # H_med_orig_03
---| 137 # H_med_orig_02
---| 138 # H_med_orig_01
---| 139 # HStad06
---| 140 # HStad05
---| 141 # HStad04
---| 142 # HStad03
---| 143 # HStad02
---| 144 # HStad01
---| 145 # HS26
---| 146 # HS42
---| 147 # HL13
---| 148 # HL12
---| 149 # HS41
---| 150 # HS35
---| 151 # HL11
---| 152 # HL10
---| 153 # HL09
---| 154 # HL08
---| 155 # HL07
---| 156 # HS27
---| 157 # HL06
---| 158 # HMed30
---| 159 # HMed29
---| 160 # HMed28
---| 161 # HMed27
---| 162 # HMed26
---| 163 # HMed25
---| 164 # HMed24
---| 165 # HMed23
---| 166 # HMed22
---| 167 # HMed21
---| 168 # HMed20
---| 169 # HMed19
---| 170 # HMed18
---| 171 # HMed17
---| 172 # HMed16
---| 173 # HMed15
---| 174 # HMed14
---| 175 # HMed13
---| 176 # HMed12
---| 177 # HOil05
---| 178 # HOil04
---| 179 # HOil03
---| 180 # HOil02
---| 181 # HOil01
---| 182 # H_med_orig_09
---| 183 # HS34
---| 184 # HS04
---| 185 # HS07
---| 186 # HI18
---| 187 # HS03
---| 188 # HS36
---| 189 # HS28
---| 190 # HS29
---| 191 # HS30
---| 192 # HT02
---| 193 # HI20
---| 194 # HI26
---| 195 # HI25
---| 196 # HI24
---| 197 # HI23
---| 198 # HI22
---| 199 # HI21
---| 200 # HJ04
---| 201 # HJ03
---| 202 # HJ02
---| 203 # HJ01
---| 204 # HL05
---| 205 # HL04
---| 206 # HL03
---| 207 # HL02
---| 208 # HL01
---| 209 # HS32
---| 210 # HS31
---| 211 # HOil06
---| 212 # HS40
---| 213 # HS39
---| 214 # HS38
---| 215 # HS37
---| 216 # Gulechoba
---| 217 # Diyarbakir
---| 218 # Konya
---| 219 # Adiyaman
---| 220 # Tel Nof
---| 221 # Ben Gurion
---| 222 # Hatzor
---| 223 # Palmachim
---| 224 # Sanliurfa Heliport
---| 225 # T2
---| 226 # T3

--- Unit attributes (`Object:hasAttribute`, task `targetTypes`): those of the unit series, then a few of weapons and airbases.
---@alias DcsId.Attribute
---| "AA_flak"
---| "AA_missile"
---| "AAA"
---| "ACLS"
---| "AD Auxillary Equipment"
---| "AFAPD"
---| "Air"
---| "Air Defence"
---| "Air Defence vehicles"
---| "Aircraft Carriers"
---| "AircraftCarrier"
---| "AircraftCarrier With Arresting Gear"
---| "AircraftCarrier With Catapult"
---| "AircraftCarrier With Tramplin"
---| "All"
---| "AntiAir Armed Vehicles"
---| "APC"
---| "Armed Air Defence"
---| "Armed ground units"
---| "Armed Ship"
---| "Armed ships"
---| "Armed vehicles"
---| "Armored vehicles"
---| "Arresting Gear"
---| "Artillery"
---| "ATGM"
---| "Attack helicopters"
---| "Aux"
---| "AWACS"
---| "Battle airplanes"
---| "Battleplanes"
---| "Bombers"
---| "C-RAM"
---| "Cargos"
---| "Cars"
---| "catapult"
---| "Corvettes"
---| "Cruisers"
---| "Datalink"
---| "Destroyers"
---| "DetectionByAWACS"
---| "EWR"
---| "Fighters"
---| "Fortifications"
---| "Frigates"
---| "GCI"
---| "Ground Units"
---| "Ground Units Non Airdefence"
---| "Ground vehicles"
---| "Heavy armed ships"
---| "HeavyArmoredUnits"
---| "HelicopterCarrier"
---| "Helicopters"
---| "human_vehicle"
---| "IFV"
---| "Indirect fire"
---| "Infantry"
---| "Infantry carriers"
---| "Interceptors"
---| "IR Guided SAM"
---| "Jammer"
---| "Landing Ships"
---| "Light armed ships"
---| "LightArmoredUnits"
---| "Link16"
---| "Link4"
---| "low_reflection_vessel"
---| "LR SAM"
---| "LTAvehicles"
---| "MANPADS"
---| "MANPADS AUX"
---| "Missile"
---| "MLRS"
---| "Mobile AAA"
---| "Modern Tanks"
---| "MR SAM"
---| "Multirole fighters"
---| "Naval"
---| "New infantry"
---| "NO_SAM"
---| "NonAndLightArmoredUnits"
---| "NonArmoredUnits"
---| "Old Tanks"
---| "Planes"
---| "PRMG_GLIDEPATH"
---| "PRMG_LOCALIZER"
---| "Prone"
---| "RADAR_BAND1_FOR_ARM"
---| "RADAR_BAND2_FOR_ARM"
---| "RailwayCarriage"
---| "RailwayCivilUnits"
---| "RailwayLocomotive"
---| "RailwayUnits"
---| "Refuelable"
---| "Rocket Attack Valid AirDefence"
---| "RSBN"
---| "SAM"
---| "SAM AUX"
---| "SAM CC"
---| "SAM elements"
---| "SAM LL"
---| "SAM related"
---| "SAM SR"
---| "SAM TR"
---| "Ships"
---| "Side approach departure"
---| "Skeleton_type_A"
---| "ski_jump"
---| "SR SAM"
---| "SS_missile"
---| "Static AAA"
---| "Straight_in_approach_type"
---| "Strategic bombers"
---| "Submarines"
---| "Tankers"
---| "Tanks"
---| "Trailers"
---| "Transport helicopters"
---| "Transports"
---| "Trucks"
---| "UAVs"
---| "Unarmed ships"
---| "Unarmed vehicles"
---| "Vehicles"
---| "AA Missiles" # AA Missiles (weapons)
---| "AG Missiles" # AG Missiles (weapons)
---| "Antiship Missiles" # Antiship Missiles (weapons)
---| "Cruise missiles" # Cruise missiles (weapons)
---| "SA Missiles" # SA Missiles (weapons)

--- Sensor names (`Unit:getSensors()` `typeName`).
---@alias DcsId.SensorName
---| "052B SAM SR"
---| "052B SAM TR"
---| "052C SAM STR"
---| "054A SAM TR"
---| "1G42"
---| "1K13-2 day"
---| "1K13-2 night"
---| "1L13 EWR"
---| "1P22"
---| "1P23"
---| "1PN22M1 day"
---| "1PN22M1 night"
---| "1PZ-3"
---| "26Sh-1"
---| "2S6 Tunguska"
---| "55G6 EWR"
---| "8TP"
---| "AAV day"
---| "AEGIS_search_radar"
---| "AESA_KJ2000"
---| "AGM-65D"
---| "AGM-65K"
---| "AGM_65D"
---| "AGM_65F"
---| "AGM_65G"
---| "AGM_65H"
---| "AGM_65K"
---| "AN/AAS-33A TRAM - Sensor"
---| "AN/AAS-38 FLIR/LDT"
---| "AN/APG-63"
---| "AN/APG-68"
---| "AN/APG-71"
---| "AN/APG-73"
---| "AN/APG-78"
---| "AN/APQ-120"
---| "AN/APQ-153"
---| "AN/APQ-159"
---| "AN/APS-137"
---| "AN/APS-138"
---| "AN/APS-142"
---| "AN/APY-1"
---| "AN/AVQ-23 Pave Spike - Sensor"
---| "AN/VSG-2 day"
---| "AN/VSG-2 night"
---| "ASQ-151"
---| "ATFLIR AN/ASQ-228 CCD TV"
---| "ATFLIR AN/ASQ-228 FLIR"
---| "Abstract RWR"
---| "B-1B SS radar"
---| "B-52H SS radar"
---| "BPK-2-42 day"
---| "BPK-2-42 night"
---| "BRLS-8B"
---| "Berkut-95"
---| "CH 1TPP1 Optic Sight IR"
---| "CH 1TPP1 Optic Sight TV"
---| "CH 2RL80 air"
---| "CH MR-320 Topaz-2V air"
---| "CH MR-320 Topaz-2V surface"
---| "CH OSIRIS Optic Sight IR"
---| "CH OSIRIS Optic Sight TV"
---| "CH Obzor surface"
---| "CH Pozitiv-ME 1.2 air"
---| "CH Pozitiv-ME 1.2 surface"
---| "CH TRML-4D air"
---| "CH Tor M2 air"
---| "CITV day"
---| "CITV night"
---| "CUPOLA_TRIPLEXES"
---| "C_RAM_Phalanx"
---| "Challenger2 sight day"
---| "DS-1"
---| "Deka RWR A"
---| "Deka RWR B"
---| "Deka RWR C"
---| "Dog Ear radar"
---| "EMES 15 day"
---| "EMES 15 night"
---| "FPS-117"
---| "FuMG-401"
---| "FuSe-65"
---| "Gepard"
---| "H-6J FLIR"
---| "H-6J RADAR"
---| "H-6J TV"
---| "HB_ANAPQ_120"
---| "HB_ANAPQ_156"
---| "HL-60 day"
---| "HL-60 night"
---| "HL-70 day"
---| "HL-70 night"
---| "HQ-7 SR"
---| "HQ-7 TR"
---| "HQ-7B IR search visir"
---| "HQ-7B Optic Sight"
---| "HQ-7B search visir"
---| "Harrier GR_5 FLIR"
---| "Hawk sr"
---| "Hawk tr"
---| "IRADS"
---| "ITSS_HIRE_III day"
---| "ITSS_HIRE_III night"
---| "JTAC_sensor"
---| "JTAC_sensor_IR"
---| "JTAC_sensor_LLTV"
---| "KKS R-790 Tsunami-BM"
---| "KLJ-7"
---| "KOLS"
---| "Ka-52 FLIR"
---| "Ka-52 TV"
---| "Kaira-1"
---| "Karat visir"
---| "Kopyo"
---| "Kub 1S91 str"
---| "LANTIRN AAQ-14 FLIR"
---| "Linebacker IR"
---| "Linebacker day"
---| "Litening AN/AAQ-28 CCD TV"
---| "Litening AN/AAQ-28 FLIR"
---| "M151 Protector RWS IR"
---| "M151 Protector RWS day"
---| "M2 sight day"
---| "M2 sight night"
---| "MGS sight day"
---| "MGS sight night"
---| "MP7"
---| "Merkury LLTV"
---| "Mi-28N FLIR"
---| "Mi-28N TV"
---| "Mys-M1_SR"
---| "N-001"
---| "N-005"
---| "N-008"
---| "N-011M"
---| "N-019"
---| "N-019M"
---| "NASAMS_Radar_MPQ64F1"
---| "NNDV day"
---| "NNDV night"
---| "NTS"
---| "OLS-27"
---| "Orion-A"
---| "Osa 9A33 ln"
---| "P14_SR"
---| "PERI-R17A2 day"
---| "PERI-R17A2 night"
---| "PERI-Z11 day"
---| "PG2"
---| "PG2_direct"
---| "PLAN Search Radar A"
---| "PLAN Search Radar B"
---| "PNA-D Leninets"
---| "PPB-2"
---| "PS-37A"
---| "Patriot str"
---| "Poisk"
---| "RDY"
---| "RLS_19J6"
---| "RPC S-200 TR"
---| "RQ-1 Predator CAM"
---| "RQ-1 Predator FLIR"
---| "RQ-1 Predator SAR"
---| "Raduga-Sh"
---| "Raven day"
---| "Raven night"
---| "Roland ADS"
---| "Roland Radar"
---| "Rubidy MM"
---| "S-300PS 40B6M tr"
---| "S-300PS 40B6M tr navy"
---| "S-300PS 40B6MD sr"
---| "S-300PS 64H6E sr"
---| "SA-11 Buk SR 9S18M1"
---| "SA-11 Buk TR"
---| "SOD-1 Optic Sight IR"
---| "SOD-1 Optic Sight TV"
---| "Shilka visir"
---| "Shkval"
---| "Shmel"
---| "Sniper XR CCD TV"
---| "Sniper XR FLIR"
---| "Su-34 FLIR"
---| "TADS DTV"
---| "TADS DVO"
---| "TADS FLIR"
---| "TAS4 TOW day"
---| "TAS4 TOW night"
---| "TIS"
---| "TKN-1S"
---| "TKN-3B day"
---| "TKN-3B night"
---| "TKN-3B_BMP_1 day"
---| "TKN-3B_BMP_1 night"
---| "TKN-4S day"
---| "TKN-4S night"
---| "TNPP220"
---| "TOGS2 night"
---| "TP-23M"
---| "TPKU-2B"
---| "TPN1"
---| "TRP-2A day"
---| "TRP-2A night"
---| "TSH-2-22 day"
---| "TVS"
---| "Tor 9A331"
---| "Tornado GR_4 FLIR"
---| "Tornado SS radar"
---| "Triton_G"
---| "Tunguska optic sight"
---| "VIRTUAL_AUDIO_SENSOR"
---| "VOP-7A"
---| "VS580-10 day"
---| "WMD7 CCD TV"
---| "WMD7 FLIR"
---| "Winglong-1 CAM"
---| "Winglong-1 FLIR"
---| "Winglong-1 SAR"
---| "ZSU-23-4 Shilka"
---| "albatros search radar"
---| "carrier search radar"
---| "generic SAM IR search visir"
---| "generic SAM LL search visir"
---| "generic SAM search visir"
---| "generic tank daysight"
---| "generic tank nightsight"
---| "long-range air defence optics"
---| "long-range naval FLIR"
---| "long-range naval FLIR A"
---| "long-range naval LLTV"
---| "long-range naval LLTV A"
---| "long-range naval optics"
---| "long-range naval optics A"
---| "molniya search radar"
---| "moskva search radar"
---| "neustrashimy search radar"
---| "p-19 s-125 sr"
---| "perry search radar"
---| "piotr velikiy search radar"
---| "rezki search radar"
---| "seasparrow tr"
---| "snr s-125 tr"
---| "son-9 tr"
---| "ticonderoga search radar"
---| "type341 fire control radar"

--- A group's main task as missions write it (`task`), keyed by name.
---@alias DcsId.MainTask
---| "Intercept"
---| "CAP"
---| "Refueling"
---| "AWACS"
---| "Nothing"
---| "AFAC"
---| "Reconnaissance"
---| "Escort"
---| "Fighter Sweep"
---| "SEAD"
---| "Antiship Strike" # Anti-ship Strike
---| "CAS"
---| "Ground Attack"
---| "Pinpoint Strike"
---| "Runway Attack"
---| "Transport"

--- Unit skills as missions write them, `Random` included.
---@alias DcsId.Skill
---| "Average"
---| "Good"
---| "High"
---| "Excellent"
---| "Random"
---| "Player"
---| "Client"

--- Formation ids (`db.FormationID`; `FollowBigFormation` `formationType`), keyed by formation.
---@alias DcsId.FormationId
---| 1 # LINE_ABREAST
---| 2 # TRAIL
---| 3 # WEDGE
---| 4 # ECHELON_RIGHT
---| 5 # ECHELON_LEFT
---| 6 # FINGER_FOUR
---| 7 # SPREAD_FOUR
---| 8 # HEL_WEDGE
---| 9 # HEL_ECHELON
---| 10 # HEL_FRONT
---| 11 # HEL_COLUMN
---| 12 # WW2_BOMBER_ELEMENT
---| 13 # WW2_BOMBER_ELEMENT_HEIGHT
---| 14 # WW2_FIGHTER_VIC
---| 15 # COMBAT_BOX
---| 16 # JAVELIN_DOWN
---| 17 # MODERN_BOMBER_ELEMENT
---| 18 # COMBAT_BOX_OPEN

--- AI option numbers (the Mission Editor's `OptionName`): `Controller.setOption` first argument, `params.name` of an `Option` action.
---@alias DcsTask.OptionName
---| -1 # NO_OPTION
---| 0 # ROE
---| 1 # REACTION_ON_THREAT
---| 3 # RADAR_USING
---| 4 # FLARE_USING
---| 5 # FORMATION
---| 6 # RTB_ON_BINGO
---| 7 # SILENCE
---| 8 # DISPERSE_ON_ATTACK
---| 9 # ALARM_STATE
---| 10 # RTB_ON_OUT_OF_AMMO
---| 11 # AWARNESS_LEVEL
---| 12 # FOLLOWING
---| 13 # ECM_USING
---| 14 # PROHIBIT_AA
---| 15 # PROHIBIT_JETT
---| 16 # PROHIBIT_AB
---| 17 # PROHIBIT_AG
---| 18 # MISSILE_ATTACK
---| 19 # PROHIBIT_WP_PASS_REPORT
---| 20 # ENGAGE_AIR_WEAPONS
---| 21 # RADIO_USAGE_CONTACT
---| 22 # RADIO_USAGE_ENGAGE
---| 23 # RADIO_USAGE_KILL
---| 24 # AIRCRAFT_INTERCEPT_RANGE
---| 25 # JETT_TANKS_IF_EMPTY
---| 26 # FORCED_ATTACK
---| 27 # ALT_RESTRICTION_MIN
---| 28 # RESTRICT_TARGET
---| 29 # ALT_RESTRICTION_MAX
---| 30 # OPTION_SET_COLUMN_INTERVAL
---| 31 # EVASION_OF_ARM
---| 32 # PREFER_VERTICAL
---| 35 # ALLOW_FORMATION_SIDE_SWAP
---| 36 # LANDING_OPTIONS
---| 37 # ALLOW_LINE_UP_RW
---| 38 # DISENGAGE_AND_RTB

--- Values of option ROE (0) for plane, helicopter; keys from the Mission Editor's display names; Mission Editor default `2`.
---@alias DcsTask.OptionValue.ROE_plane_helicopter
---| 0 # WEAPON_FREE
---| 1 # PRIORITY_DESIGNATED
---| 2 # ONLY_DESIGNATED
---| 3 # RETURN_FIRE
---| 4 # WEAPON_HOLD

--- Values of option ROE (0) for vehicle, ship; keys from the Mission Editor's display names; also the scripting API's `AI.Option` values the Mission Editor does not list (OPEN_FIRE); Mission Editor default `0`.
---@alias DcsTask.OptionValue.ROE_vehicle_ship
---| 0 # WEAPON_FREE
---| 3 # RETURN_FIRE
---| 4 # WEAPON_HOLD
---| 2 # OPEN_FIRE

--- Values of option REACTION_ON_THREAT (1); keys from the Mission Editor's display names; Mission Editor default `4`.
---@alias DcsTask.OptionValue.REACTION_ON_THREAT
---| 0 # NO_REACTION
---| 1 # PASSIVE_DEFENCE
---| 2 # EVADE_FIRE
---| 3 # BYPASS_AND_ESCAPE_N_A
---| 4 # ALLOW_ABORT_MISSION
---| 5 # HORIZONTAL_AAA_FIRE_EVADE

--- Values of option RADAR_USING (3); keys from the Mission Editor's display names; Mission Editor default `2`.
---@alias DcsTask.OptionValue.RADAR_USING
---| 0 # NEVER_USE
---| 1 # USE_FOR_ATTACK_ONLY
---| 2 # USE_FOR_SEARCH_IF_REQUIRED
---| 3 # USE_FOR_CONTINUOUS_SEARCH

--- Values of option FLARE_USING (4); keys from the Mission Editor's display names; Mission Editor default `2`.
---@alias DcsTask.OptionValue.FLARE_USING
---| 0 # NEVER_USE
---| 1 # USE_AGAINST_FIRED_MISSILE
---| 2 # USE_WHEN_FLYING_IN_SAM_WEZ
---| 3 # USE_WHEN_FLYING_NEAR_ENEMIES_N_A

--- Values of option FORMATION (5) for plane: formation index << 16 | side (0 right, 1 left) << 8 | variant, as the Mission Editor writes them; keys from the formations series.
---@alias DcsTask.OptionValue.FORMATION_plane
---| 65537 # LINE_ABREAST_CLOSE
---| 65538 # LINE_ABREAST_OPEN
---| 65539 # LINE_ABREAST_GROUP_CLOSE
---| 131073 # TRAIL_CLOSE
---| 131074 # TRAIL_OPEN
---| 131075 # TRAIL_GROUP_CLOSE
---| 196609 # WEDGE_CLOSE
---| 196610 # WEDGE_OPEN
---| 196611 # WEDGE_GROUP_CLOSE
---| 262145 # ECHELON_RIGHT_CLOSE
---| 262146 # ECHELON_RIGHT_OPEN
---| 262147 # ECHELON_RIGHT_GROUP_CLOSE
---| 327681 # ECHELON_LEFT_CLOSE
---| 327682 # ECHELON_LEFT_OPEN
---| 327683 # ECHELON_LEFT_GROUP_CLOSE
---| 393217 # FINGER_FOUR_CLOSE
---| 393218 # FINGER_FOUR_OPEN
---| 393219 # FINGER_FOUR_GROUP_CLOSE
---| 458753 # SPREAD_FOUR_CLOSE
---| 458754 # SPREAD_FOUR_OPEN
---| 458755 # SPREAD_FOUR_GROUP_CLOSE
---| 786433 # WW2_BOMBER_ELEMENT_CLOSE
---| 786434 # WW2_BOMBER_ELEMENT_OPEN
---| 851968 # WW2_BOMBER_ELEMENT_HEIGHT
---| 917505 # WW2_FIGHTER_VIC_CLOSE
---| 917506 # WW2_FIGHTER_VIC_OPEN
---| 1114113 # MODERN_BOMBER_ELEMENT_CLOSE
---| 1114114 # MODERN_BOMBER_ELEMENT_OPEN

--- Values of option FORMATION (5) for helicopter: formation index << 16 | side (0 right, 1 left) << 8 | variant, as the Mission Editor writes them; keys from the formations series.
---@alias DcsTask.OptionValue.FORMATION_helicopter
---| 524288 # HEL_WEDGE
---| 589825 # HEL_ECHELON_50X70_RIGHT
---| 590081 # HEL_ECHELON_50X70_LEFT
---| 589826 # HEL_ECHELON_50X300_RIGHT
---| 590082 # HEL_ECHELON_50X300_LEFT
---| 589827 # HEL_ECHELON_50X600_RIGHT
---| 590083 # HEL_ECHELON_50X600_LEFT
---| 655361 # HEL_FRONT_INTERVAL_300_RIGHT
---| 655617 # HEL_FRONT_INTERVAL_300_LEFT
---| 655362 # HEL_FRONT_INTERVAL_600_RIGHT
---| 655618 # HEL_FRONT_INTERVAL_600_LEFT
---| 720896 # HEL_COLUMN

--- Values of option FORMATION (5) for big_formations: formation index << 16 | side (0 right, 1 left) << 8 | variant, as the Mission Editor writes them; keys from the formations series.
---@alias DcsTask.OptionValue.FORMATION_big_formations
---| 983040 # COMBAT_BOX
---| 983041 # COMBAT_BOX_POSITION_IN_BOX
---| 983042 # COMBAT_BOX_POSITION_IN_GROUP
---| 983043 # COMBAT_BOX_POSITION_IN_WING
---| 1048576 # JAVELIN_DOWN
---| 1048577 # JAVELIN_DOWN_POSITION_IN_SQUAD
---| 1048578 # JAVELIN_DOWN_POSITION_IN_GROUP
---| 1048579 # JAVELIN_DOWN_POSITION_IN_WING
---| 1179648 # COMBAT_BOX_OPEN
---| 1179649 # COMBAT_BOX_OPEN_POSITION_IN_BOX
---| 1179650 # COMBAT_BOX_OPEN_POSITION_IN_GROUP
---| 1179651 # COMBAT_BOX_OPEN_POSITION_IN_WING

--- Values of option RTB_ON_BINGO (6); keys from the Mission Editor's display names; Mission Editor default true.
---@alias DcsTask.OptionValue.RTB_ON_BINGO
---| false # NO_RTB_ON_BINGO
---| true # AAR_REFUEL_OR_RTB
---| 2 # RTB_ON_BINGO_IGNORE_AAR

--- Values of option ALARM_STATE (9) for vehicle, ship; keys from the Mission Editor's display names; Mission Editor default `0`.
---@alias DcsTask.OptionValue.ALARM_STATE
---| 0 # AUTO
---| 1 # GREEN_STATE
---| 2 # RED_STATE

--- Values of option RTB_ON_OUT_OF_AMMO (10); keys from the Mission Editor's display names; Mission Editor default `0`.
---@alias DcsTask.OptionValue.RTB_ON_OUT_OF_AMMO
---| 0 # NO_WEAPON
---| 4294967295 # ALL
---| 805339120 # UNGUIDED
---| 805306368 # CANNONS
---| 30720 # ROCKETS
---| 2048 # LIGHT_ROCKETS
---| 16384 # HEAVY_ROCKETS
---| 2032 # BOMBS
---| 240 # IRON_BOMBS
---| 768 # CLUSTER_BOMBS
---| 1024 # CANDLE_BOMBS
---| 4294967296 # TORPEDOES
---| 268402702 # GUIDED
---| 14 # GUIDED_BOMBS
---| 268402688 # MISSILES
---| 4161536 # ASM
---| 131072 # ATGM
---| 1835008 # STANDARD_ASM
---| 32768 # ARM
---| 65536 # ANTISHIP_MISSILES
---| 2097152 # CRUISE_MISSILES
---| 264241152 # AAM
---| 4194304 # SR_AAM
---| 8388608 # MR_AAM
---| 16777216 # LR_AAM

--- Values of option AWARNESS_LEVEL (11); keys from the Mission Editor's display names; Mission Editor default `1`.
---@alias DcsTask.OptionValue.AWARNESS_LEVEL
---| 0 # SAFE
---| 1 # AWARE
---| 2 # DANGER

--- Values of option ECM_USING (13); keys from the Mission Editor's display names; Mission Editor default `1`.
---@alias DcsTask.OptionValue.ECM_USING
---| 0 # NEVER_USE
---| 1 # USE_IF_ONLY_LOCK_BY_RADAR
---| 2 # USE_IF_DETECTED_OR_LOCK_BY_RADAR
---| 3 # ALWAYS_USE

--- Values of option MISSILE_ATTACK (18); keys from the Mission Editor's display names; Mission Editor default `3`.
---@alias DcsTask.OptionValue.MISSILE_ATTACK
---| 0 # MAX_RANGE_LAUNCH
---| 1 # NO_ESCAPE_ZONE_LAUNCH
---| 2 # HALF_WAY_MAX_RANGE_NO_ESCAPE_ZONE_LAUNCH
---| 3 # LAUNCH_BY_TARGET_THREAT_ESTIMATE
---| 4 # RANDOM_BETWEEN_MAX_RANGE_AND_NO_ESCAPE_ZONE_LAUNCH

--- Values of option RESTRICT_TARGET (28); keys from the Mission Editor's display names; Mission Editor default `0`.
---@alias DcsTask.OptionValue.RESTRICT_TARGET
---| 0 # ENGAGE_ALL_UNITS
---| 1 # ENGAGE_AIR_UNITS_ONLY
---| 2 # ENGAGE_GROUND_UNIT_ONLY

--- Values of option LANDING_OPTIONS (36); keys from the Mission Editor's display names; Mission Editor default `0`.
---@alias DcsTask.OptionValue.LANDING_OPTIONS
---| 0 # STRAIGHT_IN_LANDING
---| 1 # FORCE_PAIR_LANDING
---| 2 # RESTRICT_PAIR_LANDING
---| 3 # OVERHEAD_BREAK

--- Parameters of `Aerobatics`.
---@class DcsTask.Task.AerobaticsParams
---@field maneuversParams? table Seen in: missions. Set by 377 of 1173 install mission uses.
---@field maneuversSequency? table Seen in: panel, missions. Set by 1173 of 1173 install mission uses.

--- Parameters of `AttachTrailer`.
---@class DcsTask.Task.AttachTrailerParams
---@field onStartMission? boolean Seen in: default, panel. Mission Editor default: false.
---@field unitIdTractor? any Seen in: panel.
---@field unitIdTrailer? any Seen in: panel.

--- Parameters of `CargoTransportation`.
---@class DcsTask.Task.CargoTransportationParams
---@field groupId? number Seen in: declared, panel, missions. Set by 9 of 9 install mission uses.
---@field unitId? number Seen in: missions. Set by 9 of 9 install mission uses.
---@field unitIdTransport? number Seen in: declared, panel, missions. Set by 2 of 9 install mission uses.
---@field x? number Seen in: missions. Set by 1 of 9 install mission uses.
---@field y? number Seen in: missions. Set by 1 of 9 install mission uses.
---@field zoneId? number Seen in: declared, panel, missions. Set by 9 of 9 install mission uses.

--- Parameters of `CargoTransportationPlane`.
---@class DcsTask.Task.CargoTransportationPlaneParams
---@field groupId? number Seen in: declared, panel, missions. Set by 72 of 82 install mission uses.
---@field unitId? number Seen in: missions. Set by 72 of 82 install mission uses.
---@field unitIdTransport? number Seen in: declared, panel, missions. Set by 66 of 82 install mission uses.
---@field x? number Seen in: panel, missions. Set by 72 of 82 install mission uses.
---@field y? number Seen in: panel, missions. Set by 72 of 82 install mission uses.
---@field zoneRadius? any Seen in: panel.

--- Parameters of `CargoUnloadPlane`.
---@class DcsTask.Task.CargoUnloadPlaneParams
---@field groupId? number Seen in: declared, panel, missions. Set by 5 of 6 install mission uses.
---@field unitId? number Seen in: missions. Set by 5 of 6 install mission uses.

--- Parameters of `DetachTrailer`.
---@class DcsTask.Task.DetachTrailerParams
---@field unitIdTractor? any Seen in: panel.
---@field x? any Seen in: panel.
---@field y? any Seen in: panel.

--- Parameters of `Disembarking`.
---@class DcsTask.Task.DisembarkingParams
---@field groupsForEmbarking? table Seen in: default, panel, missions. Mission Editor default: a table. Set by 77 of 77 install mission uses.
---@field x? number Seen in: panel, missions. Set by 77 of 77 install mission uses.
---@field y? number Seen in: panel, missions. Set by 77 of 77 install mission uses.

--- Parameters of `Embarking`.
---@class DcsTask.Task.EmbarkingParams
---@field distribution? table Seen in: default, panel, missions. Mission Editor default: a table. Set by 82 of 82 install mission uses.
---@field distributionFlag? boolean Seen in: default, panel, missions. Mission Editor default: false. Set by 82 of 82 install mission uses.
---@field duration? number Seen in: default, panel, missions. Mission Editor default: `300`. Set by 82 of 82 install mission uses.
---@field durationFlag? boolean Seen in: default, panel, missions. Mission Editor default: false. Set by 82 of 82 install mission uses.
---@field groupsForEmbarking? table Seen in: default, panel, missions. Mission Editor default: a table. Set by 82 of 82 install mission uses.
---@field onStartMission? boolean Seen in: default, panel, missions. Mission Editor default: false. Set by 71 of 82 install mission uses.
---@field selectedTransport? number Seen in: panel, missions. Set by 69 of 82 install mission uses.
---@field x? number Seen in: panel, missions. Set by 82 of 82 install mission uses.
---@field y? number Seen in: panel, missions. Set by 82 of 82 install mission uses.

--- Parameters of `ExternalCargoLoad`.
---@class DcsTask.Task.ExternalCargoLoadParams
---@field groupId? any Seen in: declared, panel.
---@field unitIdTransport? any Seen in: declared, panel.

--- Parameters of `ExternalCargoUnLoad`.
---@class DcsTask.Task.ExternalCargoUnLoadParams
---@field groupId? any Seen in: declared.
---@field unitIdTransport? any Seen in: declared, panel.
---@field zoneId? any Seen in: declared, panel.

--- Parameters of `FarpSpawn`.
---@class DcsTask.Task.FarpSpawnParams
---@field callsign_id? number Seen in: default. Mission Editor default: `1`.
---@field frequency? number Seen in: default. Mission Editor default: `127.5`.
---@field preset? number Seen in: default. Mission Editor default: `1`.

--- Parameters of `GoToWaypoint`.
---@class DcsTask.Task.GoToWaypointParams
---@field fromWaypointIndex? number Seen in: panel, missions. Set by 2031 of 2107 install mission uses.
---@field nWaypointIndx? number Seen in: panel, missions. Set by 2107 of 2107 install mission uses.

--- Parameters of `Hold`.
---@class DcsTask.Task.HoldParams
---@field templateId? string Seen in: default, panel, missions. Mission Editor default: `""`. Set by 1375 of 1403 install mission uses. Install mission values: `""` (1374), `"Tank Platoon Line"` (1).

--- Parameters of `NoTask`.
---@class DcsTask.Task.NoTaskParams

--- Parameters of `ParatroopersDrop`.
---@class DcsTask.Task.ParatroopersDropParams
---@field altitude? any Seen in: panel.
---@field altitudeEdited? any Seen in: panel.
---@field altitudeEnabled? any Seen in: panel.
---@field attackQty? number Seen in: default. Mission Editor default: `1`.
---@field attackQtyLimit? boolean Seen in: default. Mission Editor default: false.
---@field attackType? "Carpet"|"Dive"|"Toss"|string Seen in: default. Mission Editor default: `"Carpet"`.
---@field carpetLength? number Seen in: default. Mission Editor default: `500`.
---@field groupAttack? boolean Seen in: default. Mission Editor default: false.
---@field groupsOnBoard? table Seen in: default, panel. Mission Editor default: a table.
---@field scriptFileName? string Seen in: default, panel. Mission Editor default: `""`.
---@field x? any Seen in: panel.
---@field y? any Seen in: panel.

--- Parameters of `Refueling`.
---@class DcsTask.Task.RefuelingParams

--- Parameters of `ShipHoldPoint`.
---@class DcsTask.Task.ShipHoldPointParams

--- Task ids as the Mission Editor writes them (DCS casing).
---@alias DcsTask.TaskId
---| "Aerobatics"
---| "AttachTrailer"
---| "AttackGroup"
---| "AttackMapObject"
---| "AttackUnit"
---| "Barcap"
---| "Bombing"
---| "BombingRunway"
---| "CargoTransportation"
---| "CargoTransportationPlane"
---| "CargoUnloadPlane"
---| "CarpetBombing"
---| "DetachTrailer"
---| "Disembarking"
---| "EmbarkToTransport"
---| "Embarking"
---| "Escort"
---| "ExternalCargoLoad"
---| "ExternalCargoUnLoad"
---| "FAC_AttackGroup"
---| "FarpSpawn"
---| "FireAtPoint"
---| "Follow"
---| "FollowBigFormation"
---| "GoToWaypoint"
---| "GroundEscort"
---| "Hold"
---| "Land"
---| "NoTask"
---| "Orbit"
---| "ParatroopersDrop"
---| "RecoveryTanker"
---| "Refueling"
---| "ShipHoldPoint"
---| "Strafing"
---| "TossAttack"

--- Parameters of `AWACS`.
---@class DcsTask.EnrouteTask.AWACSParams

--- Parameters of `EWR`.
---@class DcsTask.EnrouteTask.EWRParams
---@field callname? number Seen in: panel, missions. Set by 210 of 1402 install mission uses.
---@field callsign? any Seen in: panel.
---@field number? number Seen in: panel, missions. Set by 210 of 1402 install mission uses.

--- Mission Editor variant keys of `EngageTargets`.
---@alias DcsTask.EnrouteTask.EngageTargetsKey
---| "AntiShip"
---| "CAP"
---| "CAS"
---| "FighterSweep"
---| "SEAD"

--- Parameters of `NoTask`.
---@class DcsTask.EnrouteTask.NoTaskParams

--- Parameters of `Tanker`.
---@class DcsTask.EnrouteTask.TankerParams

--- En-route task ids as the Mission Editor writes them (DCS casing).
---@alias DcsTask.EnrouteTaskId
---| "AWACS"
---| "EWR"
---| "EngageGroup"
---| "EngageTargets"
---| "EngageTargetsInZone"
---| "EngageUnit"
---| "FAC"
---| "FAC_EngageGroup"
---| "NoTask"
---| "Tanker"

--- Parameters of `ActivateACLS`.
---@class DcsTask.Command.ActivateACLSParams
---@field name? string Name of the ACLS (label only). Seen in: panel, missions. Set by 53 of 86 install mission uses. Install mission values: `"TR"` (21), `"JCS"` (8), `"ALN"` (5), `"USS Valley Forge"` (5), `"ACLS"` (4), `"AVF"` (4), `"ACLS VF"` (2), `"GW"` (2), `"VF"` (1), `"VLF"` (1).
---@field unitId? number ID of the ship unit that will provide the ACLS functionality (requires carrier with appropriate systems). Seen in: panel, missions. Set by 86 of 86 install mission uses.

--- Parameters of `ActivateGCI`.
---@class DcsTask.Command.ActivateGCIParams
---@field channel? number Seen in: makeParams, panel, missions. Set by 41 of 41 install mission uses.
---@field radius? number Seen in: makeParams, panel, missions. Set by 41 of 41 install mission uses.
---@field unitId? number Seen in: makeParams, panel, missions. Set by 41 of 41 install mission uses.
---@field x? number Seen in: makeParams, panel, missions. Set by 41 of 41 install mission uses.
---@field y? number Seen in: makeParams, panel, missions. Set by 41 of 41 install mission uses.

--- Parameters of `ActivateJammer`.
---@class DcsTask.Command.ActivateJammerParams
---@field glonassSpoofing? number Seen in: default, panel. Mission Editor default: `0`.
---@field gpsSpoofing? number Seen in: default, panel. Mission Editor default: `0`.
---@field jammingEnd? number Seen in: default, panel. Mission Editor default: `120`.
---@field jammingStart? number Seen in: default, panel. Mission Editor default: `120`.
---@field radioJamming? number Seen in: default, panel. Mission Editor default: `0`.
---@field x? any Seen in: panel.
---@field y? any Seen in: panel.

--- Parameters of `ActivateLink4`.
---@class DcsTask.Command.ActivateLink4Params
---@field frequency? number Operating frequency in Hertz for the data link communications. Seen in: panel, missions. Set by 148 of 148 install mission uses.
---@field name? string Name of the Link 4 system (label only). Seen in: panel, missions. Set by 51 of 148 install mission uses. Install mission values: `"TR"` (19), `"JCS"` (8), `"VF"` (7), `"ALN"` (5), `"USS Valley Forge"` (5), `"GW"` (2), `"L4"` (2), `"L4 VF"` (1), `"Link4"` (1), `"VFL4"` (1).
---@field unitId? number ID of the ship unit that will broadcast the Link 4 signal (must have Link 4 capability). Seen in: panel, missions. Set by 148 of 148 install mission uses.

--- Parameters of `ActivateRSBN`.
---@class DcsTask.Command.ActivateRSBNParams
---@field callsign? string Seen in: default, makeParams, panel, missions. Mission Editor default: `"TKR"`. Set by 2228 of 2228 install mission uses.
---@field channel? number Seen in: default, makeParams, panel, missions. Mission Editor default: `1`. Set by 2228 of 2228 install mission uses.

--- Parameters of `DeactivateACLS`.
---@class DcsTask.Command.DeactivateACLSParams

--- Parameters of `DeactivateBeacon`.
---@class DcsTask.Command.DeactivateBeaconParams

--- Parameters of `DeactivateGCI`.
---@class DcsTask.Command.DeactivateGCIParams

--- Parameters of `DeactivateICLS`.
---@class DcsTask.Command.DeactivateICLSParams

--- Parameters of `DeactivateJammer`.
---@class DcsTask.Command.DeactivateJammerParams

--- Parameters of `DeactivateLink4`.
---@class DcsTask.Command.DeactivateLink4Params

--- Parameters of `DeactivateRSBN`.
---@class DcsTask.Command.DeactivateRSBNParams

--- Parameters of `EPLRS`.
---@class DcsTask.Command.EPLRSParams
---@field groupId? number Track number assigned to the first unit in the group (only relevant for ground vehicle groups). Seen in: default, makeParams, missions. Mission Editor default: `0`. Set by 14891 of 14891 install mission uses.
---@field value? boolean EPLRS state where true activates the data link, false deactivates it. Seen in: default, missions. Mission Editor default: true. Set by 14891 of 14891 install mission uses.

--- Parameters of `LoadingShip`.
---@class DcsTask.Command.LoadingShipParams
---@field cargo? number Cargo load percentage (0-100) determining how much the ship sits in water (lower values raise the waterline). Seen in: default, panel, missions. Mission Editor default: `0`. Set by 1339 of 1339 install mission uses.
---@field unitId? number ID of the ship unit whose cargo load level will be modified. Seen in: panel, missions. Set by 1339 of 1339 install mission uses.

--- Parameters of `NoAction`.
---@class DcsTask.Command.NoActionParams

--- Parameters of `SMOKE_ON_OFF`.
---@class DcsTask.Command.SMOKE_ON_OFFParams
---@field value? boolean Smoke state where true activates smoke emission, false deactivates it. Seen in: default, missions. Mission Editor default: true. Set by 65 of 65 install mission uses.

--- Parameters of `Script`.
---@class DcsTask.Command.ScriptParams
---@field command? string Lua code string to be executed within the group's context. Seen in: default, panel, missions. Mission Editor default: `""`. Set by 468 of 468 install mission uses.

--- Parameters of `ScriptFile`.
---@class DcsTask.Command.ScriptFileParams
---@field file? string Seen in: default, panel. Mission Editor default: `""`.

--- Parameters of `SetImmortal`.
---@class DcsTask.Command.SetImmortalParams
---@field value? boolean Immortality state where true makes the group immune to all damage, false restores normal vulnerability. Seen in: default, missions. Mission Editor default: true. Set by 2850 of 2850 install mission uses.

--- Parameters of `SetUnlimitedFuel`.
---@class DcsTask.Command.SetUnlimitedFuelParams
---@field value? boolean Fuel state where true prevents fuel depletion during operation, false restores normal fuel consumption. Seen in: default, missions. Mission Editor default: true. Set by 509 of 509 install mission uses.

--- Parameters of `Start`.
---@class DcsTask.Command.StartParams

--- Parameters of `StopRoute`.
---@class DcsTask.Command.StopRouteParams
---@field value? boolean true halts the group in place, false resumes its route. Seen in: scripts.

--- Parameters of `StopTransmission`.
---@class DcsTask.Command.StopTransmissionParams

--- Parameters of `SwitchAction`.
---@class DcsTask.Command.SwitchActionParams
---@field actionIndex? number Index of the target action in the group's task queue to make active. Seen in: default, panel. Mission Editor default: `1`.

--- Parameters of `SwitchWaypoint`.
---@class DcsTask.Command.SwitchWaypointParams
---@field fromWaypointIndex? number Index of the waypoint where the group will begin its new route leg. Seen in: panel, missions. Set by 5863 of 7585 install mission uses.
---@field goToWaypointIndex? number Index of the destination waypoint the group will navigate toward. Seen in: panel, missions. Set by 7585 of 7585 install mission uses.

--- Parameters of `TransmitMessage`.
---@class DcsTask.Command.TransmitMessageParams
---@field duration? number Display time in seconds for the message subtitles (ignored when loop is true). Seen in: default, panel, missions. Mission Editor default: `5`. Set by 23976 of 23976 install mission uses.
---@field file? string Path to the sound file that will be played as the radio transmission. Seen in: default, panel, missions. Mission Editor default: `""`. Set by 23976 of 23976 install mission uses.
---@field loop? boolean Transmission mode where true causes the message to repeat continuously until stopped. Seen in: default, panel, missions. Mission Editor default: false. Set by 23976 of 23976 install mission uses.
---@field subtitle? string Text displayed in the radio message queue representing the transmission content. Seen in: default, panel, missions. Mission Editor default: `""`. Set by 23929 of 23976 install mission uses.

--- Command ids as the Mission Editor writes them (DCS casing).
---@alias DcsTask.CommandId
---| "ActivateACLS"
---| "ActivateBeacon"
---| "ActivateGCI"
---| "ActivateICLS"
---| "ActivateJammer"
---| "ActivateLink4"
---| "ActivateRSBN"
---| "DeactivateACLS"
---| "DeactivateBeacon"
---| "DeactivateGCI"
---| "DeactivateICLS"
---| "DeactivateJammer"
---| "DeactivateLink4"
---| "DeactivateRSBN"
---| "EPLRS"
---| "LoadingShip"
---| "NoAction"
---| "SMOKE_ON_OFF"
---| "Script"
---| "ScriptFile"
---| "SetCallsign"
---| "SetFrequency"
---| "SetFrequencyForUnit"
---| "SetImmortal"
---| "SetInvisible"
---| "SetUnlimitedFuel"
---| "Start"
---| "StopRoute"
---| "StopTransmission"
---| "SwitchAction"
---| "SwitchWaypoint"
---| "TransmitMessage"

--- Defines the structure of a Lua table detailing conditions that must be met for a task to start.
--- (Data structure definition for ControlledTaskCondition. Not a globally accessible table.)
---@class ControlledTaskCondition
---@field time? number Time in seconds since mission start when the task should begin.
---@field userFlag? string Flag identifier to check for task activation.
---@field userFlagValue? boolean Required value of the user flag to activate the task.
---@field probability? number Probability (0-100) that the task will execute when conditions are met.

--- Defines the structure of a Lua table detailing conditions that will trigger task termination.
--- (Data structure definition for ControlledTaskStopCondition. Not a globally accessible table.)
---@class ControlledTaskStopCondition
---@field time? number Time in seconds since mission start when the task should terminate.
---@field userFlag? string Flag identifier to check for task termination.
---@field userFlagValue? boolean Required value of the user flag to terminate the task.
---@field duration? number Duration in seconds that the task will run before terminating.
---@field lastWaypoint? number Waypoint number that, when reached, will terminate the task.

--- Defines the structure of a Lua table detailing the collection of tasks to be executed as part of a combination.
--- (Data structure definition for ComboTaskParams. Not a globally accessible table.)
---@class ComboTaskParams
---@field tasks table A numerically indexed table of task objects to be executed.

--- Represents all Objects those may belong to a coalition: units, airbases, static objects, weapon. Non-final class.
--- (Data structure definition for CoalitionObject. Not a globally accessible table.)
--- Since DCS 1.2.4.
---@class CoalitionObject
---@field getCoalition? function Returns an enumerator that defines the coalition that an object currently belongs to.
---@field getCountry? function Returns an enumerator that defines the country that an object currently belongs to.

Object.Category = Object.Category or {}
--- Defines the fundamental categories of objects in the DCS World environment.
---@enum Object.Category
Object.Category = {
    VOID = 0,
    UNIT = 1,
    WEAPON = 2,
    STATIC = 3,
    BASE = 4,
    SCENERY = 5,
    CARGO = 6
}

--- Defines the structure of a table containing attribute flags for an object. Each field (a `DcsId.Attribute`) is a boolean indicating whether the object has that specific attribute.
--- (Data structure definition for ObjectAttributes. Not a globally accessible table.)
---@class ObjectAttributes

StaticObject.Category = StaticObject.Category or {}
--- Defines the categories of static objects in the DCS World environment.
---@enum StaticObject.Category
StaticObject.Category = {
    VOID = 0,
    UNIT = 1,
    WEAPON = 2,
    STATIC = 3,
    BASE = 4,
    SCENERY = 5,
    CARGO = 6
}

radio.modulation = radio.modulation or {}
--- Enumerator for radio modulations: the `modulation` of AI tasks and commands such as `SetFrequency`.
---@enum radio.modulation
radio.modulation = {
    AM = 0,
    FM = 1
}

Spot.Category = Spot.Category or {}
--- Defines the types of targeting beams available in the DCS World environment.
---@enum Spot.Category
Spot.Category = {
    INFRA_RED = 0,
    LASER = 1
}

world.BirthPlace = world.BirthPlace or {}
--- Enumerator for aircraft and helicopter spawn locations, used in birth events.
---@enum world.BirthPlace
world.BirthPlace = {
    wsBirthPlace_Air = 1,
    wsBirthPlace_RunWay = 4,
    wsBirthPlace_Park = 5,
    wsBirthPlace_Heliport_Hot = 10,
    wsBirthPlace_Heliport_Cold = 11,
    wsBirthPlace_Ship = 3,
    wsBirthPlace_Ship_Hot = 13,
    wsBirthPlace_Ship_Cold = 12
}

world.VolumeType = world.VolumeType or {}
--- Enumerator for 3D volume types used in spatial queries within the DCS World.
---@enum world.VolumeType
world.VolumeType = {
    SEGMENT = 0,
    BOX = 1,
    SPHERE = 2,
    PYRAMID = 3
}

world.event = world.event or {}
--- Enumerator for event types that occur during mission execution in the DCS World.
--- Since DCS 1.2.0.
---@enum world.event
world.event = {
    S_EVENT_INVALID = 0,
    S_EVENT_SHOT = 1,
    S_EVENT_HIT = 2,
    S_EVENT_TAKEOFF = 3,
    S_EVENT_LAND = 4,
    S_EVENT_CRASH = 5,
    S_EVENT_EJECTION = 6,
    S_EVENT_REFUELING = 7,
    S_EVENT_DEAD = 8,
    S_EVENT_PILOT_DEAD = 9,
    S_EVENT_BASE_CAPTURED = 10,
    S_EVENT_MISSION_START = 11,
    S_EVENT_MISSION_END = 12,
    S_EVENT_TOOK_CONTROL = 13,
    S_EVENT_REFUELING_STOP = 14,
    S_EVENT_BIRTH = 15,
    S_EVENT_HUMAN_FAILURE = 16,
    S_EVENT_DETAILED_FAILURE = 17,
    S_EVENT_ENGINE_STARTUP = 18,
    S_EVENT_ENGINE_SHUTDOWN = 19,
    S_EVENT_PLAYER_ENTER_UNIT = 20,
    S_EVENT_PLAYER_LEAVE_UNIT = 21,
    S_EVENT_PLAYER_COMMENT = 22,
    S_EVENT_SHOOTING_START = 23,
    S_EVENT_SHOOTING_END = 24,
    S_EVENT_MARK_ADDED = 25,
    S_EVENT_MARK_CHANGE = 26,
    S_EVENT_MARK_REMOVED = 27,
    S_EVENT_KILL = 28,
    S_EVENT_SCORE = 29,
    S_EVENT_UNIT_LOST = 30,
    S_EVENT_LANDING_AFTER_EJECTION = 31,
    S_EVENT_PARATROOPER_LENDING = 32,
    S_EVENT_DISCARD_CHAIR_AFTER_EJECTION = 33,
    S_EVENT_WEAPON_ADD = 34,
    S_EVENT_TRIGGER_ZONE = 35,
    S_EVENT_LANDING_QUALITY_MARK = 36,
    S_EVENT_BDA = 37,
    S_EVENT_AI_ABORT_MISSION = 38,
    S_EVENT_DAYNIGHT = 39,
    S_EVENT_FLIGHT_TIME = 40,
    S_EVENT_PLAYER_SELF_KILL_PILOT = 41,
    S_EVENT_PLAYER_CAPTURE_AIRFIELD = 42,
    S_EVENT_EMERGENCY_LANDING = 43,
    S_EVENT_UNIT_CREATE_TASK = 44,
    S_EVENT_UNIT_DELETE_TASK = 45,
    S_EVENT_SIMULATION_START = 46,
    S_EVENT_WEAPON_REARM = 47,
    S_EVENT_WEAPON_DROP = 48,
    S_EVENT_UNIT_TASK_COMPLETE = 49,
    S_EVENT_UNIT_TASK_STAGE = 50,
    S_EVENT_MAC_EXTRA_SCORE = 51,
    S_EVENT_MISSION_RESTART = 52,
    S_EVENT_MISSION_WINNER = 53,
    S_EVENT_RUNWAY_TAKEOFF = 54,
    S_EVENT_RUNWAY_TOUCH = 55,
    S_EVENT_MAC_LMS_RESTART = 56,
    S_EVENT_SIMULATION_FREEZE = 57,
    S_EVENT_SIMULATION_UNFREEZE = 58,
    S_EVENT_HUMAN_AIRCRAFT_REPAIR_START = 59,
    S_EVENT_HUMAN_AIRCRAFT_REPAIR_FINISH = 60,
    S_EVENT_GROUP_CHANGE_OPTION = 61,
    S_EVENT_MAX = 62
}

land.SurfaceType = land.SurfaceType or {}
--- Defines terrain surface types in the DCS World environment.
---@enum land.SurfaceType
land.SurfaceType = {
    LAND = 1,
    SHALLOW_WATER = 2,
    WATER = 3,
    ROAD = 4,
    RUNWAY = 5
}

env.Mode = env.Mode or {}
--- Enumerator for mission execution lifecycle states, used to determine the current operational phase of a mission in the DCS World environment.
---@enum env.Mode
env.Mode = {
    INIT = 0,
    USER = 1,
    START = 2,
    SIMULATION = 4,
    STOP = 5,
    FINISH = 6
}

Group.Category = Group.Category or {}
--- Enumerator for group categories, used to classify different types of unit collections in the DCS World environment.
---@enum Group.Category
Group.Category = {
    AIRPLANE = 0,
    HELICOPTER = 1,
    GROUND = 2,
    SHIP = 3,
    TRAIN = 4
}

Controller.Detection = Controller.Detection or {}
--- Enumerator for detection method types, used to specify or filter how controllers detect targets in the DCS World environment.
---@enum Controller.Detection
Controller.Detection = {
    VISUAL = 1,
    OPTIC = 2,
    RADAR = 4,
    IRST = 8,
    RWR = 16,
    DLINK = 32
}

--- Enumerator for liquid fuel types, used to specify particular fuels within a `Warehouse` inventory.
---@alias LiquidType
---| 0 # jetfuel
---| 1 # Aviation_gasoline
---| 2 # MW50
---| 3 # Diesel

Airbase.Category = Airbase.Category or {}
--- Enumerator for airbase category types.
---@enum Airbase.Category
Airbase.Category = {
    AIRDROME = 0,
    HELIPAD = 1,
    SHIP = 2
}

--- Information about an airbase parking spot.
--- (Data structure definition for AirbaseParking. Not a globally accessible table.)
---@class AirbaseParking
---@field Term_Type? number Terminal type identifier.
---@field Term_Index? number Terminal index number.
---@field Term_Index_0? number Alternative terminal index.
---@field Term_Details? table Additional details about the terminal.

--- Detailed information about an airbase.
--- (Data structure definition for AirbaseDesc. Not a globally accessible table.)
---@class AirbaseDesc
---@field category? number Category identifier of the airbase.
---@field id? number Unique identifier for the airbase.
---@field callsign? string Radio callsign of the airbase.
---@field display_name? string Human-readable name of the airbase.

--- Defines the structure of a Lua table containing information about a player-controllable slot in a mission, including its unit ID, type, role, and other identifying data.
--- (Data structure definition for DCSAvailableSlotInfo. Not a globally accessible table.)
--- Since DCS 1.2.0.
---@class DCSAvailableSlotInfo

coalition.side = coalition.side or {}
--- Enumerator for coalition sides, used to identify the different factions in the DCS World environment.
---@enum coalition.side
coalition.side = {
    NEUTRAL = 0,
    RED = 1,
    BLUE = 2
}

coalition.service = coalition.service or {}
--- Enumerator for coalition service types, used to categorize radio communication services available to each faction.
---@enum coalition.service
coalition.service = {
    ATC = 0,
    AWACS = 1,
    TANKER = 2,
    FAC = 3,
    MAX = 4
}

--- Parameters of `Land`.
---@class DcsTask.Task.LandParams
---@field combatLandingFlag? boolean Seen in: default, panel, missions. Mission Editor default: false. Set by 86 of 640 install mission uses.
---@field direction? number Seen in: panel, missions. Set by 90 of 640 install mission uses.
---@field directionEnabled? boolean Seen in: panel, missions. Set by 90 of 640 install mission uses.
---@field duration? number Time in seconds that the helicopter will remain landed before automatically taking off if durationFlag is true. Seen in: default, panel, missions. Mission Editor default: `300`. Set by 640 of 640 install mission uses.
---@field durationFlag? boolean Determines whether the helicopter will remain on the ground for a specific duration before taking off again. Seen in: default, panel, missions. Mission Editor default: false. Set by 640 of 640 install mission uses.
---@field point? Vec2 A `Vec2` representing the landing coordinates in the DCS World coordinate system where the helicopter will attempt to touch down. Hand-authored (overlays.yaml): in no Mission Editor default or source, DCS script or install mission. Either `point` or `x`/`y`; which one DCS reads is unconfirmed (the Mission Editor writes `x`/`y`).
---@field x? number Seen in: panel, missions. Set by 640 of 640 install mission uses. Either `point` or `x`/`y`; which one DCS reads is unconfirmed (the Mission Editor writes `x`/`y`).
---@field y? number Seen in: panel, missions. Set by 640 of 640 install mission uses. Either `point` or `x`/`y`; which one DCS reads is unconfirmed (the Mission Editor writes `x`/`y`).

--- Represents a numerically indexed Lua table (sequence) of `Vec2` points in the DCS World coordinate system.
---@alias Vec2Array Vec2[]

--- Information about an airbase runway.
--- (Data structure definition for AirbaseRunway. Not a globally accessible table.)
---@class AirbaseRunway
---@field course? number Runway heading in degrees.
---@field name? string Runway identifier.
---@field position? Vec3 Runway position in world coordinates.
---@field width? number Runway width in meters.
---@field length? number Runway length in meters.

--- Defines the structure of a Lua table representing a 3D bounding box in the DCS World coordinate system, specified by minimum and maximum corner points.
--- (Data structure definition for Box3. Not a globally accessible table.)
---@class Box3
---@field min Vec3 A `Vec3` representing the minimum corner point (lowest x, y, z values) of the bounding box in the DCS World coordinate system.
---@field max Vec3 A `Vec3` representing the maximum corner point (highest x, y, z values) of the bounding box in the DCS World coordinate system.

--- Base cargo object used in cargo-related events.
--- (Data structure definition for Cargo. Not a globally accessible table.)
---@class Cargo
---@field mass? number Mass of the cargo in kilograms.
---@field position? Vec3 A `Vec3` representing the cargo's current position in the DCS World coordinate system.
---@field displayName? string The human-readable name of the cargo shown in mission interfaces and logs.
---@field id? number Unique identifier of the cargo.
---@field name? string Name of the cargo.

--- Dynamic cargo object that can be moved during mission.
--- (Data structure definition for DynamicCargo. Not a globally accessible table.)
---@class DynamicCargo
---@field id? number Unique identifier of the dynamic cargo.
---@field name? string Name of the dynamic cargo.
---@field type? string The type classification of cargo, determining its visual model and behavior properties.
---@field mass? number Mass of the dynamic cargo in kilograms.
---@field position? Vec3 Current 3D position of the cargo.

--- Defines the structure of a Lua table representing both position and orientation in the DCS World coordinate system.
--- (Data structure definition for Position3. Not a globally accessible table.)
---@class Position3
---@field p Vec3 A `Vec3` representing the object's position in the DCS World coordinate system.
---@field x Vec3 A normalized `Vec3` representing the object's forward direction vector in the DCS World coordinate system.
---@field y Vec3 A normalized `Vec3` representing the object's upward direction vector in the DCS World coordinate system.
---@field z Vec3 A normalized `Vec3` representing the object's rightward direction vector in the DCS World coordinate system.

--- Defines the structure of a Lua table representing a reference point used by Joint Terminal Attack Controllers (JTACs) and other mission elements for targeting and navigation.
--- (Data structure definition for RefPoint. Not a globally accessible table.)
--- Since DCS 1.2.0.
---@class RefPoint
---@field callsign string A string identifier serving as the callsign or designation for the reference point.
---@field type number A numeric identifier categorizing the reference point's purpose or classification.
---@field point Vec3 A `Vec3` representing the precise 3D position of the reference point in the DCS World coordinate system.

--- Represents a numerically indexed Lua table (sequence) of `Vec3` points in the DCS World coordinate system.
---@alias Vec3Array Vec3[]

--- Defines the structure of a Lua table representing the destructive component specifications of a weapon's payload.
--- (Data structure definition for WeaponWarheadDetails. Not a globally accessible table.)
---@class WeaponWarheadDetails
---@field type? Weapon.WarheadType A `Weapon.WarheadType` enumerator specifying the primary damage mechanism of the warhead.
---@field mass? number A numeric value representing the total mass of the warhead in kilograms.
---@field caliber? number A numeric value representing the diameter of the warhead in millimeters.
---@field explosiveMass? number A numeric value representing the mass of high explosive material in kilograms, relevant for HE and AP+HE warheads.
---@field shapedExplosiveMass? number A numeric value representing the mass of shaped charge explosive material in kilograms, relevant for shaped explosive warheads.
---@field shapedExplosiveArmorThickness? number A numeric value representing the maximum armor penetration capability in millimeters of rolled homogeneous armor equivalent.

--- Parameters of `FireAtPoint`.
---@class DcsTask.Task.FireAtPointParams
---@field MRSI? boolean Seen in: missions. Set by 11 of 3022 install mission uses.
---@field alt_type? number Determines if the altitude is defined by AGL (1) or MSL (0) Seen in: default, panel, missions. Mission Editor default: `1`. Set by 716 of 3022 install mission uses.
---@field altitude? number If present the task will be focused on shooting at the specified altitude for the point Seen in: declared, panel, missions. Set by 370 of 3022 install mission uses.
---@field counterbattaryRadius? number The radius in meters from the group leader that the group will move in random directions after completing the fireAtPoint task Seen in: panel, missions. Set by 88 of 3022 install mission uses.
---@field expendQty? number Specifies number of shots to be fired Seen in: default, panel, missions. Mission Editor default: `1`. Set by 3021 of 3022 install mission uses.
---@field expendQtyEnabled? boolean Whether or not expendQty will be used Seen in: default, panel, missions. Mission Editor default: false. Set by 3021 of 3022 install mission uses.
---@field point? Vec2 Vec2 coordinate to define where the AI will aim Hand-authored (overlays.yaml): in no Mission Editor default or source, DCS script or install mission. Either `point` or `x`/`y`; which one DCS reads is unconfirmed (the Mission Editor writes `x`/`y`).
---@field radius? number Optional radius in meters that defines the area AI will attempt to hit Hand-authored (overlays.yaml): in no Mission Editor default or source, DCS script or install mission.
---@field templateId? string Seen in: default, missions. Mission Editor default: `""`. Set by 3022 of 3022 install mission uses. Install mission values: `""` (3022).
---@field weaponType? Weapon.flag|number Weapon flag type to use for the attack Seen in: panel, missions. Set by 2388 of 3022 install mission uses.
---@field x? number X coordinate of the target (alternative to point) Seen in: panel, missions. Set by 3022 of 3022 install mission uses. Either `point` or `x`/`y`; which one DCS reads is unconfirmed (the Mission Editor writes `x`/`y`).
---@field y? number Y coordinate of the target (alternative to point) Seen in: panel, missions. Set by 3022 of 3022 install mission uses. Either `point` or `x`/`y`; which one DCS reads is unconfirmed (the Mission Editor writes `x`/`y`).
---@field zoneRadius? number Seen in: default, panel, missions. Mission Editor default: `0`. Set by 3022 of 3022 install mission uses.

--- Parameters of `ActivateICLS`.
---@class DcsTask.Command.ActivateICLSParams
---@field channel? number ICLS channel number (1-20) that aircraft will tune to for landing guidance. Seen in: default, panel, missions. Mission Editor default: `1`. Set by 433 of 433 install mission uses.
---@field modeChannel? "X"|"Y" Seen in: panel.
---@field name? string Name of the ICLS beacon (label only). Seen in: panel, missions. Set by 70 of 433 install mission uses.
---@field system? any Seen in: panel.
---@field type? BeaconType Fixed value of 131584 identifying an ICLS beacon type. Seen in: default, missions. Mission Editor default: `131584`. Set by 433 of 433 install mission uses.
---@field unitId? number ID of the ship unit that will broadcast the ICLS beacon signal. Seen in: panel, missions. Set by 431 of 433 install mission uses.

--- Parameters of `ActivateBeacon`.
---@class DcsTask.Command.ActivateBeaconParams
---@field AA? boolean Seen in: default, panel, missions. Mission Editor default: true. Set by 1667 of 1782 install mission uses.
---@field bearing? boolean Seen in: default, panel, missions. Mission Editor default: true. Set by 1782 of 1782 install mission uses.
---@field callsign? string Morse code identifier transmitted by the beacon for identification. Seen in: default, panel, missions. Mission Editor default: `"TKR"`. Set by 1770 of 1782 install mission uses.
---@field channel? number Seen in: default, panel, missions. Mission Editor default: `1`. Set by 1782 of 1782 install mission uses.
---@field frequency? number Broadcast frequency in Hertz for the navigation beacon. Seen in: default, panel, missions. Mission Editor default: `1088000000`. Set by 1782 of 1782 install mission uses.
---@field modeChannel? "X"|"Y" Seen in: default, panel, missions. Mission Editor default: `"X"`. Set by 1782 of 1782 install mission uses. Install mission values: `"X"` (1412), `"Y"` (370).
---@field name? string Descriptive name for the beacon shown in the mission editor interface. Seen in: panel, missions. Set by 76 of 1782 install mission uses.
---@field system? BeaconSystemName Navigation system that will process the beacon signal. Seen in: default, missions. Mission Editor default: `4`. Set by 1765 of 1782 install mission uses.
---@field type? BeaconType Beacon type identifier determining its functional characteristics. Seen in: default, missions. Mission Editor default: `4`. Set by 1782 of 1782 install mission uses.
---@field unitId? number Seen in: panel, missions. Set by 1392 of 1782 install mission uses.

--- Parameters of `EngageUnit`.
---@class DcsTask.EnrouteTask.EngageUnitParams
---@field altitude? number Seen in: panel, missions. Set by 538 of 571 install mission uses.
---@field altitudeEdited? boolean Seen in: panel, missions. Set by 2 of 571 install mission uses.
---@field altitudeEnabled? boolean Seen in: panel, missions. Set by 538 of 571 install mission uses.
---@field attackQty? number Number of times the group will attack if the target is still alive and AI still have ammo. Seen in: default, panel, missions. Mission Editor default: `1`. Set by 571 of 571 install mission uses.
---@field attackQtyLimit? boolean Determines if the attack quantity limit is enabled. Seen in: default, panel, missions. Mission Editor default: false. Set by 571 of 571 install mission uses.
---@field attackType? "Carpet"|"Dive"|"Toss"|string Seen in: panel.
---@field direction? number Defines the direction from which the flight will engage from (in radians). Seen in: panel, missions. Set by 538 of 571 install mission uses.
---@field directionEnabled? boolean Seen in: panel, missions. Set by 538 of 571 install mission uses.
---@field expend? "Auto"|AI.Task.WeaponExpend Defines how many munitions the AI will expend per attack run (QUARTER, TWO, ONE, FOUR, HALF, ALL). Seen in: panel, missions. Set by 571 of 571 install mission uses. Install mission values: `"Auto"` (331), `"Two"` (141), `"One"` (79), `"All"` (20).
---@field groupAttack? boolean If true, each aircraft in the group will attack the unit. Seen in: default, panel, missions. Mission Editor default: false. Set by 571 of 571 install mission uses.
---@field priority? number The priority of the tasking, where lower numbers indicate higher importance (default: 0). Seen in: default, panel, missions. Mission Editor default: `1`. Set by 571 of 571 install mission uses.
---@field unitId? number Unique identifier of the target unit. Seen in: declared, panel, missions. Set by 568 of 571 install mission uses.
---@field visible? boolean Seen in: panel, missions. Set by 571 of 571 install mission uses.
---@field weaponType? Weapon.flag|number Defines the preferred weapon type to engage the enemy. Seen in: declared, panel, missions. Set by 571 of 571 install mission uses.

--- Parameters of `AttackMapObject`.
---@class DcsTask.Task.AttackMapObjectParams
---@field altitude? number Seen in: panel, missions. Set by 193 of 225 install mission uses.
---@field altitudeEdited? boolean Seen in: panel, missions. Set by 37 of 225 install mission uses.
---@field altitudeEnabled? boolean Seen in: panel, missions. Set by 193 of 225 install mission uses.
---@field attackQty? number Number of times the group will attack if the target Seen in: default, panel, missions. Mission Editor default: `1`. Set by 193 of 225 install mission uses.
---@field attackQtyLimit? boolean If true the attackQty value will be followed Seen in: default, panel, missions. Mission Editor default: true. Set by 193 of 225 install mission uses.
---@field attackType? "Carpet"|"Dive"|"Toss"|string Seen in: panel.
---@field direction? number Attack direction in radians Seen in: panel, missions. Set by 193 of 225 install mission uses.
---@field directionEnabled? boolean Seen in: panel, missions. Set by 193 of 225 install mission uses.
---@field expend? "Auto"|AI.Task.WeaponExpend Quantity of weapons to expend (QUARTER, TWO, ONE, FOUR, HALF, ALL) Seen in: panel, missions. Set by 193 of 225 install mission uses. Install mission values: `"Auto"` (91), `"One"` (37), `"All"` (28), `"Four"` (19), `"Two"` (17), `"Half"` (1).
---@field groupAttack? boolean If true then each aircraft in the group will attack the target Seen in: default, panel, missions. Mission Editor default: false. Set by 193 of 225 install mission uses.
---@field point? Vec2 Vec2 coordinate of the target point Hand-authored (overlays.yaml): in no Mission Editor default or source, DCS script or install mission. Either `point` or `x`/`y`; which one DCS reads is unconfirmed (the Mission Editor writes `x`/`y`).
---@field weaponType? Weapon.flag|number Weapon flag type to use for the attack Seen in: declared, panel, missions. Set by 225 of 225 install mission uses.
---@field x? number X coordinate of the target (alternative to point) Seen in: panel, missions. Set by 225 of 225 install mission uses. Either `point` or `x`/`y`; which one DCS reads is unconfirmed (the Mission Editor writes `x`/`y`).
---@field y? number Y coordinate of the target (alternative to point) Seen in: panel, missions. Set by 225 of 225 install mission uses. Either `point` or `x`/`y`; which one DCS reads is unconfirmed (the Mission Editor writes `x`/`y`).

--- Parameters of `AttackUnit`.
---@class DcsTask.Task.AttackUnitParams
---@field altitude? number Seen in: panel, missions. Set by 783 of 810 install mission uses.
---@field altitudeEdited? boolean Seen in: panel, missions. Set by 23 of 810 install mission uses.
---@field altitudeEnabled? boolean Seen in: panel, missions. Set by 783 of 810 install mission uses.
---@field attackQty? number Number of attack passes the group will perform on the target. Seen in: default, panel, missions. Mission Editor default: `1`. Set by 785 of 810 install mission uses.
---@field attackQtyLimit? boolean Determines whether to use the attackQty parameter as a limit. Seen in: default, panel, missions. Mission Editor default: false. Set by 785 of 810 install mission uses.
---@field attackType? "Carpet"|"Dive"|"Toss"|string Seen in: panel.
---@field counterbattaryRadius? number Seen in: panel, missions. Set by 3 of 810 install mission uses.
---@field direction? number Attack direction in radians, defining the approach vector. Seen in: panel, missions. Set by 783 of 810 install mission uses.
---@field directionEnabled? boolean Seen in: panel, missions. Set by 783 of 810 install mission uses.
---@field expend? "Auto"|AI.Task.WeaponExpend Quantity of weapons to expend during the attack (QUARTER, TWO, ONE, FOUR, HALF, ALL). Seen in: panel, missions. Set by 785 of 810 install mission uses. Install mission values: `"Auto"` (430), `"One"` (222), `"All"` (89), `"Two"` (27), `"Half"` (10), `"Four"` (5), `"Quarter"` (2).
---@field groupAttack? boolean Determines whether each aircraft in the group will attack individually (true) or as a coordinated unit (false). Seen in: default, panel, missions. Mission Editor default: false. Set by 785 of 810 install mission uses.
---@field unitId? number Unique ID of the unit to attack. Seen in: declared, panel, missions. Set by 795 of 810 install mission uses.
---@field weaponType? Weapon.flag|number Weapon flag type to use for the attack. Seen in: declared, panel, missions. Set by 810 of 810 install mission uses.
---@field x? number Seen in: missions. Set by 2 of 810 install mission uses.
---@field y? number Seen in: missions. Set by 2 of 810 install mission uses.

--- Parameters of `Bombing`.
---@class DcsTask.Task.BombingParams
---@field altitude? number Altitude in meters for the attack Seen in: panel, missions. Set by 1138 of 1200 install mission uses.
---@field altitudeEdited? boolean Seen in: panel, missions. Set by 190 of 1200 install mission uses.
---@field altitudeEnabled? boolean Whether to use the altitude parameter Seen in: panel, missions. Set by 1138 of 1200 install mission uses.
---@field attackQty? number Number of times the group will attack the target Seen in: default, panel, missions. Mission Editor default: `1`. Set by 1200 of 1200 install mission uses.
---@field attackQtyLimit? boolean Whether to use the attackQty parameter Seen in: default, panel, missions. Mission Editor default: false. Set by 1128 of 1200 install mission uses.
---@field attackType? "Carpet"|"Dive"|"Toss"|string Attack profile to use (e.g. 'Dive' for dive bombing) Seen in: declared, panel, missions. Set by 141 of 1200 install mission uses. Install mission values: `"Dive"` (141).
---@field defaultWeapon? boolean Seen in: missions. Set by 3 of 1200 install mission uses.
---@field direction? number Attack direction in radians Seen in: panel, missions. Set by 1138 of 1200 install mission uses.
---@field directionEnabled? boolean Seen in: panel, missions. Set by 1138 of 1200 install mission uses.
---@field expend? "Auto"|AI.Task.WeaponExpend Quantity of weapons to expend (QUARTER, TWO, ONE, FOUR, HALF, ALL) Seen in: panel, missions. Set by 1200 of 1200 install mission uses. Install mission values: `"All"` (569), `"One"` (238), `"Auto"` (176), `"Two"` (69), `"Quarter"` (67), `"Half"` (64), `"Four"` (17).
---@field groupAttack? boolean If true then each aircraft in the group will attack the point Seen in: default, panel, missions. Mission Editor default: false. Set by 1157 of 1200 install mission uses.
---@field point? Vec2 Vec2 coordinate of the target Hand-authored (overlays.yaml): in no Mission Editor default or source, DCS script or install mission. Either `point` or `x`/`y`; which one DCS reads is unconfirmed (the Mission Editor writes `x`/`y`).
---@field weaponType? Weapon.flag|number Weapon flag type to use for the attack Seen in: declared, panel, missions. Set by 1200 of 1200 install mission uses.
---@field x? number X coordinate of the target (alternative to point) Seen in: panel, missions. Set by 1200 of 1200 install mission uses. Either `point` or `x`/`y`; which one DCS reads is unconfirmed (the Mission Editor writes `x`/`y`).
---@field y? number Y coordinate of the target (alternative to point) Seen in: panel, missions. Set by 1200 of 1200 install mission uses. Either `point` or `x`/`y`; which one DCS reads is unconfirmed (the Mission Editor writes `x`/`y`).

--- Parameters of `BombingRunway`.
---@class DcsTask.Task.BombingRunwayParams
---@field altitude? number Seen in: panel, missions. Set by 83 of 88 install mission uses.
---@field altitudeEdited? boolean Seen in: panel, missions. Set by 12 of 88 install mission uses.
---@field altitudeEnabled? boolean Seen in: panel, missions. Set by 83 of 88 install mission uses.
---@field attackQty? number Number of times the group will attack the target Seen in: default, panel, missions. Mission Editor default: `1`. Set by 88 of 88 install mission uses.
---@field attackQtyLimit? boolean Whether to use the attackQty parameter Seen in: default, panel, missions. Mission Editor default: false. Set by 84 of 88 install mission uses.
---@field attackType? "Carpet"|"Dive"|"Toss"|string Seen in: panel.
---@field defaultWeapon? boolean Seen in: missions. Set by 2 of 88 install mission uses.
---@field direction? number If provided the AI will attack from this azimuth and ignore bombing along the length of the runway Seen in: panel, missions. Set by 83 of 88 install mission uses.
---@field directionEnabled? boolean Seen in: panel, missions. Set by 83 of 88 install mission uses.
---@field expend? "Auto"|AI.Task.WeaponExpend Quantity of weapons to expend (QUARTER, TWO, ONE, FOUR, HALF, ALL) Seen in: panel, missions. Set by 88 of 88 install mission uses. Install mission values: `"Auto"` (45), `"All"` (37), `"Four"` (6).
---@field groupAttack? boolean If true then each aircraft in the group will attack the runway Seen in: default, panel, missions. Mission Editor default: true. Set by 88 of 88 install mission uses.
---@field runwayId? number Index of the airbase for which is to be bombed Seen in: panel, missions. Set by 88 of 88 install mission uses.
---@field weaponType? Weapon.flag|number Weapon flag type to use for the attack Seen in: declared, panel, missions. Set by 88 of 88 install mission uses.
---@field x? number Seen in: missions. Set by 8 of 88 install mission uses.
---@field y? number Seen in: missions. Set by 8 of 88 install mission uses.

--- Parameters of `CarpetBombing`.
---@class DcsTask.Task.CarpetBombingParams
---@field altitude? number Altitude in meters for the attack Seen in: panel, missions. Set by 290 of 290 install mission uses.
---@field altitudeEdited? boolean Seen in: panel, missions. Set by 12 of 290 install mission uses.
---@field altitudeEnabled? boolean Whether to use the altitude parameter Seen in: panel, missions. Set by 290 of 290 install mission uses.
---@field attackQty? number Number of times the group will attack the target Seen in: default, panel, missions. Mission Editor default: `1`. Set by 290 of 290 install mission uses.
---@field attackQtyLimit? boolean Whether to use the attackQty parameter Seen in: default, missions. Mission Editor default: false. Set by 290 of 290 install mission uses.
---@field attackType? "Carpet"|"Dive"|"Toss"|string Type of attack, typically 'Carpet' Seen in: default, missions. Mission Editor default: `"Carpet"`. Set by 290 of 290 install mission uses. Install mission values: `"Carpet"` (290).
---@field carpetLength? number Distance in meters the pattern should cover Seen in: default, panel, missions. Mission Editor default: `500`. Set by 290 of 290 install mission uses.
---@field expend? "Auto"|AI.Task.WeaponExpend Quantity of weapons to expend (QUARTER, TWO, ONE, FOUR, HALF, ALL) Seen in: panel, missions. Set by 290 of 290 install mission uses. Install mission values: `"All"` (275), `"Auto"` (15).
---@field groupAttack? boolean If true then each aircraft in the group will attack the point Seen in: default, missions. Mission Editor default: false. Set by 290 of 290 install mission uses.
---@field point? Vec2 Vec2 coordinate of the target Hand-authored (overlays.yaml): in no Mission Editor default or source, DCS script or install mission. Either `point` or `x`/`y`; which one DCS reads is unconfirmed (the Mission Editor writes `x`/`y`).
---@field weaponType? Weapon.flag|number Weapon flag type to use for the attack Seen in: default, panel, missions. Mission Editor default: a table. Set by 290 of 290 install mission uses.
---@field x? number X coordinate of the target (alternative to point) Seen in: panel, missions. Set by 290 of 290 install mission uses. Either `point` or `x`/`y`; which one DCS reads is unconfirmed (the Mission Editor writes `x`/`y`).
---@field y? number Y coordinate of the target (alternative to point) Seen in: panel, missions. Set by 290 of 290 install mission uses. Either `point` or `x`/`y`; which one DCS reads is unconfirmed (the Mission Editor writes `x`/`y`).

--- Parameters of `Strafing`.
---@class DcsTask.Task.StrafingParams
---@field attackQty? number Number of attack passes the group will perform on the target. Seen in: default, panel, missions. Mission Editor default: `1`. Set by 19 of 19 install mission uses.
---@field attackQtyLimit? boolean Determines whether to use the attackQty parameter as a limit. Seen in: default, panel, missions. Mission Editor default: false. Set by 19 of 19 install mission uses.
---@field attackType? "Carpet"|"Dive"|"Toss"|string Seen in: declared.
---@field direction? number Attack direction in radians, defining the approach vector. Seen in: panel, missions. Set by 19 of 19 install mission uses.
---@field directionEnabled? boolean Determines whether to use the specified direction for attack. Seen in: panel, missions. Set by 19 of 19 install mission uses.
---@field dropType? any Seen in: panel.
---@field expend? "Auto"|AI.Task.WeaponExpend Quantity of weapons to expend during the attack (QUARTER, TWO, ONE, FOUR, HALF, ALL). Seen in: panel, missions. Set by 19 of 19 install mission uses. Install mission values: `"All"` (8), `"Auto"` (6), `"Quarter"` (4), `"Four"` (1).
---@field groupAttack? boolean Determines whether each aircraft in the group will attack individually (true) or as a coordinated unit (false). Seen in: default, panel, missions. Mission Editor default: false. Set by 19 of 19 install mission uses.
---@field length? number Total length of the strafing target area in meters. Seen in: default, panel, missions. Mission Editor default: `0`. Set by 19 of 19 install mission uses.
---@field point? Vec2 A `Vec2` representing the target coordinates in the DCS World coordinate system. Hand-authored (overlays.yaml): in no Mission Editor default or source, DCS script or install mission. Either `point` or `x`/`y`; which one DCS reads is unconfirmed (the Mission Editor writes `x`/`y`).
---@field weaponType? Weapon.flag|number Weapon flag type to use for the attack. Seen in: declared, panel, missions. Set by 19 of 19 install mission uses.
---@field x? number X coordinate of the target (alternative to using the point field). Seen in: panel, missions. Set by 19 of 19 install mission uses. Either `point` or `x`/`y`; which one DCS reads is unconfirmed (the Mission Editor writes `x`/`y`).
---@field y? number Y coordinate of the target (alternative to using the point field). Seen in: panel, missions. Set by 19 of 19 install mission uses. Either `point` or `x`/`y`; which one DCS reads is unconfirmed (the Mission Editor writes `x`/`y`).

--- Parameters of `TossAttack`.
---@class DcsTask.Task.TossAttackParams
---@field altitude? any Seen in: panel.
---@field altitudeEnabled? any Seen in: panel.
---@field attackQty? number Seen in: default, panel. Mission Editor default: `1`.
---@field attackType? "Carpet"|"Dive"|"Toss"|string Seen in: default. Mission Editor default: `"Toss"`.
---@field desiredAngle? number Seen in: default, panel. Mission Editor default: `35`.
---@field direction? any Seen in: panel.
---@field directionEnabled? any Seen in: panel.
---@field expend? "Auto"|AI.Task.WeaponExpend Seen in: panel.
---@field groupAttack? any Seen in: panel.
---@field speed? any Seen in: panel.
---@field speedEdited? any Seen in: panel.
---@field timing? any Seen in: panel.
---@field weaponType? Weapon.flag|number Seen in: declared, panel.
---@field x? any Seen in: panel.
---@field y? any Seen in: panel.

--- Parameters of `Barcap`.
---@class DcsTask.Task.BarcapParams
---@field altitude? number Seen in: panel, missions. Set by 4 of 4 install mission uses.
---@field altitudeEdited? any Seen in: panel.
---@field pattern? "Anchored"|AI.Task.OrbitPattern Seen in: declared, panel, missions. Set by 4 of 4 install mission uses. Install mission values: `"Race-Track"` (4).
---@field speed? number Seen in: panel, missions. Set by 4 of 4 install mission uses.
---@field speedEdited? boolean Seen in: panel, missions. Set by 4 of 4 install mission uses.

--- Parameters of `Orbit`.
---@class DcsTask.Task.OrbitParams
---@field altitude? number Altitude in meters the AI will maintain during the orbit. Seen in: panel, missions. Set by 6809 of 7262 install mission uses.
---@field altitudeEdited? boolean Seen in: panel, missions. Set by 832 of 7262 install mission uses.
---@field clockWise? boolean Determines whether the anchored orbit will fly clockwise (true) or anti-clockwise (false). Seen in: panel, missions. Set by 6 of 7262 install mission uses.
---@field hotLegDir? number Heading in radians that the aircraft will fly for the return leg of the anchored orbit pattern. Seen in: panel, missions. Set by 6 of 7262 install mission uses.
---@field legLength? number Distance in meters that the aircraft will fly before turning in an anchored orbit pattern. Seen in: panel, missions. Set by 6 of 7262 install mission uses.
---@field pattern? "Anchored"|AI.Task.OrbitPattern Type of orbit pattern the AI will execute (RACE_TRACK, CIRCLE, Anchored). Seen in: declared, panel, missions. Set by 7262 of 7262 install mission uses. Install mission values: `"Race-Track"` (5350), `"Circle"` (1906), `"Anchored"` (6).
---@field point? Vec2 A `Vec2` representing the primary orbit point in the DCS World coordinate system. Hand-authored (overlays.yaml): in no Mission Editor default or source, DCS script or install mission.
---@field point2? Vec2 A `Vec2` representing the secondary point for a Race-Track orbit pattern in the DCS World coordinate system. Hand-authored (overlays.yaml): in no Mission Editor default or source, DCS script or install mission.
---@field speed? number Speed in meters per second the AI will maintain during the orbit pattern. Seen in: panel, missions. Set by 6809 of 7262 install mission uses.
---@field speedEdited? boolean Seen in: panel, missions. Set by 4215 of 7262 install mission uses.
---@field width? number Distance in meters that represents the diameter of the anchored orbit pattern. Seen in: panel, missions. Set by 6 of 7262 install mission uses.

--- Union type of all option identifier enumerators used across different AI unit types.
--- Since DCS 1.2.0.
---@alias AIOptionId AI.Option.Air.id|AI.Option.Ground.id|AI.Option.Naval.id

--- Union type of the option value enumerators of the scripting API (`AI.Option.*.val.*`).
---@alias AIOptionValue AI.Option.Air.val.ECM_USING|AI.Option.Air.val.FLARE_USING|AI.Option.Air.val.MISSILE_ATTACK|AI.Option.Air.val.RADAR_USING|AI.Option.Air.val.REACTION_ON_THREAT|AI.Option.Air.val.ROE|AI.Option.Ground.val.ALARM_STATE|AI.Option.Ground.val.ROE|AI.Option.Naval.val.ROE

--- Defines the structure of a Lua table representing an aircraft unit's loadout (`UnitSpawnData.payload`).
--- (Data structure definition for UnitPayload. Not a globally accessible table.)
---@class UnitPayload
---@field pylons? table<number, UnitPylon> Stores by station number.
---@field fuel? number|string Internal fuel in kilograms; install missions hold it as a number or a string.
---@field flare? number Number of flares.
---@field chaff? number Number of chaff cartridges.
---@field gun? number Gun ammunition in percent.
---@field ammo_type? number Gun ammunition mix number, for aircraft with several mixes.

--- Defines the structure of a Lua table representing common properties specific to both airplane and helicopter units in the DCS World. Includes all fields from UnitDesc plus the following aircraft-specific fields.
--- (Data structure definition for UnitDescAircraft. Not a globally accessible table.)
---@class UnitDescAircraft
---@field fuelMassMax? number A numeric value representing the maximum internal fuel capacity in kilograms.
---@field range? number A numeric value representing the maximum operational range in meters at standard cruise settings.
---@field Hmax? number A numeric value representing the service ceiling (maximum operational altitude) in meters.
---@field VyMax? number A numeric value representing the maximum rate of climb in meters per second.
---@field NyMin? number A numeric value representing the minimum safe negative G-load limit.
---@field NyMax? number A numeric value representing the maximum safe positive G-load limit.
---@field tankerType? Unit.RefuelingSystem An `Unit.RefuelingSystem` enumerator specifying the aerial refueling system installed, if any.

--- Defines the structure of a Lua table representing a sensor's air target detection capabilities in different hemispheres.
--- (Data structure definition for UnitSensorDetectionDistanceAir. Not a globally accessible table.)
---@class UnitSensorDetectionDistanceAir
---@field upperHemisphere? UnitSensorHemisphereDistance A table representing detection distances for targets positioned above the sensor's horizontal plane.
---@field lowerHemisphere? UnitSensorHemisphereDistance A table representing detection distances for targets positioned below the sensor's horizontal plane.

--- Any unit type: what `Unit.getDescByName` takes and `Unit:getTypeName` returns.
---@alias DcsId.UnitType DcsId.AircraftType|DcsId.GroundUnitType|DcsId.HelicopterType|DcsId.ShipType

--- Airfield names of any theatre.
---@alias DcsId.AirbaseName DcsId.Theatre.Afghanistan.AirbaseName|DcsId.Theatre.Caucasus.AirbaseName|DcsId.Theatre.Falklands.AirbaseName|DcsId.Theatre.GermanyCW.AirbaseName|DcsId.Theatre.Iraq.AirbaseName|DcsId.Theatre.Kola.AirbaseName|DcsId.Theatre.MarianaIslands.AirbaseName|DcsId.Theatre.MarianaIslandsWWII.AirbaseName|DcsId.Theatre.Nevada.AirbaseName|DcsId.Theatre.Normandy.AirbaseName|DcsId.Theatre.PersianGulf.AirbaseName|DcsId.Theatre.SinaiMap.AirbaseName|DcsId.Theatre.Syria.AirbaseName

--- Airfield ids of any theatre.
---@alias DcsId.AirdromeId DcsId.Theatre.Afghanistan.AirdromeId|DcsId.Theatre.Caucasus.AirdromeId|DcsId.Theatre.Falklands.AirdromeId|DcsId.Theatre.GermanyCW.AirdromeId|DcsId.Theatre.Iraq.AirdromeId|DcsId.Theatre.Kola.AirdromeId|DcsId.Theatre.MarianaIslands.AirdromeId|DcsId.Theatre.MarianaIslandsWWII.AirdromeId|DcsId.Theatre.Nevada.AirdromeId|DcsId.Theatre.Normandy.AirdromeId|DcsId.Theatre.PersianGulf.AirdromeId|DcsId.Theatre.SinaiMap.AirdromeId|DcsId.Theatre.Syria.AirdromeId

--- Parameters of `EngageTargetsInZone`.
---@class DcsTask.EnrouteTask.EngageTargetsInZoneParams
---@field noTargetTypes? (DcsId.Attribute|string)[] Seen in: panel, missions. Set by 739 of 3486 install mission uses.
---@field point? Vec2 A `Vec2` point defining the center of the area the group will engage targets within in the DCS World coordinate system. Hand-authored (overlays.yaml): in no Mission Editor default or source, DCS script or install mission. Either `point` or `x`/`y`; which one DCS reads is unconfirmed (the Mission Editor writes `x`/`y`).
---@field priority? number The priority of the tasking, where lower numbers indicate higher importance (default: 0). Seen in: panel, missions. Set by 2210 of 3486 install mission uses.
---@field targetTypes? (DcsId.Attribute|string)[] Table of attribute names that define valid targets. Seen in: default, panel, missions. Mission Editor default: a table. Set by 3486 of 3486 install mission uses.
---@field value? string Seen in: panel, missions. Set by 1177 of 3486 install mission uses.
---@field x? number Seen in: panel, missions. Set by 3486 of 3486 install mission uses. Either `point` or `x`/`y`; which one DCS reads is unconfirmed (the Mission Editor writes `x`/`y`).
---@field y? number Seen in: panel, missions. Set by 3486 of 3486 install mission uses. Either `point` or `x`/`y`; which one DCS reads is unconfirmed (the Mission Editor writes `x`/`y`).
---@field zoneRadius? number Radius in meters defining the size of the area the group will engage targets within. Seen in: default, panel, missions. Mission Editor default: `5000`. Set by 3486 of 3486 install mission uses.

--- Parameters of `EngageTargets`.
---@class DcsTask.EnrouteTask.EngageTargetsParams
---@field maxAlt? number Maximum altitude for targets in meters. Hand-authored (overlays.yaml): in no Mission Editor default or source, DCS script or install mission.
---@field maxAltEnabled? boolean Whether to use the maxAlt parameter. Hand-authored (overlays.yaml): in no Mission Editor default or source, DCS script or install mission.
---@field maxDist? number Maximum distance to search for targets in meters. Seen in: default, panel, missions. Mission Editor default: `15000` (ENGAGE_TARGETS). Set by 1648 of 15033 install mission uses.
---@field maxDistEnabled? boolean Whether to use the maxDist parameter. Seen in: default, panel, missions. Mission Editor default: false (ENGAGE_TARGETS). Set by 1648 of 15033 install mission uses.
---@field minAlt? number Minimum altitude for targets in meters. Hand-authored (overlays.yaml): in no Mission Editor default or source, DCS script or install mission.
---@field minAltEnabled? boolean Whether to use the minAlt parameter. Hand-authored (overlays.yaml): in no Mission Editor default or source, DCS script or install mission.
---@field noTargetTypes? (DcsId.Attribute|string)[] Seen in: panel, missions. Set by 189 of 15033 install mission uses.
---@field priority? number Priority of the task, where lower numbers indicate higher importance. Seen in: default, missions, panel. Mission Editor default: `0` (ANTI_SHIP), `0` (CAP), `0` (CAS), `0` (FIGHTER_SWEEP), `0` (SEAD). Set by 15033 of 15033 install mission uses.
---@field targetTypes? (DcsId.Attribute|string)[] Table of target categories to engage. Seen in: default, missions, panel. Mission Editor default: a table (ANTI_SHIP), a table (CAP), a table (CAS), a table (ENGAGE_TARGETS), a table (FIGHTER_SWEEP), a table (SEAD). Set by 15033 of 15033 install mission uses.
---@field value? string The value of the task. Seen in: panel, missions. Set by 228 of 15033 install mission uses.

--- Parameters of `GroundEscort`.
---@class DcsTask.Task.GroundEscortParams
---@field engagementDistMax? number Maximum distance in meters defining the size/length of the orbit pattern before the helicopter returns to the escorted group. Seen in: default, panel, missions. Mission Editor default: `500`. Set by 5 of 5 install mission uses.
---@field groupId? number Unique ID of the ground group to escort and protect. Seen in: panel, missions. Set by 5 of 5 install mission uses.
---@field lastWptIndex? number Waypoint index at which the escorting helicopter will terminate its escort task. Seen in: declared, panel, missions. Set by 5 of 5 install mission uses.
---@field lastWptIndexFlag? boolean Determines whether the helicopter will follow the ground group until it reaches a specified waypoint. Seen in: default, panel, missions. Mission Editor default: true. Set by 5 of 5 install mission uses.
---@field lastWptIndexFlagChangedManually? boolean Indicates whether the lastWptIndexFlag was manually configured rather than using system defaults. Seen in: default, panel, missions. Mission Editor default: true. Set by 5 of 5 install mission uses.
---@field targetTypes? (DcsId.Attribute|string)[] A numerically indexed table of `Attributes` defining which enemy unit types the escorting helicopter will engage. Seen in: default, missions. Mission Editor default: a table. Set by 5 of 5 install mission uses.

--- Parameters of `RecoveryTanker`.
---@class DcsTask.Task.RecoveryTankerParams
---@field altitude? number Altitude in meters at which the tanker will orbit above the naval group. Seen in: panel, missions. Set by 28 of 28 install mission uses.
---@field altitudeEdited? boolean Seen in: panel, missions. Set by 5 of 28 install mission uses.
---@field groupId? number The group ID of the naval group to follow and provide tanker services to. Seen in: panel, missions. Set by 28 of 28 install mission uses.
---@field lastWptIndex? number Waypoint index of the naval group that, when reached, will cause the recovery tanker to end its task. Seen in: declared, panel, missions. Set by 28 of 28 install mission uses.
---@field lastWptIndexFlag? boolean Determines whether the tanker task should terminate when the naval group reaches a specific waypoint. Seen in: default, panel, missions. Mission Editor default: true. Set by 28 of 28 install mission uses.
---@field lastWptIndexFlagChangedManually? boolean Seen in: default, panel, missions. Mission Editor default: true. Set by 28 of 28 install mission uses.
---@field speed? number Speed of the tanker in meters per second while performing its orbit pattern. Seen in: panel, missions. Set by 28 of 28 install mission uses.
---@field speedEdited? boolean Seen in: panel, missions. Set by 7 of 28 install mission uses.
---@field targetTypes? (DcsId.Attribute|string)[] Seen in: default, missions. Mission Editor default: a table. Set by 28 of 28 install mission uses.

--- Parameters of an `Option` action.
---@class DcsTask.OptionParams
---@field name DcsTask.OptionName Option number.
---@field value? any Option value (`DcsTask.OptionValue.*` for listed values).

--- A `FORMATION` option value: formation, side and variant.
---@alias DcsId.FormationValue DcsTask.OptionValue.FORMATION_big_formations|DcsTask.OptionValue.FORMATION_helicopter|DcsTask.OptionValue.FORMATION_plane

--- The `Aerobatics` task as the Mission Editor writes it (AEROBATICS: Aerobatics (Perform aerobatics maneuvers)).
---@class DcsTask.Task.Aerobatics
---@field id "Aerobatics" Always `"Aerobatics"` (DCS casing).
---@field params? DcsTask.Task.AerobaticsParams Parameters; every one optional.

--- The `AttachTrailer` task as the Mission Editor writes it (ATTACH_TRAILER: Attach trailer (Select a trailer unit to attach to a tractor.)).
---@class DcsTask.Task.AttachTrailer
---@field id "AttachTrailer" Always `"AttachTrailer"` (DCS casing).
---@field params? DcsTask.Task.AttachTrailerParams Parameters; every one optional.

--- The `CargoTransportation` task as the Mission Editor writes it (CARGO_TRANSPORTATION: Cargo Transportation (External) (Cargo transportaion in zone)).
---@class DcsTask.Task.CargoTransportation
---@field id "CargoTransportation" Always `"CargoTransportation"` (DCS casing).
---@field params? DcsTask.Task.CargoTransportationParams Parameters; every one optional.

--- The `CargoTransportationPlane` task as the Mission Editor writes it (CARGO_TRANSPORTATION_PLANE: Cargo Transportation (Internal) (Cargo transportaion (Internal))).
---@class DcsTask.Task.CargoTransportationPlane
---@field id "CargoTransportationPlane" Always `"CargoTransportationPlane"` (DCS casing).
---@field params? DcsTask.Task.CargoTransportationPlaneParams Parameters; every one optional.

--- The `CargoUnloadPlane` task as the Mission Editor writes it (CARGO_UNLOAD_PLANE: Cargo Unload (Cargo Unload)).
---@class DcsTask.Task.CargoUnloadPlane
---@field id "CargoUnloadPlane" Always `"CargoUnloadPlane"` (DCS casing).
---@field params? DcsTask.Task.CargoUnloadPlaneParams Parameters; every one optional.

--- The `DetachTrailer` task as the Mission Editor writes it (DETACH_TRAILER: Detach trailer (Select a unit to detach from a tractor.)).
---@class DcsTask.Task.DetachTrailer
---@field id "DetachTrailer" Always `"DetachTrailer"` (DCS casing).
---@field params? DcsTask.Task.DetachTrailerParams Parameters; every one optional.

--- The `Disembarking` task as the Mission Editor writes it (DISEMBARKING: Disembarking (Disembarking)).
---@class DcsTask.Task.Disembarking
---@field id "Disembarking" Always `"Disembarking"` (DCS casing).
---@field params? DcsTask.Task.DisembarkingParams Parameters; every one optional.

--- The `Embarking` task as the Mission Editor writes it (EMBARKING: Embarking (Embarking)).
---@class DcsTask.Task.Embarking
---@field id "Embarking" Always `"Embarking"` (DCS casing).
---@field params? DcsTask.Task.EmbarkingParams Parameters; every one optional.

--- The `ExternalCargoLoad` task as the Mission Editor writes it (EXTERNAL_CARGO_LOAD: External Cargo Load (External Cargo Lift)).
---@class DcsTask.Task.ExternalCargoLoad
---@field id "ExternalCargoLoad" Always `"ExternalCargoLoad"` (DCS casing).
---@field params? DcsTask.Task.ExternalCargoLoadParams Parameters; every one optional.

--- The `ExternalCargoUnLoad` task as the Mission Editor writes it (EXTERNAL_CARGO_UNLOAD: External Cargo Unload (External Cargo Unload at Zone)).
---@class DcsTask.Task.ExternalCargoUnLoad
---@field id "ExternalCargoUnLoad" Always `"ExternalCargoUnLoad"` (DCS casing).
---@field params? DcsTask.Task.ExternalCargoUnLoadParams Parameters; every one optional.

--- The `FarpSpawn` task as the Mission Editor writes it (FARP_SPAWN: Farp spawn (Farp spawn)).
---@class DcsTask.Task.FarpSpawn
---@field id "FarpSpawn" Always `"FarpSpawn"` (DCS casing).
---@field params? DcsTask.Task.FarpSpawnParams Parameters; every one optional.

--- The `GoToWaypoint` task as the Mission Editor writes it (GO_TO_WAYPOINT: go to waypoint (go to waypoint)).
---@class DcsTask.Task.GoToWaypoint
---@field id "GoToWaypoint" Always `"GoToWaypoint"` (DCS casing).
---@field params? DcsTask.Task.GoToWaypointParams Parameters; every one optional.

--- Hold task that commands ground forces to cease movement and maintain their current position. The `Hold` task as the Mission Editor writes it (HOLD: Hold (Stop moving)).
---@class DcsTask.Task.Hold
---@field id "Hold" Always `"Hold"` (DCS casing).
---@field params? DcsTask.Task.HoldParams Parameters; every one optional.

--- The `NoTask` task as the Mission Editor writes it (NO_TASK: No Task (Empty task)).
---@class DcsTask.Task.NoTask
---@field id "NoTask" Always `"NoTask"` (DCS casing).
---@field params? DcsTask.Task.NoTaskParams Parameters; every one optional.

--- The `ParatroopersDrop` task as the Mission Editor writes it (PARATROOPERS_DROP: Drop of paratroopers (Perform paratroopers drop at target)).
---@class DcsTask.Task.ParatroopersDrop
---@field id "ParatroopersDrop" Always `"ParatroopersDrop"` (DCS casing).
---@field params? DcsTask.Task.ParatroopersDropParams Parameters; every one optional.

--- Air refueling task directing aircraft to seek and connect with the nearest available tanker. The `Refueling` task as the Mission Editor writes it (REFUELING: Refueling (Refuel from a tanker)).
---@class DcsTask.Task.Refueling
---@field id "Refueling" Always `"Refueling"` (DCS casing).
---@field params? DcsTask.Task.RefuelingParams Parameters; every one optional.

--- The `ShipHoldPoint` task as the Mission Editor writes it (SHIP_HOLD_POINT: Hold (Stop moving)).
---@class DcsTask.Task.ShipHoldPoint
---@field id "ShipHoldPoint" Always `"ShipHoldPoint"` (DCS casing).
---@field params? DcsTask.Task.ShipHoldPointParams Parameters; every one optional.

--- En-route task that assigns the aircraft to act as an AWACS for friendly forces. The `AWACS` en-route task as the Mission Editor writes it (AWACS: AWACS (Make the lead aircraft of the group AWACS)).
---@class DcsTask.EnrouteTask.AWACS
---@field id "AWACS" Always `"AWACS"` (DCS casing).
---@field params? DcsTask.EnrouteTask.AWACSParams Parameters; every one optional.

--- En-route task that assigns the group to act as an EWR radar for friendly forces. The `EWR` en-route task as the Mission Editor writes it (EWR: EWR (Make the lead aircraft of the group EWR)).
---@class DcsTask.EnrouteTask.EWR
---@field id "EWR" Always `"EWR"` (DCS casing).
---@field params? DcsTask.EnrouteTask.EWRParams Parameters; every one optional.

--- The `NoTask` en-route task as the Mission Editor writes it (NO_ENROUTE_TASK: No Enroute Task (Empty task)).
---@class DcsTask.EnrouteTask.NoTask
---@field id "NoTask" Always `"NoTask"` (DCS casing).
---@field params? DcsTask.EnrouteTask.NoTaskParams Parameters; every one optional.

--- En-route task that assigns the aircraft to act as an airborne tanker for friendly forces. The aircraft must be a certified tanker aircraft. The `Tanker` en-route task as the Mission Editor writes it (TANKER: Tanker (Make the lead aircraft of the group a tanker)).
---@class DcsTask.EnrouteTask.Tanker
---@field id "Tanker" Always `"Tanker"` (DCS casing).
---@field params? DcsTask.EnrouteTask.TankerParams Parameters; every one optional.

--- Command that activates an Automatic Carrier Landing System (ACLS) on an aircraft carrier. The `ActivateACLS` command as the Mission Editor writes it (ACTIVATE_ACLS: Activate ACLS (Activate ACLS onboard of the group lead unit. Only one ACLS is available.)).
---@class DcsTask.Command.ActivateACLS
---@field id "ActivateACLS" Always `"ActivateACLS"` (DCS casing).
---@field params? DcsTask.Command.ActivateACLSParams Parameters; every one optional.

--- The `ActivateGCI` command as the Mission Editor writes it (ACTIVATE_GCI: Activate GCI (This command activates GCI equipment)).
---@class DcsTask.Command.ActivateGCI
---@field id "ActivateGCI" Always `"ActivateGCI"` (DCS casing).
---@field params? DcsTask.Command.ActivateGCIParams Parameters; every one optional.

--- The `ActivateJammer` command as the Mission Editor writes it (ACTIVATE_JAMMER: Activate jammer (This command activates jammer)).
---@class DcsTask.Command.ActivateJammer
---@field id "ActivateJammer" Always `"ActivateJammer"` (DCS casing).
---@field params? DcsTask.Command.ActivateJammerParams Parameters; every one optional.

--- Command that activates a Link 4 data link system for aircraft carrier operations. The `ActivateLink4` command as the Mission Editor writes it (ACTIVATE_LINK4: Activate Link 4 (Activate Link 4 onboard of the group lead unit. Only one Link 4 is available.)).
---@class DcsTask.Command.ActivateLink4
---@field id "ActivateLink4" Always `"ActivateLink4"` (DCS casing).
---@field params? DcsTask.Command.ActivateLink4Params Parameters; every one optional.

--- The `ActivateRSBN` command as the Mission Editor writes it (ACTIVATE_RSBN: Activate RSBN (This command activates corresponding RSBN or PRMG beacon)).
---@class DcsTask.Command.ActivateRSBN
---@field id "ActivateRSBN" Always `"ActivateRSBN"` (DCS casing).
---@field params? DcsTask.Command.ActivateRSBNParams Parameters; every one optional.

--- Command that deactivates any active Automatic Carrier Landing System (ACLS) on a unit or group. The `DeactivateACLS` command as the Mission Editor writes it (DEACTIVATE_ACLS: Deactivate ACLS (Dectivate active beacon (ACLS, etc) onboard of the group lead unit.)).
---@class DcsTask.Command.DeactivateACLS
---@field id "DeactivateACLS" Always `"DeactivateACLS"` (DCS casing).
---@field params? DcsTask.Command.DeactivateACLSParams Parameters; every one optional.

--- Command that deactivates any active radio navigation beacon on a unit or group. The `DeactivateBeacon` command as the Mission Editor writes it (DEACTIVATE_BEACON: Deactivate TACAN (Dectivate active beacon (TACAN, etc) onboard of the group lead unit.)).
---@class DcsTask.Command.DeactivateBeacon
---@field id "DeactivateBeacon" Always `"DeactivateBeacon"` (DCS casing).
---@field params? DcsTask.Command.DeactivateBeaconParams Parameters; every one optional.

--- The `DeactivateGCI` command as the Mission Editor writes it (DEACTIVATE_GCI: Deactivate GCI (This command deactivates GCI equipment)).
---@class DcsTask.Command.DeactivateGCI
---@field id "DeactivateGCI" Always `"DeactivateGCI"` (DCS casing).
---@field params? DcsTask.Command.DeactivateGCIParams Parameters; every one optional.

--- Command that deactivates any active Instrument Carrier Landing System (ICLS) beacon on a unit or group. The `DeactivateICLS` command as the Mission Editor writes it (DEACTIVATE_ICLS: Deactivate ICLS (Deactivate active beacon (ICLS, etc) onboard of the group lead unit.)).
---@class DcsTask.Command.DeactivateICLS
---@field id "DeactivateICLS" Always `"DeactivateICLS"` (DCS casing).
---@field params? DcsTask.Command.DeactivateICLSParams Parameters; every one optional.

--- The `DeactivateJammer` command as the Mission Editor writes it (DEACTIVATE_JAMMER: Deactivate Jammer (This command deactivate jammer)).
---@class DcsTask.Command.DeactivateJammer
---@field id "DeactivateJammer" Always `"DeactivateJammer"` (DCS casing).
---@field params? DcsTask.Command.DeactivateJammerParams Parameters; every one optional.

--- Command that deactivates any active Link 4 data link system on a unit or group. The `DeactivateLink4` command as the Mission Editor writes it (DEACTIVATE_LINK4: Deactivate Link 4 (Dectivate active beacon (Link 4, etc) onboard of the group lead unit.)).
---@class DcsTask.Command.DeactivateLink4
---@field id "DeactivateLink4" Always `"DeactivateLink4"` (DCS casing).
---@field params? DcsTask.Command.DeactivateLink4Params Parameters; every one optional.

--- The `DeactivateRSBN` command as the Mission Editor writes it (DEACTIVATE_RSBN: Deactivate RSBN (This command deactivates corresponding RSBN or PRMG beacon)).
---@class DcsTask.Command.DeactivateRSBN
---@field id "DeactivateRSBN" Always `"DeactivateRSBN"` (DCS casing).
---@field params? DcsTask.Command.DeactivateRSBNParams Parameters; every one optional.

--- Command that toggles the Enhanced Position Location Reporting System (EPLRS) data link capabilities for a unit or group. The `EPLRS` command as the Mission Editor writes it (EPLRS: EPLRS (Swich Enhanced Position Location Reporting System on and off.)).
---@class DcsTask.Command.EPLRS
---@field id "EPLRS" Always `"EPLRS"` (DCS casing).
---@field params? DcsTask.Command.EPLRSParams Parameters; every one optional.

--- Command that adjusts a ship's cargo loading level, affecting its buoyancy and water line position. The `LoadingShip` command as the Mission Editor writes it (LOADING_SHIP: Set the ship's draft (This command changes the visual waterline level of the ship)).
---@class DcsTask.Command.LoadingShip
---@field id "LoadingShip" Always `"LoadingShip"` (DCS casing).
---@field params? DcsTask.Command.LoadingShipParams Parameters; every one optional.

--- The `NoAction` command as the Mission Editor writes it (NO_ACTION: No Action (Empty command)).
---@class DcsTask.Command.NoAction
---@field id "NoAction" Always `"NoAction"` (DCS casing).
---@field params? DcsTask.Command.NoActionParams Parameters; every one optional.

--- Command that toggles aircraft smoke pod emission. The `SMOKE_ON_OFF` command as the Mission Editor writes it (SMOKE_ON_OFF: SmokeOn_Off (SmokeOn_Off)).
---@class DcsTask.Command.SMOKE_ON_OFF
---@field id "SMOKE_ON_OFF" Always `"SMOKE_ON_OFF"` (DCS casing).
---@field params? DcsTask.Command.SMOKE_ON_OFFParams Parameters; every one optional.

--- Command that executes a Lua script within the context of a group, providing access to the group through the '...' self-reference. The `Script` command as the Mission Editor writes it (SCRIPT: Script (Run lua script. The group will be passed as a single parameter to the function.)).
---@class DcsTask.Command.Script
---@field id "Script" Always `"Script"` (DCS casing).
---@field params? DcsTask.Command.ScriptParams Parameters; every one optional.

--- The `ScriptFile` command as the Mission Editor writes it (SCRIPT_FILE: Script File (Run lua script file. The group will be passed as a single parameter to the function.)).
---@class DcsTask.Command.ScriptFile
---@field id "ScriptFile" Always `"ScriptFile"` (DCS casing).
---@field params? DcsTask.Command.ScriptFileParams Parameters; every one optional.

--- Command that toggles a group's invulnerability to all damage. The `SetImmortal` command as the Mission Editor writes it (IMMORTAL: Immortal (Make all units of the group immortal.)).
---@class DcsTask.Command.SetImmortal
---@field id "SetImmortal" Always `"SetImmortal"` (DCS casing).
---@field params? DcsTask.Command.SetImmortalParams Parameters; every one optional.

--- Command that toggles infinite fuel supply for a unit or group. The `SetUnlimitedFuel` command as the Mission Editor writes it (UNLIMITED_FUEL: Unlimited fuel (Make all units in the group with unlimited fuel. Make sure this task tops the Advanced WP properties list to work properly.)).
---@class DcsTask.Command.SetUnlimitedFuel
---@field id "SetUnlimitedFuel" Always `"SetUnlimitedFuel"` (DCS casing).
---@field params? DcsTask.Command.SetUnlimitedFuelParams Parameters; every one optional.

--- Command that activates an initially inactive group, triggering AI units to follow their designated route. The `Start` command as the Mission Editor writes it (START: Start (Start the assigned task.)).
---@class DcsTask.Command.Start
---@field id "Start" Always `"Start"` (DCS casing).
---@field params? DcsTask.Command.StartParams Parameters; every one optional.

--- Halts or resumes a group's movement along its route. Sent by DCS's scripts: trigger.action.groupStopMoving (Scripts/ScriptingSystem.lua, setCommand); trigger.action.groupContinueMoving (Scripts/ScriptingSystem.lua, setCommand).
---@class DcsTask.Command.StopRoute
---@field id "StopRoute" Always `"StopRoute"` (DCS casing).
---@field params? DcsTask.Command.StopRouteParams Parameters; every one optional.

--- Command that terminates any active radio message transmission from a unit or group. The `StopTransmission` command as the Mission Editor writes it (STOP_TRANSMISSION: Stop Transmission (Stop the radio transmission from the lead unit of the group)).
---@class DcsTask.Command.StopTransmission
---@field id "StopTransmission" Always `"StopTransmission"` (DCS casing).
---@field params? DcsTask.Command.StopTransmissionParams Parameters; every one optional.

--- Command that changes the active task action within a mission group's task queue. The `SwitchAction` command as the Mission Editor writes it (SWITCH_ITEM: Switch Action (Jump to another action in the action list of the waypoint.)).
---@class DcsTask.Command.SwitchAction
---@field id "SwitchAction" Always `"SwitchAction"` (DCS casing).
---@field params? DcsTask.Command.SwitchActionParams Parameters; every one optional.

--- Command that changes the active route leg for a group, allowing control of navigation between waypoints. The `SwitchWaypoint` command as the Mission Editor writes it (SWITCH_WAYPOINT: Switch Waypoint (Switch current waypoint of the route.)).
---@class DcsTask.Command.SwitchWaypoint
---@field id "SwitchWaypoint" Always `"SwitchWaypoint"` (DCS casing).
---@field params? DcsTask.Command.SwitchWaypointParams Parameters; every one optional.

--- Command that broadcasts an audio message over a unit or group's active radio frequency. The `TransmitMessage` command as the Mission Editor writes it (TRANSMIT_MESSAGE: Transmit Message (Start radio transmission from the lead unit of the group)).
---@class DcsTask.Command.TransmitMessage
---@field id "TransmitMessage" Always `"TransmitMessage"` (DCS casing).
---@field params? DcsTask.Command.TransmitMessageParams Parameters; every one optional.

--- Defines the structure of a Lua table detailing configuration options for controlled task execution.
--- (Data structure definition for ControlledTaskParams. Not a globally accessible table.)
---@class ControlledTaskParams
---@field task table The task to be executed.
---@field condition? ControlledTaskCondition A table specifying the conditions that must be met for the task to start.
---@field stopCondition? ControlledTaskStopCondition A table specifying the conditions that will trigger task termination.

--- Defines the structure of a Lua table representing a composite task that combines multiple tasks to be executed sequentially or in parallel.
--- (Data structure definition for ComboTask. Not a globally accessible table.)
---@class ComboTask
---@field id string Task identifier, must be 'ComboTask'.
---@field params ComboTaskParams A table containing parameters that define the tasks to be combined.

--- Represents a numerically indexed table of `Object.Category` enum values.
---@alias ObjectCategoryArray Object.Category[]

--- Parameters of `SetCallsign`.
---@class DcsTask.Command.SetCallsignParams
---@field callname? number Callsign name identifier (varies by unit type; 1-19 for JTAC units per Callsigns_JTAC enum). Seen in: makeParams, panel, missions. Set by 272 of 348 install mission uses.
---@field callnameFlag? boolean Seen in: makeParams, missions. Set by 192 of 348 install mission uses.
---@field callsign? number Seen in: makeParams, panel, missions. Set by 76 of 348 install mission uses.
---@field flag? boolean Seen in: missions. Set by 80 of 348 install mission uses.
---@field frequency? number Seen in: missions. Set by 16 of 348 install mission uses.
---@field modulation? radio.modulation Seen in: missions. Set by 16 of 348 install mission uses.
---@field number? number Numeric suffix for the callsign (1-9), used to distinguish between units with the same callname. Seen in: makeParams, panel, missions. Set by 272 of 348 install mission uses.

--- Parameters of `SetFrequencyForUnit`.
---@class DcsTask.Command.SetFrequencyForUnitParams
---@field frequency? number Radio frequency in Hertz (note: mission editor displays MHz, multiply by 1,000,000 to convert). Seen in: default, panel, missions. Mission Editor default: `131000000`. Set by 170 of 170 install mission uses.
---@field modulation? radio.modulation Radio modulation type (0 = AM, 1 = FM). Seen in: default, panel, missions. Mission Editor default: `0`. Set by 170 of 170 install mission uses.
---@field power? number Radio transmit power in watts, determining broadcast range. Seen in: default, panel, missions. Mission Editor default: `10`. Set by 170 of 170 install mission uses.
---@field unitId? number ID of the specific unit within the group whose radio frequency will be modified. Seen in: panel, missions. Set by 169 of 170 install mission uses.

--- Parameters of `SetFrequency`.
---@class DcsTask.Command.SetFrequencyParams
---@field callname? number Seen in: missions. Set by 222 of 4068 install mission uses.
---@field frequency? number Radio frequency in Hertz (note: mission editor displays MHz, multiply by 1,000,000 to convert). Seen in: default, panel, missions. Mission Editor default: `131000000`. Set by 4068 of 4068 install mission uses.
---@field modulation? radio.modulation Radio modulation type (0 = AM, 1 = FM). Seen in: default, panel, missions. Mission Editor default: `0`. Set by 4068 of 4068 install mission uses.
---@field number? number Seen in: missions. Set by 222 of 4068 install mission uses.
---@field power? number Radio transmit power in watts, determining broadcast range. Seen in: default, panel, missions. Mission Editor default: `10`. Set by 2863 of 4068 install mission uses.

--- Parameters of `SetInvisible`.
---@class DcsTask.Command.SetInvisibleParams
---@field flag? boolean Seen in: missions. Set by 110 of 12773 install mission uses.
---@field frequency? number Seen in: missions. Set by 102 of 12773 install mission uses.
---@field modulation? radio.modulation Seen in: missions. Set by 102 of 12773 install mission uses.
---@field value? boolean Invisibility state where true makes the group undetectable by enemy AI, false restores normal detection. Seen in: default, missions. Mission Editor default: true. Set by 12753 of 12773 install mission uses.

--- Parameters of `EngageGroup`.
---@class DcsTask.EnrouteTask.EngageGroupParams
---@field attackQty? number Number of times the group will attack if the target is still alive and AI still have ammo. Hand-authored (overlays.yaml): in no Mission Editor default or source, DCS script or install mission.
---@field attackQtyLimit? boolean Determines if the attack quantity limit is enabled. Hand-authored (overlays.yaml): in no Mission Editor default or source, DCS script or install mission.
---@field callname? number Seen in: panel.
---@field callsign? any Seen in: panel.
---@field datalink? any Seen in: panel.
---@field designation? "WP+Laser"|AI.Task.Designation Seen in: panel.
---@field direction? number Defines the direction from which the flight will engage from (in radians). Hand-authored (overlays.yaml): in no Mission Editor default or source, DCS script or install mission.
---@field expend? "Auto"|AI.Task.WeaponExpend Defines how many munitions the AI will expend per attack run (QUARTER, TWO, ONE, FOUR, HALF, ALL). Hand-authored (overlays.yaml): in no Mission Editor default or source, DCS script or install mission.
---@field frequency? any Seen in: panel.
---@field groupId? number Unique identifier for the target group. Seen in: declared, panel, missions. Set by 958 of 964 install mission uses.
---@field groupName? string Seen in: missions. Set by 93 of 964 install mission uses.
---@field laserCode? any Seen in: panel.
---@field modulation? radio.modulation Seen in: panel.
---@field number? any Seen in: panel.
---@field priority? number The priority of the tasking, where lower numbers indicate higher importance (default: 0). Seen in: default, panel, missions. Mission Editor default: `1`. Set by 964 of 964 install mission uses.
---@field visible? boolean Seen in: panel, missions. Set by 956 of 964 install mission uses.
---@field weaponType? Weapon.flag|number Defines the preferred weapon type to engage the enemy. Seen in: declared, panel, missions. Set by 964 of 964 install mission uses.
---@field x? number Seen in: missions. Set by 7 of 964 install mission uses.
---@field y? number Seen in: missions. Set by 7 of 964 install mission uses.

--- Parameters of `FAC`.
---@class DcsTask.EnrouteTask.FACParams
---@field callname? Callsigns_JTAC JTAC callsign identifier (Axeman, Darknight, etc.). Seen in: panel, missions. Set by 35 of 176 install mission uses.
---@field callsign? any Seen in: panel.
---@field datalink? boolean Seen in: panel, missions. Set by 35 of 176 install mission uses.
---@field designation? "WP+Laser"|AI.Task.Designation Seen in: panel, missions. Set by 35 of 176 install mission uses. Install mission values: `"Auto"` (35).
---@field frequency? number Radio frequency to use for the JTAC communications. Seen in: panel, missions. Set by 35 of 176 install mission uses.
---@field groupId? any Seen in: panel.
---@field laserCode? any Seen in: panel.
---@field modulation? radio.modulation Radio modulation type for JTAC communications. Seen in: panel, missions. Set by 35 of 176 install mission uses.
---@field number? number JTAC callsign number. Seen in: panel, missions. Set by 35 of 176 install mission uses.
---@field priority? number The priority of the tasking, where lower numbers indicate higher importance (default: 0). Hand-authored (overlays.yaml): in no Mission Editor default or source, DCS script or install mission.

--- Parameters of `FAC_EngageGroup`.
---@class DcsTask.EnrouteTask.FAC_EngageGroupParams
---@field callname? Callsigns_JTAC JTAC callsign identifier (Axeman, Darknight, etc.). Seen in: panel, missions. Set by 93 of 224 install mission uses.
---@field callsign? any Seen in: panel.
---@field datalink? boolean Determines whether the JTAC will send the 9-line via SADL, enabled by default. Seen in: panel, missions. Set by 162 of 224 install mission uses.
---@field designation? "WP+Laser"|AI.Task.Designation Type of designation to be used (NO, WP, IR_POINTER, LASER, AUTO). Seen in: panel, missions. Set by 162 of 224 install mission uses. Install mission values: `"Auto"` (149), `"WP"` (8), `"WP+Laser"` (3), `"IR-Pointer"` (1), `"Laser"` (1).
---@field frequency? number Radio frequency to use for the JTAC communications. Seen in: panel, missions. Set by 93 of 224 install mission uses.
---@field groupId? number ID of the group that is to be assigned by JTAC. Seen in: panel, missions. Set by 215 of 224 install mission uses.
---@field groupName? string Seen in: missions. Set by 194 of 224 install mission uses.
---@field laserCode? number Seen in: panel, missions. Set by 1 of 224 install mission uses.
---@field modulation? radio.modulation Radio modulation type for JTAC communications. Seen in: panel, missions. Set by 93 of 224 install mission uses.
---@field number? number JTAC callsign number. Seen in: panel, missions. Set by 93 of 224 install mission uses.
---@field priority? number The priority of the tasking, where lower numbers indicate higher importance (default: 0). Seen in: panel, missions. Set by 224 of 224 install mission uses.
---@field visible? boolean Seen in: panel, missions. Set by 224 of 224 install mission uses.
---@field weaponType? Weapon.flag|number Weapon flag type that defines the preferred weapon of choice. Seen in: panel, missions. Set by 224 of 224 install mission uses.
---@field x? number Seen in: missions. Set by 5 of 224 install mission uses.
---@field y? number Seen in: missions. Set by 5 of 224 install mission uses.

--- Parameters of `AttackGroup`.
---@class DcsTask.Task.AttackGroupParams
---@field altitude? number Attack altitude in meters. Seen in: panel, missions. Set by 3689 of 4776 install mission uses.
---@field altitudeEdited? boolean Seen in: panel, missions. Set by 89 of 4776 install mission uses.
---@field altitudeEnabled? boolean Determines whether to use the specified altitude for attack. Seen in: panel, missions. Set by 3689 of 4776 install mission uses.
---@field attackQty? number Number of attack passes the group will perform on the target. Seen in: default, panel, missions. Mission Editor default: `1`. Set by 3548 of 4776 install mission uses.
---@field attackQtyLimit? boolean Determines whether to use the attackQty parameter as a limit. Seen in: default, panel, missions. Mission Editor default: false. Set by 3551 of 4776 install mission uses.
---@field attackType? "Carpet"|"Dive"|"Toss"|string Seen in: panel.
---@field callname? number Seen in: panel.
---@field callsign? any Seen in: panel.
---@field counterbattaryRadius? number Seen in: panel, missions. Set by 5 of 4776 install mission uses.
---@field datalink? any Seen in: panel.
---@field designation? "WP+Laser"|AI.Task.Designation Seen in: panel.
---@field direction? number Attack direction in radians, defining the approach vector. Seen in: panel, missions. Set by 3689 of 4776 install mission uses.
---@field directionEnabled? boolean Determines whether to use the specified direction for attack. Seen in: panel, missions. Set by 3689 of 4776 install mission uses.
---@field expend? "Auto"|AI.Task.WeaponExpend Quantity of weapons to expend during the attack (QUARTER, TWO, ONE, FOUR, HALF, ALL). Seen in: panel, missions. Set by 3689 of 4776 install mission uses. Install mission values: `"Auto"` (3312), `"All"` (261), `"One"` (59), `"Half"` (45), `"Two"` (11), `"Four"` (1).
---@field frequency? any Seen in: panel.
---@field groupAttack? boolean Seen in: default, panel, missions. Mission Editor default: false. Set by 3560 of 4776 install mission uses.
---@field groupId? number Unique ID of the group to attack. Seen in: declared, panel, scripts, missions. Set by 4764 of 4776 install mission uses.
---@field groupName? string Seen in: missions. Set by 120 of 4776 install mission uses.
---@field laserCode? any Seen in: panel.
---@field modulation? radio.modulation Seen in: panel.
---@field number? any Seen in: panel.
---@field weaponType? Weapon.flag|number Weapon flag type to use for the attack. Seen in: declared, panel, missions. Set by 4776 of 4776 install mission uses.
---@field x? number Seen in: missions. Set by 50 of 4776 install mission uses.
---@field y? number Seen in: missions. Set by 50 of 4776 install mission uses.

--- Parameters of `FAC_AttackGroup`.
---@class DcsTask.Task.FAC_AttackGroupParams
---@field altitude? any Seen in: panel.
---@field altitudeEdited? any Seen in: panel.
---@field altitudeEnabled? any Seen in: panel.
---@field attackQty? any Seen in: panel.
---@field attackQtyLimit? any Seen in: panel.
---@field attackType? "Carpet"|"Dive"|"Toss"|string Seen in: panel.
---@field callname? Callsigns_JTAC JTAC callsign identifier (Axeman, Darknight, etc.) Seen in: panel, missions. Set by 609 of 1056 install mission uses.
---@field callsign? number Seen in: panel, missions. Set by 650 of 1056 install mission uses.
---@field counterbattaryRadius? number Seen in: panel, missions. Set by 3 of 1056 install mission uses.
---@field datalink? boolean Determines whether or not the JTAC will send the 9-line via SADL, enabled by default Seen in: panel, missions. Set by 675 of 1056 install mission uses.
---@field designation? "WP+Laser"|AI.Task.Designation Type of designation to be used (NO, WP, IR_POINTER, LASER, AUTO) Seen in: panel, missions. Set by 675 of 1056 install mission uses. Install mission values: `"Auto"` (586), `"Laser"` (48), `"WP"` (16), `"IR-Pointer"` (10), `"WP+Laser"` (9), `"No"` (6).
---@field direction? any Seen in: panel.
---@field directionEnabled? any Seen in: panel.
---@field expend? "Auto"|AI.Task.WeaponExpend Seen in: panel.
---@field frequency? number Radio frequency to use for the JTAC Seen in: panel, missions. Set by 960 of 1056 install mission uses.
---@field groupAttack? any Seen in: panel.
---@field groupId? number ID of the group that is to be assigned by JTAC Seen in: declared, panel, missions. Set by 1043 of 1056 install mission uses.
---@field groupName? string Seen in: missions. Set by 887 of 1056 install mission uses.
---@field laserCode? number Seen in: panel, missions. Set by 3 of 1056 install mission uses.
---@field modulation? radio.modulation Radio modulation type Seen in: panel, missions. Set by 960 of 1056 install mission uses.
---@field number? number JTAC callsign number Seen in: panel, missions. Set by 609 of 1056 install mission uses.
---@field weaponType? Weapon.flag|number Weapon flag type that defines the preferred weapon of choice Seen in: declared, panel, missions. Set by 1056 of 1056 install mission uses.
---@field x? number Seen in: missions. Set by 43 of 1056 install mission uses.
---@field y? number Seen in: missions. Set by 43 of 1056 install mission uses.

--- Trigger zone used in mission editor and referenced in zone-related events.
--- (Data structure definition for Zone. Not a globally accessible table.)
---@class Zone
---@field id? number Unique identifier of the zone.
---@field name? string Name of the zone as defined in the mission editor.
---@field position? Vec3 3D position of the zone's center.
---@field radius? number Radius of the zone in meters.
---@field coalition? coalition.side The `coalition.side` value indicating which faction owns or controls the zone, or `nil` if not coalition-specific.

--- Landing task that directs helicopters to touch down at specific coordinates. The `Land` task as the Mission Editor writes it (LAND: Land (Land on the ground temporary)).
---@class DcsTask.Task.Land
---@field id "Land" Always `"Land"` (DCS casing).
---@field params? DcsTask.Task.LandParams Parameters; every one optional.

--- Defines the structure of a Lua table representing a scenery object's properties and physical characteristics in the DCS World.
--- (Data structure definition for SceneryObjectDesc. Not a globally accessible table.)
---@class SceneryObjectDesc
---@field life? number A numeric value representing the initial health or integrity level of the scenery object.
---@field box? Box3 A box (two Vec3 points) representing the three-dimensional collision boundaries of the scenery object in the DCS World coordinate system.
---@field category? Object.Category An `Object.Category` enumerator representing the category of the scenery object.
---@field categoryEx? Weapon.Category A `Weapon.Category` enumerator representing the subcategory of the scenery object.

--- Defines the structure of a Lua table representing a static object's properties and physical characteristics in the DCS World.
--- (Data structure definition for StaticObjectDesc. Not a globally accessible table.)
---@class StaticObjectDesc
---@field life? number A numeric value representing the initial health or integrity level of the static object.
---@field box? Box3 A box (two Vec3 points) representing the three-dimensional collision boundaries of the static object in the DCS World coordinate system.

--- Defines the structure of a Lua table representing a circular area used for spatial trigger conditions in the DCS World.
--- (Data structure definition for TriggerZoneCircular. Not a globally accessible table.)
---@class TriggerZoneCircular
---@field position Position3 A `Position3` representing the center point and orientation of the trigger zone in the DCS World coordinate system.
---@field radius number A numeric value defining the radius of the circular trigger zone in meters.

--- Defines the structure of a Lua table representing the specifications and capabilities of a weapon or ammunition type available to a unit.
--- (Data structure definition for UnitAmmoDesc. Not a globally accessible table.)
---@class UnitAmmoDesc
---@field missileCategory? Weapon.MissileCategory
---@field rangeMaxAltMax? number A numeric value representing the maximum weapon range in meters when fired at maximum altitude.
---@field rangeMin? number A numeric value representing the minimum effective range of the weapon in meters.
---@field displayName? string A string containing the human-readable name of the weapon as displayed in the DCS World interface.
---@field rangeMaxAltMin? number A numeric value representing the maximum weapon range in meters when fired at minimum altitude.
---@field altMax? number A numeric value representing the maximum altitude in meters at which the weapon can be effectively used.
---@field RCS? Box3 A `Box3` representing the radar cross-section characteristics of the weapon.
---@field box? Box3 A box (two Vec3 points) representing the physical dimensions of the weapon in the DCS World coordinate system.
---@field altMin? number A numeric value representing the minimum altitude in meters at which the weapon can be effectively used.
---@field life? number A numeric value representing the weapon's health or structural integrity.
---@field fuseDist? number A numeric value representing the distance in meters at which the weapon's fuse activates.
---@field category? Weapon.Category
---@field guidance? Weapon.GuidanceType
---@field warhead? WeaponWarheadDetails
---@field typeName? string A string containing the internal type identifier for the weapon.
---@field Nmax? number A numeric value representing the maximum G-load the weapon can withstand.

--- Defines the structure of a Lua table representing the basic properties common to all weapon types in the DCS World.
--- (Data structure definition for WeaponDesc. Not a globally accessible table.)
---@class WeaponDesc
---@field life? number A numeric value representing the weapon's total health or structural integrity.
---@field box? Box3 A box (two Vec3 points) representing the physical dimensions of the weapon in the DCS World coordinate system.
---@field category? Weapon.Category A `Weapon.Category` enumerator specifying the fundamental classification of the weapon.
---@field warhead? WeaponWarheadDetails A table representing the specifications of the weapon's destructive payload component.

--- Defines the structure of a Lua table representing the properties and capabilities of air-dropped bomb weapons in the DCS World.
--- (Data structure definition for WeaponDescBomb. Not a globally accessible table.)
---@class WeaponDescBomb
---@field life? number A numeric value representing the bomb's total health or structural integrity.
---@field box? Box3 A box (two Vec3 points) representing the physical dimensions of the bomb in the DCS World coordinate system.
---@field category? Weapon.Category A `Weapon.Category` enumerator specifying the fundamental classification of the bomb.
---@field warhead? WeaponWarheadDetails A table representing the specifications of the bomb's destructive payload component.
---@field guidance? Weapon.GuidanceType A `Weapon.GuidanceType` enumerator specifying the bomb's targeting and course correction technology, if applicable.
---@field altMin? number A numeric value representing the minimum effective release altitude in meters.
---@field altMax? number A numeric value representing the maximum effective release altitude in meters.

--- Defines the structure of a Lua table representing the properties and capabilities of missile weapons in the DCS World.
--- (Data structure definition for WeaponDescMissile. Not a globally accessible table.)
---@class WeaponDescMissile
---@field life? number A numeric value representing the missile's total health or structural integrity.
---@field box? Box3 A box (two Vec3 points) representing the physical dimensions of the missile in the DCS World coordinate system.
---@field category? Weapon.Category A `Weapon.Category` enumerator specifying the fundamental classification of the missile.
---@field warhead? WeaponWarheadDetails A table representing the specifications of the missile's destructive payload component.
---@field guidance? Weapon.GuidanceType A `Weapon.GuidanceType` enumerator specifying the missile's targeting and course correction technology.
---@field rangeMin? number A numeric value representing the minimum effective engagement range in meters.
---@field rangeMaxAltMin? number A numeric value representing the maximum engagement range in meters when fired at minimum altitude.
---@field rangeMaxAltMax? number A numeric value representing the maximum engagement range in meters when fired at maximum altitude.
---@field altMin? number A numeric value representing the minimum effective engagement altitude in meters.
---@field altMax? number A numeric value representing the maximum effective engagement altitude in meters.
---@field Nmax? number A numeric value representing the maximum G-force the missile can sustain during flight.
---@field fuseDist? number A numeric value representing the distance in meters at which the missile's proximity fuse activates.

--- Defines the structure of a Lua table representing the properties and capabilities of unguided rocket weapons in the DCS World.
--- (Data structure definition for WeaponDescRocket. Not a globally accessible table.)
---@class WeaponDescRocket
---@field life? number A numeric value representing the rocket's total health or structural integrity.
---@field box? Box3 A box (two Vec3 points) representing the physical dimensions of the rocket in the DCS World coordinate system.
---@field category? Weapon.Category A `Weapon.Category` enumerator specifying the fundamental classification of the rocket.
---@field warhead? WeaponWarheadDetails A table representing the specifications of the rocket's destructive payload component.
---@field distMin? number A numeric value representing the minimum effective firing distance in meters.
---@field distMax? number A numeric value representing the maximum effective firing distance in meters.

--- Assigns a point on the ground for which the AI will shoot at. Most commonly used with artillery to shell a target. The `FireAtPoint` task as the Mission Editor writes it (FIRE_AT_POINT: Fire at Point (Fire at point)).
---@class DcsTask.Task.FireAtPoint
---@field id "FireAtPoint" Always `"FireAtPoint"` (DCS casing).
---@field params? DcsTask.Task.FireAtPointParams Parameters; every one optional.

--- Command that activates an Instrument Carrier Landing System (ICLS) beacon for aircraft carriers. The `ActivateICLS` command as the Mission Editor writes it (ACTIVATE_ICLS: Activate ICLS (Activate ICLS onboard of the group lead unit. Only one ICLS is available.)).
---@class DcsTask.Command.ActivateICLS
---@field id "ActivateICLS" Always `"ActivateICLS"` (DCS casing).
---@field params? DcsTask.Command.ActivateICLSParams Parameters; every one optional.

--- Command that activates a radio navigation beacon on a unit or group. The `ActivateBeacon` command as the Mission Editor writes it (ACTIVATE_TACAN: Activate TACAN (Activate TACAN beacon onboard of the group lead unit. Only one beacon is available.)).
---@class DcsTask.Command.ActivateBeacon
---@field id "ActivateBeacon" Always `"ActivateBeacon"` (DCS casing).
---@field params? DcsTask.Command.ActivateBeaconParams Parameters; every one optional.

--- En-route task that assigns the controlled group to search for and engage a specific unit. The target must be detected for AI to engage it. The `EngageUnit` en-route task as the Mission Editor writes it (ENGAGE_UNIT: Engage Unit (Allow the group to engage the enemy unit or the enemy static object during the mission)).
---@class DcsTask.EnrouteTask.EngageUnit
---@field id "EngageUnit" Always `"EngageUnit"` (DCS casing).
---@field params? DcsTask.EnrouteTask.EngageUnitParams Parameters; every one optional.

--- Assigns the nearest world object to the point for AI to attack. The `AttackMapObject` task as the Mission Editor writes it (ATTACK_MAP_OBJECT: Attack Map Object (Attack the map object)).
---@class DcsTask.Task.AttackMapObject
---@field id "AttackMapObject" Always `"AttackMapObject"` (DCS casing).
---@field params? DcsTask.Task.AttackMapObjectParams Parameters; every one optional.

--- Attack task that directs a group to engage a specific unit. The `AttackUnit` task as the Mission Editor writes it (ATTACK_UNIT: Attack Unit (Attack the enemy unit or the enemy static object)).
---@class DcsTask.Task.AttackUnit
---@field id "AttackUnit" Always `"AttackUnit"` (DCS casing).
---@field params? DcsTask.Task.AttackUnitParams Parameters; every one optional.

--- Assigns a point on the ground for which the AI will attack. Best used for discriminant carpet bombing of a target or having a GBU hit a specific point on the map. The `Bombing` task as the Mission Editor writes it (BOMBING: Bombing (Deliver weapon at the point on the ground)).
---@class DcsTask.Task.Bombing
---@field id "Bombing" Always `"Bombing"` (DCS casing).
---@field params? DcsTask.Task.BombingParams Parameters; every one optional.

--- Assigns the AI a task to bomb an airbases runway. By default the AI will line up along the length of the runway and drop its payload. The `BombingRunway` task as the Mission Editor writes it (BOMBING_RUNWAY: Bombing Runway (Deliver weapon at the runway)).
---@class DcsTask.Task.BombingRunway
---@field id "BombingRunway" Always `"BombingRunway"` (DCS casing).
---@field params? DcsTask.Task.BombingRunwayParams Parameters; every one optional.

--- Assigns a point on the ground for which the AI will attack. Similar to the bombing task, but with more control over target area. Can be combined with follow big formation task for all participating aircraft to simultaneously bomb a target. The `CarpetBombing` task as the Mission Editor writes it (CARPET_BOMBING: Carpet bombing (Perform large formation bombing)).
---@class DcsTask.Task.CarpetBombing
---@field id "CarpetBombing" Always `"CarpetBombing"` (DCS casing).
---@field params? DcsTask.Task.CarpetBombingParams Parameters; every one optional.

--- Strafing task that directs AI to perform gun or rocket attacks on a ground point. The `Strafing` task as the Mission Editor writes it (STRAFING: Strafing (Order AI to Strafe surface point with guns and rockets)).
---@class DcsTask.Task.Strafing
---@field id "Strafing" Always `"Strafing"` (DCS casing).
---@field params? DcsTask.Task.StrafingParams Parameters; every one optional.

--- The `TossAttack` task as the Mission Editor writes it (TOSS_ATTACK: Toss attack (Toss attack)).
---@class DcsTask.Task.TossAttack
---@field id "TossAttack" Always `"TossAttack"` (DCS casing).
---@field params? DcsTask.Task.TossAttackParams Parameters; every one optional.

--- The `Barcap` task as the Mission Editor writes it (BARCAP: Barrier Combat Air Patrol (Orbit with Combat Air Patrol)).
---@class DcsTask.Task.Barcap
---@field id "Barcap" Always `"Barcap"` (DCS casing).
---@field params? DcsTask.Task.BarcapParams Parameters; every one optional.

--- Orbit task that directs aircraft to fly various pattern types at specified locations. The `Orbit` task as the Mission Editor writes it (ORBIT: Orbit (Fly orbit)).
---@class DcsTask.Task.Orbit
---@field id "Orbit" Always `"Orbit"` (DCS casing).
---@field params? DcsTask.Task.OrbitParams Parameters; every one optional.

--- Defines the structure of a Lua table representing a sensor system's capabilities and technical specifications.
--- (Data structure definition for UnitSensor. Not a globally accessible table.)
---@class UnitSensor
---@field type? Unit.SensorType An `Unit.SensorType` enumerator specifying the general category of the sensor system.
---@field typeName? DcsId.SensorName|string A string containing the specific model name or designation of the sensor.
---@field detectionDistanceAir? UnitSensorDetectionDistanceAir A table containing the sensor's detection ranges against aerial targets from different aspects.
---@field detectionDistanceIdle? number A numeric value representing the maximum detection distance in meters against idle (non-emitting) targets.
---@field detectionDistanceMaximal? number A numeric value representing the maximum absolute detection distance in meters under optimal conditions.
---@field detectionDistanceAfterburner? number A numeric value representing the maximum detection distance in meters against targets using afterburner.

--- Any static object type (`StaticObject:getTypeName`): a unit's, a structure's or personnel's.
---@alias DcsId.StaticType DcsId.PersonnelType|DcsId.StructureType|DcsId.UnitType

--- Parameters of `EmbarkToTransport`.
---@class DcsTask.Task.EmbarkToTransportParams
---@field concretteUnitChecked? boolean Seen in: missions. Set by 4 of 90 install mission uses.
---@field selectedType? DcsId.UnitType|string Seen in: panel, missions. Set by 84 of 90 install mission uses. Install mission values: `"CH-47Fbl1"` (49), `"CH-47D"` (17), `"UH-1H"` (7), `"Mi-8MT"` (5), `"SH-60B"` (2), `"UH-60A"` (2), `"KrAZ6322"` (1), `"LAV-25"` (1).
---@field selectedUnit? number Seen in: missions. Set by 4 of 90 install mission uses.
---@field x? number Seen in: panel, missions. Set by 90 of 90 install mission uses.
---@field y? number Seen in: panel, missions. Set by 90 of 90 install mission uses.
---@field zoneRadius? number Seen in: default, panel, missions. Mission Editor default: `200`. Set by 90 of 90 install mission uses.

--- Defines the structure of a Lua table representing the basic properties and capabilities common to all unit types in the DCS World.
--- (Data structure definition for UnitDesc. Not a globally accessible table.)
---@class UnitDesc
---@field typeName? DcsId.UnitType|string A string containing the internal identifier for the unit type used by the DCS World engine.
---@field displayName? string A string containing the human-readable name of the unit as shown in the DCS World interface.
---@field category? Unit.Category An `Unit.Category` enumerator specifying the basic classification of the unit.
---@field massEmpty? number A numeric value representing the unit's empty weight in kilograms.
---@field speedMax? number A numeric value representing the unit's maximum speed in meters per second.
---@field life? number A numeric value representing the unit's total health or structural integrity.
---@field RCS? number A numeric value representing the unit's radar cross-section signature.
---@field box? Box3 A box (two Vec3 points) representing the unit's physical dimensions in the DCS World coordinate system.
---@field attributes? UnitAttributes A table defining special characteristics and capabilities of the unit.
---@field Kmax? number A numeric coefficient related to the unit's performance characteristics.
---@field Kab? number A numeric coefficient related to afterburner performance for aircraft.

--- Defines the structure of a Lua table representing one unit of a group to be spawned (`GroupSpawnData.units`), as missions write it.
--- (Data structure definition for UnitSpawnData. Not a globally accessible table.)
---@class UnitSpawnData
---@field type DcsId.UnitType|string Unit type name (`DcsId.UnitType`; mods add more).
---@field name? string Unit name, unique within the mission.
---@field unitId? number Optional unique numeric identifier for the unit.
---@field x number X coordinate of the unit in the DCS World coordinate system.
---@field y number Y coordinate (map Z) of the unit in the DCS World coordinate system.
---@field heading? number Heading in radians.
---@field alt? number Altitude in meters (aircraft).
---@field alt_type? AI.Task.AltitudeType Altitude reference of `alt` (aircraft).
---@field speed? number Speed in meters per second (aircraft).
---@field skill? "Random"|AI.Skill Skill level; the Mission Editor's `Random` lets DCS pick one.
---@field livery_id? number|string Livery folder name of the unit type; some install missions hold `0` instead.
---@field onboard_num? string Board (tail) number, such as `"010"`.
---@field callsign? number|table Callsign: a table `{callname, flight, unit, name = "Enfield11"}` (Western), or a number (Russian).
---@field payload? UnitPayload Weapons, fuel and countermeasures (aircraft).
---@field parking? number|string Parking stand index at the take-off airfield (aircraft); missions hold it as a number or a string.
---@field parking_id? string Parking stand name at the take-off airfield (aircraft).
---@field playerCanDrive? boolean Whether a player can drive the unit (ground units).
---@field frequency? number Radio frequency in hertz (ships).
---@field modulation? radio.modulation Radio modulation of `frequency` (ships).
---@field AddPropAircraft? table Module-specific aircraft properties, by the names the module's `AddPropAircraft` declares.

--- Defines the structure of a Lua table representing a single navigation point within a mission route.
--- (Data structure definition for MissionWaypoint. Not a globally accessible table.)
---@class MissionWaypoint
---@field type "LandingReFuAr"|"On Railroads"|"TakeOffGround"|"TakeOffGroundHot"|AI.Task.WaypointType Waypoint type: `AI.Task.WaypointType`, or another type install missions use.
---@field airdromeId? DcsId.AirdromeId|number Unique identifier of the airdrome for takeoff or landing waypoints (`DcsId.Theatre.<theatre>.AirdromeId`).
---@field timeReFuAr? number Time in minutes allocated for refueling and rearming at an airdrome.
---@field helipadId? number Unique identifier of the helipad for helicopter operations.
---@field linkUnit? number Unique identifier of the linked unit (same as helipadId but required for certain operations).
---@field action "Custom"|"From Ground Area Hot"|"From Ground Area"|"From Parking Area Hot"|"From Parking Area"|"From Runway"|"Landing"|"LandingReFuAr"|"On Railroads"|"Turning Point"|AI.Task.TurnMethod|AI.Task.VehicleFormation Turn method the aircraft will use when approaching this waypoint, or the ground formation to move in; the Mission Editor writes the other listed names.
---@field x number X coordinate of the waypoint in the DCS World coordinate system.
---@field y number Y coordinate of the waypoint in the DCS World coordinate system.
---@field alt? number Altitude of the waypoint in meters.
---@field alt_type? AI.Task.AltitudeType Altitude measurement reference ('RADIO' for AGL, 'BARO' for MSL).
---@field speed number Speed in meters per second the aircraft will maintain at this waypoint.
---@field speed_locked? boolean Determines whether the speed value is fixed and cannot be optimized by AI.
---@field ETA? number Estimated time of arrival at the waypoint in seconds from mission start.
---@field ETA_locked? boolean Determines whether the ETA value is fixed and AI must adjust speed to meet it.
---@field name? string Descriptive name of the waypoint for identification purposes.
---@field task? table Task to be performed when the aircraft reaches this waypoint.

--- En-route task that assigns the controlled group to engage targets with specific attributes within a defined zone. The `EngageTargetsInZone` en-route task as the Mission Editor writes it (ENGAGE_TARGETS_IN_ZONE: Engage Targets In Zone (Engage targets of specific types in the given zone)).
---@class DcsTask.EnrouteTask.EngageTargetsInZone
---@field id "EngageTargetsInZone" Always `"EngageTargetsInZone"` (DCS casing).
---@field params? DcsTask.EnrouteTask.EngageTargetsInZoneParams Parameters; every one optional.

--- En-route task that assigns the controlled group to engage targets matching specific parameters. The `EngageTargets` en-route task as the Mission Editor writes it (ANTI_SHIP: Anti-Ship (Engage enemy ships); CAP: CAP (Engage enemy aircraft); CAS: CAS (Engage enemy ground forces); ENGAGE_TARGETS: Engage Targets (Engage targets of specific types along the route); FIGHTER_SWEEP: Fighter Sweep (Engage enemy aircraft. Enemy fighters are prioritiest targets); SEAD: SEAD (Engage enemy air defense)).
---@class DcsTask.EnrouteTask.EngageTargets
---@field id "EngageTargets" Always `"EngageTargets"` (DCS casing).
---@field key? DcsTask.EnrouteTask.EngageTargetsKey Optional Mission Editor variant key (the Mission Editor's own; whether DCS reads it is not known).
---@field params? DcsTask.EnrouteTask.EngageTargetsParams Parameters; every one optional.

--- Ground escort task that directs helicopters to provide aerial protection for ground units. The `GroundEscort` task as the Mission Editor writes it (GROUND_ESCORT: Ground Escort (Escort the ground vehicle group: follow it and protect it from specific types of threats)).
---@class DcsTask.Task.GroundEscort
---@field id "GroundEscort" Always `"GroundEscort"` (DCS casing).
---@field params? DcsTask.Task.GroundEscortParams Parameters; every one optional.

--- Naval recovery tanker task that directs an aircraft to orbit above a vessel group, providing refueling services. The `RecoveryTanker` task as the Mission Editor writes it (RECOVERY_TANKER: Recovery tanker (Follow carrier with race track pattern awaiting AAR clients)).
---@class DcsTask.Task.RecoveryTanker
---@field id "RecoveryTanker" Always `"RecoveryTanker"` (DCS casing).
---@field params? DcsTask.Task.RecoveryTankerParams Parameters; every one optional.

--- An option as the Mission Editor writes it (inside a `WrappedAction`).
---@class DcsTask.Option
---@field id "Option" Always `"Option"` (DCS casing).
---@field params DcsTask.OptionParams Option and value.

--- Parameters of `Escort`.
---@class DcsTask.Task.EscortParams
---@field engagementDistMax? number Maximum distance of targets from the followed aircraft that the AI will actively engage Seen in: default, panel, missions. Mission Editor default: `60000`. Set by 344 of 344 install mission uses.
---@field formation? DcsId.FormationValue|number Formation number, as the FORMATION option takes (DcsTask.OptionValue.FORMATION_*). Hand-authored (overlays.yaml): in no Mission Editor default or source, DCS script or install mission.
---@field groupId? number Unique ID of the group to escort Seen in: panel, missions. Set by 342 of 344 install mission uses.
---@field lastWptIndex? number Identifies the waypoint at which the following group will stop its task (default: -1) Seen in: declared, panel, missions. Set by 344 of 344 install mission uses.
---@field lastWptIndexFlag? boolean If true the AI will follow the group until it reaches a specified waypoint (default: true) Seen in: default, panel, missions. Mission Editor default: true. Set by 317 of 344 install mission uses.
---@field lastWptIndexFlagChangedManually? boolean Seen in: default, panel, missions. Mission Editor default: true. Set by 317 of 344 install mission uses.
---@field noTargetTypes? (DcsId.Attribute|string)[] Seen in: panel, missions. Set by 180 of 344 install mission uses.
---@field pos? table Vec3 point defining the relative position the controlled flight will form up on Seen in: default, panel, missions. Mission Editor default: a table. Set by 344 of 344 install mission uses.
---@field targetTypes? (DcsId.Attribute|string)[] Array of attribute types which the AI will engage Seen in: panel, missions. Set by 344 of 344 install mission uses.
---@field value? string Seen in: panel, missions. Set by 73 of 344 install mission uses. Install mission values: `"Fighters;"` (19), `"Air;"` (12), `"none;"` (12), `"Planes;"` (9), `"Helicopters;"` (8), `"Fighters;Multirole fighters;"` (5), `"SAM related;"` (4), `"Air Defence;"` (2), `"Fighters;Bombers;Interceptors;"` (1), `"Infantry;Fortifications;Ground vehicles;"` (1).
---@field x? number Seen in: missions. Set by 16 of 344 install mission uses.
---@field y? number Seen in: missions. Set by 16 of 344 install mission uses.

--- Parameters of `FollowBigFormation`.
---@class DcsTask.Task.FollowBigFormationParams
---@field formation? DcsId.FormationValue|number Formation number, as the FORMATION option takes (DcsTask.OptionValue.FORMATION_*). Hand-authored (overlays.yaml): in no Mission Editor default or source, DCS script or install mission.
---@field formationType? DcsId.FormationId|number Seen in: default, panel, missions. Mission Editor default: `0`. Set by 7 of 7 install mission uses.
---@field groupId? number Unique ID of the lead aircraft group to follow. Seen in: panel, missions. Set by 7 of 7 install mission uses.
---@field lastWptIndex? number Waypoint index of the lead group that, when reached, will cause the following aircraft to terminate the task. Seen in: declared, panel, missions. Set by 7 of 7 install mission uses.
---@field lastWptIndexFlag? boolean Determines whether the AI will terminate the follow task when the lead group reaches a specified waypoint. Seen in: default, panel, missions. Mission Editor default: true. Set by 7 of 7 install mission uses.
---@field lastWptIndexFlagChangedManually? boolean Seen in: default, panel, missions. Mission Editor default: true. Set by 7 of 7 install mission uses.
---@field pos? table A `Vec3` representing the relative position the controlled flight will maintain within the formation in the DCS World coordinate system. Seen in: default, panel, missions. Mission Editor default: a table. Set by 7 of 7 install mission uses.
---@field posInBox? number Seen in: default, panel, missions. Mission Editor default: `1`. Set by 7 of 7 install mission uses.
---@field posInGroup? number Seen in: default, panel, missions. Mission Editor default: `1`. Set by 7 of 7 install mission uses.
---@field posInWing? number Seen in: default, panel, missions. Mission Editor default: `1`. Set by 7 of 7 install mission uses.

--- Parameters of `Follow`.
---@class DcsTask.Task.FollowParams
---@field escort? boolean Seen in: missions. Set by 11 of 1720 install mission uses.
---@field formation? DcsId.FormationValue|number Formation number, as the FORMATION option takes (DcsTask.OptionValue.FORMATION_*). Hand-authored (overlays.yaml): in no Mission Editor default or source, DCS script or install mission.
---@field groupId? number Unique ID of the group to follow or orbit above if it's a ground unit. Seen in: panel, missions. Set by 1707 of 1720 install mission uses.
---@field lastWptIndex? number Waypoint index of the lead group that, when reached, will cause the following aircraft to terminate the task. Seen in: declared, panel, missions. Set by 1697 of 1720 install mission uses.
---@field lastWptIndexFlag? boolean Determines whether the AI will terminate the follow task when the lead group reaches a specified waypoint. Seen in: default, panel, missions. Mission Editor default: true. Set by 1709 of 1720 install mission uses.
---@field lastWptIndexFlagChangedManually? boolean Seen in: default, panel, missions. Mission Editor default: true. Set by 1709 of 1720 install mission uses.
---@field pos? table A `Vec3` representing the relative position the controlled flight will maintain within the formation in the DCS World coordinate system. Seen in: default, panel, missions. Mission Editor default: a table. Set by 1720 of 1720 install mission uses.
---@field x? number Seen in: missions. Set by 17 of 1720 install mission uses.
---@field y? number Seen in: missions. Set by 17 of 1720 install mission uses.

--- Defines the structure of a Lua table representing a task with start and stop conditions that determine when to execute and terminate the task.
--- (Data structure definition for ControlledTask. Not a globally accessible table.)
---@class ControlledTask
---@field id string Task identifier, must be 'ControlledTask'.
---@field params ControlledTaskParams A table containing parameters that configure the task execution conditions.

--- Command that changes a group's identification callsign for radio communications. The `SetCallsign` command as the Mission Editor writes it (SET_CALLSIGN: Set Callsign (Set callname and group number to the group.)).
---@class DcsTask.Command.SetCallsign
---@field id "SetCallsign" Always `"SetCallsign"` (DCS casing).
---@field params? DcsTask.Command.SetCallsignParams Parameters; every one optional.

--- Command that changes the radio broadcasting frequency for a specific unit within an AI group. The `SetFrequencyForUnit` command as the Mission Editor writes it (SET_FREQUENCYFORUNIT: Set Frequency for unit (Set frequency to radios to the unit)).
---@class DcsTask.Command.SetFrequencyForUnit
---@field id "SetFrequencyForUnit" Always `"SetFrequencyForUnit"` (DCS casing).
---@field params? DcsTask.Command.SetFrequencyForUnitParams Parameters; every one optional.

--- Command that changes the radio broadcasting frequency for an AI group. The `SetFrequency` command as the Mission Editor writes it (SET_FREQUENCY: Set Frequency (Set frequency to radios of all the units in the group.)).
---@class DcsTask.Command.SetFrequency
---@field id "SetFrequency" Always `"SetFrequency"` (DCS casing).
---@field params? DcsTask.Command.SetFrequencyParams Parameters; every one optional.

--- Command that toggles a group's visibility to enemy AI sensors. The `SetInvisible` command as the Mission Editor writes it (INVISIBLE: Invisible (Make all units of the group invisible.)).
---@class DcsTask.Command.SetInvisible
---@field id "SetInvisible" Always `"SetInvisible"` (DCS casing).
---@field params? DcsTask.Command.SetInvisibleParams Parameters; every one optional.

--- En-route task that assigns the controlled group to search for and engage a specific group. The target must be detected for AI to engage it. The `EngageGroup` en-route task as the Mission Editor writes it (ENGAGE_GROUP: Engage Group (Allow the group to engage the enemy group during the mission)).
---@class DcsTask.EnrouteTask.EngageGroup
---@field id "EngageGroup" Always `"EngageGroup"` (DCS casing).
---@field params? DcsTask.EnrouteTask.EngageGroupParams Parameters; every one optional.

--- En-route task that assigns the controlled group to act as a Forward Air Controller or JTAC. Any detected targets will be assigned as targets to the player via the JTAC radio menu. The `FAC` en-route task as the Mission Editor writes it (FAC: FAC (Make the lead aircraft of the a FAC and let it to choose targets to assign by its own)).
---@class DcsTask.EnrouteTask.FAC
---@field id "FAC" Always `"FAC"` (DCS casing).
---@field params? DcsTask.EnrouteTask.FACParams Parameters; every one optional.

--- En-route task that assigns the controlled group to act as a Forward Air Controller or JTAC and engage the specified group as a JTAC target once detected. The `FAC_EngageGroup` en-route task as the Mission Editor writes it (FAC_ENGAGE_GROUP: FAC - Engage Group (Make the lead aircraft of the group FAC and allow it to assign the enemy group)).
---@class DcsTask.EnrouteTask.FAC_EngageGroup
---@field id "FAC_EngageGroup" Always `"FAC_EngageGroup"` (DCS casing).
---@field params? DcsTask.EnrouteTask.FAC_EngageGroupParams Parameters; every one optional.

--- Attack task that directs a group to engage another group. The `AttackGroup` task as the Mission Editor writes it (ATTACK_GROUP: Attack Group (Attack the enemy group)). Also sent by DCS's scripts: forceAttackGroup (Scripts/rtsScripting.lua, pushTask).
---@class DcsTask.Task.AttackGroup
---@field id "AttackGroup" Always `"AttackGroup"` (DCS casing).
---@field params? DcsTask.Task.AttackGroupParams Parameters; every one optional.

--- Assigns the controlled group to act as a Forward Air Controller or JTAC in attacking the specified group. This task adds the group to the JTAC radio menu and interacts with a player to destroy the target. The `FAC_AttackGroup` task as the Mission Editor writes it (FAC_ATTACK_GROUP: FAC - Attack Group (Make the lead unit of the group FAC and assign it the target to designate)).
---@class DcsTask.Task.FAC_AttackGroup
---@field id "FAC_AttackGroup" Always `"FAC_AttackGroup"` (DCS casing).
---@field params? DcsTask.Task.FAC_AttackGroupParams Parameters; every one optional.

--- Defines the structure of a Lua table representing a target detected by a controller, including its object reference and detection details.
--- (Data structure definition for ControllerDetectedTarget. Not a globally accessible table.)
---@class ControllerDetectedTarget
---@field object? Object Reference to the detected target object.
---@field visible? boolean Whether the target is currently visible via line of sight.
---@field type? boolean Whether the target's specific type is known to the detector.
---@field distance? boolean Whether the distance to the target is known to the detector.

--- Base structure for all event data. Contains common fields present in every event.
--- (Data structure definition for EventDataBase. Not a globally accessible table.)
---@class EventDataBase
---@field id? world.event The event ID that identifies the type of event.
---@field time? number Timestamp when the event occurred in mission time.
---@field initiator? Object The initiating object (can be a Unit, StaticObject, or other object type depending on event).

--- Base structure for mark-related events.
--- (Data structure definition for EventDataMarkBase. Not a globally accessible table.)
---@class EventDataMarkBase
---@field id? world.event The event ID that identifies the type of event.
---@field time? number Timestamp when the event occurred in mission time.
---@field initiator? Object The initiating object (can be a Unit, StaticObject, or other object type depending on event).
---@field MarkID? number ID of the mark that was added, changed, or removed.
---@field MarkText? string Text of the mark.
---@field MarkCoordinate? Vec3 Coordinate of the mark.
---@field MarkCoalition? coalition.side Coalition that owns the mark.

--- Event data structure for S_EVENT_SHOOTING_START events. Occurs when continuous shooting begins.
--- (Data structure definition for EventDataShootingStart. Not a globally accessible table.)
---@class EventDataShootingStart
---@field id? world.event The event ID that identifies the type of event.
---@field time? number Timestamp when the event occurred in mission time.
---@field initiator? Object The initiating object (can be a Unit, StaticObject, or other object type depending on event).
---@field target? Object The target being shot at, if applicable.

--- Event data structure for S_EVENT_WEAPON_ADD events. Occurs when a weapon is added to a unit.
--- (Data structure definition for EventDataWeaponAdd. Not a globally accessible table.)
---@class EventDataWeaponAdd
---@field id? world.event The event ID that identifies the type of event.
---@field time? number Timestamp when the event occurred in mission time.
---@field initiator? Object The initiating object (can be a Unit, StaticObject, or other object type depending on event).
---@field WeaponName? string Name of the weapon that was added.

--- Represents a numerically indexed table of `Object` instances.
---@alias ObjectArray Object[]

--- Defines the structure of a Lua table representing a specific weapon or ammunition type and its quantity in a unit's inventory.
--- (Data structure definition for UnitAmmoItem. Not a globally accessible table.)
---@class UnitAmmoItem
---@field count? number A numeric value indicating the quantity of this ammunition type available to the unit.
---@field desc? UnitAmmoDesc A table representing the specifications and capabilities of this ammunition type.

--- Defines the structure of a Lua table representing spawn parameters for a static object used with coalition.addStaticObject.
--- (Data structure definition for StaticObjectSpawnData. Not a globally accessible table.)
---@class StaticObjectSpawnData
---@field name? string A string identifier for the static object.
---@field type? DcsId.StaticType|string A string specifying the classification or model type of the static object.
---@field x? number X coordinate of the static object's position in the DCS World coordinate system.
---@field y? number Y coordinate of the static object's position in the DCS World coordinate system.
---@field heading? number Orientation angle in radians representing the static object's heading in the DCS World.
---@field category? string A string specifying the functional category of the static object.
---@field dead? boolean Controls whether the static object spawns in a destroyed state.
---@field shape_name? string A string identifying the 3D model resource used to render the static object.
---@field rate? number A numeric value controlling the visual appearance rate, typically set to 100.
---@field canCargo? boolean Controls whether the static object can be loaded as cargo.
---@field mass? number A numeric value specifying the object's mass in kilograms.

--- The `EmbarkToTransport` task as the Mission Editor writes it (EMBARK_TO_TRANSPORT: Embark to transport (Embark to transport)).
---@class DcsTask.Task.EmbarkToTransport
---@field id "EmbarkToTransport" Always `"EmbarkToTransport"` (DCS casing).
---@field params? DcsTask.Task.EmbarkToTransportParams Parameters; every one optional.

--- Defines the structure of a Lua table containing an ordered sequence of waypoints that form a route.
--- (Data structure definition for MissionRoute. Not a globally accessible table.)
---@class MissionRoute
---@field points MissionWaypoint[] A numerically indexed table of waypoint objects that define the mission route.

--- Controlled aircraft will follow the assigned group along their route in formation and will engage threats within a defined distance from the followed group. The `Escort` task as the Mission Editor writes it (ESCORT: Escort (Escort the another group: follow it and protect it from specific types of threats)).
---@class DcsTask.Task.Escort
---@field id "Escort" Always `"Escort"` (DCS casing).
---@field params? DcsTask.Task.EscortParams Parameters; every one optional.

--- Advanced formation-following task for coordinated bombing missions with multiple aircraft. The `FollowBigFormation` task as the Mission Editor writes it (WW2_BIG_FORMATION: Big formation (Follow as big formation)).
---@class DcsTask.Task.FollowBigFormation
---@field id "FollowBigFormation" Always `"FollowBigFormation"` (DCS casing).
---@field params? DcsTask.Task.FollowBigFormationParams Parameters; every one optional.

--- Follow task that directs aircraft to join formation with another group or orbit above ground units. The `Follow` task as the Mission Editor writes it (FOLLOW: Follow (Follow the another group)).
---@class DcsTask.Task.Follow
---@field id "Follow" Always `"Follow"` (DCS casing).
---@field params? DcsTask.Task.FollowParams Parameters; every one optional.

--- Any command table, by DCS id.
---@alias DcsTask.AnyCommand DcsTask.Command.ActivateACLS|DcsTask.Command.ActivateBeacon|DcsTask.Command.ActivateGCI|DcsTask.Command.ActivateICLS|DcsTask.Command.ActivateJammer|DcsTask.Command.ActivateLink4|DcsTask.Command.ActivateRSBN|DcsTask.Command.DeactivateACLS|DcsTask.Command.DeactivateBeacon|DcsTask.Command.DeactivateGCI|DcsTask.Command.DeactivateICLS|DcsTask.Command.DeactivateJammer|DcsTask.Command.DeactivateLink4|DcsTask.Command.DeactivateRSBN|DcsTask.Command.EPLRS|DcsTask.Command.LoadingShip|DcsTask.Command.NoAction|DcsTask.Command.SMOKE_ON_OFF|DcsTask.Command.Script|DcsTask.Command.ScriptFile|DcsTask.Command.SetCallsign|DcsTask.Command.SetFrequency|DcsTask.Command.SetFrequencyForUnit|DcsTask.Command.SetImmortal|DcsTask.Command.SetInvisible|DcsTask.Command.SetUnlimitedFuel|DcsTask.Command.Start|DcsTask.Command.StopRoute|DcsTask.Command.StopTransmission|DcsTask.Command.SwitchAction|DcsTask.Command.SwitchWaypoint|DcsTask.Command.TransmitMessage

--- Any en-route task table, by DCS id.
---@alias DcsTask.AnyEnrouteTask DcsTask.EnrouteTask.AWACS|DcsTask.EnrouteTask.EWR|DcsTask.EnrouteTask.EngageGroup|DcsTask.EnrouteTask.EngageTargets|DcsTask.EnrouteTask.EngageTargetsInZone|DcsTask.EnrouteTask.EngageUnit|DcsTask.EnrouteTask.FAC|DcsTask.EnrouteTask.FAC_EngageGroup|DcsTask.EnrouteTask.NoTask|DcsTask.EnrouteTask.Tanker

--- Represents a numerically indexed Lua table (sequence) where each element is a table containing information about a detected target.
---@alias ControllerDetectedTargetArray ControllerDetectedTarget[]

--- Defines the structure of a Lua table representing a group to be spawned with coalition.addGroup or coalition.add_dyn_group functions.
--- (Data structure definition for GroupSpawnData. Not a globally accessible table.)
---@class GroupSpawnData
---@field name? string A string identifier for the group, must be unique within the mission.
---@field task? DcsId.MainTask|string The primary mission task assigned to the group, determines default behavior patterns; ground groups have `"Ground Nothing"`.
---@field units? UnitSpawnData[] A numerically indexed table of unit definitions for all units in the group, each containing position, type, and other properties.
---@field x? number X coordinate of the group's reference position in the DCS World coordinate system.
---@field y? number Y coordinate of the group's reference position in the DCS World coordinate system.
---@field start_time? number Time in seconds after mission start when the group will spawn (0 for immediate spawn).
---@field visible? boolean Controls visibility of the group before its scheduled start time in the mission editor.
---@field taskSelected? boolean Indicates if the task is selected for execution when the group spawns.
---@field route? MissionRoute A table defining waypoints and assigned tasks for the group's route, determining movement patterns.
---@field hidden? boolean Controls visibility of the group on the F10 map view for players.
---@field groupId? number Optional unique numeric identifier for the group, used for scripting references.

--- Defines the structure of a Lua table detailing mission execution parameters and route information.
--- (Data structure definition for MissionParams. Not a globally accessible table.)
---@class MissionParams
---@field airborne? boolean Indicates whether the aircraft group is already airborne when the mission is assigned.
---@field route MissionRoute A table containing the route waypoints to be followed during the mission.

--- Any task table, by DCS id.
---@alias DcsTask.AnyTask DcsTask.Task.Aerobatics|DcsTask.Task.AttachTrailer|DcsTask.Task.AttackGroup|DcsTask.Task.AttackMapObject|DcsTask.Task.AttackUnit|DcsTask.Task.Barcap|DcsTask.Task.Bombing|DcsTask.Task.BombingRunway|DcsTask.Task.CargoTransportation|DcsTask.Task.CargoTransportationPlane|DcsTask.Task.CargoUnloadPlane|DcsTask.Task.CarpetBombing|DcsTask.Task.DetachTrailer|DcsTask.Task.Disembarking|DcsTask.Task.EmbarkToTransport|DcsTask.Task.Embarking|DcsTask.Task.Escort|DcsTask.Task.ExternalCargoLoad|DcsTask.Task.ExternalCargoUnLoad|DcsTask.Task.FAC_AttackGroup|DcsTask.Task.FarpSpawn|DcsTask.Task.FireAtPoint|DcsTask.Task.Follow|DcsTask.Task.FollowBigFormation|DcsTask.Task.GoToWaypoint|DcsTask.Task.GroundEscort|DcsTask.Task.Hold|DcsTask.Task.Land|DcsTask.Task.NoTask|DcsTask.Task.Orbit|DcsTask.Task.ParatroopersDrop|DcsTask.Task.RecoveryTanker|DcsTask.Task.Refueling|DcsTask.Task.ShipHoldPoint|DcsTask.Task.Strafing|DcsTask.Task.TossAttack

--- Parameters of a `WrappedAction`.
---@class DcsTask.WrappedActionParams
---@field action DcsTask.AnyCommand|DcsTask.Option The wrapped command or option.

--- Defines the structure of a Lua table representing a route-based mission consisting of waypoints assigned to a group.
--- (Data structure definition for Mission. Not a globally accessible table.)
---@class Mission
---@field id "Mission" Task identifier, always `"Mission"`.
---@field params MissionParams A table containing parameters that define the mission configuration.

--- A command or option as a task (how the Mission Editor stores them in a route).
---@class DcsTask.WrappedAction
---@field id "WrappedAction" Always `"WrappedAction"` (DCS casing).
---@field params DcsTask.WrappedActionParams The action.

--- Represents a numerically indexed Lua table (sequence) of `Airbase` objects in the DCS World mission.
---@alias AirbaseArray Airbase[]

--- Event data structure that contains information about an event. The id field identifies which type of event is being handled.
--- (Data structure definition for EventData. Not a globally accessible table.)
---@class EventData
---@field id? world.event The event ID that identifies the type of event.
---@field time? number Timestamp when the event occurred in mission time.
---@field initiator? Object The initiating object (can be a Unit, StaticObject, or other object type depending on event).
---@field target? Object The target object involved in the event (present in hit, kill, shooting events).
---@field weapon? Weapon The weapon used during the event (present in shot, hit, kill events).
---@field WeaponName? string Name of the weapon (present in weapon_add events).
---@field place? Airbase The place object (used in landing, takeoff, birth, base_captured events).
---@field subplace? world.BirthPlace The specific location within the place (used in birth events).
---@field MarkID? number ID of the mark in mark-related events.
---@field MarkText? string Text of the mark.
---@field MarkCoordinate? Vec3 Coordinate of the mark.
---@field MarkCoalition? coalition.side Coalition that owns the mark.
---@field Zone? Zone The zone object in trigger zone events.
---@field Cargo? Cargo The cargo object in cargo-related events.
---@field IniCoalition? coalition.side Coalition of the initiator.
---@field TgtCoalition? coalition.side Coalition of the target.
---@field IniPlayerName? string Name of the player that initiated the event.
---@field TgtPlayerName? string Name of the player that was targeted.

--- Event data structure for S_EVENT_BASE_CAPTURED events. Occurs when a base is captured.
--- (Data structure definition for EventDataBaseCaptured. Not a globally accessible table.)
---@class EventDataBaseCaptured
---@field id? world.event The event ID that identifies the type of event.
---@field time? number Timestamp when the event occurred in mission time.
---@field initiator? Object The initiating object (can be a Unit, StaticObject, or other object type depending on event).
---@field place? Airbase The airbase that was captured.

--- Event data structure for S_EVENT_BIRTH events. Occurs when an object is spawned.
--- (Data structure definition for EventDataBirth. Not a globally accessible table.)
---@class EventDataBirth
---@field id? world.event The event ID that identifies the type of event.
---@field time? number Timestamp when the event occurred in mission time.
---@field initiator? Object The initiating object (can be a Unit, StaticObject, or other object type depending on event).
---@field place? Airbase The place where the unit was spawned, if applicable.
---@field subplace? world.BirthPlace The specific location type within the place where the unit was spawned.

--- Event data structure containing all possible fields from any event type.
--- (Data structure definition for EventDataGeneric. Not a globally accessible table.)
---@class EventDataGeneric
---@field id? world.event The event ID that identifies the type of event.
---@field time? number Timestamp when the event occurred in mission time.
---@field initiator? Object The initiating object (can be a Unit, StaticObject, or other object type depending on event).
---@field IniObjectCategory? Object.Category (UNIT/STATIC/SCENERY) The initiator object category (Object.Category.UNIT or Object.Category.STATIC).
---@field IniDCSUnit? StaticObject|Unit (UNIT/STATIC) The initiating DCS Unit or StaticObject.
---@field IniDCSUnitName? string (UNIT/STATIC) The initiating Unit name.
---@field IniUnit? Unit (UNIT) The initiating MOOSE Unit wrapper of the initiator Unit object.
---@field IniUnitName? string (UNIT) The initiating UNIT name (same as IniDCSUnitName).
---@field IniDCSGroup? Group (UNIT) The initiating Group.
---@field IniDCSGroupName? string (UNIT) The initiating Group name.
---@field IniGroup? Group (UNIT) The initiating GROUP object.
---@field IniGroupName? string (UNIT) The initiating GROUP name (same as IniDCSGroupName).
---@field IniCategory? Unit.Category (UNIT) The category of the initiator.
---@field IniCoalition? coalition.side (UNIT) The coalition of the initiator.
---@field IniTypeName? string (UNIT) The type name of the initiator.
---@field IniPlayerName? string (UNIT) The name of the initiating player in case the Unit is a client or player slot.
---@field IniPlayerUCID? string (UNIT) The UCID of the initiating player in case the Unit is a client or player slot.
---@field target? Object (UNIT/STATIC) The target object (Unit/StaticObject/other depending on event type).
---@field TgtObjectCategory? Object.Category (UNIT/STATIC) The target object category (Object.Category.UNIT or Object.Category.STATIC).
---@field TgtDCSUnit? StaticObject|Unit (UNIT/STATIC) The target DCS Unit or StaticObject.
---@field TgtDCSUnitName? string (UNIT/STATIC) The target Unit name.
---@field TgtUnit? Unit (UNIT) The target Unit object.
---@field TgtUnitName? string (UNIT) The target UNIT name (same as TgtDCSUnitName).
---@field TgtDCSGroup? Group (UNIT) The target Group.
---@field TgtDCSGroupName? string (UNIT) The target Group name.
---@field TgtGroup? Group (UNIT) The target GROUP object.
---@field TgtGroupName? string (UNIT) The target GROUP name (same as TgtDCSGroupName).
---@field TgtCategory? Unit.Category (UNIT) The category of the target.
---@field TgtCoalition? coalition.side (UNIT) The coalition of the target.
---@field TgtTypeName? string (UNIT) The type name of the target.
---@field TgtPlayerName? string (UNIT) The name of the target player in case the Unit is a client or player slot.
---@field TgtPlayerUCID? string (UNIT) The UCID of the target player in case the Unit is a client or player slot.
---@field weapon? Weapon The weapon used during the event (present in shot, hit, kill events).
---@field WeaponName? string Name of the weapon.
---@field WeaponTypeName? string Type name of the weapon.
---@field WeaponCategory? Weapon.Category Category of the weapon.
---@field WeaponCoalition? coalition.side Coalition of the weapon.
---@field WeaponPlayerName? string Player name associated with the weapon, if applicable.
---@field WeaponTgtDCSUnit? Unit Target unit of the weapon.
---@field WeaponUNIT? Unit Sometimes, the weapon is a player unit.
---@field place? Airbase The place object (used in landing, takeoff, birth, base_captured events).
---@field PlaceName? string The name of the place.
---@field subplace? world.BirthPlace The specific location within the place (used in birth events).
---@field MarkID? number ID of the mark in mark-related events.
---@field MarkText? string Text of the mark.
---@field MarkCoordinate? Vec3 Coordinate of the mark.
---@field MarkVec3? Vec3 Vector 3D position of the mark.
---@field MarkCoalition? coalition.side Coalition that owns the mark.
---@field MarkGroupID? number Group ID associated with the mark, if applicable.
---@field Cargo? Cargo The cargo object in cargo-related events.
---@field CargoName? string The name of the cargo.
---@field IniDynamicCargo? DynamicCargo The dynamic cargo object in dynamic cargo events.
---@field IniDynamicCargoName? string The name of the dynamic cargo.
---@field Zone? Zone The zone object in zone-related events.
---@field ZoneName? string The name of the zone.

--- Event data structure for S_EVENT_HIT events. Occurs whenever an object is hit by a weapon.
--- (Data structure definition for EventDataHit. Not a globally accessible table.)
---@class EventDataHit
---@field id? world.event The event ID that identifies the type of event.
---@field time? number Timestamp when the event occurred in mission time.
---@field initiator? Object The initiating object (can be a Unit, StaticObject, or other object type depending on event).
---@field weapon? Weapon The weapon that hit the target. May be nil in multiplayer due to desync issues.
---@field target? Object The object that was hit.

--- Event data structure for S_EVENT_KILL events. Occurs when a unit kills another unit.
--- (Data structure definition for EventDataKill. Not a globally accessible table.)
---@class EventDataKill
---@field id? world.event The event ID that identifies the type of event.
---@field time? number Timestamp when the event occurred in mission time.
---@field initiator? Object The initiating object (can be a Unit, StaticObject, or other object type depending on event).
---@field target? Object The object that was killed.
---@field weapon? Weapon The weapon that caused the kill, if applicable.

--- Event data structure for S_EVENT_LAND events. Occurs when an aircraft lands.
--- (Data structure definition for EventDataLand. Not a globally accessible table.)
---@class EventDataLand
---@field id? world.event The event ID that identifies the type of event.
---@field time? number Timestamp when the event occurred in mission time.
---@field initiator? Object The initiating object (can be a Unit, StaticObject, or other object type depending on event).
---@field place? Airbase The airbase or ship where the landing occurred.

--- Event data structure for S_EVENT_SHOT events. Occurs whenever any unit fires a weapon.
--- (Data structure definition for EventDataShot. Not a globally accessible table.)
---@class EventDataShot
---@field id? world.event The event ID that identifies the type of event.
---@field time? number Timestamp when the event occurred in mission time.
---@field initiator? Object The initiating object (can be a Unit, StaticObject, or other object type depending on event).
---@field weapon? Weapon The weapon that was fired.

--- Event data structure for S_EVENT_TAKEOFF events. Occurs when an aircraft takes off.
--- (Data structure definition for EventDataTakeoff. Not a globally accessible table.)
---@class EventDataTakeoff
---@field id? world.event The event ID that identifies the type of event.
---@field time? number Timestamp when the event occurred in mission time.
---@field initiator? Object The initiating object (can be a Unit, StaticObject, or other object type depending on event).
---@field place? Airbase The airbase or ship from which the takeoff occurred.

--- Maps event IDs to their respective event data types. Used to document which event types correspond to which event IDs.
--- (Data structure definition for EventTypeMap. Not a globally accessible table.)
---@class EventTypeMap
---@field S_EVENT_INVALID? EventDataBase Event data for invalid events (ID 0).
---@field S_EVENT_SHOT? EventDataShot Event data for shot events (ID 1).
---@field S_EVENT_HIT? EventDataHit Event data for hit events (ID 2).
---@field S_EVENT_TAKEOFF? EventDataTakeoff Event data for takeoff events (ID 3).
---@field S_EVENT_LAND? EventDataLand Event data for landing events (ID 4).
---@field S_EVENT_CRASH? EventDataGeneric Event data for crash events (ID 5).
---@field S_EVENT_EJECTION? EventDataGeneric Event data for ejection events (ID 6).
---@field S_EVENT_REFUELING? EventDataGeneric Event data for refueling events (ID 7).
---@field S_EVENT_DEAD? EventDataGeneric Event data for dead events (ID 8).
---@field S_EVENT_PILOT_DEAD? EventDataGeneric Event data for pilot dead events (ID 9).
---@field S_EVENT_BASE_CAPTURED? EventDataBaseCaptured Event data for base captured events (ID 10).
---@field S_EVENT_MISSION_START? EventDataGeneric Event data for mission start events (ID 11).
---@field S_EVENT_MISSION_END? EventDataGeneric Event data for mission end events (ID 12).
---@field S_EVENT_TOOK_CONTROL? EventDataGeneric Event data for took control events (ID 13).
---@field S_EVENT_REFUELING_STOP? EventDataGeneric Event data for refueling stop events (ID 14).
---@field S_EVENT_BIRTH? EventDataBirth Event data for birth/spawn events (ID 15).
---@field S_EVENT_HUMAN_FAILURE? EventDataGeneric Event data for human failure events (ID 16).
---@field S_EVENT_DETAILED_FAILURE? EventDataGeneric Event data for detailed failure events (ID 17).
---@field S_EVENT_ENGINE_STARTUP? EventDataGeneric Event data for engine startup events (ID 18).
---@field S_EVENT_ENGINE_SHUTDOWN? EventDataGeneric Event data for engine shutdown events (ID 19).
---@field S_EVENT_PLAYER_ENTER_UNIT? EventDataGeneric Event data for player enter unit events (ID 20).
---@field S_EVENT_PLAYER_LEAVE_UNIT? EventDataGeneric Event data for player leave unit events (ID 21).
---@field S_EVENT_PLAYER_COMMENT? EventDataGeneric Event data for player comment events (ID 22).
---@field S_EVENT_SHOOTING_START? EventDataShootingStart Event data for shooting start events (ID 23).
---@field S_EVENT_SHOOTING_END? EventDataGeneric Event data for shooting end events (ID 24).
---@field S_EVENT_MARK_ADDED? EventDataMarkBase Event data for mark added events (ID 25).
---@field S_EVENT_MARK_CHANGE? EventDataMarkBase Event data for mark change events (ID 26).
---@field S_EVENT_MARK_REMOVED? EventDataMarkBase Event data for mark removed events (ID 27).
---@field S_EVENT_KILL? EventDataKill Event data for kill events (ID 28).
---@field S_EVENT_SCORE? EventDataGeneric Event data for score events (ID 29).
---@field S_EVENT_UNIT_LOST? EventDataGeneric Event data for unit lost events (ID 30).
---@field S_EVENT_LANDING_AFTER_EJECTION? EventDataGeneric Event data for landing after ejection events (ID 31).
---@field S_EVENT_PARATROOPER_LENDING? EventDataGeneric Event data for paratrooper landing events (ID 32).
---@field S_EVENT_DISCARD_CHAIR_AFTER_EJECTION? EventDataGeneric Event data for discard chair after ejection events (ID 33).
---@field S_EVENT_WEAPON_ADD? EventDataWeaponAdd Event data for weapon add events (ID 34).
---@field S_EVENT_TRIGGER_ZONE? EventDataGeneric Event data for trigger zone events (ID 35).
---@field S_EVENT_LANDING_QUALITY_MARK? EventDataGeneric Event data for landing quality mark events (ID 36).
---@field S_EVENT_BDA? EventDataGeneric Event data for battle damage assessment events (ID 37).
---@field S_EVENT_AI_ABORT_MISSION? EventDataGeneric Event data for AI abort mission events (ID 38).
---@field S_EVENT_DAYNIGHT? EventDataGeneric Event data for day/night transition events (ID 39).
---@field S_EVENT_FLIGHT_TIME? EventDataGeneric Event data for flight time events (ID 40).
---@field S_EVENT_PLAYER_SELF_KILL_PILOT? EventDataGeneric Event data for player self-kill pilot events (ID 41).
---@field S_EVENT_PLAYER_CAPTURE_AIRFIELD? EventDataGeneric Event data for player capture airfield events (ID 42).
---@field S_EVENT_EMERGENCY_LANDING? EventDataGeneric Event data for emergency landing events (ID 43).
---@field S_EVENT_UNIT_CREATE_TASK? EventDataGeneric Event data for unit create task events (ID 44).
---@field S_EVENT_UNIT_DELETE_TASK? EventDataGeneric Event data for unit delete task events (ID 45).
---@field S_EVENT_SIMULATION_START? EventDataGeneric Event data for simulation start events (ID 46).
---@field S_EVENT_WEAPON_REARM? EventDataGeneric Event data for weapon rearm events (ID 47).
---@field S_EVENT_WEAPON_DROP? EventDataGeneric Event data for weapon drop events (ID 48).
---@field S_EVENT_UNIT_TASK_COMPLETE? EventDataGeneric Event data for unit task complete events (ID 49).
---@field S_EVENT_UNIT_TASK_STAGE? EventDataGeneric Event data for unit task stage events (ID 50).
---@field S_EVENT_MAC_EXTRA_SCORE? EventDataGeneric Event data for MAC extra score events (ID 51).
---@field S_EVENT_MISSION_RESTART? EventDataGeneric Event data for mission restart events (ID 52).
---@field S_EVENT_MISSION_WINNER? EventDataGeneric Event data for mission winner events (ID 53).
---@field S_EVENT_RUNWAY_TAKEOFF? EventDataGeneric Event data for runway takeoff events (ID 54).
---@field S_EVENT_RUNWAY_TOUCH? EventDataGeneric Event data for runway touch events (ID 55).
---@field S_EVENT_MAC_LMS_RESTART? EventDataGeneric Event data for MAC LMS restart events (ID 56).
---@field S_EVENT_SIMULATION_FREEZE? EventDataGeneric Event data for simulation freeze events (ID 57).
---@field S_EVENT_SIMULATION_UNFREEZE? EventDataGeneric Event data for simulation unfreeze events (ID 58).
---@field S_EVENT_HUMAN_AIRCRAFT_REPAIR_START? EventDataGeneric Event data for human aircraft repair start events (ID 59).
---@field S_EVENT_HUMAN_AIRCRAFT_REPAIR_FINISH? EventDataGeneric Event data for human aircraft repair finish events (ID 60).
---@field S_EVENT_MAX? EventDataBase Maximum event ID marker (ID 61).
