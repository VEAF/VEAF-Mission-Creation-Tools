------------------------------------------------------------------
-- VEAF Skynet-IADS contacts monitoring
-- By Flogas (2023)
--
-- Features:
-- ---------
-- * This module offers tools to trigger actions when a Skynet IADS detects a target
--
-- See the documentation : https://veaf.github.io/documentation/
------------------------------------------------------------------

veafSkynetMonitor = {}

-------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Global settings. Stores the script constants
-------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Identifier. All output in DCS.log will start with this.
veafSkynetMonitor.Id = "SKYNET_MONITOR"

--- Version.
veafSkynetMonitor.Version = "1.0.1"

-- trace level, specific to this module
--veafSkynetMonitor.LogLevel = "trace"
veaf.loggers.new(veafSkynetMonitor.Id, veafSkynetMonitor.LogLevel)

---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
---  general tools
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
local function tableContains(tab, element)
    for _, e in pairs(tab) do
        if e == element then
            return true
        end
    end
    return false
end

local function tableRemove(tab, element)
    for i, e in pairs(tab) do
        if e == element then
            table.remove(tab, i)
            return
        end
    end
end

local function isNullOrEmpty(s)
    return (s == nil or (type(s) == "string" and s == ""))
end

---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
---  VeafSkynetMonitorDescriptor class
---  Provides text descriptions to check an IADS content and structure
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
VeafSkynetMonitorDescriptor = {}

VeafSkynetMonitorDescriptor._staticSring = { Separator = " | ", Indentation = "  " }
VeafSkynetMonitorDescriptor.Option =
{
    -- general
    Ewr = 1,        -- display Early Warning Radars
    Sam = 2,        -- display SAM sites
    Targets = 3,    -- display targets tracked by the IADS
    -- Elements (Sam sites, EWRs)
    ElementTargets = 4, -- display targets tracked by each sam site
    ElementDetail = 5,  -- display static element informations (go live conditions, HARM detection percentages, etc)
    ElementStructure = 6,  -- display units attached to each element (point defences, child radars, etc)
    
    NestedPointDefences = 7 -- the point defences will be displayed as part of the element they defend
}
---------------------------------------------------------------------------------------------------
---  CTOR
function VeafSkynetMonitorDescriptor:Create(iads, options)
    options = options or
        { VeafSkynetMonitorDescriptor.Option.Ewr, VeafSkynetMonitorDescriptor.Option.Sam,
            VeafSkynetMonitorDescriptor.Option.Targets }

    local this =
    {
        Iads = iads,
        Options = options,
        FilterNatoName = {},
        FilterGroupName = {}
    }
    setmetatable(this, self)
    self.__index = self

    return this
end

function VeafSkynetMonitorDescriptor:GetIndentationString(iIndentation)
    iIndentation = iIndentation or 0
    return string.rep(self._staticSring.Indentation, iIndentation)
end

function VeafSkynetMonitorDescriptor:AppendString(s, sAppend)
    sAppend = sAppend or ""

    if (isNullOrEmpty(s)) then
        return sAppend
    elseif (isNullOrEmpty(sAppend)) then
        return s
    else
        return s .. self._staticSring.Separator .. sAppend
    end
end

function VeafSkynetMonitorDescriptor:NewLine(s, iIndentation)
    return s .. "\n" .. self:GetIndentationString(iIndentation)
end

function VeafSkynetMonitorDescriptor:AppendLine(s, sAppend, iIndentation)
    sAppend = sAppend or ""

    if (isNullOrEmpty(s)) then
        return self:GetIndentationString(iIndentation) .. sAppend
    elseif (isNullOrEmpty(sAppend)) then
        return s
    else
        return self:NewLine(s, iIndentation) .. sAppend
    end
end

function VeafSkynetMonitorDescriptor:GetStringSkynetElement(skynetElement)
    local s = veafSkynet.getStringSkynetElement(skynetElement)
    local dcsGroup = veafSkynet.getDcsGroupFromSkynetElement(skynetElement)
    if (dcsGroup == nil) then
        s = s .. " (dcs group not found)"
    else
        local bActive = false
        for _, dcsUnit in pairs(dcsGroup:getUnits()) do
            if (dcsUnit:isActive()) then
                bActive = true
                break
            end
        end

        if (not bActive) then
            s = s .. " (dcs group not active)" 
        end
    end

    return s
end

function VeafSkynetMonitorDescriptor:GetStringElementStructure(details, sDetailType)
    local s = ""

    if (details == nil or #details <= 0) then
        s = self:AppendString(s, "No " .. sDetailType)
    else
        s = self:AppendString(s, sDetailType .. ":" .. #details)
    end

    return s
end

function VeafSkynetMonitorDescriptor:GetStringEwr(ewr, iIndentation)
    local s = ""

    -- Site description
    s = self:AppendLine(s, "EWR : " .. VeafSkynetMonitorDescriptor:GetStringSkynetElement(ewr), iIndentation)

    -- Site detail
    if (tableContains(self.Options, VeafSkynetMonitorDescriptor.Option.ElementDetail)) then
        s = self:NewLine(s, iIndentation + 1)

        if (ewr.harmDetectionChance) then
            s = self:AppendString(s, "HARM detection " .. ewr.harmDetectionChance .. "%")
        end
        if (ewr.autonomousBehaviour == SkynetIADSAbstractRadarElement.AUTONOMOUS_STATE_DCS_AI) then
            s = self:AppendString(s, "Autonomous:DCS AI")
        elseif (ewr.autonomousBehaviour == SkynetIADSAbstractRadarElement.AUTONOMOUS_STATE_DARK) then
            s = self:AppendString(s, "Autonomous:dark")
        end
        if (ewr.goLiveRange == SkynetIADSAbstractRadarElement.GO_LIVE_WHEN_IN_KILL_ZONE) then
            s = self:AppendString(s, "Go live:kill zone")
        elseif (ewr.goLiveRange == SkynetIADSAbstractRadarElement.GO_LIVE_WHEN_IN_SEARCH_RANGE) then
            s = self:AppendString(s, "Go live:search range")
        end
    end

    -- Site structure
    local pointDefences = ewr:getPointDefences()
    if (tableContains(self.Options, VeafSkynetMonitorDescriptor.Option.ElementStructure)) then
        local radars = ewr:getRadars()

        s = self:NewLine(s, iIndentation + 1)
        s = self:AppendString(s, self:GetStringElementStructure(radars, "Radars"))
        s = self:AppendString(s, self:GetStringElementStructure(pointDefences, "Point defences"))
    end

    -- Site state
    s = self:NewLine(s, iIndentation + 1)
    if (ewr:isActive()) then
        s = self:AppendString(s, "Active")
    else
        s = self:AppendString(s, "Not active")
    end
    if (ewr:getAutonomousState()) then
        s = self:AppendString(s, "Autonomous")
    end
    if (ewr.harmSilenceID ~= nil) then
        s = self:AppendString(s, "Defending HARM")
    end

    if (tableContains(self.Options, VeafSkynetMonitorDescriptor.Option.ElementTargets)) then
        local targets = ewr:getDetectedTargets()
        if (targets == nil or #targets <= 0) then
            s = self:AppendLine(s, "No targets", iIndentation + 1)
        else
            s = self:AppendLine(s, "Targets :", iIndentation + 1)

            for i = 1, #targets do
                local target = targets[i]
                s = self:AppendLine(s, target:getName(), iIndentation + 2)
                s = self:AppendString(s, target:getTypeName())
            end
        end
    end

    if (tableContains(self.Options, VeafSkynetMonitorDescriptor.Option.NestedPointDefences)) then
        if (pointDefences and #pointDefences > 0) then
            s = self:AppendLine(s, "Point defences :", iIndentation + 1)

            for i = 1, #pointDefences do
                local pointDefence = pointDefences[i]
                s = self:AppendLine(s, self:GetStringSam(pointDefence, iIndentation + 2))
            end
        end
    end

    return s
end

function VeafSkynetMonitorDescriptor:GetStringSam(samSite, iIndentation)
    local s = ""

    -- Site description
    s = self:AppendLine(s, "Sam site : " .. VeafSkynetMonitorDescriptor:GetStringSkynetElement(samSite), iIndentation)
    if (samSite.isAPointDefence) then
        s = self:AppendString(s, "**Point defence**")
    end

    -- Site detail
    if (tableContains(self.Options, VeafSkynetMonitorDescriptor.Option.ElementDetail)) then
        s = self:NewLine(s, iIndentation + 1)

        if (samSite:getCanEngageAirWeapons()) then
            s = self:AppendString(s, "Can engage air weapons")
        end
        if (samSite:getCanEngageHARM()) then
            s = self:AppendString(s, "Can engage HARMs")
        end
        if (samSite.harmDetectionChance) then
            s = self:AppendString(s, "HARM detection " .. samSite.harmDetectionChance .. "%")
        end
        if (samSite.autonomousBehaviour == SkynetIADSAbstractRadarElement.AUTONOMOUS_STATE_DCS_AI) then
            s = self:AppendString(s, "Autonomous:DCS AI")
        elseif (samSite.autonomousBehaviour == SkynetIADSAbstractRadarElement.AUTONOMOUS_STATE_DARK) then
            s = self:AppendString(s, "Autonomous:dark")
        end
        if (samSite.goLiveRange == SkynetIADSAbstractRadarElement.GO_LIVE_WHEN_IN_KILL_ZONE) then
            s = self:AppendString(s, "Go live:kill zone")
        elseif (samSite.goLiveRange == SkynetIADSAbstractRadarElement.GO_LIVE_WHEN_IN_SEARCH_RANGE) then
            s = self:AppendString(s, "Go live:search range")
        end
    end

    -- Site structure
    local pointDefences = samSite:getPointDefences()
    if (tableContains(self.Options, VeafSkynetMonitorDescriptor.Option.ElementStructure)) then
        local searchRadars = samSite:getSearchRadars()
        local trackRadars = samSite:getTrackingRadars()
        local launchers = samSite:getLaunchers()

        s = self:NewLine(s, iIndentation + 1)
        s = self:AppendString(s, self:GetStringElementStructure(searchRadars, "Search radars"))
        s = self:AppendString(s, self:GetStringElementStructure(trackRadars, "Track radars"))
        s = self:AppendString(s, self:GetStringElementStructure(launchers, "Launchers"))
        s = self:AppendString(s, self:GetStringElementStructure(pointDefences, "Point defences"))
    end

    -- Site state
    s = self:NewLine(s, iIndentation + 1)
    if (samSite:isActive()) then
        s = self:AppendString(s, "Active")
    else
        s = self:AppendString(s, "Not active")
    end
    if (samSite:getAutonomousState()) then
        s = self:AppendString(s, "Autonomous")
    end
    if (samSite:getActAsEW()) then
        s = self:AppendString(s, "Acting as EW")
    end
    if (not samSite:hasRemainingAmmo()) then
        s = self:AppendString(s, "No ammo")
    end
    if (samSite.harmSilenceID ~= nil) then
        s = self:AppendString(s, "Defending HARM")
    end

    if (tableContains(self.Options, VeafSkynetMonitorDescriptor.Option.ElementTargets)) then
        local targets = samSite:getDetectedTargets()
        if (targets == nil or #targets <= 0) then
            s = self:AppendLine(s, "No targets", iIndentation + 1)
        else
            s = self:AppendLine(s, "Targets :", iIndentation + 1)

            for i = 1, #targets do
                local target = targets[i]
                s = self:AppendLine(s, target:getName(), iIndentation + 2)
                s = self:AppendString(s, target:getTypeName())
            end
        end
    end

    if (tableContains(self.Options, VeafSkynetMonitorDescriptor.Option.NestedPointDefences)) then
        if (pointDefences and #pointDefences > 0) then
            s = self:AppendLine(s, "Point defences :", iIndentation + 1)

            for i = 1, #pointDefences do
                local pointDefence = pointDefences[i]
                s = self:AppendLine(s, self:GetStringSam(pointDefence, iIndentation + 2))
            end
        end
    end

    return s
end

function VeafSkynetMonitorDescriptor:GetStringDescription()
    local s = ""
    s = self:AppendLine("IADS : " .. self.Iads:getCoalitionString())
    local iIndentation = 1

    if (tableContains(self.Options, VeafSkynetMonitorDescriptor.Option.Ewr)) then
        local ewrs = self.Iads:getEarlyWarningRadars()
        if (#ewrs <= 0) then
            s = self:AppendLine(s, "No EWR", iIndentation)
        else
            s = self:AppendLine(s, "EWRs :", iIndentation)
            for i = 1, #ewrs do
                local ewr = ewrs[i]
                
                local bAddEwr = true
                
                if(self.FilterNatoName and #self.FilterNatoName > 0 and not tableContains(self.FilterNatoName, ewr:getNatoName())) then
                    bAddEwr = false
                end

                if(self.FilterGroupName and #self.FilterGroupName > 0) then
                    for _, sFilter in pairs(self.FilterGroupName) do
                        if (string.match(ewr.dcsName, sFilter) == nil) then
                            bAddEwr = false
                        end
                    end
                end

                if (bAddEwr) then
                    s = self:AppendLine(s, self:GetStringEwr(ewr, iIndentation + 1))
                end
            end
        end
    end

    if (tableContains(self.Options, VeafSkynetMonitorDescriptor.Option.Sam)) then
        local samSites = self.Iads:getSAMSites()
        if (#samSites <= 0) then
            s = self:AppendLine(s, "No sam sites", iIndentation)
        else
            s = self:AppendLine(s, "Sam sites :", iIndentation)
            for i = 1, #samSites do
                local samSite = samSites[i]
                
                local bAddSamSite = true

                if (tableContains(self.Options, VeafSkynetMonitorDescriptor.Option.NestedPointDefences) and samSite.isAPointDefence) then
                    bAddSamSite = false
                end
                
                if(self.FilterNatoName and #self.FilterNatoName > 0 and not tableContains(self.FilterNatoName, samSite:getNatoName())) then
                        bAddSamSite = false
                end

                if(self.FilterGroupName and #self.FilterGroupName > 0) then
                    for _, sFilter in pairs(self.FilterGroupName) do
                        if (string.match(samSite.dcsName, sFilter) == nil) then
                            bAddSamSite = false
                        end
                    end
                end

                if (bAddSamSite) then
                    s = self:AppendLine(s, self:GetStringSam(samSite, iIndentation + 1))
                end
            end
        end
    end

    if (tableContains(self.Options, VeafSkynetMonitorDescriptor.Option.Targets)) then

    end

    return s
end

---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
---  VeafSkynetMonitorTask base class
---  Named monitoring task
---  A monitoring task represents a task to be executed by the monitoring thread
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
VeafSkynetMonitorTask = {}
---------------------------------------------------------------------------------------------------
---  CTOR
function VeafSkynetMonitorTask:Create(sName)
    local this =
    {
        Name = sName
    }
    setmetatable(this, self)
    self.__index = self

    return this
end

function VeafSkynetMonitorTask:ToString()
    return self.Name
end

function VeafSkynetMonitorTask:Execute()
    veaf.loggers.get(veafSkynetMonitor.Id):trace("Executing VeafSkynetMonitorTask")
end

---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
---  VeafSkynetMonitorTaskContacts class
---  Named monitoring task to check for contacts detected and lost by an iads
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
VeafSkynetMonitorTaskContacts = {}
VeafSkynetMonitorTaskContacts = inheritsFrom(VeafSkynetMonitorTask) -- oop functions are from Skynet
---------------------------------------------------------------------------------------------------
---  CTOR
function VeafSkynetMonitorTaskContacts:Create(sName, iads, unitsToMonitor, onDetectedAction, onLostAction)
    local this = self:superClass():Create(sName, iads)
    setmetatable(this, self)
    self.__index = self

    this.Iads = iads
    this.UnitsToMonitor = unitsToMonitor
    this.TrackedUnits = {}
    this.OnDetectedAction = onDetectedAction
    this.OnLostAction = onLostAction

    return this
end

function VeafSkynetMonitorTaskContacts:ToString()
    return self.Name .. " | IADS [" .. self.Iads:getCoalitionString() .. "]"
end

function VeafSkynetMonitorTaskContacts:Execute()
    veaf.loggers.get(veafSkynetMonitor.Id):trace("Executing VeafSkynetMonitorTaskContacts")
    local currentContacts = self:GetIadsCurrentContacts()
    veaf.loggers.get(veafSkynetMonitor.Id):trace(self:ToString() .. " - currently tracking " .. #self.TrackedUnits .. " monitored units")

    for _, sContactName in pairs(currentContacts) do
        if (self:ContactIsToMonitor(sContactName) and not self:ContactIsTracked(sContactName)) then
            veaf.loggers.get(veafSkynetMonitor.Id):trace("Monitored contact detected: " .. sContactName)
            self:AddTrackedContact(sContactName)
            local err, errmsg = pcall(self.OnDetectedAction, sContactName)
        end
    end

    for _, sContactName in pairs(self.TrackedUnits) do
        if (not tableContains(currentContacts, sContactName)) then
            veaf.loggers.get(veafSkynetMonitor.Id):trace("Monitored contact lost: " .. sContactName)
            self:RemoveTrackedContact(sContactName)
            local err, errmsg = pcall(self.OnLostAction, sContactName)
        end
    end
end

function VeafSkynetMonitorTaskContacts:ContactIsToMonitor(sContactName)
    return self.UnitsToMonitor and tableContains(self.UnitsToMonitor, sContactName)
end

function VeafSkynetMonitorTaskContacts:GetIadsCurrentContacts()
    local currentContacts = {}
    for _, contact in pairs(self.Iads:getContacts()) do
        table.insert(currentContacts, contact:getName())
    end

    return currentContacts
end

function VeafSkynetMonitorTaskContacts:ContactIsTracked(sContactName)
    return tableContains(self.TrackedUnits, sContactName)
end

function VeafSkynetMonitorTaskContacts:AddTrackedContact(sContactName)
    table.insert(self.TrackedUnits, sContactName)
end

function VeafSkynetMonitorTaskContacts:RemoveTrackedContact(sContactName)
    tableRemove(self.TrackedUnits, sContactName)
end

---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
---  VeafSkynetMonitorTaskDescriptor class
---  Named monitoring task to display informations regarding an iads
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
VeafSkynetMonitorTaskDescriptor = {}
VeafSkynetMonitorTaskDescriptor = inheritsFrom(VeafSkynetMonitorTask) -- oop functions are from Skynet

VeafSkynetMonitorTaskDescriptor.OutputDcsTextRecipients = { All = "*All*", Coalition = "*Coalition*" }
---------------------------------------------------------------------------------------------------
---  CTOR
function VeafSkynetMonitorTaskDescriptor:Create(sName, descriptors, sOutputLogLevel, outputDcsTextRecipients)
    local this = self:superClass():Create(sName)
    setmetatable(this, self)
    self.__index = self

    this.Descriptors = descriptors
    this.OutputLogLevel = sOutputLogLevel
    this.OutputDcsTextRecipients = outputDcsTextRecipients

    return this
end

function VeafSkynetMonitorTaskDescriptor:Output(sInformation)
    if (self.OutputLogLevel == "error") then
        veaf.loggers.get(veafSkynetMonitor.Id):error(sInformation)
    elseif (self.OutputLogLevel == "warning") then
        veaf.loggers.get(veafSkynetMonitor.Id):warning(sInformation)
    elseif (self.OutputLogLevel == "info") then
        veaf.loggers.get(veafSkynetMonitor.Id):info(sInformation)
    elseif (self.OutputLogLevel == "debug") then
        veaf.loggers.get(veafSkynetMonitor.Id):debug(sInformation)
    elseif (self.OutputLogLevel == "trace") then
        veaf.loggers.get(veafSkynetMonitor.Id):trace(sInformation)
    end

    if (self.OutputDcsTextRecipients and type(self.OutputDcsTextRecipients) == "table" and #self.OutputDcsTextRecipients > 0) then
        local iDuration = 4
        for _, recipient in pairs(self.OutputDcsTextRecipients) do
            if (recipient == VeafSkynetMonitorTaskDescriptor.OutputDcsTextRecipients.All) then
                trigger.action.outText(sInformation, iDuration)
            elseif (tableContains (coalition.side, recipient)) then
                trigger.action.outTextForCoalition(recipient, sInformation, iDuration)
            else
                local group = Group.getByName(recipient)
                if (group) then
                    trigger.action.outTextForGroup(group.id_, sInformation, iDuration)
                end
            end
        end
    end
end

function VeafSkynetMonitorTaskDescriptor:Execute()
    veaf.loggers.get(veafSkynetMonitor.Id):trace("Executing VeafSkynetMonitorTaskInformations")

    self:Output("----- Task Descriptor [ " .. self.Name .. " ] -----")
    for _, descriptor in pairs(self.Descriptors) do
        local sInformation = descriptor:GetStringDescription()
        self:Output(sInformation)
    end
end

---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
---  Skynet monitoring thread management
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
veafSkynetMonitor._monitoringTasks = {}
veafSkynetMonitor._monitoringThreadId = nil
veafSkynetMonitor._interval = 5 -- iads.contactUpdateInterval

function veafSkynetMonitor.AddMonitoringTask(task)
    if (task == nil) then
        return
    end

    if (task.Name == nil or task.Name == "") then
        veaf.loggers.get(veafSkynetMonitor.Id):error("Monitoring task with incorrect name cannot be added")
        return
    end
    if (veafSkynetMonitor._monitoringTasks[task.Name] ~= nil) then
        veaf.loggers.get(veafSkynetMonitor.Id):error("Monitoring task with name [" .. task.Name .. "] already added")
        return
    end

    veaf.loggers.get(veafSkynetMonitor.Id):trace("Adding monitoring task: " .. task:ToString())
    veafSkynetMonitor._monitoringTasks[task.Name] = task

    if (veafSkynetMonitor._monitoringThreadId == nil) then
        veaf.loggers.get(veafSkynetMonitor.Id):trace("Starting mist thread")
        veafSkynetMonitor._monitoringThreadId = mist.scheduleFunction(veafSkynetMonitor.ExecuteMonitoringTasks, {},
            timer.getTime() + veafSkynetMonitor._interval, veafSkynetMonitor._interval, timer.getTime() + 3600)
    end
end

function veafSkynetMonitor.AddMonitoringTaskContacts(sTaskName, iads, unitsToMonitor, onDetectedAction, onLostAction)
    local task = VeafSkynetMonitorTaskContacts:Create(sTaskName, iads, unitsToMonitor, onDetectedAction, onLostAction)
    veafSkynetMonitor.AddMonitoringTask(task)
end

function veafSkynetMonitor.RemoveMonitoringTask(sTaskName)
    sTaskName = sTaskName or ""
    if (sTaskName ~= "" and veafSkynetMonitor._monitoringTasks[sTaskName]) then
        veaf.loggers.get(veafSkynetMonitor.Id):trace("Removing monitoring task: " .. veafSkynetMonitor._monitoringTasks[sTaskName]:ToString())
        veafSkynetMonitor._monitoringTasks[sTaskName] = nil
    end

    if (veaf.length(veafSkynetMonitor._monitoringTasks) <= 0) then
        veaf.loggers.get(veafSkynetMonitor.Id):trace("Nothing to monitor, stopping mist thread")
        mist.removeFunction(veafSkynetMonitor._monitoringThreadId)
    end
end

function veafSkynetMonitor.ExecuteMonitoringTasks()
    for _, task in pairs(veafSkynetMonitor._monitoringTasks) do
        task:Execute()
    end
end

---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
---  Skynet iads informations
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------

veaf.loggers.get(veafSkynetMonitor.Id):info(string.format("Loading version %s", veafSkynetMonitor.Version))
