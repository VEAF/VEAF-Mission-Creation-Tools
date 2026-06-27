--[[ DCS World Lua Type Definitions
Generated from schema: dcs-world-api-schema.json
DO NOT MODIFY - AUTO-GENERATED FILE
Generated on: 2025-09-28T01:14:13.793598
--]]

---@meta

-- Global Namespaces and Classes
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
---@version 1.2.0
---@class trigger
---@field action table Contains functions that perform mission actions equivalent to Mission Editor trigger actions.
---@field misc table Contains utility functions for trigger operations and flag management.
trigger = trigger or {}

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
---@version 2.5.0
---@param message string Text content of the message.
---@param all boolean When `true`, sends to all players; when `false`, sends to current coalition only.
function net.send_chat(message, all) end

--- Sends a targeted chat message to a specific player, optionally appearing from another player.
---@version 2.5.0
---@param message string Text content of the message.
---@param playerId number Target player's unique identifier.
---@param fromId? number Source player's ID that the message will appear to come from.
function net.send_chat_to(message, playerId, fromId) end

--- Returns a numerically indexed table of player IDs currently connected to the server.
---@version 2.5.0
---@return table
function net.get_player_list() end

--- Returns the current player's unique identifier (always 1 for server scripts).
---@version 2.5.0
---@return number
function net.get_my_player_id() end

--- Returns the server's player ID, which is always 1.
---@version 2.5.0
---@return number
function net.get_server_id() end

--- Returns information about a player, either as a complete table or a specific attribute value.
---@version 2.5.0
---@param playerId number Target player's unique identifier.
---@param attribute? string Specific attribute name to return (e.g., `'name'`, `'ucid'`, `'ping'`).
---@return table
function net.get_player_info(playerId, attribute) end

--- Removes a player from the server with an optional displayed message.
---@version 2.5.0
---@param playerId number Target player's unique identifier.
---@param message string Explanation message displayed to the kicked player.
---@return boolean
function net.kick(playerId, message) end

--- Returns a specific statistical value for a player (e.g., kills, deaths).
---@version 2.5.0
---@param playerId number Target player's unique identifier.
---@param statID number Statistic identifier (one of the `net.PS_*` constants).
---@return number
function net.get_stat(playerId, statID) end

--- Returns a player's display name (equivalent to `net.get_player_info(playerID, 'name')`).
---@version 2.5.0
---@param playerId number Target player's unique identifier.
---@return string
function net.get_name(playerId) end

--- Returns a player's coalition ID and slot ID as two separate values.
---@version 2.5.0
---@param playerId number Target player's unique identifier.
---@return number
function net.get_slot(playerId) end

--- Moves a player to a specified coalition and aircraft/vehicle slot.
---@version 2.5.0
---@param playerID number Target player's unique identifier.
---@param sideId number Coalition ID (0 for spectators, 1 for Red, 2 for Blue).
---@param slotId string Unit ID or `UnitID_Seat` for multicrew positions.
---@return boolean
function net.force_player_slot(playerID, sideId, slotId) end

--- Serializes a Lua value into a JSON string.
---@version 2.5.0
---@param lua_value any Lua value to convert to JSON.
---@return string
function net.lua2json(lua_value) end

--- Parses a JSON string into equivalent Lua data.
---@version 2.5.0
---@param json_string string JSON string to convert to Lua.
---@return any
function net.json2lua(json_string) end

--- Executes a Lua code string in a specific DCS World environment context.
---@version 2.5.0
---@param state string Target environment (`'config'`, `'mission'`, or `'export'`).
---@param dostring string Lua code to execute.
---@return string
function net.dostring_in(state, dostring) end

--- Writes a message to the DCS server log file.
---@version 2.5.0
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


--- Provides functions for measuring mission time and scheduling deferred function execution in the DCS World environment.
---@class timer
timer = timer or {}
--- Returns the elapsed mission time in seconds since mission start, which pauses when the game is paused.
---@version 1.2.0
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
---@version 2.5.0
---@return boolean
function timer.getPause() end

--- Returns the game world time in seconds, based on the mission start time and continuously increasing regardless of pause state.
---@version 1.2.0
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
---@version 1.2.0
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
---@version 1.2.0
---@param functionToCall fun(...) Function to be executed at the scheduled time.
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
---@version 1.2.0
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
---@version 1.2.0
---@param functionId number Identifier returned by `scheduleFunction()` for the function to reschedule.
---@param modelTime number New mission time in seconds when the function should execute.
--- ### Examples
--- --- The following will run a function named "main" 120 seconds from one the code would run.
--- ```lua
--- local id = timer.scheduleFunction(main, {}, timer.getTime() + 120)
--- 
--- ```
--- --- If further down in the code it was decided to run the main() function sooner it could look like this
--- ```lua
--- if mustGoFaster == true then  
---   timer.setFunctionTime(id, timer.getTime() + 1)
--- end
--- 
--- ```
function timer.setFunctionTime(functionId, modelTime) end


--- Provides functions for querying atmospheric conditions in the DCS World environment, including wind, temperature, and pressure data.
---@class atmosphere
atmosphere = atmosphere or {}
--- Returns a `Vec3` representing the wind velocity vector at the specified position in the DCS World coordinate system.
---@version 1.2.6
---@param vec3 Vec3
---@return Vec3
function atmosphere.getWind(vec3) end

--- Returns a `Vec3` representing the wind velocity vector with turbulence effects at the specified position in the DCS World coordinate system.
---@version 1.2.6
---@param vec3 Vec3
---@return Vec3
function atmosphere.getWindWithTurbulence(vec3) end

--- Returns two `number` values representing the temperature (in Kelvins) and pressure (in Pascals) at the specified position in the DCS World coordinate system.
---@version 2.0.6
---@param vec3 Vec3
---@return number
function atmosphere.getTemperatureAndPressure(vec3) end


--- Provides functions for creating and managing voice chat rooms in multiplayer missions.
---@class VoiceChat
---@field RadioHandlers VoiceChat.RadioHandlers Enumerator for radio functionality constants used in voice communications.
---@field RadioHandlersSingletons VoiceChat.RadioHandlersSingletons Enumerator for intercom functionality constants used in voice communications.
---@field Side VoiceChat.Side Enumerator for coalition sides (NEUTRAL, RED, BLUE, ALL) in voice chat rooms.
---@field RoomType VoiceChat.RoomType Enumerator for voice chat room types (PERSISTENT, MULTICREW, MANAGEABLE).
VoiceChat = VoiceChat or {}
--- Creates a voice chat room for players in a multiplayer mission.
---@version 2.5.6
---@param roomName string
---@param side VoiceChat.Side
---@param roomType VoiceChat.RoomType
--- ### Examples
--- ```lua
--- VoiceChat.CreateRoom("SRSIsBetter", 2, 0)
--- ```
function VoiceChat.createRoom(roomName, side, roomType) end

--- Adds a user to a voice chat room.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.addUser(unknown) end

--- Changes a user's slot in a voice chat room.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.changeSlot(unknown) end

--- Modifies voice chat options for a room or user.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.changeVoiceChatOption(unknown) end

--- Removes a voice chat room from the mission.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.deleteRoom(unknown) end

--- Returns a list of peers with access to a voice chat room.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.getAccessPeersList(unknown) end

--- Returns the currently active voice chat room for a user.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.getActiveRoom(unknown) end

--- Returns the radio currently being used for transmission.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.getCurrentTransmittingRadio(unknown) end

--- Returns `true` if voice encryption is enabled, `false` otherwise.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.getEncryptionEnabled(unknown) end

--- Returns data about the intercom system.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.getIntercomData(unknown) end

--- Returns information about the intercom's status indicators.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.getIntercomIndication(unknown) end

--- Returns the current microphone mode for the intercom.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.getIntercomMicMode(unknown) end

--- Returns the current volume level for the intercom.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.getIntercomVolume(unknown) end

--- Returns `true` if voice chat is controlled by an external system, `false` otherwise.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.getIsExternallyControlled(unknown) end

--- Returns information about the most recently used transmitting radio.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.getLastTransmittingRadio(unknown) end

--- Returns the current microphone activation mode.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.getMicMode(unknown) end

--- Returns current voice chat system options.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.getOptions(unknown) end

--- Returns audio state information for a specified peer.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.getPeerAudioState(unknown) end

--- Returns a list of all peers in voice chat.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.getPeersList(unknown) end

--- Returns the currently selected radio channel.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.getRadioChannel(unknown) end

--- Returns the encryption key for a specified radio.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.getRadioEncryptionKey(unknown) end

--- Returns the frequency of a specified radio.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.getRadioFrequency(unknown) end

--- Returns radio frequencies for specified units.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.getRadioFrequencyByUnits(unknown) end

--- Returns the frequency of the guard receiver on a specified radio.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.getRadioGuardReceiverFrequency(unknown) end

--- Returns the modulation type of the guard receiver on a specified radio.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.getRadioGuardReceiverModulation(unknown) end

--- Returns the on/off state of the guard receiver on a specified radio.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.getRadioGuardReceiverOnOff(unknown) end

--- Returns status indicator information for a specified radio.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.getRadioIndication(unknown) end

--- Returns a list of available radios for the current unit.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.getRadioList(unknown) end

--- Returns the modulation type for a specified radio.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.getRadioModulation(unknown) end

--- Returns the on/off state of a specified radio.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.getRadioOnOff(unknown) end

--- Returns the power setting of a specified radio.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.getRadioPower(unknown) end

--- Returns the squelch on/off state for a specified radio.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.getRadioSquelchOnOff(unknown) end

--- Returns the volume level for a specified radio.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.getRadioVolume(unknown) end

--- Returns a list of all voice chat rooms in the mission.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.getRooms(unknown) end

--- Returns the coalition side of a voice chat room or user.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.getSide(unknown) end

--- Returns the current voice chat operating mode.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.getVoiceChatMode(unknown) end

--- Returns `true` if a player is in a unit with voice chat capabilities, `false` otherwise.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.isInUnit(unknown) end

--- Returns `true` if an intercom system is available, `false` otherwise.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.isIntercom(unknown) end

--- Returns `true` if a specified radio can transmit, `false` otherwise.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.isRadioAvailableForTransmission(unknown) end

--- Removes a user from a voice chat room.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.leaveRoom(unknown) end

--- Handles peer connection events in voice chat.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.onPeerConnect(unknown) end

--- Handles peer disconnection events in voice chat.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.onPeerDisconnect(unknown) end

--- Handles state processing events in voice chat.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.onProcessState(unknown) end

--- Handles RTC connection change events.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.onRtcConnectionChange(unknown) end

--- Handles RTC failure events.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.onRtcFailure(unknown) end

--- Handles RTC signaling change events.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.onRtcSignalingChange(unknown) end

--- Enables or disables voice for a specific peer.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.peerVoiceEnable(unknown) end

--- Toggles encryption for a specified radio.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.radioEncryptionOnOff(unknown) end

--- Attempts to reconnect to the voice chat system.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.reconnect(unknown) end

--- Removes a user from the voice chat system.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.removeUser(unknown) end

--- Sets the active voice chat room for a user.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.setActiveRoom(unknown) end

--- Enables or disables voice encryption.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.setEncryptionEnabled(unknown) end

--- Sets the microphone mode for the intercom system.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.setIntercomMicMode(unknown) end

--- Enables or disables external control of the voice chat system.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.setIsExternallyControlled(unknown) end

--- Sets the microphone activation mode.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.setMicMode(unknown) end

--- Configures voice chat system options.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.setOptions(unknown) end

--- Sets the active channel on a specified radio.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.setRadioChannel(unknown) end

--- Sets the encryption key for a specified radio.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.setRadioEncryptionKey(unknown) end

--- Sets the frequency for a specified radio.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.setRadioFrequency(unknown) end

--- Sets the guard receiver frequency for a specified radio.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.setRadioGuardReceiverFrequency(unknown) end

--- Sets the guard receiver modulation type for a specified radio.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.setRadioGuardReceiverModulation(unknown) end

--- Enables or disables the guard receiver for a specified radio.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.setRadioGuardReceiverOnOff(unknown) end

--- Sets the modulation type for a specified radio.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.setRadioModulation(unknown) end

--- Turns a specified radio on or off.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.setRadioOnOff(unknown) end

--- Sets the power level for a specified radio.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.setRadioPower(unknown) end

--- Enables or disables squelch for a specified radio.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.setRadioSquelchOnOff(unknown) end

--- Sets the volume level for a specified radio.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.setRadioVolume(unknown) end

--- Sets the volume level for audio tracks in voice chat.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.setTrackAudioVolume(unknown) end

--- Sets the operating mode for voice chat.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.setVoiceChatMode(unknown) end

--- Starts or stops a test of sound filter options.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.startStopTestSoundFilterOptions(unknown) end

--- Starts a voice stream for a specified user or room.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.startStream(unknown) end

--- Starts the audio level test meter.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.startTestPeekMeter(unknown) end

--- Stops a voice stream for a specified user or room.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.stopStream(unknown) end

--- Stops the audio level test meter.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.stopTestPeekMeter(unknown) end

--- Tests the peak meter functionality.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.testCallPeekMeterFunc(unknown) end

--- Updates the volume levels for crew communications.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.updateCrewVolume(unknown) end

--- Updates the parameters for sound filtering in voice chat.
---@param unknown? any Unknown parameter(s)
---@return any
function VoiceChat.updateSoundFilterParameters(unknown) end


--- Provides functions for converting between different coordinate systems in the DCS World environment, including Latitude/Longitude, Local (XYZ), and Military Grid Reference System (MGRS).
---@class coord
coord = coord or {}
--- Converts geographical coordinates (Latitude/Longitude) to DCS World local coordinates, returning a Vec2 position vector.
---@version 1.2.0
---@param lat LatLon|number Latitude value in decimal degrees, or a LatLon structure. If a LatLon is provided, the lon parameter is ignored.
---@param lon? number Longitude value in decimal degrees. Ignored if lat parameter is a LatLon structure.
---@return Vec2
function coord.LLtoLO(lat, lon) end

--- Converts DCS World local coordinates to geographical coordinates, returning a LatLon structure.
---@version 1.2.0
---@param x number X coordinate in the DCS World coordinate system.
---@param y number Y coordinate (not Z) in the DCS World coordinate system.
---@return LatLon
function coord.LOtoLL(x, y) end

--- Converts geographical coordinates (Latitude/Longitude) to Military Grid Reference System (MGRS) coordinates.
---@version 1.2.0
---@param lat LatLon|number Latitude value in decimal degrees, or a LatLon structure. If a LatLon is provided, the lon parameter is ignored.
---@param lon number Longitude value in decimal degrees. Ignored if lat parameter is a LatLon structure.
---@return MGRS
function coord.LLtoMGRS(lat, lon) end

--- Converts Military Grid Reference System (MGRS) coordinates to geographical coordinates, returning a LatLon structure.
---@version 1.2.0
---@param mgrs MGRS MGRS coordinate object with UTMZone, MGRSDigraph, Easting, and Northing fields.
---@return LatLon
function coord.MGRStoLL(mgrs) end


--- Provides functions and constants for controlling artificial intelligence behavior in the DCS World environment.
---@class AI
---@field Option table Provides a hierarchical structure of options for configuring AI unit and group behavior, including engagement rules, formation patterns, and reaction settings.
---@field Task table Provides constants and table structures for creating and assigning mission tasks to AI-controlled units and groups.
---@field Skill AI.Skill Provides enumerator values for setting AI proficiency levels, affecting decision-making, accuracy, and tactical behavior.
AI = AI or {}

--- Provides functions for manipulating positions, terrain queries, and random number generation within the DCS World. **Warning:** This class is not formally documented by ED and descriptions and params may be incorrect.
---@class Disposition
Disposition = Disposition or {}
--- Unknown use case, possibly related to route drift or movement.
---@version 0.0.0
---@param pos1 Vec3 First position vector.
---@param pos2 Vec3 Second position vector.
---@param coalitionId coalition.side Coalition side enumeration value.
---@return table
function Disposition.DriftRoute(pos1, pos2, coalitionId) end

--- Returns zones around runway strips in an elliptical pattern.
---@version 0.0.0
---@param numAreas number Unknown
---@param numPositions number Unknown
---@param perim table Unknown
---@param degrees number Unknown
---@param radiusRatio number Unknown
---@return table
function Disposition.getElipsSideZones(numAreas, numPositions, perim, degrees, radiusRatio) end

--- Returns the terrain height at the specified position in the DCS World coordinate system? See: land.getHeight()
---@version 0.0.0
---@param pos Vec3 Position vector in the DCS World coordinate system.
---@return number
function Disposition.getPointHeight(pos) end

--- Checks if water exists at the specified position within given parameters? See: land.getSurfaceType()
---@version 0.0.0
---@param pos Vec3 3D Position
---@param a number Unknown
---@param b number Unknown
---@return boolean
function Disposition.getPointWater(pos, a, b) end

--- Generates a random number within the specified range.
---@version 0.0.0
---@param isFloat boolean If true, returns a floating-point number; otherwise, returns an integer.
---@param min number Minimum value of the random range.
---@param max number Maximum value of the random range.
---@return number
function Disposition.getRandom(isFloat, min, max) end

--- Unknown function, likely related to random selection within a specified range or container.
---@version 0.0.0
---@return any
function Disposition.getRandomIn() end

--- Randomly shuffles the elements of the input table.
---@version 0.0.0
---@param t table Table to be randomly shuffled.
---@return table
function Disposition.getRandomSort(t) end

--- Unknown function
---@version 0.0.0
---@param thresholdPos Vec3 Unknown
---@param pos Vec3 Unknown
---@param a number Unknown
---@param b number Unknown
---@return boolean
function Disposition.getRouteAwayWater(thresholdPos, pos, a, b) end

--- Returns the perimeter of a runway defined by runway data? See: airbase.getRunways()
---@version 0.0.0
---@param runway table Runway data table obtained from airbase:getRunways().
---@return table
function Disposition.getRunwayPerimetr(runway) end

--- Finds clear positions within an area for placing units. Assumed behavior.
---@version 0.0.0
---@param pos Vec3 Center position vector for the search area.
---@param radius number Radius of the search area.
---@param posRadius number Required clear radius around each position.
---@param numPositions number Number of positions to find.
---@return table
function Disposition.getSimpleZones(pos, radius, posRadius, numPositions) end

--- Returns zones along runway edges based on the provided perimeter.
---@version 0.0.0
---@param numPositions number Number of positions to generate.
---@param perim table Perimeter table defining the runway edges.
---@return table
function Disposition.getThresholdFourZones(numPositions, perim) end

--- Unknown function, likely related to setting a marker at a specific point. May be related to world and trigger functions.
---@version 0.0.0
---@return any
function Disposition.setMarkerPoint() end


--- Provides functions for creating and managing interactive menu commands in the F10 radio menu.
---@class missionCommands
missionCommands = missionCommands or {}
--- Adds an interactive command to the F10 radio menu for all players that executes a specified Lua function when selected.
---@version 1.2.4
---@param name string Display text for the menu command.
---@param path? nil|table Path to parent menu as a sequence table of menu names. If `nil`, command is added to root menu.
---@param functionToRun fun(...) Function to execute when command is selected.
---@param anyArguement? any Optional value passed to `functionToRun` when executed.
---@return table
function missionCommands.addCommand(name, path, functionToRun, anyArguement) end

--- Creates a submenu in the F10 radio menu for all players, which can contain additional commands or nested submenus.
---@version 1.2.4
---@param name string Display text for the submenu.
---@param path? table Path to parent menu as a sequence table of menu names. If `nil`, submenu is added to root menu.
---@return table
function missionCommands.addSubMenu(name, path) end

--- Removes a menu item or entire submenu from the F10 radio menu for all players.
---@version 1.2.4
---@param path? nil|table Path to the menu item as a sequence table of menu names. If `nil`, removes all items.
function missionCommands.removeItem(path) end

--- Adds an interactive command to the F10 radio menu for players of a specific coalition.
---@version 1.2.4
---@param coalition_side coalition.side Target coalition (`coalition.side.NEUTRAL`, `coalition.side.RED`, or `coalition.side.BLUE`).
---@param name string Display text for the menu command.
---@param path? nil|table Path to parent menu as a sequence table of menu names. If `nil`, command is added to root menu.
---@param functionToRun fun(...) Function to execute when command is selected.
---@param anyArguement? any Optional value passed to `functionToRun` when executed.
---@return table
function missionCommands.addCommandForCoalition(coalition_side, name, path, functionToRun, anyArguement) end

--- Creates a submenu in the F10 radio menu for players of a specific coalition.
---@version 1.2.4
---@param coalitionSide number Target coalition as a `coalition.side` enum value.
---@param name string Display text for the submenu.
---@param path? table Path to parent menu as a sequence table of menu names. If `nil`, submenu is added to root menu.
---@return table
function missionCommands.addSubMenuForCoalition(coalitionSide, name, path) end

--- Removes a menu item or entire submenu from the F10 radio menu for a specific coalition.
---@version 1.2.4
---@param coalitionSide number Target coalition as a `coalition.side` enum value.
---@param path? nil|table Path to the menu item as a sequence table of menu names. If `nil`, removes all items for the coalition.
function missionCommands.removeItemForCoalition(coalitionSide, path) end

--- Adds an interactive command to the F10 radio menu for players in a specific group.
---@version 1.2.4
---@param groupId number ID of the target group.
---@param name string Display text for the menu command.
---@param path? nil|table Path to parent menu as a sequence table of menu names. If `nil`, command is added to root menu.
---@param functionToRun fun(...) Function to execute when command is selected.
---@param anyArguement? any Optional value passed to `functionToRun` when executed.
---@return table
function missionCommands.addCommandForGroup(groupId, name, path, functionToRun, anyArguement) end

--- Creates a submenu in the F10 radio menu for players in a specific group.
---@version 1.2.4
---@param groupId number ID of the target group.
---@param name string Display text for the submenu.
---@param path? table Path to parent menu as a sequence table of menu names. If `nil`, submenu is added to root menu.
---@return table
function missionCommands.addSubMenuForGroup(groupId, name, path) end

--- Removes a menu item or entire submenu from the F10 radio menu for a specific group.
---@version 1.2.4
---@param groupId number ID of the target group.
---@param path? nil|table Path to the menu item as a sequence table of menu names. If `nil`, removes all items for the group.
function missionCommands.removeItemForGroup(groupId, path) end

--- Executes a radio menu action programmatically without user interaction.
---@version 2.5.0
---@param path table Path to the menu command as a sequence table of menu names.
function missionCommands.doAction(path) end


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
---@version 2.5.0
---@return table
function dcs.getCurrentMission() end

--- Pauses or resumes the simulation, affecting all connected clients in multiplayer.
---@version 2.5.0
---@param action boolean `true` to pause the simulation, `false` to resume it.
function dcs.setPause(action) end

--- Returns a `boolean` indicating whether the simulation is currently paused.
---@version 2.5.0
---@return boolean
function dcs.getPause() end

--- Terminates the current mission and returns to the mission selection screen.
---@version 2.5.0
function dcs.stopMission() end

--- Closes the DCS World application completely, terminating all processes.
---@version 2.5.0
function dcs.exitProcess() end

--- Returns `true` if the current simulation is in multiplayer mode, `false` if in single-player mode.
---@version 2.5.0
---@return boolean
function dcs.isMultiplayer() end

--- Returns `true` if the current instance is running as a dedicated server or single player host, `false` otherwise.
---@version 2.5.0
---@return boolean
function dcs.isServer() end

--- Returns a `number` representing the total simulation time in seconds since the DCS application was launched.
---@version 2.5.0
---@return number
function dcs.getModelTime() end

--- Returns a `number` representing the elapsed time in seconds since the current mission started.
---@version 2.5.0
---@return number
function dcs.getRealTime() end

--- Returns a table containing the mission options as stored in the options.lua file within the mission package.
---@version 2.5.0
---@return table
function dcs.getMissionOptions() end

--- Returns a map-like table where keys are coalition IDs and values are tables containing information about coalitions with available player slots.
---@version 2.5.0
---@return table
function dcs.getAvailableCoalitions() end

--- Returns a numerically indexed table of tables containing information about player slots available in the specified coalition.
---@version 2.5.0
---@param coaId number|string Coalition identifier (numeric ID or string name).
---@return DCSAvailableSlotInfo[]
function dcs.getAvailableSlots(coaId) end

--- Returns a table containing information about all player-controllable slots available in the current mission.
---@return DCSAvailableSlotInfo
function dcs.getAvailableSlotsAll() end


--- Represents a physical entity in the DCS World with position, orientation, and identity properties.
---@class Object
Object = Object or {}
--- Returns `true` if this object currently exists in the mission environment.
---@return boolean
function Object:isExist() end

--- Removes this object from the mission without generating events, causing it to immediately disappear.
---@return fun(...)
function Object:destroy() end

--- Returns two `Object.Category` values indicating this object's primary and secondary classification.
---@return Object.Category
function Object:getCategory() end

--- Returns the type name of this object as defined in the DCS database.
---@return string
function Object:getTypeName() end

--- Returns `true` if this object possesses the specified attribute as defined in the DCS database.
---@param attribute Attributes|string Attribute name to check for. Can be any valid attribute from the Attributes enum.
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
---@version 1.2.0
---@return ObjectAttributes
function Object:getAttributes() end

--- Aborts the current cargo selection operation for this object.
---@version 2.5.0
function Object:cancelChoosingCargo() end


--- Provides functions for querying terrain geometry in the mission environment.
---@class land
land = land or {}
--- Returns terrain height (distance from sea level) at the specified point.
---@version 1.2.0
---@param point Vec2 Position coordinates to check.
---@return number
function land.getHeight(point) end

--- Returns both terrain height and seabed depth at the specified point as `{number, number}` where the first value is height above sea level and the second is seabed depth.
---@version 1.2.0
---@param point Vec2 Position coordinates to check.
---@return table
function land.getSurfaceHeightWithSeabed(point) end

--- Returns the surface type enum at the specified point.
---@version 1.2.0
---@param point Vec2 Position coordinates to check.
---@return land.SurfaceType
function land.getSurfaceType(point) end

--- Performs line-of-sight check between two points, returning whether terrain obstructs visibility.
--- 
--- Note: This only tests terrain collision - buildings and other objects are not considered.
--- When working with ground objects, offset the Y-value (height) to prevent false negatives from the origin point clipping into terrain.
---@version 1.2.0
---@param origin Vec3 Starting point of the line-of-sight check.
---@param destination Vec3 Ending point of the line-of-sight check.
---@return boolean
function land.isVisible(origin, destination) end

--- Returns the intersection point where a ray originating from `origin` in the given direction intersects terrain, or `nil` if no intersection within specified distance.
---@version 1.2.0
---@param origin Vec3 Starting point of the ray.
---@param direction Vec3 Normalized direction vector of the ray.
---@param distance number Maximum distance to check for intersection.
---@return Vec3|nil
function land.getIP(origin, direction, distance) end

--- Returns a table of `Vec3` points representing the terrain profile between two points.
---@version 1.2.0
---@param origin Vec3 Starting point of the profile.
---@param destination Vec3 Ending point of the profile.
---@return Vec3Array
function land.profile(origin, destination) end

--- Returns X and Y coordinates of the nearest point on a road from the given position.
--- 
--- Note: This function accepts individual X/Y coordinates rather than `Vec2` or `Vec3` objects.
---@version 2.5
---@param roadType string Road type to search. Valid values: `'roads'`, `'railroads'`.
---@param xCoord number X-coordinate (map X) of reference point.
---@param yCoord number Y-coordinate (map Z) of reference point.
---@return Vec2
function land.getClosestPointOnRoads(roadType, xCoord, yCoord) end

--- Returns a route as a sequence of points along roads between start and destination.
--- 
--- The result is a numerically-indexed table of `Vec2` points from start to destination.
--- 
--- Note: When using railroad paths, the parameter value should be `'rails'` (not `'railroads'`).
---@version 2.5
---@param roadType string Road type to use. Valid values: `'roads'`, `'rails'`.
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
---@version 1.2.0
---@return number
function SceneryObject:getLife() end

--- Returns a table containing detailed properties of this scenery object based on its type.
---@version 1.2.0
---@return SceneryObjectDesc
function SceneryObject:getDesc() end

--- Returns a table containing detailed properties of a scenery object type without requiring an instance.
---@version 1.2.0
---@param typeName string Type name of the scenery object to retrieve information about.
---@return SceneryObjectDesc
function SceneryObject.getDescByName(typeName) end


--- Represents a targeting designation beam (laser or infrared) used for marking targets in the DCS World environment.
---@class Spot
Spot = Spot or {}
--- Removes this spot from the mission, immediately terminating the targeting beam.
---@version 1.2.0
function Spot:destroy() end

--- Returns two category enumerator values identifying this spot's primary and secondary classifications.
---@version 1.2.0
---@return Object.Category
---@return Spot.Category
function Spot:getCategory() end

--- Returns a `Spot.Category` enumerator value indicating whether this spot is infrared or laser.
---@version 2.9.2
---@return Spot.Category
function Spot:getCategoryEx() end

--- Returns a `Vec3` representing the target point of this beam in the DCS World coordinate system.
---@version 1.2.0
---@return Vec3
function Spot:getPoint() end

--- Changes the target endpoint of this beam to a new position in the DCS World coordinate system.
---@version 1.2.6
---@param point Vec3 New target position in the DCS World coordinate system.
function Spot:setPoint(point) end

--- Returns the 4-digit laser code number used for target designation with this beam.
---@version 1.2.6
---@return number
function Spot:getCode() end

--- Sets a new 4-digit laser code (1111-1788) for this beam, determining which guided weapons can track it.
---@version 1.2.6
---@param code number New laser code value between 1111 and 1788.
function Spot:setCode(code) end

--- Creates an infrared targeting beam from a source object to a specified point, visible only through night vision devices.
---@version 1.2.6
---@param source Object Source object that will emit the infrared beam.
---@param localRef? Vec3|nil Optional local reference point on the source object. If `nil`, uses the object's center.
---@param point Vec3 Target point for the infrared beam in the DCS World coordinate system.
---@return Spot
function Spot.createInfraRed(source, localRef, point) end

--- Creates a laser targeting beam from a source object to a specified point in the DCS World coordinate system.
---@version 1.2.6
---@param source Object Source object that will emit the laser beam.
---@param localRef? Vec3|nil Optional local reference point on the source object. If `nil`, uses the object's center.
---@param point Vec3 Target point for the laser beam in the DCS World coordinate system.
---@param laserCode? number Optional 4-digit laser code between 1111 and 1788. If omitted, creates an infrared beam.
---@return Spot
function Spot.createLaser(source, localRef, point, laserCode) end


--- Represents non-moving structures and objects placed in the DCS World mission environment.
---@class StaticObject : Object, CoalitionObject
StaticObject = StaticObject or {}
--- Returns the current health value of this static object, where values below 1 indicate destruction.
---@version 1.2.0
---@return number
function StaticObject:getLife() end

--- Returns a table containing detailed properties of this static object based on its type.
---@version 1.2.0
---@return StaticObjectDesc
function StaticObject:getDesc() end

--- Returns a `number` representing the unique mission identifier of this static object.
---@version 1.2.0
---@return number
function StaticObject:getID() end

--- Returns a `coalition.side` enumerator value indicating which faction this static object belongs to.
---@version 1.2.0
---@return coalition.side
function StaticObject:getCoalition() end

--- Returns a `country.id` enumerator value identifying the nation this static object belongs to.
---@version 1.2.0
---@return country.id
function StaticObject:getCountry() end

--- Returns a `string` name of the force group this static object belongs to, or `nil` if not assigned.
---@version 1.2.0
---@return nil|string
function StaticObject:getForcesName() end

--- Returns the current animation parameter value for a specific argument on this static object's 3D model.
---@version 1.2.0
---@param arg number Animation argument identifier to query.
---@return number
function StaticObject:getDrawArgumentValue(arg) end

--- Initiates the cargo selection process for this static object.
---@version 2.5.0
function StaticObject:chooseCargo() end

--- Returns a `string` containing the human-readable name of the cargo attached to this static object.
---@version 2.5.0
---@return string
function StaticObject:getCargoDisplayName() end

--- Returns a `number` representing the weight of the cargo attached to this static object.
---@version 2.5.0
---@return number
function StaticObject:getCargoWeight() end

--- Returns a `StaticObject` with the specified name, or `nil` if no such object exists.
---@version 1.2.0
---@param name string Unique identifier of the static object to retrieve.
---@return StaticObject|nil
function StaticObject.getByName(name) end

--- Returns a table containing detailed properties of a static object type without requiring an instance.
---@version 1.2.0
---@param typeName string Type name of the static object to retrieve information about.
---@return StaticObjectDesc
function StaticObject.getDescByName(typeName) end


--- Provides functions for managing faction-based entities in the DCS World environment, including unit information retrieval, group spawning, and static object creation.
---@class coalition
---@field side coalition.side Provides access to the coalition side enumerator for faction identification.
---@field service coalition.service Provides access to the service type enumerator for communications services.
coalition = coalition or {}
--- Adds a new group to the mission for the specified coalition and country, returning a `function` that can be called to complete the spawn process.
---@version 1.2.0
---@param coalition coalition.side Coalition side enumeration value.
---@param country country.id Country identifier within the coalition.
---@param groupData GroupSpawnData Table defining the group configuration to be spawned.
---@return fun(...)
function coalition.addGroup(coalition, country, groupData) end

--- Adds a dynamic (runtime-created) group to the mission for the specified coalition and country, returning a `function` that finalizes the spawn process.
---@version 2.8.0
---@param coalition coalition.side Coalition side enumeration value.
---@param country country.id Country identifier within the coalition.
---@param groupData GroupSpawnData Table defining the dynamic group configuration to be spawned.
---@return fun(...)
function coalition.add_dyn_group(coalition, country, groupData) end

--- Removes a previously added dynamic group from the mission, returning `true` if successful.
---@version 2.8.0
---@param groupName string Name of the dynamic group to remove from the mission.
---@return boolean
function coalition.remove_dyn_group(groupName) end

--- Adds a new static object to the mission for the specified country, returning a `StaticObject`. The coalition is automatically determined from the country identifier.
---@version 1.2.0
---@param country country.id Country identifier that determines which coalition the static object will belong to.
---@param staticData StaticObjectSpawnData Table defining the static object configuration to be spawned.
---@return StaticObject
function coalition.addStaticObject(country, staticData) end

--- Returns a numerically indexed table of `Group` objects belonging to the specified coalition and country.
---@version 1.2.0
---@param coalition coalition.side Coalition side enumeration value.
---@param country country.id Country identifier within the coalition.
---@return table
function coalition.getGroups(coalition, country) end

--- Returns a numerically indexed table of `StaticObject` objects belonging to the specified coalition and country.
---@version 1.2.0
---@param coalition coalition.side Coalition side enumeration value.
---@param country country.id Country identifier within the coalition.
---@return table
function coalition.getStaticObjects(coalition, country) end

--- Returns a numerically indexed table of `Airbase` objects belonging to the specified coalition and country.
---@version 1.2.0
---@param coalition coalition.side Coalition side enumeration value.
---@param country country.id Country identifier within the coalition.
---@return table
function coalition.getAirbases(coalition, country) end

--- Returns a numerically indexed table of `Unit` objects representing player-controlled units in the specified coalition.
---@version 1.2.0
---@param coalition coalition.side Coalition side enumeration value.
---@return table
function coalition.getPlayers(coalition) end

--- Returns a numerically indexed table of `Unit` objects providing the specified service type within the coalition.
---@version 1.2.0
---@param coalition coalition.side Coalition side enumeration value.
---@param service coalition.service Service type enumeration value (e.g., ATC, AWACS, TANKER, FAC).
---@return table
function coalition.getServiceProviders(coalition, service) end

--- Adds a reference point for the specified coalition, returning a `function` that finalizes the addition.
---@version 1.2.0
---@param coalition coalition.side Coalition side enumeration value.
---@param refPoint RefPoint Table defining the reference point to be added.
---@return fun(...)
function coalition.addRefPoint(coalition, refPoint) end

--- Returns a table of reference points defined for the specified coalition.
---@version 1.2.0
---@param coalition coalition.side Coalition side enumeration value.
---@return table
function coalition.getRefPoints(coalition) end

--- Returns a table representing the primary reference point for the specified coalition.
---@version 1.2.0
---@param coalition coalition.side Coalition side enumeration value.
---@return table
function coalition.getMainRefPoint(coalition) end

--- Returns a `number` representing the coalition identifier that the specified country belongs to.
---@version 1.2.0
---@param country country.id Country identifier to query.
---@return number
function coalition.getCountryCoalition(country) end

--- Returns `true` if cargo selection is possible for the specified unit within the coalition.
---@version 2.8.0
---@param coalition coalition.side Coalition side enumeration value.
---@param unitId number Unique identifier of the unit to check.
---@return boolean
function coalition.checkChooseCargo(coalition, unitId) end

--- Returns `true` if a descent operation (e.g., paratrooper drop) is possible for the specified unit.
---@version 2.8.0
---@param coalition coalition.side Coalition side enumeration value.
---@param unitId number Unique identifier of the unit to check.
---@return boolean
function coalition.checkDescent(coalition, unitId) end

--- Returns a table of all available descent operations (e.g., paratroopers, cargo) for the specified coalition.
---@version 2.8.0
---@param coalition coalition.side Coalition side enumeration value.
---@return table
function coalition.getAllDescents(coalition) end

--- Returns a table of all descent operations (e.g., paratroopers, cargo) currently loaded on the specified unit.
---@version 2.8.0
---@param unitId number Unique identifier of the unit to query.
---@return table
function coalition.getDescentsOnBoard(unitId) end


--- Represents an AI behavior controller that manages tasking, commands, and detection capabilities for units and groups in the DCS World environment.
---@class Controller
Controller = Controller or {}
--- Assigns a task to this controller's associated units or groups, replacing any current task in the queue.
---@param task ControllerTask Table defining either a main task or enroute task to assign
function Controller:setTask(task) end

--- Clears all tasks from this controller's task queue, causing controlled units to cease their current activity.
function Controller:resetTask() end

--- Adds a task to the front of this controller's task queue, making it the highest priority task to execute.
---@param task ControllerTask Table defining either a main task or enroute task to prioritize
function Controller:pushTask(task) end

--- Removes the highest priority task from this controller's task queue.
function Controller:popTask() end

--- Returns `true` if this controller currently has at least one task in its queue.
---@return boolean
function Controller:hasTask() end

--- Issues an immediate command to this controller that executes instantly and does not affect the current task queue.
---@param command ControllerCommand Table defining the command to execute
function Controller:setCommand(command) end

--- Configures a behavior option for this controller that affects how it performs all tasks and commands.
---@param optionId AIOptionId Option identifier from AI.Option namespaces (Air, Ground, or Naval)
---@param optionValue FormationType|boolean|number|string Value to set for the specified option
function Controller:setOption(optionId, optionValue) end

--- Enables or disables the AI behavior for this controller's ground or naval units. Note: Does not work with aircraft or helicopters.
---@param value boolean `true` to enable AI behavior, `false` to disable
function Controller:setOnOff(value) end

--- Sets the altitude for this controller's aircraft group, with options to maintain across waypoints and specify altitude type.
---@param altitude number Target altitude in meters
---@param keep? boolean `true` to maintain altitude across waypoints, `false` to return to route-defined altitudes
---@param altType? string Altitude reference type: "BARO" (barometric) or "RADIO" (radar)
function Controller:setAltitude(altitude, keep, altType) end

--- Sets the movement speed for this controller's group, with option to maintain across waypoints.
---@param speed number Target speed in meters per second
---@param keep? boolean `true` to maintain speed across waypoints, `false` to return to route-defined speeds
function Controller:setSpeed(speed, keep) end

--- Forces a unit-level controller to have awareness of a specific target without natural detection. Note: Does not work at group level.
---@param object Object Target object to become aware of
---@param _type boolean `true` to know the target type, `false` otherwise
---@param distance boolean `true` to know the target distance, `false` otherwise
function Controller:knowTarget(object, _type, distance) end

--- Returns multiple values indicating whether and how the specified target is detected by this controller's unit or group.
---@param Target Object Target object to check detection status
---@param detectionType1? Controller.Detection First detection method to check
---@param detectionType2? Controller.Detection Second detection method to check
---@param detectionType3? Controller.Detection Third detection method to check
---@return boolean
---@return number
---@return Vec3
function Controller:isTargetDetected(Target, detectionType1, detectionType2, detectionType3) end

--- Returns a numerically indexed table of tables containing detection information about targets detected by this controller, optionally filtered by detection methods.
---@param detectionType1? Controller.Detection First detection method to filter by
---@param detectionType2? Controller.Detection Second detection method to filter by
---@param detectionType3? Controller.Detection Third detection method to filter by
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
---@version 1.2.0
---@return Object.Category
function Airbase:getCategory() end

--- Returns an `Airbase.Category` enumerator value indicating the specific type of this airbase.
---@return Airbase.Category
function Airbase:getCategoryEx() end

--- Returns a numerically indexed table where each element is a table detailing an airbase parking spot, optionally filtered by availability.
---@param available? boolean
---@return AirbaseParking[]
function Airbase:getParking(available) end

--- Returns a numerically indexed table where each element is a table detailing runway information, including dimensions, course, and name.
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
---@version 1.2.0
---@return string
function Airbase:getName() end

--- Returns a `string` representing the type name of this airbase.
---@version 1.2.0
---@return string
function Airbase:getTypeName() end

--- Returns a `Vec3` representing the position of this airbase in the DCS World coordinate system.
---@version 1.2.0
---@return Vec3
function Airbase:getPoint() end

--- Returns a `Position3` representing the precise position and orientation of this airbase in the DCS World coordinate system.
---@version 1.2.0
---@return Position3
function Airbase:getPosition() end

--- Returns a `Vec3` representing the velocity of this airbase in the DCS World coordinate system.
---@version 1.2.0
---@return Vec3
function Airbase:getVelocity() end

--- Returns a table containing a detailed description of this airbase, including its ID, callsign, category, and operational data.
---@version 1.2.0
---@return AirbaseDesc
function Airbase:getDesc() end

--- Returns a `coalition.side` enumerator value indicating which coalition controls this airbase.
---@version 1.2.0
---@return coalition.side
function Airbase:getCoalition() end

--- Returns an `Airbase` object corresponding to the airbase with the specified name, or `nil` if no such airbase exists.
---@param name string
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
---@version 1.2.0
---@return boolean
function Group:isExist() end

--- Activates this group if it has delayed start or late activation settings, making it appear in the mission.
---@version 1.2.0
---@return fun(...)
function Group:activate() end

--- Removes this group and all its units from the game world without triggering events, causing them to completely disappear.
---@version 1.2.0
---@return fun(...)
function Group:destroy() end

--- Returns an enumerator value indicating both the generic object category and specific group type for this group.
---@version 1.2.0
---@return Object.Category
---@return Group.Category
function Group:getCategory() end

--- Returns a `Group.Category` enumerator value indicating the specific type of this group (e.g., AIRPLANE, HELICOPTER, GROUND).
---@version 2.9.2
---@return Group.Category
function Group:getCategoryEx() end

--- Returns a `coalition.side` enumerator value indicating which faction this group belongs to.
---@version 1.2.4
---@return coalition.side
function Group:getCoalition() end

--- Returns a `string` representing the unique name identifier of this group.
---@version 1.2.0
---@return string
function Group:getName() end

--- Returns a `number` representing the unique mission ID of this group.
---@version 1.2.0
---@return number
function Group:getID() end

--- Returns a `Unit` object at the specified index within this group, or `nil` if no unit exists at that index.
---@version 1.2.0
---@param UnitIndex number Numeric index of the unit to retrieve, starting from 1.
---@return Unit|nil
function Group:getUnit(UnitIndex) end

--- Returns a numerically indexed table of `Unit` objects belonging to this group, ordered by their position in the group.
---@version 1.2.0
---@return Unit[]
function Group:getUnits() end

--- Returns a `number` representing the current count of units in this group, which decreases as units are destroyed.
---@version 1.2.0
---@return number
function Group:getSize() end

--- Returns a `number` representing the original count of units in this group as defined at creation, which remains constant regardless of unit losses.
---@version 1.2.6
---@return number
function Group:getInitialSize() end

--- Returns a `Controller` object that can be used to manage AI behavior for this group. Note: Ship and ground groups can only be controlled at group level.
---@version 1.2.0
---@return Controller
function Group:getController() end

--- Sets the radar emission status for all applicable units in this group, allowing control of detection signatures without changing AI behavior.
---@version 2.7.0
---@param setting boolean `true` to enable radar emissions, `false` to disable them.
function Group:enableEmission(setting) end

--- Returns `true` if any unit in this group is currently in the process of loading cargo.
---@version 2.5.5
---@return boolean
function Group:embarking() end

--- Creates a map marker visible to this group at the specified position with optional text label.
---@version 2.5.0
---@param point Vec3 Position in the DCS World coordinate system where the marker will appear.
---@param text? string Optional text to display with the marker.
function Group:markGroup(point, text) end

--- Returns a `Group` object with the specified name, or `nil` if no such group exists. Works with both active and inactive groups.
---@version 1.2.0
---@param name string Unique identifier of the group to retrieve.
---@return Group|nil
function Group.getByName(name) end


--- Represents a unit entity in the DCS World, including airplanes, helicopters, vehicles, ships, and armed ground structures.
---@class Unit : Object, CoalitionObject
Unit = Unit or {}
--- Returns `true` if the unit is activated in the mission, `false` otherwise.
---@version 1.2.0
---@return boolean
function Unit:isActive() end

--- Returns the `string` name of the player controlling this unit, or `nil` if AI-controlled.
---@version 1.2.4
---@return nil|string
function Unit:getPlayerName() end

--- Returns the `number` representing the unique mission ID of the unit.
---@version 1.2.0
---@return number
function Unit:getID() end

--- Returns the `number` representing the index of the unit within its group. This index persists even as other units in the group are destroyed.
---@version 1.2.0
---@return number
function Unit:getNumber() end

--- Returns a `Unit.Category` enumerator representing the specific category of the unit.
---@version 2.9.2
---@return Unit.Category
function Unit:getCategoryEx() end

--- Returns the `number` representing the runtime object ID of the unit. Every simulation object has a unique objectID.
---@version 1.2.4
---@return number
function Unit:getObjectID() end

--- Returns the `Controller` object for this unit. Note: Ships and ground units are only controllable at a group level.
---@version 1.2.0
---@return Controller
function Unit:getController() end

--- Returns the `Group` object that this unit belongs to.
---@version 1.2.0
---@return Group
function Unit:getGroup() end

--- Returns a `string` representing the localized callsign of the unit.
---@version 1.2.6
---@return string
function Unit:getCallsign() end

--- Returns a `number` representing the current hit points of the unit. Values below 1 indicate the unit is destroyed.
---@version 1.2.0
---@return number
function Unit:getLife() end

--- Returns a `number` representing the maximum hit points of the unit. This value never changes during a mission.
---@version 1.2.0
---@return number
function Unit:getLife0() end

--- Returns a `number` representing the remaining fuel percentage (0.0 to 1.0+). Values above 1.0 indicate external fuel tanks.
---@version 1.2.3
---@return number
function Unit:getFuel() end

--- Returns a numerically indexed table of ammunition data for all weapons loaded on the unit.
---@version 1.2.4
---@return UnitAmmoItem[]
function Unit:getAmmo() end

--- Returns a numerically indexed table containing all sensors available on the unit.
---@version 1.2.0
---@return UnitSensor[]
function Unit:getSensors() end

--- Returns `true` if the unit has the specified sensor type and subcategory, `false` otherwise.
---@version 1.2.0
---@param sensorType Unit.SensorType Type of sensor to check for.
---@param subCategory number Subcategory of the sensor type to check for.
---@return boolean
function Unit:hasSensors(sensorType, subCategory) end

--- Returns information about the unit's radar status: operational state and tracked object (if any).
---@version 1.2.0
---@return boolean
---@return Object|nil
function Unit:getRadar() end

--- Returns a `number` representing the current value of a specified animation parameter on the unit's 3D model.
---@version 1.2.0
---@param arg number The argument number for the animation parameter.
---@return number
function Unit:getDrawArgumentValue(arg) end

--- Returns a numerically indexed table of nearby friendly cargo objects sorted by distance, or `nil` if not applicable.
---@version 2.5.5
---@return Object[]|nil
function Unit:getNearestCargos() end

--- Enables or disables the unit's emissions, affecting radar and other detectable systems without changing AI state.
---@version 2.7.0
---@param setting boolean True to enable emissions, false to disable.
function Unit:enableEmission(setting) end

--- Returns a `number` representing the infantry capacity of an aircraft, or `nil` for non-aircraft units.
---@version 2.5.6
---@return nil|number
function Unit:getDescentCapacity() end

--- Returns a table containing detailed technical specifications of the unit. The exact type of descriptor returned depends on the unit's category: AIRPLANE units return UnitDescAirplane, HELICOPTER units return UnitDescHelicopter, GROUND_UNIT units return UnitDescVehicle, SHIP units return UnitDescShip, and other types return the base UnitDesc.
---@version 1.2.0
---@return UnitDesc|UnitDescAircraft|UnitDescAirplane|UnitDescHelicopter|UnitDescShip|UnitDescVehicle
function Unit:getDesc() end

--- Returns the `Airbase` object where the unit is stationed or landed, or `nil` if not at an airbase.
---@version unknown
---@return Airbase|nil
function Unit:getAirbase() end

--- Returns `true` if the unit can land on a ship, `false` otherwise.
---@version unknown
---@return boolean
function Unit:canShipLanding() end

--- Returns `true` if the unit's ramp is currently open, `false` otherwise.
---@version unknown
---@return boolean
function Unit:checkOpenRamp() end

--- Initiates the disembarkation process for troops or cargo from this transport unit.
---@version unknown
function Unit:disembarking() end

--- Returns a numerically indexed table of cargo objects currently loaded on the unit.
---@version unknown
---@return Object[]
function Unit:getCargosOnBoard() end

--- Returns a `coalition.side` enumerator representing the unit's coalition alignment.
---@version 1.2.4
---@return coalition.side
function Unit:getCoalition() end

--- Returns the communication system object for this unit.
---@version unknown
---@return unknown
function Unit:getCommunicator() end

--- Returns a `country.id` enumerator representing the unit's country affiliation.
---@version 1.2.0
---@return country.id
function Unit:getCountry() end

--- Returns information about troops currently loaded on the unit.
---@version unknown
---@return unknown
function Unit:getDescentOnBoard() end

--- Returns a `string` name of the military force this unit belongs to, or `nil` if not specified.
---@version unknown
---@return nil|string
function Unit:getForcesName() end

--- Returns a `number` representing the low fuel threshold for this unit, or `nil` if not applicable.
---@version unknown
---@return nil|number
function Unit:getFuelLowState() end

--- Returns a numerically indexed table of nearby cargo objects suitable for aircraft loading, or `nil` if not applicable.
---@version unknown
---@return Object[]|nil
function Unit:getNearestCargosForAircraft() end

--- Returns information about available seating in the unit.
---@version unknown
---@return unknown
function Unit:getSeats() end

--- Returns `true` if the unit is or has aircraft carrier capabilities, `false` otherwise.
---@version unknown
---@return boolean
function Unit:hasCarrier() end

--- Loads specified cargo or troops onto this transport unit.
---@version unknown
function Unit:LoadOnBoard() end

--- Marks a task for disembarking troops or cargo from this unit.
---@version unknown
function Unit:markDisembarkingTask() end

--- Displays the legacy carrier operations menu for this unit.
---@version unknown
function Unit:OldCarrierMenuShow() end

--- Opens the cargo ramp on this transport unit to allow loading/unloading.
---@version unknown
function Unit:openRamp() end

--- Initiates the unloading process for cargo carried by this unit.
---@version unknown
function Unit:UnloadCargo() end

--- Returns `true` if the unit has VTOL landing capabilities, `false` otherwise.
---@version unknown
---@return boolean
function Unit:vtolableLA() end

--- Returns a `Unit` object with the specified name, or `nil` if not found. Provides access to both activated and non-activated units.
---@version 1.2.0
---@param name string Name of the unit as defined in the mission editor or mission.
---@return Unit|nil
function Unit.getByName(name) end

--- Returns a table containing detailed description of the specified unit type. The exact type of descriptor returned depends on the unit's category: AIRPLANE units return UnitDescAirplane, HELICOPTER units return UnitDescHelicopter, GROUND_UNIT units return UnitDescVehicle, SHIP units return UnitDescShip, and other types return the base UnitDesc. Functions even for unit types not present in the current mission.
---@version 1.2.4
---@param typeName string Internal type name of the unit, e.g. 'FA-18C_hornet'.
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
---@version 2.8.8
---@param name string The name of the warehouse.
---@return Warehouse|nil
function Warehouse.getByName(name) end

--- Returns a `Warehouse` object associated with a cargo static object, or `nil` if not applicable.
---@version 2.8.8
---@param cargo StaticObject The cargo static object.
---@return Warehouse|nil
function Warehouse.getCargoAsWarehouse(cargo) end

--- Returns a table of all warehouses in the mission, indexed by warehouse name.
---@version 2.8.8
---@return table
function Warehouse.getResourceMap() end


--- Represents a weapon entity in the DCS World, including shells, rockets, missiles, and bombs.
---@class Weapon : Object, CoalitionObject
Weapon = Weapon or {}
--- Returns an `Object.Category` enumerator and a `Weapon.Category` enumerator representing the weapon's classification.
---@version 1.2.0
---@return Object.Category
---@return Weapon.Category
function Weapon:getCategory() end

--- Returns a `Vec3` representing the weapon's position in the DCS World coordinate system.
---@version 1.2.0
---@return Vec3
function Weapon:getPoint() end

--- Returns a `Vec3` representing the weapon's velocity vector in the DCS World coordinate system.
---@version 1.2.0
---@return Vec3
function Weapon:getVelocity() end

--- Returns a `coalition.side` enumerator representing the weapon's coalition alignment.
---@version 1.2.0
---@return coalition.side
function Weapon:getCoalition() end

--- Returns a `string` representing the weapon's name in the mission.
---@version 1.2.0
---@return string
function Weapon:getName() end

--- Returns a `string` representing the weapon's type designation.
---@version 1.2.0
---@return string
function Weapon:getTypeName() end

--- Returns a table containing detailed technical specifications of the weapon. The exact structure depends on the weapon category.
---@version 1.2.0
---@return WeaponDesc|WeaponDescBomb|WeaponDescMissile|WeaponDescRocket
function Weapon:getDesc() end

--- Removes the weapon from the mission without generating destruction events.
---@version 1.2.0
function Weapon:destroy() end

--- Returns `true` if the weapon exists in the mission, `false` otherwise.
---@version 1.2.0
---@return boolean
function Weapon:isExist() end

--- Returns a `Position3` representing the weapon's position and orientation in the DCS World coordinate system.
---@version 1.2.0
---@return Position3
function Weapon:getPosition() end

--- Returns the `Unit` object that launched this weapon.
---@version 1.2.4
---@return Unit
function Weapon:getLauncher() end

--- Returns the `Object` that this guided weapon is targeting, or `nil` for unguided weapons or ground-targeted weapons.
---@version 1.2.4
---@return Object|nil
function Weapon:getTarget() end

--- Returns a `Weapon.Category` enumerator representing the specific weapon classification (SHELL, MISSILE, ROCKET, BOMB).
---@version 1.2.4
---@return Weapon.Category
function Weapon:getCategoryEx() end

--- Returns a `country.id` enumerator representing the country that owns this weapon (via its launcher).
---@version 1.2.0
---@return country.id
function Weapon:getCountry() end

--- Returns a `string` representing the force name this weapon belongs to, or `nil` if not assigned to a specific force.
---@return nil|string
function Weapon:getForcesName() end


--- Provides functions for managing events, accessing game world information, and controlling weather conditions in the DCS World.
---@class world
---@field weather table Provides functions for controlling fog and weather conditions in the mission.@version 2.9.10
---@field event world.event #READONLY Enumerator for event types that can occur in the DCS World simulation.
---@field BirthPlace world.BirthPlace #READONLY Enumerator for spawn locations of aircraft and helicopters.
---@field VolumeType world.VolumeType #READONLY Enumerator for 3D volume types used in spatial queries.
---@field eventHandlers table #READONLY Table of all registered event handler functions.
---@field persistenceHandlers table #READONLY Table of all registered persistence handler functions.
world = world or {}
--- Registers an event handler table to be called when simulator events occur. The table must contain an onEvent method.
---@version 1.2.0
---@param handler EventHandlerTable A table containing an onEvent method that will be called with event data when events occur.
function world.addEventHandler(handler) end

--- Unregisters a previously added event handler table.
---@version 1.2.0
---@param handler EventHandlerTable The event handler table to remove. Must be the same table that was passed to addEventHandler.
function world.removeEventHandler(handler) end

--- Handles simulator events internally for the DCS Mission environment. Different event types produce different event data structures.
---@param eventData EventData Event data containing information about the triggered event. The specific event type determines which fields are available.
function world.onEvent(eventData) end

--- Returns the `Unit` controlled by the player, or `nil` if no unit is directly controlled.
---@version 1.2.4
---@return Unit|nil
function world.getPlayer() end

--- Returns a numerically indexed table of all airbase objects in the mission.
---@version 1.2.4
---@return AirbaseArray
function world.getAirbases() end

--- Returns objects within a specified 3D volume, optionally applying a handler function to each found object.
---@version 1.2.4
---@param category Object.Category|ObjectCategoryArray The category or categories of objects to search for.
---@param searchVolume table A table defining the search volume.
---@param Handler? fun(...) An optional handler function to run on each found object.
---@param data? any Optional data to pass to the handler function.
---@return ObjectArray
function world.searchObjects(category, searchVolume, Handler, data) end

--- Returns a table of all active map markers and drawn shapes in the mission.
---@version 2.5.1
---@return table
function world.getMarkPanels() end

--- Removes debris within a specified volume, returning the number of items cleared.
---@version 2.8.4
---@param searchVolume table A table defining the volume from which to remove junk.
---@return number
function world.removeJunk(searchVolume) end

--- Returns mission persistence data used for saving mission state.
---@return table
function world.getPersistenceData() end

--- Executes all registered persistence handler functions.
function world.runPersistenceHandlers() end

--- Registers a handler function for mission persistence operations.
---@param handler fun(...) The persistence handler function.
function world.setPersistenceHandler(handler) end



-- Type Definitions (Enums, Aliases, Records/Classes)
--- Defines the structure of a Lua table representing spawn parameters for a static object used with coalition.addStaticObject.
--- (Data structure definition for StaticObjectSpawnData. Not a globally accessible table.)
---@class StaticObjectSpawnData
---@field name string A string identifier for the static object.
---@field _type string A string specifying the classification or model type of the static object.
---@field x number X coordinate of the static object's position in the DCS World coordinate system.
---@field y number Y coordinate of the static object's position in the DCS World coordinate system.
---@field heading number Orientation angle in radians representing the static object's heading in the DCS World.
---@field category string A string specifying the functional category of the static object.
---@field dead boolean Controls whether the static object spawns in a destroyed state.
---@field shape_name string A string identifying the 3D model resource used to render the static object.
---@field rate number A numeric value controlling the visual appearance rate, typically set to 100.
---@field canCargo boolean Controls whether the static object can be loaded as cargo.
---@field mass number A numeric value specifying the object's mass in kilograms.

country = country or {}
country.id = country.id or {}
--- Enumerator for country identifiers, used to specify nation affiliation for units and coalition forces in the DCS World.
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
    Argentina = 83,
    Cyprus = 84,
    Slovenia = 85,
    BOLIVIA = 86,
    GHANA = 87,
    NIGERIA = 88,
    PERU = 89,
    ECUADOR = 90,
    AFGHANISTAN = 91,
    ["NEW ZEALAND"] = 92
}

country.name = country.name or {}
--- Enumerator for retrieving country names from numeric identifiers, providing a reverse lookup of country.id values.
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
    ["14"] = "ISRAEL",
    ["15"] = "GEORGIA",
    ["16"] = "INSURGENTS",
    ["17"] = "ABKHAZIA",
    ["18"] = "SOUTH_OSETIA",
    ["19"] = "ITALY",
    ["20"] = "AUSTRALIA",
    ["21"] = "SWITZERLAND",
    ["22"] = "AUSTRIA",
    ["23"] = "BELARUS",
    ["24"] = "BULGARIA",
    ["25"] = "CHEZH_REPUBLIC",
    ["26"] = "CHINA",
    ["27"] = "CROATIA",
    ["28"] = "EGYPT",
    ["29"] = "FINLAND",
    ["30"] = "GREECE",
    ["31"] = "HUNGARY",
    ["32"] = "INDIA",
    ["33"] = "IRAN",
    ["34"] = "IRAQ",
    ["35"] = "JAPAN",
    ["36"] = "KAZAKHSTAN",
    ["37"] = "NORTH_KOREA",
    ["38"] = "PAKISTAN",
    ["39"] = "POLAND",
    ["40"] = "ROMANIA",
    ["41"] = "SAUDI_ARABIA",
    ["42"] = "SERBIA",
    ["43"] = "SLOVAKIA",
    ["44"] = "SOUTH_KOREA",
    ["45"] = "SWEDEN",
    ["46"] = "SYRIA",
    ["47"] = "YEMEN",
    ["48"] = "VIETNAM",
    ["49"] = "VENEZUELA",
    ["50"] = "TUNISIA",
    ["51"] = "THAILAND",
    ["52"] = "SUDAN",
    ["53"] = "PHILIPPINES",
    ["54"] = "MOROCCO",
    ["55"] = "MEXICO",
    ["56"] = "MALAYSIA",
    ["57"] = "LIBYA",
    ["58"] = "JORDAN",
    ["59"] = "INDONESIA",
    ["60"] = "HONDURAS",
    ["61"] = "ETHIOPIA",
    ["62"] = "CHILE",
    ["63"] = "BRAZIL",
    ["64"] = "BAHRAIN",
    ["65"] = "THIRDREICH",
    ["66"] = "YUGOSLAVIA",
    ["67"] = "USSR",
    ["68"] = "ITALIAN_SOCIAL_REPUBLIC",
    ["69"] = "ALGERIA",
    ["70"] = "KUWAIT",
    ["71"] = "QATAR",
    ["72"] = "OMAN",
    ["73"] = "UNITED_ARAB_EMIRATES",
    ["74"] = "SOUTH_AFRICA",
    ["75"] = "CUBA",
    ["76"] = "PORTUGAL",
    ["77"] = "GDR",
    ["78"] = "LEBANON",
    ["79"] = "CJTF_BLUE",
    ["80"] = "CJTF_RED",
    ["81"] = "UN_PEACEKEEPERS",
    ["82"] = "ARGENTINA",
    ["83"] = "CYPRUS",
    ["84"] = "SLOVENIA",
    ["85"] = "BOLIVIA",
    ["86"] = "GHANA",
    ["87"] = "NIGERIA",
    ["88"] = "PERU",
    ["89"] = "ECUADOR",
    ["90"] = "AFGHANISTAN",
    ["91"] = "NEW_ZEALAND"
}

--- Defines the structure of a Lua table representing a group to be spawned with coalition.addGroup or coalition.add_dyn_group functions.
--- (Data structure definition for GroupSpawnData. Not a globally accessible table.)
---@class GroupSpawnData
---@field name string A string identifier for the group, must be unique within the mission.
---@field task string The primary mission task assigned to the group, determines default behavior patterns.
---@field units table A numerically indexed table of unit definitions for all units in the group, each containing position, type, and other properties.
---@field x number X coordinate of the group's reference position in the DCS World coordinate system.
---@field y number Y coordinate of the group's reference position in the DCS World coordinate system.
---@field start_time number Time in seconds after mission start when the group will spawn (0 for immediate spawn).
---@field visible boolean Controls visibility of the group before its scheduled start time in the mission editor.
---@field taskSelected boolean Indicates if the task is selected for execution when the group spawns.
---@field route table A table defining waypoints and assigned tasks for the group's route, determining movement patterns.
---@field hidden boolean Controls visibility of the group on the F10 map view for players.
---@field groupId number Optional unique numeric identifier for the group, used for scripting references.

BeaconType = BeaconType or {}
--- Enumerator for types of beacons that can be activated.
---@version 1.2.4
---@enum BeaconType
BeaconType = {
    BEACON_TYPE_NULL = 0,
    BEACON_TYPE_VOR = 1,
    BEACON_TYPE_DME = 2,
    BEACON_TYPE_VOR_DME = 3,
    BEACON_TYPE_TACAN = 4,
    BEACON_TYPE_VORTAC = 5,
    BEACON_TYPE_RSBN = 32,
    BEACON_TYPE_BROADCAST_STATION = 1024,
    BEACON_TYPE_HOMER = 8,
    BEACON_TYPE_AIRPORT_HOMER = 4104,
    BEACON_TYPE_AIRPORT_HOMER_WITH_MARKER = 4136,
    BEACON_TYPE_ILS_FAR_HOMER = 16408,
    BEACON_TYPE_ILS_NEAR_HOMER = 16456,
    BEACON_TYPE_ILS_LOCALIZER = 16640,
    BEACON_TYPE_ILS_GLIDESLOPE = 16896,
    BEACON_TYPE_NAUTICAL_HOMER = 32776
}

BeaconSystemName = BeaconSystemName or {}
--- Enumerator for types of beacon systems.
---@version 1.2.4
---@enum BeaconSystemName
BeaconSystemName = {
    PAR_10 = 1,
    RSBN_5 = 2,
    TACAN = 3,
    TACAN_TANKER = 4,
    ILS_LOCALIZER = 5,
    ILS_GLIDESLOPE = 6,
    BROADCAST_STATION = 7
}

--- Represents a 3D vector or point, typically used for positions or velocities in the DCS World coordinate system. It is a Lua table with `x`, `y`, and `z` keys.
--- (Data structure definition for Vec3. Not a globally accessible table.)
---@class Vec3
---@field x number X coordinate, which represents the north-south direction in the DCS World coordinate system. North is positive, South is negative.
---@field y number Y coordinate, which represents the elevation direction in the DCS World coordinate system. Up is positive, Down is negative.
---@field z number Z coordinate, which represents the east-west direction in the DCS World coordinate system. East is positive, West is negative.

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

VoiceChat.Side = VoiceChat.Side or {}
--- Enumerator for coalition sides, used to define which players have access to specific voice chat rooms.
---@version 2.5.6
---@enum VoiceChat.Side
VoiceChat.Side = {
    NEUTRAL = 0,
    RED = 1,
    BLUE = 2,
    ALL = 3
}

VoiceChat.RoomType = VoiceChat.RoomType or {}
--- Enumerator for voice chat room categories, used to specify the behavior and persistence of communication channels. Note: Only PERSISTENT (0) is reliable for scripted room creation.
---@version 2.5.6
---@enum VoiceChat.RoomType
VoiceChat.RoomType = {
    PERSISTENT = 0,
    MULTICREW = 1,
    MANAGEABLE = 2
}

VoiceChat.RadioHandlers = VoiceChat.RadioHandlers or {}
--- Enumerator for radio control properties, used to access and modify aircraft radio communication settings through the VoiceChat API.
---@version 2.8.0
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
---@version 2.8.0
---@enum VoiceChat.RadioHandlersSingletons
VoiceChat.RadioHandlersSingletons = {
    INTERCOM_SOUND_VOLUME = 0,
    INTERCOM_HOT_MIKE_STATUS = 1,
    INITIALIZATION_COMPLETE = 3
}

--- Represents a value whose type is not strictly defined or may vary across different contexts in the DCS World scripting environment.
---@alias unknown boolean|number|string|table

--- Defines the structure of a Lua table representing a Military Grid Reference System (MGRS) coordinate used for precise position referencing in the DCS World.
--- (Data structure definition for MGRS. Not a globally accessible table.)
---@version 1.2.0
---@class MGRS
---@field UTMZone string The Universal Transverse Mercator (UTM) zone designation indicating the longitude zone.
---@field MGRSDigraph string The MGRS grid square designator consisting of two letters identifying a specific 100km square.
---@field Easting number Easting coordinate in meters, measuring the distance eastward from the zone's central meridian.
---@field Northing number Northing coordinate in meters, measuring the distance northward from the equator.

--- Represents a 2D vector or point, typically used for map coordinates in the DCS World coordinate system. It is a Lua table with `x` and `y` keys.
--- (Data structure definition for Vec2. Not a globally accessible table.)
---@class Vec2
---@field x number X coordinate, which represents the north-south direction in the DCS World coordinate system. North is positive, South is negative.
---@field y number Y coordinate, which represents the east-west direction in the DCS World coordinate system. East is positive, West is negative.

--- Defines the structure of a Lua table representing geographical coordinates using latitude and longitude values.
--- (Data structure definition for LatLon. Not a globally accessible table.)
---@version 1.2.0
---@class LatLon
---@field lat number Latitude value in decimal degrees, with positive values representing north of the equator and negative values representing south.
---@field lon number Longitude value in decimal degrees, with positive values representing east of the prime meridian and negative values representing west.

Callsigns_JTAC = Callsigns_JTAC or {}
--- Enumerator for Joint Terminal Attack Controller (JTAC) callsigns, used to identify JTAC units in communications and mission planning.
---@version 1.2.4
---@enum Callsigns_JTAC
Callsigns_JTAC = {
    Axeman = 1,
    Darknight = 2,
    Warrior = 3,
    Pointer = 4,
    Eyeball = 5,
    Moonbeam = 6,
    Whiplash = 7,
    Finger = 8,
    Pinpoint = 9,
    Ferret = 10,
    Shaba = 11,
    Playboy = 12,
    Hammer = 13,
    Jaguar = 14,
    Deathstar = 15,
    Anvil = 16,
    Firefly = 17,
    Mantis = 18,
    Badger = 19
}

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

--- A table of capability and characteristic flags that define the features and abilities of a unit. Fields correspond to attributes from the Attributes enum.
--- (Data structure definition for UnitAttributes. Not a globally accessible table.)
---@class UnitAttributes

--- Defines the structure of a Lua table representing detection ranges based on aspect angle within a hemisphere.
--- (Data structure definition for UnitSensorHemisphereDistance. Not a globally accessible table.)
---@class UnitSensorHemisphereDistance
---@field tailOn number A numeric value representing the maximum detection distance in meters when facing the rear of the target.
---@field headOn number A numeric value representing the maximum detection distance in meters when facing the front of the target.

--- Defines the structure of a Lua table representing performance characteristics specific to fixed-wing aircraft in the DCS World. Includes all fields from UnitDesc and UnitDescAircraft plus the following airplane-specific fields.
--- (Data structure definition for UnitDescAirplane. Not a globally accessible table.)
---@class UnitDescAirplane
---@field speedMax0 number A numeric value representing the maximum true airspeed in meters per second at sea level.
---@field speedMax10K number A numeric value representing the maximum true airspeed in meters per second at 10,000 meters altitude.

--- Defines the structure of a Lua table representing performance characteristics specific to rotary-wing aircraft in the DCS World. Includes all fields from UnitDesc and UnitDescAircraft plus the following helicopter-specific fields.
--- (Data structure definition for UnitDescHelicopter. Not a globally accessible table.)
---@class UnitDescHelicopter
---@field HmaxStat number A numeric value representing the maximum hover ceiling in meters (altitude at which the helicopter can maintain a stable hover).

--- Defines the structure of a Lua table representing performance characteristics specific to ground vehicles in the DCS World. Includes all fields from UnitDesc plus the following vehicle-specific fields.
--- (Data structure definition for UnitDescVehicle. Not a globally accessible table.)
---@class UnitDescVehicle
---@field maxSlopeAngle number A numeric value representing the maximum terrain slope angle in radians that the vehicle can traverse.
---@field riverCrossing boolean A boolean value indicating whether the vehicle has amphibious capabilities to cross water obstacles.
---@field speedMaxOffRoad nil|number A numeric value representing the maximum speed in meters per second when traveling on unpaved terrain.

--- Defines the structure of a Lua table representing performance characteristics specific to naval vessels in the DCS World. Includes all fields from UnitDesc plus any ship-specific fields.
--- (Data structure definition for UnitDescShip. Not a globally accessible table.)
---@class UnitDescShip

trigger.smokeColor = trigger.smokeColor or {}
--- Enumerator for smoke colors, used to specify colored smoke effects in trigger actions.
---@version 1.2.0
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
---@version 1.2.0
---@enum trigger.flareColor
trigger.flareColor = {
    Green = 0,
    Red = 1,
    White = 2,
    Yellow = 3
}

MarkupShapeId = MarkupShapeId or {}
--- Enumerator for markup geometric shape types, used with trigger.action.markupToAll to create map annotations.
---@version 2.5.6
---@enum MarkupShapeId
MarkupShapeId = {
    Line = 1,
    Circle = 2,
    Rect = 3,
    Arrow = 4,
    Text = 5,
    Quad = 6,
    Freeform = 7
}

MarkupLineType = MarkupLineType or {}
--- Enumerator for line style patterns, used to customize map markup line appearances in trigger actions.
---@version 2.5.5
---@enum MarkupLineType
MarkupLineType = {
    NoLine = 0,
    Solid = 1,
    Dashed = 2,
    Dotted = 3,
    DotDash = 4,
    LongDash = 5,
    TwoDash = 6
}

BigSmokeType = BigSmokeType or {}
--- Enumerator for smoke and fire effect variants, used to specify visual effect intensity and characteristics in trigger actions.
---@version 1.2.0
---@enum BigSmokeType
BigSmokeType = {
    SmallSmokeAndFire = 1,
    MediumSmokeAndFire = 2,
    LargeSmokeAndFire = 3,
    HugeSmokeAndFire = 4,
    SmallSmoke = 5,
    MediumSmoke = 6,
    LargeSmoke = 7,
    HugeSmoke = 8
}

RadioModulation = RadioModulation or {}
--- Enumerator for radio transmission modulation types, used to specify signal modulation in trigger communication actions.
---@version 1.2.0
---@enum RadioModulation
RadioModulation = {
    AM = 0,
    FM = 1
}

Attributes = Attributes or {}
--- Enumerator for unit capability and classification attributes, used to identify unit properties and targeting criteria in the DCS World.
---@version 2.5.0
---@enum Attributes
Attributes = {
    plane_carrier = "plane_carrier",
    no_tail_trail = "no_tail_trail",
    cord = "cord",
    ski_jump = "ski_jump",
    catapult = "catapult",
    low_reflection_vessel = "low_reflection_vessel",
    AA_flak = "AA_flak",
    AA_missile = "AA_missile",
    ["Cruise missiles"] = "Cruise missiles",
    ["Anti-Ship missiles"] = "Anti-Ship missiles",
    Missiles = "Missiles",
    Fighters = "Fighters",
    Interceptors = "Interceptors",
    ["Multirole fighters"] = "Multirole fighters",
    Bombers = "Bombers",
    Battleplanes = "Battleplanes",
    AWACS = "AWACS",
    Tankers = "Tankers",
    Aux = "Aux",
    Transports = "Transports",
    ["Strategic bombers"] = "Strategic bombers",
    UAVs = "UAVs",
    ["Attack helicopters"] = "Attack helicopters",
    ["Transport helicopters"] = "Transport helicopters",
    Planes = "Planes",
    Helicopters = "Helicopters",
    Cars = "Cars",
    Trucks = "Trucks",
    Infantry = "Infantry",
    Tanks = "Tanks",
    Artillery = "Artillery",
    MLRS = "MLRS",
    IFV = "IFV",
    APC = "APC",
    Fortifications = "Fortifications",
    ["Armed vehicles"] = "Armed vehicles",
    ["Static AAA"] = "Static AAA",
    ["Mobile AAA"] = "Mobile AAA",
    ["SAM SR"] = "SAM SR",
    ["SAM TR"] = "SAM TR",
    ["SAM LL"] = "SAM LL",
    ["SAM CC"] = "SAM CC",
    ["SAM AUX"] = "SAM AUX",
    ["SR SAM"] = "SR SAM",
    ["MR SAM"] = "MR SAM",
    ["LR SAM"] = "LR SAM",
    ["SAM elements"] = "SAM elements",
    ["IR Guided SAM"] = "IR Guided SAM",
    SAM = "SAM",
    ["SAM related"] = "SAM related",
    AAA = "AAA",
    EWR = "EWR",
    ["Air Defence vehicles"] = "Air Defence vehicles",
    MANPADS = "MANPADS",
    ["MANPADS AUX"] = "MANPADS AUX",
    ["Unarmed vehicles"] = "Unarmed vehicles",
    ["Armed ground units"] = "Armed ground units",
    ["Armed Air Defence"] = "Armed Air Defence",
    ["Air Defence"] = "Air Defence",
    ["Aircraft Carriers"] = "Aircraft Carriers",
    Cruisers = "Cruisers",
    Destroyers = "Destroyers",
    Frigates = "Frigates",
    Corvettes = "Corvettes",
    ["Heavy armed ships"] = "Heavy armed ships",
    ["Light armed ships"] = "Light armed ships",
    ["Armed ships"] = "Armed ships",
    ["Unarmed ships"] = "Unarmed ships",
    Air = "Air",
    ["Ground vehicles"] = "Ground vehicles",
    Ships = "Ships",
    Buildings = "Buildings",
    HeavyArmoredUnits = "HeavyArmoredUnits",
    ATGM = "ATGM",
    ["Old Tanks"] = "Old Tanks",
    ["Modern Tanks"] = "Modern Tanks",
    LightArmoredUnits = "LightArmoredUnits",
    ["Rocket Attack Valid AirDefence"] = "Rocket Attack Valid AirDefence",
    ["Battle airplanes"] = "Battle airplanes",
    All = "All",
    ["Infantry carriers"] = "Infantry carriers",
    Vehicles = "Vehicles",
    ["Ground Units"] = "Ground Units",
    ["Ground Units Non Airdefence"] = "Ground Units Non Airdefence",
    ["Armored vehicles"] = "Armored vehicles",
    ["AntiAir Armed Vehicles"] = "AntiAir Armed Vehicles",
    Airfields = "Airfields",
    Heliports = "Heliports",
    ["Grass Airfields"] = "Grass Airfields",
    Point = "Point",
    NonArmoredUnits = "NonArmoredUnits",
    NonAndLightArmoredUnits = "NonAndLightArmoredUnits",
    human_vehicle = "human_vehicle",
    RADAR_BAND1_FOR_ARM = "RADAR_BAND1_FOR_ARM",
    RADAR_BAND2_FOR_ARM = "RADAR_BAND2_FOR_ARM",
    Prone = "Prone",
    DetectionByAWACS = "DetectionByAWACS",
    Datalink = "Datalink",
    CustomAimPoint = "CustomAimPoint",
    ["Indirect fire"] = "Indirect fire",
    Refuelable = "Refuelable",
    Weapon = "Weapon",
    Shell = "Shell",
    Rocket = "Rocket",
    Bomb = "Bomb",
    Missile = "Missile"
}

--- Defines the structure of a Lua table representing an event handler object that can be registered with world.addEventHandler.
--- (Data structure definition for EventHandlerTable. Not a globally accessible table.)
---@class EventHandlerTable
---@field onEvent fun(...) Function that handles simulator events when they occur. Called with (self, event) parameters where event is of type EventData.

AI.Task = AI.Task or {}
AI.Task.WeaponExpend = AI.Task.WeaponExpend or {}
--- Enumerator for ammunition expenditure levels per attack run, used in AI task assignments.
---@version 1.2.4
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
---@version 1.2.4
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
---@version 1.2.4
---@enum AI.Task.OrbitPattern
AI.Task.OrbitPattern = {
    RACE_TRACK = "Race-Track",
    CIRCLE = "Circle"
}

AI.Task.TurnMethod = AI.Task.TurnMethod or {}
--- Enumerator for waypoint turn methods used in AI navigation.
---@version 1.1
---@enum AI.Task.TurnMethod
AI.Task.TurnMethod = {
    FLY_OVER_POINT = "Fly Over Point",
    FIN_POINT = "Fin Point"
}

AI.Task.VehicleFormation = AI.Task.VehicleFormation or {}
--- Enumerator for ground vehicle formation patterns used in group movement.
---@version 1.2.0
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
---@version 1.2.0
---@enum AI.Task.AltitudeType
AI.Task.AltitudeType = {
    RADIO = "RADIO",
    BARO = "BARO"
}

AI.Task.WaypointType = AI.Task.WaypointType or {}
--- Enumerator for waypoint types used in AI flight planning.
---@version 1.1
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
---@version 1.2.0
---@enum AI.Skill
AI.Skill = {
    PLAYER = "PLAYER",
    CLIENT = "CLIENT",
    AVERAGE = "AVERAGE",
    GOOD = "GOOD",
    HIGH = "HIGH",
    EXCELLENT = "EXCELLENT"
}

--- Defines the structure of options applicable to AI-controlled aircraft.
---@version 1.2.0
---@class AI.Option.Air
AI.Option = AI.Option or {}
AI.Option.Air = AI.Option.Air or {}

AI.Option.Air.id = AI.Option.Air.id or {}
--- Enumerator for option identifiers applicable to AI-controlled aircraft.
---@version 1.2.0
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
    ALLOW_FORMATION_SIDE_SWAP = 35
}

--- Defines the structure of option values for AI-controlled aircraft settings.
---@version 1.2.0
---@class AI.Option.Air.val
AI.Option.Air.val = AI.Option.Air.val or {}

AI.Option.Air.val.ROE = AI.Option.Air.val.ROE or {}
--- Enumerator for Rules of Engagement settings available to AI-controlled aircraft.
---@version 1.2.4
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
---@version 1.2.4
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
---@version 1.2.4
---@enum AI.Option.Air.val.RADAR_USING
AI.Option.Air.val.RADAR_USING = {
    NEVER = 0,
    FOR_ATTACK_ONLY = 1,
    FOR_SEARCH_IF_REQUIRED = 2,
    FOR_CONTINUOUS_SEARCH = 3
}

AI.Option.Air.val.FLARE_USING = AI.Option.Air.val.FLARE_USING or {}
--- Enumerator for flare countermeasure usage policies available to AI-controlled aircraft.
---@version 1.2.4
---@enum AI.Option.Air.val.FLARE_USING
AI.Option.Air.val.FLARE_USING = {
    NEVER = 0,
    AGAINST_FIRED_MISSILE = 1,
    WHEN_FLYING_IN_SAM_WEZ = 2,
    WHEN_FLYING_NEAR_ENEMIES = 3
}

AI.Option.Air.val.ECM_USING = AI.Option.Air.val.ECM_USING or {}
--- Enumerator for electronic countermeasure usage policies available to AI-controlled aircraft.
---@version 1.5.0
---@enum AI.Option.Air.val.ECM_USING
AI.Option.Air.val.ECM_USING = {
    NEVER_USE = 0,
    USE_IF_ONLY_LOCK_BY_RADAR = 1,
    USE_IF_DETECTED_LOCK_BY_RADAR = 2,
    ALWAYS_USE = 3
}

AI.Option.Air.val.MISSILE_ATTACK = AI.Option.Air.val.MISSILE_ATTACK or {}
--- Enumerator for missile engagement range policies available to AI-controlled aircraft.
---@version 1.5.0
---@enum AI.Option.Air.val.MISSILE_ATTACK
AI.Option.Air.val.MISSILE_ATTACK = {
    MAX_RANGE = 0,
    NEZ_RANGE = 1,
    HALF_WAY_RMAX_NEZ = 2,
    TARGET_THREAT_EST = 3,
    RANDOM_RANGE = 4
}

--- Defines the structure of options applicable to AI-controlled ground units.
---@version 1.2.0
---@class AI.Option.Ground
AI.Option.Ground = AI.Option.Ground or {}

AI.Option.Ground.id = AI.Option.Ground.id or {}
--- Enumerator for option identifiers applicable to AI-controlled ground units.
---@version 1.2.0
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
---@version 1.2.0
---@class AI.Option.Ground.val
AI.Option.Ground.val = AI.Option.Ground.val or {}

AI.Option.Ground.val.ALARM_STATE = AI.Option.Ground.val.ALARM_STATE or {}
--- Enumerator for alert readiness levels available to AI-controlled ground units.
---@version 1.2.4
---@enum AI.Option.Ground.val.ALARM_STATE
AI.Option.Ground.val.ALARM_STATE = {
    AUTO = 0,
    GREEN = 1,
    RED = 2
}

AI.Option.Ground.val.ROE = AI.Option.Ground.val.ROE or {}
--- Enumerator for Rules of Engagement settings available to AI-controlled ground units.
---@version 1.2.4
---@enum AI.Option.Ground.val.ROE
AI.Option.Ground.val.ROE = {
    OPEN_FIRE = 2,
    RETURN_FIRE = 3,
    WEAPON_HOLD = 4
}

--- Defines the structure of options applicable to AI-controlled naval units.
---@version 1.2.0
---@class AI.Option.Naval
AI.Option.Naval = AI.Option.Naval or {}

AI.Option.Naval.id = AI.Option.Naval.id or {}
--- Enumerator for option identifiers applicable to AI-controlled naval units.
---@version 1.2.0
---@enum AI.Option.Naval.id
AI.Option.Naval.id = {
    NO_OPTION = -1,
    ROE = 0
}

--- Defines the structure of option values for AI-controlled naval unit settings.
---@version 1.2.0
---@class AI.Option.Naval.val
AI.Option.Naval.val = AI.Option.Naval.val or {}

AI.Option.Naval.val.ROE = AI.Option.Naval.val.ROE or {}
--- Enumerator for Rules of Engagement settings available to AI-controlled naval units.
---@version 1.2.4
---@enum AI.Option.Naval.val.ROE
AI.Option.Naval.val.ROE = {
    OPEN_FIRE = 2,
    RETURN_FIRE = 3,
    WEAPON_HOLD = 4
}

FormationType = FormationType or {}
--- Enumerator for all formation patterns used across different AI unit types.
---@version 1.2.0
---@enum FormationType
FormationType = {
    LINE_ABREAST = 1,
    TRAIL = 2,
    WEDGE = 3,
    ECHELON_RIGHT_AIR = 4,
    ECHELON_LEFT_AIR = 5,
    FINGER_FOUR = 6,
    SPREAD_FOUR = 7,
    HEL_WEDGE = 8,
    HEL_ECHELON = 9,
    HEL_FRONT = 10,
    HEL_COLUMN = 11,
    WW2_BOMBER_ELEMENT = 12,
    WW2_BOMBER_ELEMENT_HEIGHT = 13,
    WW2_FIGHTER_VIC = 14,
    GROUND_VEE = "Vee",
    GROUND_ECHELON_RIGHT = "EchelonR",
    GROUND_OFF_ROAD = "Off Road",
    GROUND_RANK = "Rank",
    GROUND_ECHELON_LEFT = "EchelonL",
    GROUND_ON_ROAD = "On Road",
    GROUND_CONE = "Cone",
    GROUND_DIAMOND = "Diamond"
}

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

--- Defines the structure of a Lua table containing parameters for the ICLS beacon activation.
--- (Data structure definition for CommandActivateICLSParams. Not a globally accessible table.)
---@class CommandActivateICLSParams
---@field _type number Fixed value of 131584 identifying an ICLS beacon type.
---@field channel number ICLS channel number (1-20) that aircraft will tune to for landing guidance.
---@field unitId number ID of the ship unit that will broadcast the ICLS beacon signal.
---@field name string Descriptive name of the ICLS beacon for identification purposes only.

--- Defines the structure of a Lua table containing parameters for the invisibility toggle command.
--- (Data structure definition for CommandSetInvisibleParams. Not a globally accessible table.)
---@class CommandSetInvisibleParams
---@field value boolean Invisibility state where true makes the group undetectable by enemy AI, false restores normal detection.

--- Defines the structure of a Lua table containing parameters for the Link 4 activation command.
--- (Data structure definition for CommandActivateLink4Params. Not a globally accessible table.)
---@class CommandActivateLink4Params
---@field unitId number ID of the ship unit that will broadcast the Link 4 signal (must have Link 4 capability).
---@field frequency number Operating frequency in Hertz for the data link communications.
---@field name string Descriptive name of the Link 4 system for identification purposes only.

--- Defines the structure of a Lua table containing parameters for the EPLRS data link toggle command.
--- (Data structure definition for CommandEPLRSParams. Not a globally accessible table.)
---@class CommandEPLRSParams
---@field value boolean EPLRS state where true activates the data link, false deactivates it.
---@field groupId number Track number assigned to the first unit in the group (only relevant for ground vehicle groups).

--- Defines the structure of a Lua table containing parameters for the callsign change command.
--- (Data structure definition for CommandSetCallsignParams. Not a globally accessible table.)
---@class CommandSetCallsignParams
---@field callname number Callsign name identifier (varies by unit type; 1-19 for JTAC units per Callsigns_JTAC enum).
---@field number number Numeric suffix for the callsign (1-9), used to distinguish between units with the same callname.

--- Defines the structure of a Lua table containing parameters for the unlimited fuel toggle command.
--- (Data structure definition for CommandSetUnlimitedFuelParams. Not a globally accessible table.)
---@class CommandSetUnlimitedFuelParams
---@field value boolean Fuel state where true prevents fuel depletion during operation, false restores normal fuel consumption.

--- Defines the structure of a Lua table containing parameters for the beacon deactivation command.
--- (Data structure definition for CommandDeactivateBeaconParams. Not a globally accessible table.)
---@class CommandDeactivateBeaconParams

--- Defines the structure of a Lua table containing parameters for the ACLS activation command.
--- (Data structure definition for CommandActivateACLSParams. Not a globally accessible table.)
---@class CommandActivateACLSParams
---@field unitId number ID of the ship unit that will provide the ACLS functionality (requires carrier with appropriate systems).
---@field name string Descriptive name of the ACLS for identification purposes only.

--- Defines the structure of a Lua table containing parameters for the waypoint switching command.
--- (Data structure definition for CommandSwitchWaypointParams. Not a globally accessible table.)
---@class CommandSwitchWaypointParams
---@field fromWaypointIndex number Index of the waypoint where the group will begin its new route leg.
---@field goToWaypointIndex number Index of the destination waypoint the group will navigate toward.

--- Defines the structure of a Lua table containing parameters for the script execution command.
--- (Data structure definition for CommandScriptParams. Not a globally accessible table.)
---@class CommandScriptParams
---@field command string Lua code string to be executed within the group's context.

--- Defines the structure of a Lua table containing parameters for the immortality toggle command.
--- (Data structure definition for CommandSetImmortalParams. Not a globally accessible table.)
---@class CommandSetImmortalParams
---@field value boolean Immortality state where true makes the group immune to all damage, false restores normal vulnerability.

--- Defines the structure of a Lua table containing parameters for the ship cargo loading command.
--- (Data structure definition for CommandLoadingShipParams. Not a globally accessible table.)
---@class CommandLoadingShipParams
---@field cargo number Cargo load percentage (0-100) determining how much the ship sits in water (lower values raise the waterline).
---@field unitId number ID of the ship unit whose cargo load level will be modified.

CommandId = CommandId or {}
--- Enumerator for command identifiers that can be sent to Controller entities, used to specify the type of command being issued.
---@enum CommandId
CommandId = {
    CommandScript = "script",
    CommandSetCallsign = "setCallsign",
    CommandSetFrequency = "setFrequency",
    CommandSetFrequencyForUnit = "setFrequencyForUnit",
    CommandSwitchWaypoint = "switchWaypoint",
    CommandStopRoute = "stopRoute",
    CommandSwitchAction = "switchAction",
    CommandSetInvisible = "setInvisible",
    CommandSetImmortal = "setImmortal",
    CommandSetUnlimitedFuel = "setUnlimitedFuel",
    CommandActivateBeacon = "ActivateBeacon",
    CommandDeactivateBeacon = "DeactivateBeacon",
    CommandActivateICLS = "ActivateICLS",
    CommandDeactivateICLS = "DeactivateICLS",
    CommandEPLRS = "EPLRS",
    CommandStart = "start",
    CommandTransmitMessage = "transmitMessage",
    CommandStopTransmission = "stopTransmission",
    CommandSmokeOnOff = "smoke_on_off",
    CommandActivateLink4 = "ActivateLink4",
    CommandDeactivateLink4 = "DeactivateLink4",
    CommandActivateACLS = "ActivateACLS",
    CommandDeactivateACLS = "DeactivateACLS",
    CommandLoadingShip = "LoadingShip"
}

--- Defines the structure of a Lua table containing parameters for the frequency change command.
--- (Data structure definition for CommandSetFrequencyParams. Not a globally accessible table.)
---@class CommandSetFrequencyParams
---@field frequency number Radio frequency in Hertz (note: mission editor displays MHz, multiply by 1,000,000 to convert).
---@field modulation number Radio modulation type (0 = AM, 1 = FM).
---@field power number Radio transmit power in watts, determining broadcast range.

--- Defines the structure of a Lua table containing parameters for the transmission termination command.
--- (Data structure definition for CommandStopTransmissionParams. Not a globally accessible table.)
---@class CommandStopTransmissionParams

--- Defines the structure of a Lua table containing parameters for the group activation command.
--- (Data structure definition for CommandStartParams. Not a globally accessible table.)
---@class CommandStartParams

--- Defines the structure of a Lua table containing parameters for the action switching command.
--- (Data structure definition for CommandSwitchActionParams. Not a globally accessible table.)
---@class CommandSwitchActionParams
---@field actionIndex number Index of the target action in the group's task queue to make active.

--- Defines the structure of a Lua table containing parameters for the ACLS deactivation command.
--- (Data structure definition for CommandDeactivateACLSParams. Not a globally accessible table.)
---@class CommandDeactivateACLSParams

--- Defines the structure of a Lua table containing parameters for the Link 4 deactivation command.
--- (Data structure definition for CommandDeactivateLink4Params. Not a globally accessible table.)
---@class CommandDeactivateLink4Params

--- Defines the structure of a Lua table containing parameters for the route control command.
--- (Data structure definition for CommandStopRouteParams. Not a globally accessible table.)
---@class CommandStopRouteParams
---@field value boolean Movement state where true halts the group in place, false allows it to resume following its route.

--- Defines the structure of a Lua table containing parameters for the unit-specific frequency change command.
--- (Data structure definition for CommandSetFrequencyForUnitParams. Not a globally accessible table.)
---@class CommandSetFrequencyForUnitParams
---@field frequency number Radio frequency in Hertz (note: mission editor displays MHz, multiply by 1,000,000 to convert).
---@field modulation number Radio modulation type (0 = AM, 1 = FM).
---@field power number Radio transmit power in watts, determining broadcast range.
---@field unitId number ID of the specific unit within the group whose radio frequency will be modified.

--- Defines the structure of a Lua table containing parameters for the smoke toggle command.
--- (Data structure definition for CommandSmokeOnOffParams. Not a globally accessible table.)
---@class CommandSmokeOnOffParams
---@field value boolean Smoke state where true activates smoke emission, false deactivates it.

--- Defines the structure of a Lua table containing parameters for the ICLS beacon deactivation command.
--- (Data structure definition for CommandDeactivateICLSParams. Not a globally accessible table.)
---@class CommandDeactivateICLSParams

--- Defines the structure of a Lua table containing parameters for the radio message transmission command.
--- (Data structure definition for CommandTransmitMessageParams. Not a globally accessible table.)
---@class CommandTransmitMessageParams
---@field file string Path to the sound file that will be played as the radio transmission.
---@field duration number Display time in seconds for the message subtitles (ignored when loop is true).
---@field subtitle string Text displayed in the radio message queue representing the transmission content.
---@field loop boolean Transmission mode where true causes the message to repeat continuously until stopped.

--- Defines the structure of a Lua table containing parameters for the EWR task (no parameters required).
--- (Data structure definition for TaskEnRouteEWRParams. Not a globally accessible table.)
---@class TaskEnRouteEWRParams

--- Defines the structure of a Lua table containing parameters for the engageGroup task.
--- (Data structure definition for TaskEnRouteEngageGroupParams. Not a globally accessible table.)
---@class TaskEnRouteEngageGroupParams
---@field groupId number Unique identifier for the target group.
---@field weaponType number Defines the preferred weapon type to engage the enemy.
---@field expend string Defines how many munitions the AI will expend per attack run (QUARTER, TWO, ONE, FOUR, HALF, ALL).
---@field attackQty number Number of times the group will attack if the target is still alive and AI still have ammo.
---@field direction number Defines the direction from which the flight will engage from (in radians).
---@field attackQtyLimit boolean Determines if the attack quantity limit is enabled.
---@field priority number The priority of the tasking, where lower numbers indicate higher importance (default: 0).

--- Defines the structure of a Lua table containing parameters for the tanker task (no parameters required).
--- (Data structure definition for TaskEnRouteTankerParams. Not a globally accessible table.)
---@class TaskEnRouteTankerParams

--- Defines the structure of a Lua table containing parameters for the engageUnit task.
--- (Data structure definition for TaskEnRouteEngageUnitParams. Not a globally accessible table.)
---@class TaskEnRouteEngageUnitParams
---@field unitId number Unique identifier of the target unit.
---@field weaponType number Defines the preferred weapon type to engage the enemy.
---@field expend string Defines how many munitions the AI will expend per attack run (QUARTER, TWO, ONE, FOUR, HALF, ALL).
---@field attackQty number Number of times the group will attack if the target is still alive and AI still have ammo.
---@field direction number Defines the direction from which the flight will engage from (in radians).
---@field attackQtyLimit boolean Determines if the attack quantity limit is enabled.
---@field groupAttack boolean If true, each aircraft in the group will attack the unit.
---@field priority number The priority of the tasking, where lower numbers indicate higher importance (default: 0).

--- Defines the structure of a Lua table containing parameters for the AWACS task (no parameters required).
--- (Data structure definition for TaskEnRouteAWACSParams. Not a globally accessible table.)
---@class TaskEnRouteAWACSParams

--- Defines the structure of a Lua table containing parameters for the engageTargets task.
--- (Data structure definition for TaskEnRouteEngageTargetsParams. Not a globally accessible table.)
---@class TaskEnRouteEngageTargetsParams
---@field targetTypes table Table of target categories to engage.
---@field priority number Priority of the task, where lower numbers indicate higher importance.
---@field value string The value of the task.
---@field maxDistEnabled boolean Whether to use the maxDist parameter.
---@field maxDist number Maximum distance to search for targets in meters.
---@field maxAltEnabled boolean Whether to use the maxAlt parameter.
---@field maxAlt number Maximum altitude for targets in meters.
---@field minAltEnabled boolean Whether to use the minAlt parameter.
---@field minAlt number Minimum altitude for targets in meters.

TaskEnRouteId = TaskEnRouteId or {}
--- Enumerator for en-route task identifiers that can be assigned to Controller entities but are not globally accessible.
---@enum TaskEnRouteId
TaskEnRouteId = {
    TaskEnRouteEngageTargets = "engageTargets",
    TaskEnRouteEngageTargetsInZone = "engageTargetsInZone",
    TaskEnRouteEngageGroup = "engageGroup",
    TaskEnRouteEngageUnit = "engageUnit",
    TaskEnRouteAWACS = "awacs",
    TaskEnRouteTanker = "tanker",
    TaskEnRouteEWR = "ewr",
    TaskEnRouteFACEngageGroup = "FAC_engageGroup",
    TaskEnRouteFAC = "FAC"
}

--- Defines the structure of a Lua table for hold parameters, which is currently empty as the task requires no additional configuration.
--- (Data structure definition for TaskHoldParams. Not a globally accessible table.)
---@class TaskHoldParams

--- Defines the structure of a Lua table detailing configuration options for a unit attack mission.
--- (Data structure definition for TaskAttackUnitParams. Not a globally accessible table.)
---@class TaskAttackUnitParams
---@field unitId number Unique ID of the unit to attack.
---@field weaponType number Weapon flag type to use for the attack.
---@field expend string Quantity of weapons to expend during the attack (QUARTER, TWO, ONE, FOUR, HALF, ALL).
---@field direction number Attack direction in radians, defining the approach vector.
---@field attackQtyLimit boolean Determines whether to use the attackQty parameter as a limit.
---@field attackQty number Number of attack passes the group will perform on the target.
---@field groupAttack boolean Determines whether each aircraft in the group will attack individually (true) or as a coordinated unit (false).

--- Defines the structure of a Lua table detailing configuration options for a naval recovery tanker mission.
--- (Data structure definition for TaskRecoveryTankerParams. Not a globally accessible table.)
---@class TaskRecoveryTankerParams
---@field groupId number The group ID of the naval group to follow and provide tanker services to.
---@field speed number Speed of the tanker in meters per second while performing its orbit pattern.
---@field altitude number Altitude in meters at which the tanker will orbit above the naval group.
---@field lastWptIndexFlag boolean Determines whether the tanker task should terminate when the naval group reaches a specific waypoint.
---@field lastWptIndex number Waypoint index of the naval group that, when reached, will cause the recovery tanker to end its task.

--- Defines the structure of a Lua table for refueling parameters, which is currently empty as the task requires no additional configuration.
--- (Data structure definition for TaskRefuelingParams. Not a globally accessible table.)
---@class TaskRefuelingParams

--- Parameters for the BombingRunway task
--- (Data structure definition for TaskBombingRunwayParams. Not a globally accessible table.)
---@class TaskBombingRunwayParams
---@field runwayId number Index of the airbase for which is to be bombed
---@field weaponType number Weapon flag type to use for the attack
---@field expend string Quantity of weapons to expend (QUARTER, TWO, ONE, FOUR, HALF, ALL)
---@field attackQty number Number of times the group will attack the target
---@field attackQtyLimit boolean Whether to use the attackQty parameter
---@field direction number If provided the AI will attack from this azimuth and ignore bombing along the length of the runway
---@field groupAttack boolean If true then each aircraft in the group will attack the runway

--- Defines the structure of a Lua table detailing configuration options for a group attack mission.
--- (Data structure definition for TaskAttackGroupParams. Not a globally accessible table.)
---@class TaskAttackGroupParams
---@field groupId number Unique ID of the group to attack.
---@field weaponType number Weapon flag type to use for the attack.
---@field expend string Quantity of weapons to expend during the attack (QUARTER, TWO, ONE, FOUR, HALF, ALL).
---@field directionEnabled boolean Determines whether to use the specified direction for attack.
---@field direction number Attack direction in radians, defining the approach vector.
---@field altitudeEnabled boolean Determines whether to use the specified altitude for attack.
---@field altitude number Attack altitude in meters.
---@field attackQtyLimit boolean Determines whether to use the attackQty parameter as a limit.
---@field attackQty number Number of attack passes the group will perform on the target.

TaskId = TaskId or {}
--- Enumerator for task identifiers used to assign specific behaviors to Controller entities in the DCS World.
---@enum TaskId
TaskId = {
    TaskAttackGroup = "AttackGroup",
    TaskAttackUnit = "AttackUnit",
    TaskBombing = "Bombing",
    TaskStrafing = "Strafing",
    TaskCarpetBombing = "CarpetBombing",
    TaskAttackMapObject = "AttackMapObject",
    TaskBombingRunway = "BombingRunway",
    TaskOrbit = "orbit",
    TaskRefueling = "refueling",
    TaskLand = "land",
    TaskFollow = "follow",
    TaskFollowBigFormation = "followBigFormation",
    TaskEscort = "escort",
    TaskEmbarking = "Embarking",
    TaskFireAtPoint = "fireAtPoint",
    TaskHold = "hold",
    TaskFACAttackGroup = "FAC_AttackGroup",
    TaskEmbarkToTransport = "EmbarkToTransport",
    TaskDisembarkFromTransport = "DisembarkFromTransport",
    TaskCargoTransportation = "CargoTransportation",
    TaskGoToWaypoint = "goToWaypoint",
    TaskGroundEscort = "groundEscort",
    TaskRecoveryTanker = "RecoveryTanker"
}

--- Defines the structure of a Lua table containing the action that will be executed as a task.
--- (Data structure definition for WrappedActionParams. Not a globally accessible table.)
---@class WrappedActionParams
---@field action table The command or action object to be executed as a task.

--- Defines the structure of a Lua table detailing conditions that must be met for a task to start.
--- (Data structure definition for ControlledTaskCondition. Not a globally accessible table.)
---@class ControlledTaskCondition
---@field time number Time in seconds since mission start when the task should begin.
---@field userFlag string Flag identifier to check for task activation.
---@field userFlagValue boolean Required value of the user flag to activate the task.
---@field probability number Probability (0-100) that the task will execute when conditions are met.

--- Defines the structure of a Lua table detailing conditions that will trigger task termination.
--- (Data structure definition for ControlledTaskStopCondition. Not a globally accessible table.)
---@class ControlledTaskStopCondition
---@field time number Time in seconds since mission start when the task should terminate.
---@field userFlag string Flag identifier to check for task termination.
---@field userFlagValue boolean Required value of the user flag to terminate the task.
---@field duration number Duration in seconds that the task will run before terminating.
---@field lastWaypoint number Waypoint number that, when reached, will terminate the task.

--- Defines the structure of a Lua table containing an ordered sequence of waypoints that form a route.
--- (Data structure definition for MissionRoute. Not a globally accessible table.)
---@class MissionRoute
---@field points table A numerically indexed table of waypoint objects that define the mission route.

--- Defines the structure of a Lua table representing a single navigation point within a mission route.
--- (Data structure definition for MissionWaypoint. Not a globally accessible table.)
---@class MissionWaypoint
---@field _type string Waypoint type identifier (e.g., 'TakeOff', 'Land', 'Turning Point').
---@field airdromeId number Unique identifier of the airdrome for takeoff or landing waypoints.
---@field timeReFuAr number Time in minutes allocated for refueling and rearming at an airdrome.
---@field helipadId number Unique identifier of the helipad for helicopter operations.
---@field linkUnit number Unique identifier of the linked unit (same as helipadId but required for certain operations).
---@field action string Turn method the aircraft will use when approaching this waypoint.
---@field x number X coordinate of the waypoint in the DCS World coordinate system.
---@field y number Y coordinate of the waypoint in the DCS World coordinate system.
---@field alt number Altitude of the waypoint in meters.
---@field alt_type string Altitude measurement reference ('RADIO' for AGL, 'BARO' for MSL).
---@field speed number Speed in meters per second the aircraft will maintain at this waypoint.
---@field speed_locked boolean Determines whether the speed value is fixed and cannot be optimized by AI.
---@field ETA number Estimated time of arrival at the waypoint in seconds from mission start.
---@field ETA_locked boolean Determines whether the ETA value is fixed and AI must adjust speed to meet it.
---@field name string Descriptive name of the waypoint for identification purposes.
---@field task table Task to be performed when the aircraft reaches this waypoint.

--- Defines the structure of a Lua table detailing the collection of tasks to be executed as part of a combination.
--- (Data structure definition for ComboTaskParams. Not a globally accessible table.)
---@class ComboTaskParams
---@field tasks table A numerically indexed table of task objects to be executed.

LiquidType = LiquidType or {}
--- Enumerator for liquid fuel types, used to specify particular fuels within a `Warehouse` inventory.
---@enum LiquidType
LiquidType = {
    jetfuel = 0,
    Aviation_gasoline = 1,
    MW50 = 2,
    Diesel = 3
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

world.BirthPlace = world.BirthPlace or {}
--- Enumerator for aircraft and helicopter spawn locations, used in birth events.
---@enum world.BirthPlace
world.BirthPlace = {
    wsBirthPlace_Air = 1,
    wsBirthPlace_RunWay = 4,
    wsBirthPlace_Park = 5,
    wsBirthPlace_Heliport_Hot = 9,
    wsBirthPlace_Heliport_Cold = 10,
    wsBirthPlace_Ship = 3,
    wsBirthPlace_Ship_Hot = 12,
    wsBirthPlace_Ship_Cold = 11
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
---@version 1.2.0
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
    S_EVENT_MAX = 61
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

Spot.Category = Spot.Category or {}
--- Defines the types of targeting beams available in the DCS World environment.
---@enum Spot.Category
Spot.Category = {
    INFRA_RED = 0,
    LASER = 1
}

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
---@field Term_Type number Terminal type identifier.
---@field Term_Index number Terminal index number.
---@field Term_Index_0 number Alternative terminal index.
---@field Term_Details table Additional details about the terminal.

--- Detailed information about an airbase.
--- (Data structure definition for AirbaseDesc. Not a globally accessible table.)
---@class AirbaseDesc
---@field category number Category identifier of the airbase.
---@field id number Unique identifier for the airbase.
---@field callsign string Radio callsign of the airbase.
---@field display_name string Human-readable name of the airbase.

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

--- Defines the structure of a Lua table containing information about a player-controllable slot in a mission, including its unit ID, type, role, and other identifying data.
--- (Data structure definition for DCSAvailableSlotInfo. Not a globally accessible table.)
---@version 1.2.0
---@class DCSAvailableSlotInfo

--- Represents all Objects those may belong to a coalition: units, airbases, static objects, weapon. Non-final class.
--- (Data structure definition for CoalitionObject. Not a globally accessible table.)
---@version 1.2.4
---@class CoalitionObject
---@field getCoalition fun(...) Returns an enumerator that defines the coalition that an object currently belongs to.
---@field getCountry fun(...) Returns an enumerator that defines the country that an object currently belongs to.

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

--- Defines the structure of a table containing attribute flags for an object. Each field is a boolean indicating whether the object has that specific attribute.
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

--- Defines the structure of a Lua table containing parameters for the beacon activation command.
--- (Data structure definition for CommandActivateBeaconParams. Not a globally accessible table.)
---@class CommandActivateBeaconParams
---@field _type BeaconType Beacon type identifier determining its functional characteristics.
---@field system BeaconSystemName Navigation system that will process the beacon signal.
---@field frequency number Broadcast frequency in Hertz for the navigation beacon.
---@field callsign string Morse code identifier transmitted by the beacon for identification.
---@field name string Descriptive name for the beacon shown in the mission editor interface.

--- Information about an airbase runway.
--- (Data structure definition for AirbaseRunway. Not a globally accessible table.)
---@class AirbaseRunway
---@field course number Runway heading in degrees.
---@field name string Runway identifier.
---@field position Vec3 Runway position in world coordinates.
---@field width number Runway width in meters.
---@field length number Runway length in meters.

--- Defines the structure of a Lua table representing a 3D bounding box in the DCS World coordinate system, specified by minimum and maximum corner points.
--- (Data structure definition for Box3. Not a globally accessible table.)
---@class Box3
---@field min Vec3 A `Vec3` representing the minimum corner point (lowest x, y, z values) of the bounding box in the DCS World coordinate system.
---@field max Vec3 A `Vec3` representing the maximum corner point (highest x, y, z values) of the bounding box in the DCS World coordinate system.

--- Base cargo object used in cargo-related events.
--- (Data structure definition for Cargo. Not a globally accessible table.)
---@class Cargo
---@field mass number Mass of the cargo in kilograms.
---@field position Vec3 A `Vec3` representing the cargo's current position in the DCS World coordinate system.
---@field displayName string The human-readable name of the cargo shown in mission interfaces and logs.
---@field id number Unique identifier of the cargo.
---@field name string Name of the cargo.

--- Dynamic cargo object that can be moved during mission.
--- (Data structure definition for DynamicCargo. Not a globally accessible table.)
---@class DynamicCargo
---@field id number Unique identifier of the dynamic cargo.
---@field name string Name of the dynamic cargo.
---@field _type string The type classification of cargo, determining its visual model and behavior properties.
---@field mass number Mass of the dynamic cargo in kilograms.
---@field position Vec3 Current 3D position of the cargo.

--- Defines the structure of a Lua table representing both position and orientation in the DCS World coordinate system.
--- (Data structure definition for Position3. Not a globally accessible table.)
---@class Position3
---@field p Vec3 A `Vec3` representing the object's position in the DCS World coordinate system.
---@field x Vec3 A normalized `Vec3` representing the object's forward direction vector in the DCS World coordinate system.
---@field y Vec3 A normalized `Vec3` representing the object's upward direction vector in the DCS World coordinate system.
---@field z Vec3 A normalized `Vec3` representing the object's rightward direction vector in the DCS World coordinate system.

--- Defines the structure of a Lua table representing a reference point used by Joint Terminal Attack Controllers (JTACs) and other mission elements for targeting and navigation.
--- (Data structure definition for RefPoint. Not a globally accessible table.)
---@version 1.2.0
---@class RefPoint
---@field callsign string A string identifier serving as the callsign or designation for the reference point.
---@field _type number A numeric identifier categorizing the reference point's purpose or classification.
---@field point Vec3 A `Vec3` representing the precise 3D position of the reference point in the DCS World coordinate system.

--- Represents a numerically indexed Lua table (sequence) of `Vec3` points in the DCS World coordinate system.
---@alias Vec3Array Vec3[]

--- Defines the structure of a Lua table representing the destructive component specifications of a weapon's payload.
--- (Data structure definition for WeaponWarheadDetails. Not a globally accessible table.)
---@class WeaponWarheadDetails
---@field _type Weapon.WarheadType A `Weapon.WarheadType` enumerator specifying the primary damage mechanism of the warhead.
---@field mass number A numeric value representing the total mass of the warhead in kilograms.
---@field caliber number A numeric value representing the diameter of the warhead in millimeters.
---@field explosiveMass number A numeric value representing the mass of high explosive material in kilograms, relevant for HE and AP+HE warheads.
---@field shapedExplosiveMass number A numeric value representing the mass of shaped charge explosive material in kilograms, relevant for shaped explosive warheads.
---@field shapedExplosiveArmorThickness number A numeric value representing the maximum armor penetration capability in millimeters of rolled homogeneous armor equivalent.

--- Parameters for the AttackMapObject task
--- (Data structure definition for TaskAttackMapObjectParams. Not a globally accessible table.)
---@class TaskAttackMapObjectParams
---@field point Vec2 Vec2 coordinate of the target point
---@field x number X coordinate of the target (alternative to point)
---@field y number Y coordinate of the target (alternative to point)
---@field weaponType number Weapon flag type to use for the attack
---@field expend string Quantity of weapons to expend (QUARTER, TWO, ONE, FOUR, HALF, ALL)
---@field attackQty number Number of times the group will attack if the target
---@field attackQtyLimit boolean If true the attackQty value will be followed
---@field direction number Attack direction in radians
---@field groupAttack boolean If true then each aircraft in the group will attack the target

--- Parameters for the Bombing task
--- (Data structure definition for TaskBombingParams. Not a globally accessible table.)
---@class TaskBombingParams
---@field point Vec2 Vec2 coordinate of the target
---@field x number X coordinate of the target (alternative to point)
---@field y number Y coordinate of the target (alternative to point)
---@field weaponType number Weapon flag type to use for the attack
---@field expend string Quantity of weapons to expend (QUARTER, TWO, ONE, FOUR, HALF, ALL)
---@field attackQty number Number of times the group will attack the target
---@field attackQtyLimit boolean Whether to use the attackQty parameter
---@field direction number Attack direction in radians
---@field groupAttack boolean If true then each aircraft in the group will attack the point
---@field altitude number Altitude in meters for the attack
---@field altitudeEnabled boolean Whether to use the altitude parameter
---@field attackType string Attack profile to use (e.g. 'Dive' for dive bombing)

--- Parameters for the CarpetBombing task
--- (Data structure definition for TaskCarpetBombingParams. Not a globally accessible table.)
---@class TaskCarpetBombingParams
---@field attackType string Type of attack, typically 'Carpet'
---@field carpetLength number Distance in meters the pattern should cover
---@field point Vec2 Vec2 coordinate of the target
---@field x number X coordinate of the target (alternative to point)
---@field y number Y coordinate of the target (alternative to point)
---@field weaponType number Weapon flag type to use for the attack
---@field expend string Quantity of weapons to expend (QUARTER, TWO, ONE, FOUR, HALF, ALL)
---@field attackQty number Number of times the group will attack the target
---@field attackQtyLimit boolean Whether to use the attackQty parameter
---@field groupAttack boolean If true then each aircraft in the group will attack the point
---@field altitude number Altitude in meters for the attack
---@field altitudeEnabled boolean Whether to use the altitude parameter

--- Defines the structure of a Lua table containing parameters for the engageTargetsInZone task.
--- (Data structure definition for TaskEnRouteEngageTargetsInZoneParams. Not a globally accessible table.)
---@class TaskEnRouteEngageTargetsInZoneParams
---@field point Vec2 A `Vec2` point defining the center of the area the group will engage targets within in the DCS World coordinate system.
---@field zoneRadius number Radius in meters defining the size of the area the group will engage targets within.
---@field targetTypes table Table of attribute names that define valid targets.
---@field priority number The priority of the tasking, where lower numbers indicate higher importance (default: 0).

--- Parameters for the fireAtPoint task
--- (Data structure definition for TaskFireAtPointParams. Not a globally accessible table.)
---@class TaskFireAtPointParams
---@field point Vec2 Vec2 coordinate to define where the AI will aim
---@field x number X coordinate of the target (alternative to point)
---@field y number Y coordinate of the target (alternative to point)
---@field radius number Optional radius in meters that defines the area AI will attempt to hit
---@field expendQty number Specifies number of shots to be fired
---@field expendQtyEnabled boolean Whether or not expendQty will be used
---@field weaponType number Weapon flag type to use for the attack
---@field altitude number If present the task will be focused on shooting at the specified altitude for the point
---@field alt_type number Determines if the altitude is defined by AGL (1) or MSL (0)
---@field counterbattaryRadius number The radius in meters from the group leader that the group will move in random directions after completing the fireAtPoint task

--- Defines the structure of a Lua table detailing configuration options for a helicopter landing operation.
--- (Data structure definition for TaskLandParams. Not a globally accessible table.)
---@class TaskLandParams
---@field point Vec2 A `Vec2` representing the landing coordinates in the DCS World coordinate system where the helicopter will attempt to touch down.
---@field durationFlag boolean Determines whether the helicopter will remain on the ground for a specific duration before taking off again.
---@field duration number Time in seconds that the helicopter will remain landed before automatically taking off if durationFlag is true.

--- Defines the structure of a Lua table detailing configuration options for aircraft orbit patterns and behavior.
--- (Data structure definition for TaskOrbitParams. Not a globally accessible table.)
---@class TaskOrbitParams
---@field pattern string Type of orbit pattern the AI will execute (RACE_TRACK, CIRCLE, Anchored).
---@field point Vec2 A `Vec2` representing the primary orbit point in the DCS World coordinate system.
---@field point2 Vec2 A `Vec2` representing the secondary point for a Race-Track orbit pattern in the DCS World coordinate system.
---@field speed number Speed in meters per second the AI will maintain during the orbit pattern.
---@field altitude number Altitude in meters the AI will maintain during the orbit.
---@field hotLegDir number Heading in radians that the aircraft will fly for the return leg of the anchored orbit pattern.
---@field legLength number Distance in meters that the aircraft will fly before turning in an anchored orbit pattern.
---@field width number Distance in meters that represents the diameter of the anchored orbit pattern.
---@field clockWise boolean Determines whether the anchored orbit will fly clockwise (true) or anti-clockwise (false).

--- Defines the structure of a Lua table detailing configuration options for a strafing attack mission.
--- (Data structure definition for TaskStrafingParams. Not a globally accessible table.)
---@class TaskStrafingParams
---@field point Vec2 A `Vec2` representing the target coordinates in the DCS World coordinate system.
---@field x number X coordinate of the target (alternative to using the point field).
---@field y number Y coordinate of the target (alternative to using the point field).
---@field weaponType number Weapon flag type to use for the attack.
---@field expend string Quantity of weapons to expend during the attack (QUARTER, TWO, ONE, FOUR, HALF, ALL).
---@field attackQty number Number of attack passes the group will perform on the target.
---@field attackQtyLimit boolean Determines whether to use the attackQty parameter as a limit.
---@field direction number Attack direction in radians, defining the approach vector.
---@field directionEnabled boolean Determines whether to use the specified direction for attack.
---@field groupAttack boolean Determines whether each aircraft in the group will attack individually (true) or as a coordinated unit (false).
---@field length number Total length of the strafing target area in meters.

--- Represents a numerically indexed Lua table (sequence) of `Vec2` points in the DCS World coordinate system.
---@alias Vec2Array Vec2[]

--- Defines the structure of a Lua table containing parameters for the FAC_EngageGroup task.
--- (Data structure definition for TaskEnRouteFACEngageGroupParams. Not a globally accessible table.)
---@class TaskEnRouteFACEngageGroupParams
---@field groupId number ID of the group that is to be assigned by JTAC.
---@field weaponType number Weapon flag type that defines the preferred weapon of choice.
---@field designation string Type of designation to be used (NO, WP, IR_POINTER, LASER, AUTO).
---@field datalink boolean Determines whether the JTAC will send the 9-line via SADL, enabled by default.
---@field frequency number Radio frequency to use for the JTAC communications.
---@field modulation number Radio modulation type for JTAC communications.
---@field callname Callsigns_JTAC JTAC callsign identifier (Axeman, Darknight, etc.).
---@field number number JTAC callsign number.
---@field priority number The priority of the tasking, where lower numbers indicate higher importance (default: 0).

--- Defines the structure of a Lua table containing parameters for the FAC task.
--- (Data structure definition for TaskEnRouteFACParams. Not a globally accessible table.)
---@class TaskEnRouteFACParams
---@field frequency number Radio frequency to use for the JTAC communications.
---@field modulation number Radio modulation type for JTAC communications.
---@field callname Callsigns_JTAC JTAC callsign identifier (Axeman, Darknight, etc.).
---@field number number JTAC callsign number.
---@field priority number The priority of the tasking, where lower numbers indicate higher importance (default: 0).

--- Parameters for the FAC_AttackGroup task
--- (Data structure definition for TaskFACAttackGroupParams. Not a globally accessible table.)
---@class TaskFACAttackGroupParams
---@field groupId number ID of the group that is to be assigned by JTAC
---@field weaponType number Weapon flag type that defines the preferred weapon of choice
---@field designation string Type of designation to be used (NO, WP, IR_POINTER, LASER, AUTO)
---@field datalink boolean Determines whether or not the JTAC will send the 9-line via SADL, enabled by default
---@field frequency number Radio frequency to use for the JTAC
---@field modulation number Radio modulation type
---@field callname Callsigns_JTAC JTAC callsign identifier (Axeman, Darknight, etc.)
---@field number number JTAC callsign number

--- Defines the structure of a Lua table representing common properties specific to both airplane and helicopter units in the DCS World. Includes all fields from UnitDesc plus the following aircraft-specific fields.
--- (Data structure definition for UnitDescAircraft. Not a globally accessible table.)
---@class UnitDescAircraft
---@field fuelMassMax number A numeric value representing the maximum internal fuel capacity in kilograms.
---@field range number A numeric value representing the maximum operational range in meters at standard cruise settings.
---@field Hmax number A numeric value representing the service ceiling (maximum operational altitude) in meters.
---@field VyMax number A numeric value representing the maximum rate of climb in meters per second.
---@field NyMin number A numeric value representing the minimum safe negative G-load limit.
---@field NyMax number A numeric value representing the maximum safe positive G-load limit.
---@field tankerType Unit.RefuelingSystem An `Unit.RefuelingSystem` enumerator specifying the aerial refueling system installed, if any.

--- Defines the structure of a Lua table representing a sensor's air target detection capabilities in different hemispheres.
--- (Data structure definition for UnitSensorDetectionDistanceAir. Not a globally accessible table.)
---@class UnitSensorDetectionDistanceAir
---@field upperHemisphere UnitSensorHemisphereDistance A table representing detection distances for targets positioned above the sensor's horizontal plane.
---@field lowerHemisphere UnitSensorHemisphereDistance A table representing detection distances for targets positioned below the sensor's horizontal plane.

--- Defines the structure of a Lua table detailing configuration options for helicopter escort operations above ground forces.
--- (Data structure definition for TaskGroundEscortParams. Not a globally accessible table.)
---@class TaskGroundEscortParams
---@field groupId number Unique ID of the ground group to escort and protect.
---@field engagementDistMax number Maximum distance in meters defining the size/length of the orbit pattern before the helicopter returns to the escorted group.
---@field lastWptIndexFlag boolean Determines whether the helicopter will follow the ground group until it reaches a specified waypoint.
---@field lastWptIndex number Waypoint index at which the escorting helicopter will terminate its escort task.
---@field targetTypes Attributes[] A numerically indexed table of `Attributes` defining which enemy unit types the escorting helicopter will engage.
---@field lastWptIndexFlagChangedManually boolean Indicates whether the lastWptIndexFlag was manually configured rather than using system defaults.

--- Union type of all option identifier enumerators used across different AI unit types.
---@version 1.2.0
---@alias AIOptionId AI.Option.Air.id|AI.Option.Ground.id|AI.Option.Naval.id

--- Parameters for the escort task
--- (Data structure definition for TaskEscortParams. Not a globally accessible table.)
---@class TaskEscortParams
---@field groupId number Unique ID of the group to escort
---@field pos Vec3 Vec3 point defining the relative position the controlled flight will form up on
---@field formation FormationType Formation pattern to use when escorting the group. Use AircraftFormationType for fixed-wing aircraft or HelicopterFormationType for helicopters.
---@field lastWptIndexFlag boolean If true the AI will follow the group until it reaches a specified waypoint (default: true)
---@field lastWptIndex number Identifies the waypoint at which the following group will stop its task (default: -1)
---@field engagementDistMax number Maximum distance of targets from the followed aircraft that the AI will actively engage
---@field targetTypes Attributes[] Array of attribute types which the AI will engage

--- Defines the structure of a Lua table detailing configuration options for large-scale formation flying between aircraft groups.
--- (Data structure definition for TaskFollowBigFormationParams. Not a globally accessible table.)
---@class TaskFollowBigFormationParams
---@field groupId number Unique ID of the lead aircraft group to follow.
---@field pos Vec3 A `Vec3` representing the relative position the controlled flight will maintain within the formation in the DCS World coordinate system.
---@field formation FormationType Formation pattern to use when following the group, must match aircraft type (fixed-wing or helicopter).
---@field lastWptIndexFlag boolean Determines whether the AI will terminate the follow task when the lead group reaches a specified waypoint.
---@field lastWptIndex number Waypoint index of the lead group that, when reached, will cause the following aircraft to terminate the task.

--- Defines the structure of a Lua table detailing configuration options for formation flying between aircraft groups.
--- (Data structure definition for TaskFollowParams. Not a globally accessible table.)
---@class TaskFollowParams
---@field groupId number Unique ID of the group to follow or orbit above if it's a ground unit.
---@field pos Vec3 A `Vec3` representing the relative position the controlled flight will maintain within the formation in the DCS World coordinate system.
---@field formation FormationType Formation pattern to use when following the group, must match aircraft type (fixed-wing or helicopter).
---@field lastWptIndexFlag boolean Determines whether the AI will terminate the follow task when the lead group reaches a specified waypoint.
---@field lastWptIndex number Waypoint index of the lead group that, when reached, will cause the following aircraft to terminate the task.

--- Defines the structure of a command that activates an Instrument Carrier Landing System (ICLS) beacon for aircraft carriers.
--- (Data structure definition for CommandActivateICLS. Not a globally accessible table.)
---@class CommandActivateICLS
---@field id string Command identifier that must be 'ActivateICLS'.
---@field params CommandActivateICLSParams

--- Defines the structure of a command that toggles a group's visibility to enemy AI sensors.
--- (Data structure definition for CommandSetInvisible. Not a globally accessible table.)
---@class CommandSetInvisible
---@field id string Command identifier that must be 'setInvisible'.
---@field params CommandSetInvisibleParams

--- Defines the structure of a command that activates a Link 4 data link system for aircraft carrier operations.
--- (Data structure definition for CommandActivateLink4. Not a globally accessible table.)
---@class CommandActivateLink4
---@field id string Command identifier that must be 'ActivateLink4'.
---@field params CommandActivateLink4Params

--- Defines the structure of a command that toggles the Enhanced Position Location Reporting System (EPLRS) data link capabilities for a unit or group.
--- (Data structure definition for CommandEPLRS. Not a globally accessible table.)
---@class CommandEPLRS
---@field id string Command identifier that must be 'EPLRS'.
---@field params CommandEPLRSParams

--- Defines the structure of a command that changes a group's identification callsign for radio communications.
--- (Data structure definition for CommandSetCallsign. Not a globally accessible table.)
---@class CommandSetCallsign
---@field id string Command identifier that must be 'SetCallsign'.
---@field params CommandSetCallsignParams

--- Defines the structure of a command that toggles infinite fuel supply for a unit or group.
--- (Data structure definition for CommandSetUnlimitedFuel. Not a globally accessible table.)
---@class CommandSetUnlimitedFuel
---@field id string Command identifier that must be 'setUnlimitedFuel'.
---@field params CommandSetUnlimitedFuelParams

--- Defines the structure of a command that deactivates any active radio navigation beacon on a unit or group.
--- (Data structure definition for CommandDeactivateBeacon. Not a globally accessible table.)
---@class CommandDeactivateBeacon
---@field id string Command identifier that must be 'DeactivateBeacon'.
---@field params CommandDeactivateBeaconParams

--- Defines the structure of a command that activates an Automatic Carrier Landing System (ACLS) on an aircraft carrier.
--- (Data structure definition for CommandActivateACLS. Not a globally accessible table.)
---@class CommandActivateACLS
---@field id string Command identifier that must be 'ActivateACLS'.
---@field params CommandActivateACLSParams

--- Defines the structure of a command that changes the active route leg for a group, allowing control of navigation between waypoints.
--- (Data structure definition for CommandSwitchWaypoint. Not a globally accessible table.)
---@class CommandSwitchWaypoint
---@field id string Command identifier that must be 'SwitchWaypoint'.
---@field params CommandSwitchWaypointParams

--- Defines the structure of a command that executes a Lua script within the context of a group, providing access to the group through the '...' self-reference.
--- (Data structure definition for CommandScript. Not a globally accessible table.)
---@class CommandScript
---@field id string Command identifier that must be 'Script'.
---@field params CommandScriptParams

--- Defines the structure of a command that toggles a group's invulnerability to all damage.
--- (Data structure definition for CommandSetImmortal. Not a globally accessible table.)
---@class CommandSetImmortal
---@field id string Command identifier that must be 'setImmortal'.
---@field params CommandSetImmortalParams

--- Defines the structure of a command that adjusts a ship's cargo loading level, affecting its buoyancy and water line position.
--- (Data structure definition for CommandLoadingShip. Not a globally accessible table.)
---@class CommandLoadingShip
---@field id string Command identifier that must be 'LoadingShip'.
---@field params CommandLoadingShipParams

--- Defines the structure of a command that changes the radio broadcasting frequency for an AI group.
--- (Data structure definition for CommandSetFrequency. Not a globally accessible table.)
---@class CommandSetFrequency
---@field id string Command identifier that must be 'SetFrequency'.
---@field params CommandSetFrequencyParams

--- Defines the structure of a command that terminates any active radio message transmission from a unit or group.
--- (Data structure definition for CommandStopTransmission. Not a globally accessible table.)
---@class CommandStopTransmission
---@field id string Command identifier that must be 'stopTransmission'.
---@field params CommandStopTransmissionParams

--- Defines the structure of a command that activates an initially inactive group, triggering AI units to follow their designated route.
--- (Data structure definition for CommandStart. Not a globally accessible table.)
---@class CommandStart
---@field id string Command identifier that must be 'start'.
---@field params CommandStartParams

--- Defines the structure of a command that changes the active task action within a mission group's task queue.
--- (Data structure definition for CommandSwitchAction. Not a globally accessible table.)
---@class CommandSwitchAction
---@field id string Command identifier that must be 'SwitchAction'.
---@field params CommandSwitchActionParams

--- Defines the structure of a command that deactivates any active Automatic Carrier Landing System (ACLS) on a unit or group.
--- (Data structure definition for CommandDeactivateACLS. Not a globally accessible table.)
---@class CommandDeactivateACLS
---@field id string Command identifier that must be 'DeactivateACLS'.
---@field params CommandDeactivateACLSParams

--- Defines the structure of a command that deactivates any active Link 4 data link system on a unit or group.
--- (Data structure definition for CommandDeactivateLink4. Not a globally accessible table.)
---@class CommandDeactivateLink4
---@field id string Command identifier that must be 'DeactivateLink4'.
---@field params CommandDeactivateLink4Params

--- Defines the structure of a command that halts or resumes a ground group's movement along its route.
--- (Data structure definition for CommandStopRoute. Not a globally accessible table.)
---@class CommandStopRoute
---@field id string Command identifier that must be 'StopRoute'.
---@field params CommandStopRouteParams

--- Defines the structure of a command that changes the radio broadcasting frequency for a specific unit within an AI group.
--- (Data structure definition for CommandSetFrequencyForUnit. Not a globally accessible table.)
---@class CommandSetFrequencyForUnit
---@field id string Command identifier that must be 'SetFrequencyForUnit'.
---@field params CommandSetFrequencyForUnitParams

--- Defines the structure of a command that toggles aircraft smoke pod emission.
--- (Data structure definition for CommandSmokeOnOff. Not a globally accessible table.)
---@class CommandSmokeOnOff
---@field id string Command identifier that must be 'smoke_on_off'.
---@field params CommandSmokeOnOffParams

--- Defines the structure of a command that deactivates any active Instrument Carrier Landing System (ICLS) beacon on a unit or group.
--- (Data structure definition for CommandDeactivateICLS. Not a globally accessible table.)
---@class CommandDeactivateICLS
---@field id string Command identifier that must be 'DeactivateICLS'.
---@field params CommandDeactivateICLSParams

--- Defines the structure of a command that broadcasts an audio message over a unit or group's active radio frequency.
--- (Data structure definition for CommandTransmitMessage. Not a globally accessible table.)
---@class CommandTransmitMessage
---@field id string Command identifier that must be 'transmitMessage'.
---@field params CommandTransmitMessageParams

--- Defines the structure of a Lua table representing an en-route task that assigns the group to act as an EWR radar for friendly forces.
--- (Data structure definition for TaskEnRouteEWR. Not a globally accessible table.)
---@class TaskEnRouteEWR
---@field id string En-route task identifier, must be 'ewr'.
---@field params TaskEnRouteEWRParams

--- Defines the structure of a Lua table representing an en-route task that assigns the controlled group to search for and engage a specific group. The target must be detected for AI to engage it.
--- (Data structure definition for TaskEnRouteEngageGroup. Not a globally accessible table.)
---@class TaskEnRouteEngageGroup
---@field id string En-route task identifier, must be 'engageGroup'.
---@field params TaskEnRouteEngageGroupParams

--- Defines the structure of a Lua table representing an en-route task that assigns the aircraft to act as an airborne tanker for friendly forces. The aircraft must be a certified tanker aircraft.
--- (Data structure definition for TaskEnRouteTanker. Not a globally accessible table.)
---@class TaskEnRouteTanker
---@field id string En-route task identifier, must be 'tanker'.
---@field params TaskEnRouteTankerParams

--- Defines the structure of a Lua table representing an en-route task that assigns the controlled group to search for and engage a specific unit. The target must be detected for AI to engage it.
--- (Data structure definition for TaskEnRouteEngageUnit. Not a globally accessible table.)
---@class TaskEnRouteEngageUnit
---@field id string En-route task identifier, must be 'engageUnit'.
---@field params TaskEnRouteEngageUnitParams

--- Defines the structure of a Lua table representing an en-route task that assigns the aircraft to act as an AWACS for friendly forces.
--- (Data structure definition for TaskEnRouteAWACS. Not a globally accessible table.)
---@class TaskEnRouteAWACS
---@field id string En-route task identifier, must be 'awacs'.
---@field params TaskEnRouteAWACSParams

--- Defines the structure of a Lua table representing an en-route task that assigns the controlled group to engage targets matching specific parameters.
--- (Data structure definition for TaskEnRouteEngageTargets. Not a globally accessible table.)
---@class TaskEnRouteEngageTargets
---@field id string En-route task identifier, must be 'engageTargets'.
---@field params TaskEnRouteEngageTargetsParams

--- Defines the structure of a Lua table representing a hold task that commands ground forces to cease movement and maintain their current position.
--- (Data structure definition for TaskHold. Not a globally accessible table.)
---@class TaskHold
---@field id string Task identifier, must be 'hold'.
---@field params TaskHoldParams A table containing parameters for the hold task.

--- Defines the structure of a Lua table representing an attack task that directs a group to engage a specific unit.
--- (Data structure definition for TaskAttackUnit. Not a globally accessible table.)
---@class TaskAttackUnit
---@field id string Task identifier, must be 'AttackUnit'.
---@field params TaskAttackUnitParams A table containing parameters that configure the attack behavior.

--- Defines the structure of a Lua table representing a naval recovery tanker task that directs an aircraft to orbit above a vessel group, providing refueling services.
--- (Data structure definition for TaskRecoveryTanker. Not a globally accessible table.)
---@class TaskRecoveryTanker
---@field id string Task identifier, must be 'RecoveryTanker'.
---@field params TaskRecoveryTankerParams A table containing parameters that configure the recovery tanker behavior.

--- Defines the structure of a Lua table representing an air refueling task directing aircraft to seek and connect with the nearest available tanker.
--- (Data structure definition for TaskRefueling. Not a globally accessible table.)
---@class TaskRefueling
---@field id string Task identifier, must be 'refueling'.
---@field params TaskRefuelingParams A table containing parameters for the refueling task.

--- Assigns the AI a task to bomb an airbases runway. By default the AI will line up along the length of the runway and drop its payload.
--- (Data structure definition for TaskBombingRunway. Not a globally accessible table.)
---@class TaskBombingRunway
---@field id string Task identifier, must be 'BombingRunway'
---@field params TaskBombingRunwayParams

--- Defines the structure of a Lua table representing an attack task that directs a group to engage another group.
--- (Data structure definition for TaskAttackGroup. Not a globally accessible table.)
---@class TaskAttackGroup
---@field id string Task identifier, must be 'AttackGroup'.
---@field params TaskAttackGroupParams A table containing parameters that configure the attack behavior.

--- Defines the structure of a Lua table representing a wrapper that allows a command or action to be used as a task.
--- (Data structure definition for WrappedAction. Not a globally accessible table.)
---@class WrappedAction
---@field id string Task identifier, must be 'WrappedAction'.
---@field params WrappedActionParams A table containing the action to be wrapped as a task.

--- Defines the structure of a Lua table detailing configuration options for controlled task execution.
--- (Data structure definition for ControlledTaskParams. Not a globally accessible table.)
---@class ControlledTaskParams
---@field task table The task to be executed.
---@field condition ControlledTaskCondition A table specifying the conditions that must be met for the task to start.
---@field stopCondition ControlledTaskStopCondition A table specifying the conditions that will trigger task termination.

--- Defines the structure of a Lua table detailing mission execution parameters and route information.
--- (Data structure definition for MissionParams. Not a globally accessible table.)
---@class MissionParams
---@field airborne boolean Indicates whether the aircraft group is already airborne when the mission is assigned.
---@field route MissionRoute A table containing the route waypoints to be followed during the mission.

--- Defines the structure of a Lua table representing a composite task that combines multiple tasks to be executed sequentially or in parallel.
--- (Data structure definition for ComboTask. Not a globally accessible table.)
---@class ComboTask
---@field id string Task identifier, must be 'ComboTask'.
---@field params ComboTaskParams A table containing parameters that define the tasks to be combined.

--- Trigger zone used in mission editor and referenced in zone-related events.
--- (Data structure definition for Zone. Not a globally accessible table.)
---@class Zone
---@field id number Unique identifier of the zone.
---@field name string Name of the zone as defined in the mission editor.
---@field position Vec3 3D position of the zone's center.
---@field radius number Radius of the zone in meters.
---@field coalition coalition.side|nil The `coalition.side` value indicating which faction owns or controls the zone, or `nil` if not coalition-specific.

--- Represents a numerically indexed table of `Object.Category` enum values.
---@alias ObjectCategoryArray Object.Category[]

--- Defines the structure of a command that activates a radio navigation beacon on a unit or group.
--- (Data structure definition for CommandActivateBeacon. Not a globally accessible table.)
---@class CommandActivateBeacon
---@field id string Command identifier that must be 'ActivateBeacon'.
---@field params CommandActivateBeaconParams

--- Defines the structure of a Lua table representing a scenery object's properties and physical characteristics in the DCS World.
--- (Data structure definition for SceneryObjectDesc. Not a globally accessible table.)
---@class SceneryObjectDesc
---@field life number A numeric value representing the initial health or integrity level of the scenery object.
---@field box Box3 A box (two Vec3 points) representing the three-dimensional collision boundaries of the scenery object in the DCS World coordinate system.
---@field category Object.Category An `Object.Category` enumerator representing the category of the scenery object.
---@field categoryEx Weapon.Category A `Weapon.Category` enumerator representing the subcategory of the scenery object.

--- Defines the structure of a Lua table representing a static object's properties and physical characteristics in the DCS World.
--- (Data structure definition for StaticObjectDesc. Not a globally accessible table.)
---@class StaticObjectDesc
---@field life number A numeric value representing the initial health or integrity level of the static object.
---@field box Box3 A box (two Vec3 points) representing the three-dimensional collision boundaries of the static object in the DCS World coordinate system.

--- Defines the structure of a Lua table representing the basic properties and capabilities common to all unit types in the DCS World.
--- (Data structure definition for UnitDesc. Not a globally accessible table.)
---@class UnitDesc
---@field typeName string A string containing the internal identifier for the unit type used by the DCS World engine.
---@field displayName string A string containing the human-readable name of the unit as shown in the DCS World interface.
---@field category Unit.Category An `Unit.Category` enumerator specifying the basic classification of the unit.
---@field massEmpty number A numeric value representing the unit's empty weight in kilograms.
---@field speedMax number A numeric value representing the unit's maximum speed in meters per second.
---@field life number A numeric value representing the unit's total health or structural integrity.
---@field RCS nil|number A numeric value representing the unit's radar cross-section signature.
---@field box Box3|nil A box (two Vec3 points) representing the unit's physical dimensions in the DCS World coordinate system.
---@field attributes UnitAttributes A table defining special characteristics and capabilities of the unit.
---@field Kmax nil|number A numeric coefficient related to the unit's performance characteristics.
---@field Kab nil|number A numeric coefficient related to afterburner performance for aircraft.

--- Defines the structure of a Lua table representing a circular area used for spatial trigger conditions in the DCS World.
--- (Data structure definition for TriggerZoneCircular. Not a globally accessible table.)
---@class TriggerZoneCircular
---@field position Position3 A `Position3` representing the center point and orientation of the trigger zone in the DCS World coordinate system.
---@field radius number A numeric value defining the radius of the circular trigger zone in meters.

--- Defines the structure of a Lua table representing the specifications and capabilities of a weapon or ammunition type available to a unit.
--- (Data structure definition for UnitAmmoDesc. Not a globally accessible table.)
---@class UnitAmmoDesc
---@field missileCategory Weapon.MissileCategory|nil
---@field rangeMaxAltMax nil|number A numeric value representing the maximum weapon range in meters when fired at maximum altitude.
---@field rangeMin nil|number A numeric value representing the minimum effective range of the weapon in meters.
---@field displayName string A string containing the human-readable name of the weapon as displayed in the DCS World interface.
---@field rangeMaxAltMin nil|number A numeric value representing the maximum weapon range in meters when fired at minimum altitude.
---@field altMax nil|number A numeric value representing the maximum altitude in meters at which the weapon can be effectively used.
---@field RCS Box3|nil A `Box3` representing the radar cross-section characteristics of the weapon.
---@field box Box3|nil A box (two Vec3 points) representing the physical dimensions of the weapon in the DCS World coordinate system.
---@field altMin nil|number A numeric value representing the minimum altitude in meters at which the weapon can be effectively used.
---@field life nil|number A numeric value representing the weapon's health or structural integrity.
---@field fuseDist nil|number A numeric value representing the distance in meters at which the weapon's fuse activates.
---@field category Weapon.Category|nil
---@field guidance Weapon.GuidanceType|nil
---@field warhead WeaponWarheadDetails|nil
---@field typeName string A string containing the internal type identifier for the weapon.
---@field Nmax nil|number A numeric value representing the maximum G-load the weapon can withstand.

--- Defines the structure of a Lua table representing the basic properties common to all weapon types in the DCS World.
--- (Data structure definition for WeaponDesc. Not a globally accessible table.)
---@class WeaponDesc
---@field life number A numeric value representing the weapon's total health or structural integrity.
---@field box Box3 A box (two Vec3 points) representing the physical dimensions of the weapon in the DCS World coordinate system.
---@field category Weapon.Category A `Weapon.Category` enumerator specifying the fundamental classification of the weapon.
---@field warhead WeaponWarheadDetails A table representing the specifications of the weapon's destructive payload component.

--- Defines the structure of a Lua table representing the properties and capabilities of air-dropped bomb weapons in the DCS World.
--- (Data structure definition for WeaponDescBomb. Not a globally accessible table.)
---@class WeaponDescBomb
---@field life number A numeric value representing the bomb's total health or structural integrity.
---@field box Box3 A box (two Vec3 points) representing the physical dimensions of the bomb in the DCS World coordinate system.
---@field category Weapon.Category A `Weapon.Category` enumerator specifying the fundamental classification of the bomb.
---@field warhead WeaponWarheadDetails A table representing the specifications of the bomb's destructive payload component.
---@field guidance Weapon.GuidanceType A `Weapon.GuidanceType` enumerator specifying the bomb's targeting and course correction technology, if applicable.
---@field altMin number A numeric value representing the minimum effective release altitude in meters.
---@field altMax number A numeric value representing the maximum effective release altitude in meters.

--- Defines the structure of a Lua table representing the properties and capabilities of missile weapons in the DCS World.
--- (Data structure definition for WeaponDescMissile. Not a globally accessible table.)
---@class WeaponDescMissile
---@field life number A numeric value representing the missile's total health or structural integrity.
---@field box Box3 A box (two Vec3 points) representing the physical dimensions of the missile in the DCS World coordinate system.
---@field category Weapon.Category A `Weapon.Category` enumerator specifying the fundamental classification of the missile.
---@field warhead WeaponWarheadDetails A table representing the specifications of the missile's destructive payload component.
---@field guidance Weapon.GuidanceType A `Weapon.GuidanceType` enumerator specifying the missile's targeting and course correction technology.
---@field rangeMin number A numeric value representing the minimum effective engagement range in meters.
---@field rangeMaxAltMin number A numeric value representing the maximum engagement range in meters when fired at minimum altitude.
---@field rangeMaxAltMax number A numeric value representing the maximum engagement range in meters when fired at maximum altitude.
---@field altMin number A numeric value representing the minimum effective engagement altitude in meters.
---@field altMax number A numeric value representing the maximum effective engagement altitude in meters.
---@field Nmax number A numeric value representing the maximum G-force the missile can sustain during flight.
---@field fuseDist number A numeric value representing the distance in meters at which the missile's proximity fuse activates.

--- Defines the structure of a Lua table representing the properties and capabilities of unguided rocket weapons in the DCS World.
--- (Data structure definition for WeaponDescRocket. Not a globally accessible table.)
---@class WeaponDescRocket
---@field life number A numeric value representing the rocket's total health or structural integrity.
---@field box Box3 A box (two Vec3 points) representing the physical dimensions of the rocket in the DCS World coordinate system.
---@field category Weapon.Category A `Weapon.Category` enumerator specifying the fundamental classification of the rocket.
---@field warhead WeaponWarheadDetails A table representing the specifications of the rocket's destructive payload component.
---@field distMin number A numeric value representing the minimum effective firing distance in meters.
---@field distMax number A numeric value representing the maximum effective firing distance in meters.

--- Assigns the nearest world object to the point for AI to attack.
--- (Data structure definition for TaskAttackMapObject. Not a globally accessible table.)
---@class TaskAttackMapObject
---@field id string Task identifier, must be 'AttackMapObject'
---@field params TaskAttackMapObjectParams

--- Assigns a point on the ground for which the AI will attack. Best used for discriminant carpet bombing of a target or having a GBU hit a specific point on the map.
--- (Data structure definition for TaskBombing. Not a globally accessible table.)
---@class TaskBombing
---@field id string Task identifier, must be 'Bombing'
---@field params TaskBombingParams

--- Assigns a point on the ground for which the AI will attack. Similar to the bombing task, but with more control over target area. Can be combined with follow big formation task for all participating aircraft to simultaneously bomb a target.
--- (Data structure definition for TaskCarpetBombing. Not a globally accessible table.)
---@class TaskCarpetBombing
---@field id string Task identifier, must be 'CarpetBombing'
---@field params TaskCarpetBombingParams

--- Defines the structure of a Lua table representing an en-route task that assigns the controlled group to engage targets with specific attributes within a defined zone.
--- (Data structure definition for TaskEnRouteEngageTargetsInZone. Not a globally accessible table.)
---@class TaskEnRouteEngageTargetsInZone
---@field id string En-route task identifier, must be 'engageTargetsInZone'.
---@field params TaskEnRouteEngageTargetsInZoneParams

--- Assigns a point on the ground for which the AI will shoot at. Most commonly used with artillery to shell a target.
--- (Data structure definition for TaskFireAtPoint. Not a globally accessible table.)
---@class TaskFireAtPoint
---@field id string Task identifier, must be 'fireAtPoint'
---@field params TaskFireAtPointParams

--- Defines the structure of a Lua table representing a landing task that directs helicopters to touch down at specific coordinates.
--- (Data structure definition for TaskLand. Not a globally accessible table.)
---@class TaskLand
---@field id string Task identifier, must be 'land'.
---@field params TaskLandParams A table containing parameters that configure the landing behavior.

--- Defines the structure of a Lua table representing an orbit task that directs aircraft to fly various pattern types at specified locations.
--- (Data structure definition for TaskOrbit. Not a globally accessible table.)
---@class TaskOrbit
---@field id string Task identifier, must be 'orbit'.
---@field params TaskOrbitParams A table containing parameters that configure the orbit behavior and pattern.

--- Defines the structure of a Lua table representing a strafing task that directs AI to perform gun or rocket attacks on a ground point.
--- (Data structure definition for TaskStrafing. Not a globally accessible table.)
---@class TaskStrafing
---@field id string Task identifier, must be 'Strafing'.
---@field params TaskStrafingParams A table containing parameters that configure the strafing attack behavior.

--- Defines the structure of a Lua table representing an en-route task that assigns the controlled group to act as a Forward Air Controller or JTAC and engage the specified group as a JTAC target once detected.
--- (Data structure definition for TaskEnRouteFACEngageGroup. Not a globally accessible table.)
---@class TaskEnRouteFACEngageGroup
---@field id string En-route task identifier, must be 'FAC_engageGroup'.
---@field params TaskEnRouteFACEngageGroupParams

--- Defines the structure of a Lua table representing an en-route task that assigns the controlled group to act as a Forward Air Controller or JTAC. Any detected targets will be assigned as targets to the player via the JTAC radio menu.
--- (Data structure definition for TaskEnRouteFAC. Not a globally accessible table.)
---@class TaskEnRouteFAC
---@field id string En-route task identifier, must be 'fac'.
---@field params TaskEnRouteFACParams

--- Assigns the controlled group to act as a Forward Air Controller or JTAC in attacking the specified group. This task adds the group to the JTAC radio menu and interacts with a player to destroy the target.
--- (Data structure definition for TaskFACAttackGroup. Not a globally accessible table.)
---@class TaskFACAttackGroup
---@field id string Task identifier, must be 'FAC_AttackGroup'
---@field params TaskFACAttackGroupParams

--- Defines the structure of a Lua table representing a sensor system's capabilities and technical specifications.
--- (Data structure definition for UnitSensor. Not a globally accessible table.)
---@class UnitSensor
---@field _type Unit.SensorType An `Unit.SensorType` enumerator specifying the general category of the sensor system.
---@field typeName string A string containing the specific model name or designation of the sensor.
---@field detectionDistanceAir UnitSensorDetectionDistanceAir|nil A table containing the sensor's detection ranges against aerial targets from different aspects.
---@field detectionDistanceIdle nil|number A numeric value representing the maximum detection distance in meters against idle (non-emitting) targets.
---@field detectionDistanceMaximal nil|number A numeric value representing the maximum absolute detection distance in meters under optimal conditions.
---@field detectionDistanceAfterburner nil|number A numeric value representing the maximum detection distance in meters against targets using afterburner.

--- Defines the structure of a Lua table representing a ground escort task that directs helicopters to provide aerial protection for ground units.
--- (Data structure definition for TaskGroundEscort. Not a globally accessible table.)
---@class TaskGroundEscort
---@field id string Task identifier, must be 'groundEscort'.
---@field params TaskGroundEscortParams A table containing parameters that configure the ground escort behavior.

--- Controlled aircraft will follow the assigned group along their route in formation and will engage threats within a defined distance from the followed group.
--- (Data structure definition for TaskEscort. Not a globally accessible table.)
---@class TaskEscort
---@field id string Task identifier, must be 'escort'
---@field params TaskEscortParams

--- Defines the structure of a Lua table representing an advanced formation-following task for coordinated bombing missions with multiple aircraft.
--- (Data structure definition for TaskFollowBigFormation. Not a globally accessible table.)
---@class TaskFollowBigFormation
---@field id string Task identifier, must be 'followBigFormation'.
---@field params TaskFollowBigFormationParams A table containing parameters that configure the formation-following behavior.

--- Defines the structure of a Lua table representing a follow task that directs aircraft to join formation with another group or orbit above ground units.
--- (Data structure definition for TaskFollow. Not a globally accessible table.)
---@class TaskFollow
---@field id string Task identifier, must be 'follow'.
---@field params TaskFollowParams A table containing parameters that configure the follow behavior.

--- Defines the structure of a Lua table representing a task with start and stop conditions that determine when to execute and terminate the task.
--- (Data structure definition for ControlledTask. Not a globally accessible table.)
---@class ControlledTask
---@field id string Task identifier, must be 'ControlledTask'.
---@field params ControlledTaskParams A table containing parameters that configure the task execution conditions.

--- Defines the structure of a Lua table representing a route-based mission consisting of waypoints assigned to a group.
--- (Data structure definition for Mission. Not a globally accessible table.)
---@class Mission
---@field id string Task identifier, must be 'Mission'.
---@field params MissionParams A table containing parameters that define the mission configuration.

--- Represents a Lua table structure defining an immediate command that can be issued to a controller to affect AI behavior without modifying tasks.
---@alias ControllerCommand CommandActivateACLS|CommandActivateBeacon|CommandActivateICLS|CommandActivateLink4|CommandDeactivateACLS|CommandDeactivateBeacon|CommandDeactivateICLS|CommandDeactivateLink4|CommandEPLRS|CommandLoadingShip|CommandScript|CommandSetCallsign|CommandSetFrequency|CommandSetFrequencyForUnit|CommandSetImmortal|CommandSetInvisible|CommandSetUnlimitedFuel|CommandSmokeOnOff|CommandStart|CommandStopRoute|CommandStopTransmission|CommandSwitchAction|CommandSwitchWaypoint|CommandTransmitMessage

--- Defines the structure of a Lua table representing a target detected by a controller, including its object reference and detection details.
--- (Data structure definition for ControllerDetectedTarget. Not a globally accessible table.)
---@class ControllerDetectedTarget
---@field object Object Reference to the detected target object.
---@field visible boolean Whether the target is currently visible via line of sight.
---@field _type boolean Whether the target's specific type is known to the detector.
---@field distance boolean Whether the distance to the target is known to the detector.

--- Base structure for all event data. Contains common fields present in every event.
--- (Data structure definition for EventDataBase. Not a globally accessible table.)
---@class EventDataBase
---@field id world.event The event ID that identifies the type of event.
---@field time number Timestamp when the event occurred in mission time.
---@field initiator Object|nil The initiating object (can be a Unit, StaticObject, or other object type depending on event).

--- Base structure for mark-related events.
--- (Data structure definition for EventDataMarkBase. Not a globally accessible table.)
---@class EventDataMarkBase
---@field id world.event The event ID that identifies the type of event.
---@field time number Timestamp when the event occurred in mission time.
---@field initiator Object|nil The initiating object (can be a Unit, StaticObject, or other object type depending on event).
---@field MarkID number ID of the mark that was added, changed, or removed.
---@field MarkText nil|string Text of the mark.
---@field MarkCoordinate Vec3|nil Coordinate of the mark.
---@field MarkCoalition coalition.side|nil Coalition that owns the mark.

--- Event data structure for S_EVENT_SHOOTING_START events. Occurs when continuous shooting begins.
--- (Data structure definition for EventDataShootingStart. Not a globally accessible table.)
---@class EventDataShootingStart
---@field id world.event The event ID that identifies the type of event.
---@field time number Timestamp when the event occurred in mission time.
---@field initiator Object|nil The initiating object (can be a Unit, StaticObject, or other object type depending on event).
---@field target Object|nil The target being shot at, if applicable.

--- Event data structure for S_EVENT_WEAPON_ADD events. Occurs when a weapon is added to a unit.
--- (Data structure definition for EventDataWeaponAdd. Not a globally accessible table.)
---@class EventDataWeaponAdd
---@field id world.event The event ID that identifies the type of event.
---@field time number Timestamp when the event occurred in mission time.
---@field initiator Object|nil The initiating object (can be a Unit, StaticObject, or other object type depending on event).
---@field WeaponName string Name of the weapon that was added.

--- Represents a numerically indexed table of `Object` instances.
---@alias ObjectArray Object[]

--- Defines the structure of a Lua table representing a specific weapon or ammunition type and its quantity in a unit's inventory.
--- (Data structure definition for UnitAmmoItem. Not a globally accessible table.)
---@class UnitAmmoItem
---@field count number A numeric value indicating the quantity of this ammunition type available to the unit.
---@field desc UnitAmmoDesc A table representing the specifications and capabilities of this ammunition type.

--- Represents a Lua table structure defining either a main task or an enroute task that can be assigned to a controller to direct AI behavior.
---@alias ControllerTask TaskAttackGroup|TaskAttackMapObject|TaskAttackUnit|TaskBombing|TaskBombingRunway|TaskCarpetBombing|TaskEnRouteAWACS|TaskEnRouteEWR|TaskEnRouteEngageGroup|TaskEnRouteEngageTargets|TaskEnRouteEngageTargetsInZone|TaskEnRouteEngageUnit|TaskEnRouteFAC|TaskEnRouteFACEngageGroup|TaskEnRouteTanker|TaskEscort|TaskFACAttackGroup|TaskFireAtPoint|TaskFollow|TaskFollowBigFormation|TaskGroundEscort|TaskHold|TaskLand|TaskOrbit|TaskRecoveryTanker|TaskRefueling|TaskStrafing

--- Represents a numerically indexed Lua table (sequence) where each element is a table containing information about a detected target.
---@alias ControllerDetectedTargetArray ControllerDetectedTarget[]

--- Represents a numerically indexed Lua table (sequence) of `Airbase` objects in the DCS World mission.
---@alias AirbaseArray Airbase[]

--- Event data structure that contains information about an event. The id field identifies which type of event is being handled.
--- (Data structure definition for EventData. Not a globally accessible table.)
---@class EventData
---@field id world.event The event ID that identifies the type of event.
---@field time number Timestamp when the event occurred in mission time.
---@field initiator Object|nil The initiating object (can be a Unit, StaticObject, or other object type depending on event).
---@field target Object|nil The target object involved in the event (present in hit, kill, shooting events).
---@field weapon Weapon|nil The weapon used during the event (present in shot, hit, kill events).
---@field WeaponName nil|string Name of the weapon (present in weapon_add events).
---@field place Airbase|nil The place object (used in landing, takeoff, birth, base_captured events).
---@field subplace nil|world.BirthPlace The specific location within the place (used in birth events).
---@field MarkID nil|number ID of the mark in mark-related events.
---@field MarkText nil|string Text of the mark.
---@field MarkCoordinate Vec3|nil Coordinate of the mark.
---@field MarkCoalition coalition.side|nil Coalition that owns the mark.
---@field Zone Zone|nil The zone object in trigger zone events.
---@field Cargo Cargo|nil The cargo object in cargo-related events.
---@field IniCoalition coalition.side|nil Coalition of the initiator.
---@field TgtCoalition coalition.side|nil Coalition of the target.
---@field IniPlayerName nil|string Name of the player that initiated the event.
---@field TgtPlayerName nil|string Name of the player that was targeted.

--- Event data structure for S_EVENT_BASE_CAPTURED events. Occurs when a base is captured.
--- (Data structure definition for EventDataBaseCaptured. Not a globally accessible table.)
---@class EventDataBaseCaptured
---@field id world.event The event ID that identifies the type of event.
---@field time number Timestamp when the event occurred in mission time.
---@field initiator Object|nil The initiating object (can be a Unit, StaticObject, or other object type depending on event).
---@field place Airbase The airbase that was captured.

--- Event data structure for S_EVENT_BIRTH events. Occurs when an object is spawned.
--- (Data structure definition for EventDataBirth. Not a globally accessible table.)
---@class EventDataBirth
---@field id world.event The event ID that identifies the type of event.
---@field time number Timestamp when the event occurred in mission time.
---@field initiator Object|nil The initiating object (can be a Unit, StaticObject, or other object type depending on event).
---@field place Airbase|nil The place where the unit was spawned, if applicable.
---@field subplace nil|world.BirthPlace The specific location type within the place where the unit was spawned.

--- Comprehensive event data structure containing all possible fields from any event type.
--- (Data structure definition for EventDataGeneric. Not a globally accessible table.)
---@class EventDataGeneric
---@field id world.event The event ID that identifies the type of event.
---@field time number Timestamp when the event occurred in mission time.
---@field initiator Object|nil The initiating object (can be a Unit, StaticObject, or other object type depending on event).
---@field IniObjectCategory Object.Category|nil (UNIT/STATIC/SCENERY) The initiator object category (Object.Category.UNIT or Object.Category.STATIC).
---@field IniDCSUnit StaticObject|Unit|nil (UNIT/STATIC) The initiating DCS Unit or StaticObject.
---@field IniDCSUnitName nil|string (UNIT/STATIC) The initiating Unit name.
---@field IniUnit Unit|nil (UNIT) The initiating MOOSE Unit wrapper of the initiator Unit object.
---@field IniUnitName nil|string (UNIT) The initiating UNIT name (same as IniDCSUnitName).
---@field IniDCSGroup Group|nil (UNIT) The initiating Group.
---@field IniDCSGroupName nil|string (UNIT) The initiating Group name.
---@field IniGroup Group|nil (UNIT) The initiating GROUP object.
---@field IniGroupName nil|string (UNIT) The initiating GROUP name (same as IniDCSGroupName).
---@field IniCategory Unit.Category|nil (UNIT) The category of the initiator.
---@field IniCoalition coalition.side|nil (UNIT) The coalition of the initiator.
---@field IniTypeName nil|string (UNIT) The type name of the initiator.
---@field IniPlayerName nil|string (UNIT) The name of the initiating player in case the Unit is a client or player slot.
---@field IniPlayerUCID nil|string (UNIT) The UCID of the initiating player in case the Unit is a client or player slot.
---@field target Object|nil (UNIT/STATIC) The target object (Unit/StaticObject/other depending on event type).
---@field TgtObjectCategory Object.Category|nil (UNIT/STATIC) The target object category (Object.Category.UNIT or Object.Category.STATIC).
---@field TgtDCSUnit StaticObject|Unit|nil (UNIT/STATIC) The target DCS Unit or StaticObject.
---@field TgtDCSUnitName nil|string (UNIT/STATIC) The target Unit name.
---@field TgtUnit Unit|nil (UNIT) The target Unit object.
---@field TgtUnitName nil|string (UNIT) The target UNIT name (same as TgtDCSUnitName).
---@field TgtDCSGroup Group|nil (UNIT) The target Group.
---@field TgtDCSGroupName nil|string (UNIT) The target Group name.
---@field TgtGroup Group|nil (UNIT) The target GROUP object.
---@field TgtGroupName nil|string (UNIT) The target GROUP name (same as TgtDCSGroupName).
---@field TgtCategory Unit.Category|nil (UNIT) The category of the target.
---@field TgtCoalition coalition.side|nil (UNIT) The coalition of the target.
---@field TgtTypeName nil|string (UNIT) The type name of the target.
---@field TgtPlayerName nil|string (UNIT) The name of the target player in case the Unit is a client or player slot.
---@field TgtPlayerUCID nil|string (UNIT) The UCID of the target player in case the Unit is a client or player slot.
---@field weapon Weapon|nil The weapon used during the event (present in shot, hit, kill events).
---@field WeaponName nil|string Name of the weapon.
---@field WeaponTypeName nil|string Type name of the weapon.
---@field WeaponCategory Weapon.Category|nil Category of the weapon.
---@field WeaponCoalition coalition.side|nil Coalition of the weapon.
---@field WeaponPlayerName nil|string Player name associated with the weapon, if applicable.
---@field WeaponTgtDCSUnit Unit|nil Target unit of the weapon.
---@field WeaponUNIT Unit|nil Sometimes, the weapon is a player unit.
---@field place Airbase|nil The place object (used in landing, takeoff, birth, base_captured events).
---@field PlaceName nil|string The name of the place.
---@field subplace nil|world.BirthPlace The specific location within the place (used in birth events).
---@field MarkID nil|number ID of the mark in mark-related events.
---@field MarkText nil|string Text of the mark.
---@field MarkCoordinate Vec3|nil Coordinate of the mark.
---@field MarkVec3 Vec3|nil Vector 3D position of the mark.
---@field MarkCoalition coalition.side|nil Coalition that owns the mark.
---@field MarkGroupID nil|number Group ID associated with the mark, if applicable.
---@field Cargo Cargo|nil The cargo object in cargo-related events.
---@field CargoName nil|string The name of the cargo.
---@field IniDynamicCargo DynamicCargo|nil The dynamic cargo object in dynamic cargo events.
---@field IniDynamicCargoName nil|string The name of the dynamic cargo.
---@field Zone Zone|nil The zone object in zone-related events.
---@field ZoneName nil|string The name of the zone.

--- Event data structure for S_EVENT_HIT events. Occurs whenever an object is hit by a weapon.
--- (Data structure definition for EventDataHit. Not a globally accessible table.)
---@class EventDataHit
---@field id world.event The event ID that identifies the type of event.
---@field time number Timestamp when the event occurred in mission time.
---@field initiator Object|nil The initiating object (can be a Unit, StaticObject, or other object type depending on event).
---@field weapon Weapon|nil The weapon that hit the target. May be nil in multiplayer due to desync issues.
---@field target Object The object that was hit.

--- Event data structure for S_EVENT_KILL events. Occurs when a unit kills another unit.
--- (Data structure definition for EventDataKill. Not a globally accessible table.)
---@class EventDataKill
---@field id world.event The event ID that identifies the type of event.
---@field time number Timestamp when the event occurred in mission time.
---@field initiator Object|nil The initiating object (can be a Unit, StaticObject, or other object type depending on event).
---@field target Object The object that was killed.
---@field weapon Weapon|nil The weapon that caused the kill, if applicable.

--- Event data structure for S_EVENT_LAND events. Occurs when an aircraft lands.
--- (Data structure definition for EventDataLand. Not a globally accessible table.)
---@class EventDataLand
---@field id world.event The event ID that identifies the type of event.
---@field time number Timestamp when the event occurred in mission time.
---@field initiator Object|nil The initiating object (can be a Unit, StaticObject, or other object type depending on event).
---@field place Airbase|nil The airbase or ship where the landing occurred.

--- Event data structure for S_EVENT_SHOT events. Occurs whenever any unit fires a weapon.
--- (Data structure definition for EventDataShot. Not a globally accessible table.)
---@class EventDataShot
---@field id world.event The event ID that identifies the type of event.
---@field time number Timestamp when the event occurred in mission time.
---@field initiator Object|nil The initiating object (can be a Unit, StaticObject, or other object type depending on event).
---@field weapon Weapon The weapon that was fired.

--- Event data structure for S_EVENT_TAKEOFF events. Occurs when an aircraft takes off.
--- (Data structure definition for EventDataTakeoff. Not a globally accessible table.)
---@class EventDataTakeoff
---@field id world.event The event ID that identifies the type of event.
---@field time number Timestamp when the event occurred in mission time.
---@field initiator Object|nil The initiating object (can be a Unit, StaticObject, or other object type depending on event).
---@field place Airbase|nil The airbase or ship from which the takeoff occurred.

--- Maps event IDs to their respective event data types. Used to document which event types correspond to which event IDs.
--- (Data structure definition for EventTypeMap. Not a globally accessible table.)
---@class EventTypeMap
---@field S_EVENT_INVALID EventDataBase Event data for invalid events (ID 0).
---@field S_EVENT_SHOT EventDataShot Event data for shot events (ID 1).
---@field S_EVENT_HIT EventDataHit Event data for hit events (ID 2).
---@field S_EVENT_TAKEOFF EventDataTakeoff Event data for takeoff events (ID 3).
---@field S_EVENT_LAND EventDataLand Event data for landing events (ID 4).
---@field S_EVENT_CRASH EventDataGeneric Event data for crash events (ID 5).
---@field S_EVENT_EJECTION EventDataGeneric Event data for ejection events (ID 6).
---@field S_EVENT_REFUELING EventDataGeneric Event data for refueling events (ID 7).
---@field S_EVENT_DEAD EventDataGeneric Event data for dead events (ID 8).
---@field S_EVENT_PILOT_DEAD EventDataGeneric Event data for pilot dead events (ID 9).
---@field S_EVENT_BASE_CAPTURED EventDataBaseCaptured Event data for base captured events (ID 10).
---@field S_EVENT_MISSION_START EventDataGeneric Event data for mission start events (ID 11).
---@field S_EVENT_MISSION_END EventDataGeneric Event data for mission end events (ID 12).
---@field S_EVENT_TOOK_CONTROL EventDataGeneric Event data for took control events (ID 13).
---@field S_EVENT_REFUELING_STOP EventDataGeneric Event data for refueling stop events (ID 14).
---@field S_EVENT_BIRTH EventDataBirth Event data for birth/spawn events (ID 15).
---@field S_EVENT_HUMAN_FAILURE EventDataGeneric Event data for human failure events (ID 16).
---@field S_EVENT_DETAILED_FAILURE EventDataGeneric Event data for detailed failure events (ID 17).
---@field S_EVENT_ENGINE_STARTUP EventDataGeneric Event data for engine startup events (ID 18).
---@field S_EVENT_ENGINE_SHUTDOWN EventDataGeneric Event data for engine shutdown events (ID 19).
---@field S_EVENT_PLAYER_ENTER_UNIT EventDataGeneric Event data for player enter unit events (ID 20).
---@field S_EVENT_PLAYER_LEAVE_UNIT EventDataGeneric Event data for player leave unit events (ID 21).
---@field S_EVENT_PLAYER_COMMENT EventDataGeneric Event data for player comment events (ID 22).
---@field S_EVENT_SHOOTING_START EventDataShootingStart Event data for shooting start events (ID 23).
---@field S_EVENT_SHOOTING_END EventDataGeneric Event data for shooting end events (ID 24).
---@field S_EVENT_MARK_ADDED EventDataMarkBase Event data for mark added events (ID 25).
---@field S_EVENT_MARK_CHANGE EventDataMarkBase Event data for mark change events (ID 26).
---@field S_EVENT_MARK_REMOVED EventDataMarkBase Event data for mark removed events (ID 27).
---@field S_EVENT_KILL EventDataKill Event data for kill events (ID 28).
---@field S_EVENT_SCORE EventDataGeneric Event data for score events (ID 29).
---@field S_EVENT_UNIT_LOST EventDataGeneric Event data for unit lost events (ID 30).
---@field S_EVENT_LANDING_AFTER_EJECTION EventDataGeneric Event data for landing after ejection events (ID 31).
---@field S_EVENT_PARATROOPER_LENDING EventDataGeneric Event data for paratrooper landing events (ID 32).
---@field S_EVENT_DISCARD_CHAIR_AFTER_EJECTION EventDataGeneric Event data for discard chair after ejection events (ID 33).
---@field S_EVENT_WEAPON_ADD EventDataWeaponAdd Event data for weapon add events (ID 34).
---@field S_EVENT_TRIGGER_ZONE EventDataGeneric Event data for trigger zone events (ID 35).
---@field S_EVENT_LANDING_QUALITY_MARK EventDataGeneric Event data for landing quality mark events (ID 36).
---@field S_EVENT_BDA EventDataGeneric Event data for battle damage assessment events (ID 37).
---@field S_EVENT_AI_ABORT_MISSION EventDataGeneric Event data for AI abort mission events (ID 38).
---@field S_EVENT_DAYNIGHT EventDataGeneric Event data for day/night transition events (ID 39).
---@field S_EVENT_FLIGHT_TIME EventDataGeneric Event data for flight time events (ID 40).
---@field S_EVENT_PLAYER_SELF_KILL_PILOT EventDataGeneric Event data for player self-kill pilot events (ID 41).
---@field S_EVENT_PLAYER_CAPTURE_AIRFIELD EventDataGeneric Event data for player capture airfield events (ID 42).
---@field S_EVENT_EMERGENCY_LANDING EventDataGeneric Event data for emergency landing events (ID 43).
---@field S_EVENT_UNIT_CREATE_TASK EventDataGeneric Event data for unit create task events (ID 44).
---@field S_EVENT_UNIT_DELETE_TASK EventDataGeneric Event data for unit delete task events (ID 45).
---@field S_EVENT_SIMULATION_START EventDataGeneric Event data for simulation start events (ID 46).
---@field S_EVENT_WEAPON_REARM EventDataGeneric Event data for weapon rearm events (ID 47).
---@field S_EVENT_WEAPON_DROP EventDataGeneric Event data for weapon drop events (ID 48).
---@field S_EVENT_UNIT_TASK_COMPLETE EventDataGeneric Event data for unit task complete events (ID 49).
---@field S_EVENT_UNIT_TASK_STAGE EventDataGeneric Event data for unit task stage events (ID 50).
---@field S_EVENT_MAC_EXTRA_SCORE EventDataGeneric Event data for MAC extra score events (ID 51).
---@field S_EVENT_MISSION_RESTART EventDataGeneric Event data for mission restart events (ID 52).
---@field S_EVENT_MISSION_WINNER EventDataGeneric Event data for mission winner events (ID 53).
---@field S_EVENT_RUNWAY_TAKEOFF EventDataGeneric Event data for runway takeoff events (ID 54).
---@field S_EVENT_RUNWAY_TOUCH EventDataGeneric Event data for runway touch events (ID 55).
---@field S_EVENT_MAC_LMS_RESTART EventDataGeneric Event data for MAC LMS restart events (ID 56).
---@field S_EVENT_SIMULATION_FREEZE EventDataGeneric Event data for simulation freeze events (ID 57).
---@field S_EVENT_SIMULATION_UNFREEZE EventDataGeneric Event data for simulation unfreeze events (ID 58).
---@field S_EVENT_HUMAN_AIRCRAFT_REPAIR_START EventDataGeneric Event data for human aircraft repair start events (ID 59).
---@field S_EVENT_HUMAN_AIRCRAFT_REPAIR_FINISH EventDataGeneric Event data for human aircraft repair finish events (ID 60).
---@field S_EVENT_MAX EventDataBase Maximum event ID marker (ID 61).
