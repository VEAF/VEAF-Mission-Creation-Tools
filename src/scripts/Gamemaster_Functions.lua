--Gamemaster_Functions v. 2.1, created by Cake - TaktLwG 66, CTLD-Functions contributed by fargo007

--Start of Config-Section--------------------------------------------------------------------------------------------------------------------------------------------

local DebugMode = false --Toggles the display of status messages, only needed for debugging

local CmdSymbol = "-" --The symbol or string the script looks for to separate the marker text into the command and the different parameters. You can change this to any string or symbol. DO NOT remove the quotation marks! 

local RestrToCoal = nil --restricts the usage of the commands to one coalition only, enter 1 to restrict to red, 2 to restrict to blue, nil allows players from both coalitions to use the commands

local DefaultSkill = "Random" --Default skill of units spawned via the "-s" command, possible values are: Random, Excellent, High, Good, Average. Does NOT override the skill set by the parameter of the "-s" command.

local DefaultCountry = nil --All units spawned via the "-s" and "-sta" command will be spawned as units of the country specified here. For countrynames see documentation. Does NOT override the country set by the parameter of the "-s" command.
                           --Nil defaults to USAF aggressors for all spawns that are included in Gamemaster_Templates. For all other spawns nil defaults to the country set up in the ME. 

local EPLRS = true --Toggles EPLRS (Datalink) for Groups spawned via the "-s" command, true = on, false = off. Gets overriden by the "keep tasking" parameter

local MessageBorderL = ">>>> " --Enter any collection of letters, numbers and/or signs to precede (BorderL) and/or follow (BorderR) Messages sent by the "-text" command. Makes it look nice ;)
local MessageBorderR = " <<<<"

local MessageSound = nil --Sound that plays when a message is sent through the "-text" command, needs to be loaded into the mission at mission start with a trigger using one of the "Sound To .." actions. 
                         --Enter the exact name of the soundfile in the following format: "Filename.ending"! Leave at nil if no sound is meant to be played.

--End of Config, don't change anything below this line, unless you know what you're doing!!!!----------------------------------------------------------------------

_SETTINGS:SetPlayerMenuOff()
    
--Init Variables----------------------------------------------------------------------------------------------------------------------------------------

local deleteZoneNum = 0
local queryZoneNum = 0
local Spawns = {}

--Init Query-Function

local function WhatsThis(param1, mcoord)

  local queryZoneName = string.format("QueryZone %d", queryZoneNum)
  queryZoneNum = queryZoneNum + 1
  local queryRadius = 500
  
  if tonumber(param1) 
    
    then queryRadius = tonumber(param1)

  end  
  
  local queryZone = ZONE_RADIUS:New(queryZoneName, mcoord:GetVec2(), queryRadius)
  queryZone:Scan(Object.Category) 
  local queryTable = queryZone:GetScannedUnits()
  
  for i, unit in pairs(queryTable)
  
   do local scanUName = unit:getName()
      local scanGrName = "No Group"
      local unitCategory = unit:getCategory()
      
      if unitCategory ~= 3 and unitCategory ~= 6 
        then scanGrName = unit:getGroup():getName()
      end  
          
      local queryMarker = MARKER:New(mcoord, "Unit: " .. scanUName .. ", Group: " .. scanGrName)
             
      if RestrToCoal == 1
       then queryMarker:ToCoaliton(coaliton.side.RED)
      elseif RestrToCoal == 2
       then queryMarker:ToCoaliton(coaliton.side.BLUE)
      else queryMarker:ToAll()
      end
      
     break
          
   end
    


end

--Init Flag-Function---------------------------------------------------------------------------------------------------------------------------------

local function UserFlagSet(param1, param2)

  if DebugMode == true
  
    then trigger.action.outText("DEBUG: Flaggen-Funktion aktiv!", 10)
    
  end
  
  local FlagValue = nil
  
  if param2 == "true" then FlagValue = true
  elseif param2 == "false" then FlagValue = false
  elseif tonumber(param2) then FlagValue = param2
  end
  
  trigger.action.setUserFlag(param1, FlagValue)
  
  if DebugMode == true
  
    then trigger.action.outText("DEBUG: Flagge " .. param1 .. " auf Wert " .. param2 .. " gesetzt!", 10)
    
  end
  
end

--Init Flare-Function-----------------------------------------------------------------------------------------------------------------------------------

local function Flare(param1, param2, param3, mcoord)
  
  if DebugMode == true
  
    then trigger.action.outText("DEBUG: Flare-Funktion aktiv!", 10)
    
  end
  
  local flareParams = {}
  
  flareParams.color = nil
  flareParams.counter = nil
  flareParams.hdg = nil
  
  if param2 == "ne" then flareParams.hdg = 45
  elseif param2 == "e" then flareParams.hdg = 90
  elseif param2 == "se" then flareParams.hdg = 135
  elseif param2 == "s" then flareParams.hdg = 180
  elseif param2 == "sw" then flareParams.hdg = 225
  elseif param2 == "w" then flareParams.hdg = 270
  elseif param2 == "nw" then flareParams.hdg = 315
  elseif tonumber(param2) then param3 = param2
  end

  if param1 == "g" then flareParams.color = "Green"
  elseif param1 == "r" then flareParams.color = "Red"
  elseif param1 == "w" then flareParams.color = "White"
  elseif param1 == "y" then flareParams.color = "Yellow"
  end
  
  if param3 ~= nil
  
    then flareParams.counter = tonumber(param3)
    
         local function FlareMult(flareParams)
          
          if flareParams.counter > 0
          
            then flareParams.counter = flareParams.counter - 1
                 mcoord:Flare(FLARECOLOR[flareParams.color], flareParams.hdg)
                 timer.scheduleFunction(FlareMult, flareParams, timer.getTime() + 1)
                 
                 if DebugMode == true
                 
                  then trigger.action.outText("DEBUG: " .. flareParams.counter .. " Flare(s) noch zu schiessen!", 10)
                  
                 end
                 
          end
          
         end
         
         FlareMult(flareParams)
  
  else mcoord:Flare(FLARECOLOR[flareParams.color], flareParams.hdg)
       
       if DebugMode == true
       
        then trigger.action.outText("DEBUG: Einzelne Flare geschossen!", 10)
        
       end
              
  end
  
end

--Init Smoke-Function----------------------------------------------------------------------------------------------------------------------------------------

local function Smoke(param1, param2, mcoord)
  
  if DebugMode == true
  
    then trigger.action.outText("DEBUG: Smoke-Funktion aktiv!", 10)
    
  end
  
  local smokeParams = {}
  
  smokeParams.color = nil
  smokeParams.counter = nil
  
  if param1 == "b" then smokeParams.color = "Blue"
  elseif param1 == "g" then smokeParams.color = "Green"
  elseif param1 == "o" then smokeParams.color = "Orange"
  elseif param1 == "r" then smokeParams.color = "Red"
  elseif param1 == "w" then smokeParams.color = "White"
  end
  
  if tonumber(param2)
    
    then smokeParams.counter = math.floor((tonumber(param2)/5)+0.5)
         
         if DebugMode == true
                 
          then trigger.action.outText("DEBUG: " .. smokeParams.counter .. " mal wird der Rauch noch erneuert!", 10)
                  
         end
         
         mcoord:Smoke(SMOKECOLOR[smokeParams.color])
    
         local function smokeMult(smokeParams)
         
          if smokeParams.counter > 0 
          
            then smokeParams.counter = smokeParams.counter - 1
                 mcoord:Smoke(SMOKECOLOR[smokeParams.color])
                 timer.scheduleFunction(smokeMult, smokeParams, timer.getTime() + 300)

          end
          
         end
         
         timer.scheduleFunction(smokeMult, smokeParams, timer.getTime() + 300)
         
  else mcoord:Smoke(SMOKECOLOR[smokeParams.color])
    
  end
  
  if DebugMode == true
  
    then trigger.action.outText("DEBUG: ".. smokeParams.color .."-Smoke aktiv!", 10)
    
  end
  
end

--Init Explode-Function------------------------------------------------------------------------------------------------------------------------------

local function ExplodeAtMark(param1, param2, param3, mcoord)
 
 if DebugMode == true
  
    then trigger.action.outText("DEBUG: Explosions-Funktion aktiv!", 10)
    
 end
 
 local expDelay = 1
 local expYield = 100
 local expGroup = nil
 
 if param1 ~= nil and GROUP:FindByName(param1) == nil
 
  then if string.find(param1, "d")
 
        then expDelay = tonumber(string.sub(param1, 2))
        
       elseif tonumber(param1)
       
        then expYield = tonumber(param1)
       
       end
       
 end
  
 if param2 ~= nil and GROUP:FindByName(param2) == nil
 
  then if string.find(param2, "d")
  
        then expDelay = tonumber(string.sub(param2, 2))
        
       elseif tonumber(param2)
       
        then expYield = tonumber(param2)
        
       end
  
 end
 
 if param3 ~= nil and GROUP:FindByName(param3) == nil
 
  then if string.find(param3, "d")
  
        then expDelay = tonumber(string.sub(param3, 2))
        
       elseif tonumber(param3)
       
        then expYield = tonumber(param3)
        
       end
  
 end
 
 if GROUP:FindByName(param1) then expGroup = GROUP:FindByName(param1)
 elseif GROUP:FindByName(param2) then expGroup = GROUP:FindByName(param2)
 elseif GROUP:FindByName(param3) then expGroup = GROUP:FindByName(param3)
 end
 
 if expGroup ~= nil
 
  then local expUnits = expGroup:GetUnits()
    
       for i, Victim in pairs(expUnits)
       
        do Victim:Explode(expYield, expDelay)
        
       end
  
 else mcoord:Explosion(expYield, expDelay)
       
 end      

 if DebugMode == true
  
    then trigger.action.outText("DEBUG: Explosion gezuendet! Delay = " .. expDelay .. ", Yield = " .. expYield .. "!", 10)
    
 end

end

--Init Illumination-Function---------------------------------------------------------------------------------------------------------------------------

local function IllumAtMark(param1, param2, mcoord)
 
  if DebugMode == true
  
    then trigger.action.outText("DEBUG: Leuchtgranaten-Funktion aktiv!", 10)
    
 end
 
 if param1 == nil 
 
  then mcoord.y = mcoord.y + 650
 
 else mcoord.y = mcoord.y + param1
 
 end
 
 if param2 == nil 
 
  then param2 = 10000
  
 end
 
 mcoord:IlluminationBomb(param2)

 if DebugMode == true
  
    then trigger.action.outText("DEBUG: Leuchtgranate gezuendet!", 10)
    
 end

end

--Init SmokeFX-Function-------------------------------------------------------------------------------------------------------------------------------

local function FXFireSmoke(param1, param2, mvec3)
  
  if DebugMode == true
  
    then trigger.action.outText("DEBUG: Rauch und Feuer Funktion aktiv!", 10)
    
  end
  
  local SmokePreset = nil
  
  if param1 == "ssf" then SmokePreset = 1
  elseif param1 == "msf" then SmokePreset = 2
  elseif param1 == "lsf" then SmokePreset = 3
  elseif param1 == "hsf" then SmokePreset = 4
  elseif param1 == "ss" then SmokePreset = 5
  elseif param1 == "ms" then SmokePreset = 6
  elseif param1 == "ls" then SmokePreset = 7
  elseif param1 == "hs" then SmokePreset = 8
  end
 
  if param2 ~= nil
    
    then param2 = param2 / 100
    
  end
  
  trigger.action.effectSmokeBig(mvec3, SmokePreset, param2 )
  
  if DebugMode == true
  
    then trigger.action.outText("DEBUG: Es brennt, Modus " .. param1 .. "!", 10)
    
  end

end

--Init Sound-Function--------------------------------------------------------------------------------------------------------------------------------------

local function PlaySound(param1, param2)
  
  if DebugMode == true
  
    then trigger.action.outText("DEBUG: Sound-Funktion aktiv!", 10)
    
  end
  
  if param1 ~= nil
    
    then if param2 ~= nil
    
           then if param2 == "b"
           
                 then trigger.action.outSoundForCoalition(2 ,param1)
                      
                      if DebugMode == true
                        
                        then trigger.action.outText("DEBUG: Sound an Blau gespielt!", 10)
                        
                      end
           
                elseif param2 == "r"
           
                 then trigger.action.outSoundForCoalition(1, param1)
                      
                      if DebugMode == true
                        
                        then trigger.action.outText("DEBUG: Sound an Rot gespielt!", 10)
                        
                      end
           
                elseif string.len(param2) > 1
          
                 then local RecGroup = Group.getByName(param2)
                      local RecID = RecGroup:getID()
                      trigger.action.outSoundForGroup(RecID, param1)
                      
                      if DebugMode == true
                      
                        then trigger.action.outText("DEBUG: Sound an Gruppe " .. RecID .." gespielt!", 10)
                        
                      end
                
                end
                
         else trigger.action.outSound(param1)
              
              if DebugMode == true
              
                then trigger.action.outText("DEBUG: Sound an Alle gespielt!", 10)
                
              end
         
         end 
  
  end
  
end

--Init Text-Function--------------------------------------------------------------------------------------------------------------------

local function ShowText(param1, param2, param3, param4)
  
  if DebugMode == true
  
    then trigger.action.outText("DEBUG: Text-Funktion aktiv!", 10)
    
  end
  
  if param1 ~= nil
    
    then local coalition = nil
         local clearView = false
         local DispTime = 15
         local RecGroup = nil
         
         if param2 == "b" or param3 == "b" or param4 == "b"
         
          then coalition = 2
               
               if param2 == "b" then param2 = nil
               elseif param3 == "b" then param3 = nil
               elseif param4 == "b" then param4 = nil
               end
               
          
         elseif param2 == "r" or param3 == "r" or param4 == "r"
         
          then coalition = 1
          
               if param2 == "r" then param2 = nil
               elseif param3 == "r" then param3 = nil
               elseif param4 == "r" then param4 = nil
               end
          
         end
         
         if param2 ~= nil and Group.getByName(param2) 
            then RecGroup = Group.getByName(param2)
                 param2 = nil
         elseif param3 ~= nil and Group.getByName(param3) 
            then RecGroup = Group.getByName(param3)
                 param3= nil
         elseif param4 ~= nil and Group.getByName(param4) 
            then RecGroup = Group.getByName(param4)
                 param4 = nil
         end
         
         if tonumber(param2) then DispTime = param2
         elseif tonumber(param3) then DispTime = param3
         elseif tonumber(param4) then DispTime = param4
         end
         
         if param2 == "c" or param3 == "c" or param4 == "c"

           then clearView = true
                
                if param2 == "c" then param2 = nil
                elseif param3 == "c" then param3 = nil
                elseif param4 == "c" then param4 = nil
                end
         end
         
         
                    
         if coalition ~= nil 
         
          then trigger.action.outTextForCoalition(coalition, MessageBorderL .. param1 .. MessageBorderR, DispTime, clearView)
           
                  if DebugMode == true
                  
                    then trigger.action.outText("DEBUG: Text an Koalition " .. coalition .. " ausgegeben!", 10)
                    
                  end
                  
                  if MessageSound ~= nil
                  
                    then trigger.action.outSoundForCoalition(coalition, MessageSound)
                  
                  end
           
         elseif  RecGroup ~= nil
          
                  then local RecID = RecGroup:getID()
                       trigger.action.outTextForGroup(RecID, MessageBorderL .. param1 .. MessageBorderR, DispTime, clearView)
                       
                       if DebugMode == true
                       
                        then trigger.action.outText("DEBUG: Text an Gruppe " .. RecID .." ausgegeben!", 10)
                        
                       end
                       
                       if MessageSound ~= nil
                  
                          then trigger.action.outSoundForGroup(RecID, MessageSound)
                  
                       end
            
         else trigger.action.outText(MessageBorderL .. param1 .. MessageBorderR, DispTime, clearView)
              
              if DebugMode == true
              
                then trigger.action.outText("DEBUG: Text an Alle ausgegeben!", 10)
                
              end
              
              if MessageSound ~= nil
                  
                then trigger.action.outSound(MessageSound)
                  
              end
      
         end
      
  end
  
end

--Init Invisible-Function---------------------------------------------------------------------------------------------------------------------------------

local function SetInvisible(param1, param2)

  
  if DebugMode == true
  
    then trigger.action.outText("DEBUG: Invisible-Funktion aktiv!", 10)
    
  end
    
  if param2 == "on"
  
    then param2 = true
    
  elseif param2 == "off"
  
    then param2 = false
    
  end
  
  local InvGroup = nil
    
  if Group.getByName(param1)
  
    then InvGroup = Group.getByName(param1)
         
         local InvCommand = { id = 'SetInvisible', 
                              params = { value = param2 } }
                              
         InvGroup:getController():setCommand(InvCommand)
         
         if DebugMode == true
         
          then trigger.action.outText("DEBUG: Invisible-Befehl an Gruppe " .. InvGroup:getName() .. " gesendet!", 10)
          
         end
  
  end    
  
end

--Init Immortal-Function-----------------------------------------------------------------------------------------------------------------------------------

local function SetImmortal(param1, param2)
  
  if DebugMode == true
    
    then trigger.action.outText("DEBUG: Immortal-Funktion aktiv!", 10)
    
  end
    
  if param2 == "on"
  
    then param2 = true
    
  elseif param2 == "off"
  
    then param2 = false
    
  end
  
  local ImmGroup = nil
    
  if Group.getByName(param1)
  
    then ImmGroup = Group.getByName(param1)
         
         local ImmCommand = { id = 'SetImmortal', 
                              params = { value = param2 } }
                              
         ImmGroup:getController():setCommand(ImmCommand)
         
         if DebugMode == true
         
          then trigger.action.outText("DEBUG: Immortal-Befehl an Gruppe " .. ImmGroup:getName() .. " gesendet!", 10)
          
         end
  
  end    
  
end

--Init AI-Togglefunction------------------------------------------------------------------------------------------------------------------------------

local function ToggleAI(param1, param2)
  
  if DebugMode == true
    
    then trigger.action.outText("DEBUG: KI-Togglefunktion aktiv!", 10)
    
  end
    
  if param2 == "on"
  
    then param2 = true
    
  elseif param2 == "off"
  
    then param2 = false
    
  end
  
  local AIMGroup = nil
    
  if Group.getByName(param1)
  
    then AIMGroup = GROUP:FindByName(param1)
                              
         AIMGroup:SetAIOnOff(param2)
         
         if DebugMode == true
         
          then trigger.action.outText("DEBUG: KI der Gruppe " .. param1 .. " umgeschaltet!", 10)
          
         end
  
  end    
  
end

--Init Pickup-Function---------------------------------------------------------------------------------------------------------------------------

local function CargoPickup(param1, param2, mcoord)

  if DebugMode == true
 
    then trigger.action.outText("DEBUG: Pickup-Funktion aktiv!", 10)
  
  end
  
  if GROUP:FindByName(param2)
  
    then local CarrierGrp = GROUP:FindByName(param2)
         local LoadObject = CARGO:FindByName(param1)
  
         if LoadObject:CanBoard()
         
          then LoadObject:Board(CarrierGrp, 10)
          
         elseif LoadObject:CanLoad()
         
          then LoadObject:Load(CarrierGrp)
         
         end
                        
         if DebugMode == true
 
            then trigger.action.outText("DEBUG: Gruppe " .. param1 .. " wird eingeladen in Transporter " .. param2 .. " !", 10)
  
         end
  
  end
  
end

--Init Unload-Function---------------------------------------------------------------------------------------------------------------------------

local function CargoDrop(param1, mcoord)

  if DebugMode == true
 
    then trigger.action.outText("DEBUG: Aussteige-Funktion aktiv!", 10)
  
  end
  
  if CARGO:FindByName(param1)
  
    then local DropObject = CARGO:FindByName(param1)
    
         if DropObject:CanUnboard()
         
          then DropObject:UnBoard(mcoord)
          
         elseif DropObject:CanUnload()
         
          then DropObject:UnLoad(mcoord) 
             
         end
                        
         if DebugMode == true
 
          then trigger.action.outText("DEBUG: Gruppe " .. param1 .. " steigt aus!", 10)
  
         end
          
  end
  
end

--Init RTB-Function----------------------------------------------------------------------------------------------------------------------------------

local function AIReturnToBase(param1, param2, mcoord)

  if DebugMode == true
 
    then trigger.action.outText("DEBUG: RTB-Funktion aktiv!", 10)
  
  end
  
  local AItoRTB = nil
  local RTBSpeed = nil
  local RTBAirfield = nil
  
  if GROUP:FindByName(param1)
  
    then AItoRTB = GROUP:FindByName(param1)
          
         if tonumber(param2)
  
          then RTBSpeed = UTILS.KnotsToKmph(param2)
          
          else RTBSpeed = AItoRTB:GetVelocityKMH()
          
         end
  
         RTBAirfield = mcoord:GetClosestAirbase()
         
         if RTBAirfield ~= nil 
         
          then AItoRTB:RouteRTB(RTBAirfield, RTBSpeed)
         
         end
         
         if DebugMode == true
 
          then trigger.action.outText("DEBUG: Gruppe " .. param1 .. " geht RTB!", 10)
  
         end
         
  end

end

--Init Helicopter LZ Function-----------------------------------------------------------------------------------------------------------------------------

local function HeloLand(param1, param2, mcoord)

  if DebugMode == true
  
    then trigger.action.outText("DEBUG: Helikopter-Landefunktion aktiv!", 10)
  
 end

  if GROUP:FindByName(param1)

    then local AIHelo = GROUP:FindByName(param1)
         local LZVec2 = mcoord:GetVec2()
         local DTime = 120
       
         if tonumber(param2)
       
          then DTime = tonumber(param2)
        
         end
       
         local LandingTask = AIHelo:TaskLandAtVec2(LZVec2, DTime)
         AIHelo:SetTask(LandingTask, 1)
       
         if DebugMode == true
 
          then trigger.action.outText("DEBUG: Gruppe " .. param1 .. " landet!", 10)
  
         end
       
  
  end

end

--Init Waypoint-Function-------------------------------------------------------------------------------------------------------------------------------

local function RouteAI(param1, param2, param3, param4, mcoord)
 
 if DebugMode == true
 
  then trigger.action.outText("DEBUG: Wegpunkt-Funktion aktiv!", 10)
  
 end
 
 local AIDesc = Group.getByName(param1):getUnit(1):getDesc()
 local AIMGroup = GROUP:FindByName(param1)
 local AIRoute = nil
 
 if AIDesc.category == 3
  
  then if mcoord:GetSurfaceType() == 2 or mcoord:GetSurfaceType() == 3 
  
        then local mvec2 = POINT_VEC2:New(mcoord.x, mcoord.y, mcoord.z)
             AIRoute = AIMGroup:RouteToVec2(mvec2, param2)
       
       end
 
 elseif AIDesc.category == 2
 
  then if mcoord:GetSurfaceType() ~= 2 and mcoord:GetSurfaceType() ~= 3
  
        then local UseRoad = false
             local TrSpeed = 20
             local Form = nil
             
             if param2 == "road" or param3 == "road" or param4 == "road" 
             
              then UseRoad = true

             end
             
             if tonumber(param2) then TrSpeed = param2
             elseif tonumber(param3) then TrSpeed = param3
             elseif tonumber(param4) then TrSpeed = param4 
             end
             
             if param2 == "v" or param3 == "v" or param4 == "v" then Form = "Vee"
             elseif param2 == "c" or param3 == "c" or param4 == "c" then Form = "Cone"
             elseif param2 == "d" or param3 == "d" or param4 == "d" then Form = "Diamond"
             elseif param3 == "r" or param3 == "r" or param4 == "r" then Form = "Rank"
             elseif param3 == "el" or param3 == "el" or param4 == "el" then Form = "EchelonL"
             elseif param3 == "er" or param3 == "er" or param4 == "er" then Form = "EchelonR"
             end
             
             if UseRoad == true 
             
              then AIRoute = AIMGroup:RouteGroundOnRoad(mcoord, TrSpeed, 1, "OFF_ROAD")
              
             else AIRoute = AIMGroup:RouteGroundTo(mcoord, TrSpeed, Form, 1)
             
             end
             

             
       end
 
 end
 
 AIMGroup:SetTask(AIRoute, 1)
 
 if DebugMode == true
 
  then trigger.action.outText("DEBUG: WP fuer Gruppe " .. param1 .. " zugewiesen!", 10)
  
 end
 
end

--Init Orbit-Function--------------------------------------------------------------------------------------------------------------------------

local function Orbit(param1, param2, param3, param4, mcoord)
  
  if DebugMode == true
  
    then trigger.action.outText("DEBUG: Orbit-Funktion aktiv!", 10)
  
  end
  
  local Orbiter = GROUP:FindByName(param1)
  local OrbiterVec3 = Orbiter:GetPositionVec3()
  local OrbiterCoord = COORDINATE:NewFromVec3(OrbiterVec3)
  
  if param4 == "r"
  
    then local OrbitTask = Orbiter:TaskOrbit(OrbiterCoord, param2, param3 / 1.94, mcoord)
         Orbiter:SetTask(OrbitTask, 1)
         
         if DebugMode == true
         
          then trigger.action.outText("DEBUG: Racetrack-Orbit fuer Gruppe " .. param1 .. " zugewiesen!", 10)
        
         end
        
  else local OrbitTask = Orbiter:TaskOrbit(mcoord, param2, param3 / 1.94)
       Orbiter:SetTask(OrbitTask, 1)
        
        if DebugMode == true
         
          then trigger.action.outText("DEBUG: Orbit fuer Gruppe " .. param1 .. " zugewiesen!", 10)
        
        end
        
  end

end

--Init Escort-Function--------------------------------------------------------------------------------------------------------------------------------------

local function AirEscortAI(param1, param2, param3, mcoord)
  
  if DebugMode == true
         
    then trigger.action.outText("DEBUG: Eskorten-Funktion aktiv!", 10)
        
  end
  
  local AirEscort = GROUP:FindByName(param1)
  local AirEscorted = GROUP:FindByName(param2)
  local AirEscortOffset = POINT_VEC3:New( -100, 0 , 100 )
  local AirEscortER = 83340
  
  if param3 ~= nil
    
    then AirEscortER = param3 * 1852
  
  end
  
  local AirEscortTask = AirEscort:TaskEscort(AirEscorted, AirEscortOffset, nil, AirEscortER, {"Air"} )
  AirEscort:SetTask( AirEscortTask, 2)
  
  if DebugMode == true
  
    then trigger.action.outText("DEBUG: Eskorte zugewiesen!", 10)
    
  end

end

--Init Delete-Function-----------------------------------------------------------------------------------------------------------------------------

local function Delete(param1, mcoord)
  
  if DebugMode == true
  
    then trigger.action.outText("DEBUG: Loeschen-Funktion aktiv!", 10)
    
  end
  
  if param1 == nil or tonumber(param1)
  
    then if param1 == nil
    
          then param1 = 100
         
         end
   
         local deleteZoneName = string.format("DeleteZone %d", deleteZoneNum)
         deleteZoneNum = deleteZoneNum + 1
  
         local deleteZone = ZONE_RADIUS:New(deleteZoneName, mcoord:GetVec2(), param1)
         deleteZone:Scan(Object.Category) 
         local deleteTable = deleteZone:GetScannedUnits()
  
         for i, unit in pairs(deleteTable)
  
          do if unit:getPlayerName() == nil 
      
              then unit:destroy()
        
             end
    
             if DebugMode == true
    
              then trigger.action.outText("DEBUG: Eine Einheit/Static wurde geloescht!", 10)
      
             end
  
         end
  
  elseif Group.getByName(param1)
  
    then local DestroyGroup = Group.getByName(param1)
         DestroyGroup:destroy()
         
         if DebugMode == true
    
          then trigger.action.outText("DEBUG: Eine Gruppe wurde geloescht!", 10)
      
         end
         
  end
  
end

--Init Control Toggle Function----------------------------------------------------------------------------------------------------------------------------

local function ControlToggle(param1)

  if DebugMode == true
    
    then trigger.action.outText("Control-Toggle-Funktion aktiv", 10)
         trigger.action.outText("Param1 = " .. param1 .. " !", 10)
    
  end
    
  if GROUP:FindByName(param1)
         
   then local UctGroup = GROUP:FindByName(param1)
        UctGroup:RespawnAtCurrentAirbase(nil, SPAWN.Takeoff.Cold, false)
        
        if DebugMode == true
    
          then trigger.action.outText("Gruppe " .. param1 .. " mit Pilot neu gespawnt!", 10)
    
        end
        
  end

end

--Init Late Activation Function----------------------------------------------------------------------------------------------------------------------------

local function LateActivate(param1)
  
  if DebugMode == true
  
    then trigger.action.outText("DEBUG: Late Activation Funktion aktiv!", 10)
    
  end
  
  if Group.getByName(param1)
  
    then local ActGroup = Group.getByName(param1)
         trigger.action.activateGroup(ActGroup)
         
         if DebugMode == true
         
          then trigger.action.outText("DEBUG: Gruppe " .. param1 .. " aktiviert!", 10)
          
         end
         
  end

end

--Init Static Spawn Function----------------------------------------------------------------------------------------------------------------------------------

local function StaticSpawn(param1, param2, param3, param4, mcoord)

  if DebugMode == true
  
    then trigger.action.outText("DEBUG: Static Spawn-Funktion aktiv!", 10)
    
  end
  
  local StaOriCountry = nil
  local StaOriCountryID = nil
  local StaSetCountry = nil
  local StaSpawnObject = nil
  local StaHeading = nil
  local StaIsCargo = nil
  local StaticSpawn = nil
  
  if StaticObject.getByName(param1)
  
    then if DefaultCountry == nil 
         
          then StaOriCountryID = StaticObject.getByName(param1):getCountry()
               StaOriCountry = country.name[StaOriCountryID]
               
         else StaOriCountryID = country.id[DefaultCountry]
              StaOriCountry = DefaultCountry
         
         end
         
         if DebugMode == true
  
          then trigger.action.outText("DEBUG: LandID = " .. StaOriCountryID .. ", Landname =  " .. StaOriCountry, 10)
    
         end
         
         if country.id[param2] ~= nil then StaSetCountry = country.id[param2]
         elseif country.id[param3] ~= nil then StaSetCountry = country.id[param3]
         elseif country.id[param4] ~= nil then StaSetCountry = country.id[param4]
         else StaSetCountry = country.id[StaOriCountry]
         end
         
         if tonumber(param2) then StaHeading = tonumber(param2)
         elseif tonumber(param3) then StaHeading = tonumber(param3)
         elseif tonumber(param4) then StaHeading = tonumber(param4)
         end
         
         if param2 == "cargo" or param3 == "cargo" or param4 == "cargo"
  
          then StaIsCargo = true
    
         end
    
         if Spawns[param1] == nil 
    
          then Spawns[param1] = SPAWNSTATIC:NewFromStatic(param1, StaSetCountry)
  
         end
         
         StaSpawnObject = Spawns[param1]     
         StaSpawnObject:InitCountry(StaSetCountry)
         
         if DebugMode == true
                      
          then trigger.action.outText("DEBUG: Land auf " .. StaSetCountry .. " gesetzt!", 10)
                      
         end
         
         StaticSpawn = StaSpawnObject:SpawnFromCoordinate(mcoord, StaHeading)
         
         if StaIsCargo == true
                   
          then local StaCargoName = StaticSpawn:GetName()
               local StaCargo = CARGO_CRATE:New(StaticSpawn, "Static", StaCargoName, 500, 500)                     
                         
         end
         
  end       

end

--Init spawn function for CTLD crates (Contribution by fargo007)------------------------------------------------------------------------------------------------

local function SpawnCTLDCrate(param1, param2, mcoord)
 
  if DebugMode == true
  
    then trigger.action.outText("DEBUG: Spawn-Funktion CTLD-Kisten aktiv!", 10)
    
  end
  
  if ctld ~= nil 
  
    then param2 = tonumber(param2)
    
         ctld.spawnCrateAtPoint(param1, param2, mcoord)
    
  end
  
end

--Init spawn function for CTLD extractable groups (Contribution by fargo007)-----------------------------------------------------------------------------------

local function SpawnExtractableCTLD(param1, param2, param3, mcoord)

  if DebugMode == true
  
    then trigger.action.outText("DEBUG: Spawn-Funktion CTLD-Gruppen aktiv!", 10)
    
  end

  if ctld ~= nil 
  
    then param2 = tonumber(param2)
         param3 = tonumber(param3)
    
         ctld.spawnGroupAtPoint(param1, param2, mcoord, param3)
  
  end
  
end

--Init Spawn-Function-----------------------------------------------------------------------------------------------------------------------------------------
    
local function Spawn(param1, param2, param3, param4, param5, param6, mcoord)
    
  if DebugMode == true
  
    then trigger.action.outText("DEBUG: Spawn-Funktion aktiv!", 10)
    
  end
  
  local SpawnObject = nil
  local SpawnGroupDCS = nil
  local SpawnCat = nil
  local OriCountryID = nil
  local OriCountry = nil
  local KeepTasking = false
  local NoMarkSp = false
  local AirbaseSpawn = false
  local IsCargo = false
  local SetCountry = nil
  local SpawnAlt = nil
  local SetSkill = DefaultSkill
  
  if Group.getByName(param1)
  
    then SpawnGroupDCS = Group.getByName(param1)
         SpawnCat = SpawnGroupDCS:getCategory()
         
         if DefaultCountry == nil 
         
          then OriCountryID = SpawnGroupDCS:getUnit(1):getCountry()
               OriCountry = country.name[OriCountryID]
               
         else OriCountryID = country.id[DefaultCountry]
              OriCountry = DefaultCountry
         
         end
         
         if DebugMode == true
  
          then trigger.action.outText("DEBUG: LandID = " .. OriCountryID .. ", Landname =  " .. OriCountry, 10)
    
         end
         
  end
  
  if Spawns[param1] == nil 
    
    then Spawns[param1] = SPAWN:New(param1)
  
  end
  
  SpawnObject = Spawns[param1]
  
  if param2 == "kt" or param3 == "kt" or param4 == "kt" or param5 == "kt"
  
    then KeepTasking = true
    
  end
  
  if param2 == "op" or param3 == "op" or param4 == "op" or param5 == "op" or param6 == "op"
  
    then NoMarkSp = true
    
  end
  
  if param2 == "ground" or param3 == "ground" or param4 == "ground" or param5 == "ground" or param6 == "ground"
  
    then AirbaseSpawn = true
    
  end
  
  if param2 == "cargo" or param3 == "cargo" or param4 == "cargo" or param5 == "cargo" or param6 == "cargo"
  
    then IsCargo = true
    
  end
  
  if tonumber(param2) then SpawnAlt = param2  
  elseif tonumber(param3) then SpawnAlt = param3
  elseif tonumber(param4) then SpawnAlt = param4
  elseif tonumber(param5) then SpawnAlt = param5
  elseif tonumber(param6) then SpawnAlt = param6 
  end
  
  if country.id[param2] ~= nil then SetCountry = country.id[param2]
  elseif country.id[param3] ~= nil then SetCountry = country.id[param3]
  elseif country.id[param4] ~= nil then SetCountry = country.id[param4]
  elseif country.id[param5] ~= nil then SetCountry = country.id[param5]
  elseif country.id[param6] ~= nil then SetCountry = country.id[param6]
  elseif DefaultCountry ~= nil then SetCountry = country.id[DefaultCountry]
  end
  
  if param2 == "a" or param3 == "a" or param4 == "a" or param5 == "a" or param6 == "a" then SetSkill = "Average"
  elseif param2 == "g" or param3 == "g" or param4 == "g" or param5 == "g" or param6 == "g" then SetSkill = "Good"
  elseif param2 == "h" or param3 == "h" or param4 == "h" or param5 == "h" or param6 == "h" then SetSkill = "High"
  elseif param2 == "e" or param3 == "e" or param4 == "e" or param5 == "e" or param6 == "e" then SetSkill = "Excellent"
  elseif param2 == "r" or param3 == "r" or param4 == "r" or param5 == "r" or param6 == "r" then SetSkill = "Random"
  end
  
  if SetCountry ~= nil 
         
   then SpawnObject:InitCountry(SetCountry)
          
        if DebugMode == true
                      
          then trigger.action.outText("DEBUG: Land auf " .. SetCountry .. " gesetzt!", 10)
                      
        end
          
  end
  
  if SetSkill ~= nil
  
    then SpawnObject:InitSkill(SetSkill)
    
         if DebugMode == true
                      
          then trigger.action.outText("DEBUG: Skill auf " .. SetSkill .. " gesetzt!", 10)
                      
         end
         
  end
  
  if SpawnCat < 2
  
    then if SpawnAlt == nil
    
          then mcoord.y = mcoord.y + 1000
          
               if DebugMode == true
                      
                then trigger.action.outText("DEBUG: Flughoehe auf Standard gesetzt!", 10)
                      
               end
         
         elseif SpawnAlt ~= nil 
         
           then mcoord.y = SpawnAlt   
           
                if DebugMode == true
                      
                 then trigger.action.outText("DEBUG: Flughoehe auf " .. mcoord.y .. " gesetzt!", 10)
                     
                end
                
         end
         
         local AIPlane = nil
         
         if NoMarkSp == true 
         
            then AIPlane = SpawnObject:Spawn()
            
         else AIPlane = SpawnObject:SpawnFromCoordinate(mcoord)
         
         end
         
         if AIPlane ~= nil and AirbaseSpawn == true
         
          then local function ABReSpawn(AIPlane)
               
                  AIPlane:RespawnAtCurrentAirbase(nil, SPAWN.Takeoff.Cold, true)
        
                  if DebugMode == true
    
                    then trigger.action.outText("Gruppe " .. AIPlane:GetName() .. " ohne Pilot am Boden gespawnt!", 10)
    
                  end 
               
               end
                
               timer.scheduleFunction(ABReSpawn, AIPlane, timer.getTime() + 0.25)
 
         elseif AIPlane ~= nil and KeepTasking ~= true
         
          then local PlanePosVec3 = AIPlane:GetPositionVec3()
               local PlanePosCoord = COORDINATE:NewFromVec3(PlanePosVec3)
               local AITaskCAP = AIPlane:TaskOrbitCircle( mcoord.y, 250, PlanePosCoord )
               AIPlane:SetTask( AITaskCAP, 1 )
               
               if EPLRS == true
                         
                then AIPlane:CommandEPLRS(true, 2)
                          
               end
               
         end
               
  elseif SpawnCat == 2
       
       then if mcoord:GetSurfaceType() ~= 2 and mcoord:GetSurfaceType() ~= 3  
              
              then local SpawnHeading = SpawnAlt
                   
                   if SpawnHeading ~= nil
                   
                    then SpawnObject:InitHeading(SpawnHeading, SpawnHeading)
                    
                   end
                   
                   local AIGround = nil                 
      
                   if NoMarkSp ~= true
                       
                     then AIGround = SpawnObject:SpawnFromCoordinate(mcoord)
                    
                   else AIGround = SpawnObject:Spawn()
                            
                   end
                   
                   if KeepTasking ~= true
                   
                    then local AIHold = AIGround:TaskHold()
                         AIGround:SetTask(AIHold, 1)
                         
                         if EPLRS == true
                         
                          then AIGround:CommandEPLRS(true, 2)
                          
                         end
                    
                   end         
                   
                   if IsCargo == true
                   
                    then local CargoName = AIGround:GetName()
                         local CargoGroup = CARGO_GROUP:New(AIGround, "Mobile", CargoName, 500, 5)
                         
                         if CargoGroup:GetCoalition() == 1 and ctld ~= nil --CTLD integration starts here
                         
                          then table.insert(ctld.droppedTroopsRED, CargoGroup:GetObjectName())
                          
                         elseif CargoGroup:GetCoalition() == 2 and ctld ~= nil
                         
                          then table.insert(ctld.droppedTroopsBLUE, CargoGroup:GetObjectName())
                          
                         end                         
                         
                   end
  
            end
          
  elseif SpawnCat == 3
        
        then if mcoord:GetSurfaceType() == 2 or mcoord:GetSurfaceType() == 3
  
              then local AIShip = nil
                   local SpawnHeading = SpawnAlt
                   
                   if SpawnHeading ~= nil
                   
                    then SpawnObject:InitHeading(SpawnHeading, SpawnHeading)
                    
                   end
                   
                   if NoMarkSp ~= true 
                   
                    then AIShip = SpawnObject:SpawnFromCoordinate(mcoord)
                    
                   else AIShip = SpawnObject:Spawn()
                   
                   end
                   
                   if KeepTasking ~= true
                   
                    then local AIHold = AIShip:TaskHold()
                         AIShip:SetTask(AIHold, 1)
                         
                         if EPLRS == true
                         
                          then AIShip:CommandEPLRS(true, 2)
                          
                         end
                    
                   end
         
             end
  
  end         
  
  SpawnObject:InitCountry(country.id[OriCountry])
  
end
    
--Init Eventhandler for Marks----------------------------------------------------------------------------------------------------------------
    
local MarkHandler = {}
    
function MarkHandler:onEvent(event)
    
    if event.id == 25
    
        then trigger.action.outText(" ", 0, true) --Überschreibt "Created New Mark" 
    
    elseif event.id == 27 and string.find(event.text, CmdSymbol)
    
        then if event.coalition == RestrToCoal or RestrToCoal == nil
        
                then local full = nil
                     local remString = nil
                     local cmd = nil
                     local param1 = nil
                     local param1Start = nil
                     local param2 = nil
                     local param2Start = nil
                     local param3 = nil
                     local param3Start = nil
                     local param4 = nil
                     local param4Start = nil
                     local param5 = nil
                     local param5Start = nil
                     local param6 = nil
                     local param6Start = nil
                     local mcoord = COORDINATE:New(event.pos.x, event.pos.y, event.pos.z)
                     local mvec3 = event.pos
             
                     full = string.sub(event.text, 2)
             
                     if string.find(full, CmdSymbol)
             
                      then param1Start = string.find(full, CmdSymbol)
                           cmd = string.sub(full, 0, param1Start-1)
                           remString = string.sub(full, param1Start+1)
                     
                           if string.find(remString, CmdSymbol)
                     
                            then param2Start = string.find(remString, CmdSymbol)
                                 param1 = string.sub(remString, 0, param2Start-1)
                                 remString = string.sub(remString, param2Start+1)
                             
                                 if string.find(remString, CmdSymbol)
                             
                                  then param3Start = string.find(remString, CmdSymbol)
                                       param2 = string.sub(remString, 0, param3Start-1)
                                       remString = string.sub(remString, param3Start+1)
                                     
                                       if string.find(remString, CmdSymbol)
                                     
                                        then param4Start = string.find(remString, CmdSymbol)
                                             param3 = string.sub(remString, 0, param4Start-1)
                                             remString = string.sub(remString, param4Start+1)
                                             
                                             if string.find(remString, CmdSymbol)
                                     
                                                then param5Start = string.find(remString, CmdSymbol)
                                                     param4 = string.sub(remString, 0, param5Start-1)
                                                     remString = string.sub(remString, param5Start+1)
                                                     
                                                     if string.find(remString, CmdSymbol)
                                     
                                                       then param6Start = string.find(remString, CmdSymbol)
                                                            param5 = string.sub(remString, 0, param6Start-1)
                                                            param6 = string.sub(remString, param6Start+1)
                                                            
                                                     else param5 = remString
                                                     
                                                     end
                                                     
                                             else param4 = remString
                                             
                                             end     
                                     
                                       else param3 = remString
                                     
                                       end
                                                                     
                                 else param2 = remString
                                
                                 end
                             
                           else param1 = remString
                        
                           end
                
                     else cmd = full
                
                     end
             
                     if DebugMode == true
             
                     then trigger.action.outText("Voller Text = " .. full, 10)
                          trigger.action.outText("Befehl = " .. cmd, 10)
                          if param1 ~= nil then trigger.action.outText("Parameter1 = " .. param1, 10) end
                          if param2 ~= nil then trigger.action.outText("Parameter2 = " .. param2, 10) end
                          if param3 ~= nil then trigger.action.outText("Parameter3 = " .. param3, 10) end
                          if param4 ~= nil then trigger.action.outText("Parameter4 = " .. param4, 10) end
                          if param5 ~= nil then trigger.action.outText("Parameter5 = " .. param5, 10) end
                          if param6 ~= nil then trigger.action.outText("Parameter6 = " .. param6, 10) end
                          
                     end  
             
                     if string.find(cmd, "del")
              
                      then if DebugMode == true
              
                            then trigger.action.outText("DEBUG: Loeschen-Funktion gestartet!", 10)
                    
                           end
                   
                           Delete(param1, mcoord)
                   
                     elseif string.find(cmd, "flag")
             
                      then if DebugMode == true 
              
                            then trigger.action.outText("DEBUG: Flaggen-Funktion gestartet!", 10)
                    
                           end
                   
                           UserFlagSet(param1, param2)
                           
                     elseif string.find(cmd, "ctrlon")
             
                      then if DebugMode == true 
              
                            then trigger.action.outText("DEBUG: Control-Toggle-Funktion gestartet!", 10)
                    
                           end
                   
                           ControlToggle(param1)
             
                     elseif string.find(cmd, "sound")
             
                      then if DebugMode == true 
              
                            then trigger.action.outText("DEBUG: Sound-Funktion gestartet!", 10)
                    
                           end
                   
                           PlaySound(param1, param2)
              
                     elseif string.find(cmd, "text")
             
                      then if DebugMode == true 
              
                            then trigger.action.outText("DEBUG: Text-Funktion gestartet!", 10)
                    
                           end
                   
                           ShowText(param1, param2, param3, param4)
                   
                     elseif string.find(cmd, "flare")
             
                      then if DebugMode == true
              
                            then trigger.action.outText("DEBUG: Flare-Funktion gestartet!", 10)
                    
                           end
                    
                           Flare(param1, param2, param3, mcoord)
                   
                     elseif string.find(cmd, "smoke")
             
                      then if DebugMode == true
              
                            then trigger.action.outText("DEBUG: Smoke-Funktion gestartet!", 10)
                    
                           end
                   
                           Smoke(param1, param2, mcoord)
                   
                     elseif string.find(cmd, "exp")
             
                      then if DebugMode == true
              
                            then trigger.action.outText("DEBUG: Explode-Funktion gestartet!", 10)
                    
                           end
                   
                           ExplodeAtMark(param1, param2, param3, mcoord)
                   
                     elseif string.find(cmd, "illum")
             
                      then if DebugMode == true
              
                            then trigger.action.outText("DEBUG: Leuchtgranaten-Funktion gestartet!", 10)
                    
                           end
                   
                           IllumAtMark(param1, param2, mcoord)
                   
                     elseif string.find(cmd, "sf")
             
                      then if DebugMode == true
              
                            then trigger.action.outText("DEBUG: Rauch und Feuer Funktion gestartet!", 10)
                    
                           end
                   
                           FXFireSmoke(param1, param2, mvec3)
             
                     elseif string.find(cmd, "inv")
              
                      then if DebugMode == true
              
                            then trigger.action.outText("DEBUG: Invisible-Funktion gestartet!", 10)
                    
                           end
                   
                           SetInvisible(param1, param2)
                   
                     elseif string.find(cmd, "imm")
              
                      then if DebugMode == true
              
                            then trigger.action.outText("DEBUG: Invincible-Funktion gestartet!", 10)
                    
                           end
                   
                           SetImmortal(param1, param2)
                   
                     elseif string.find(cmd, "ai")
             
                      then if DebugMode == true
                    
                            then trigger.action.outText("DEBUG: KI-Togglefunktion gestartet!", 10)
                    
                           end
                   
                           ToggleAI(param1, param2, mcoord) 
                                
                     elseif string.find(cmd, "wp")
             
                      then if DebugMode == true
                    
                            then trigger.action.outText("DEBUG: Wegpunkt-Funktion gestartet!", 10)
                    
                           end
                   
                           RouteAI(param1, param2, param3, param4, mcoord)
                   
                     elseif string.find(cmd, "rtb")
             
                      then if DebugMode == true
                    
                            then trigger.action.outText("DEBUG: RTB-Funktion gestartet!", 10)
                    
                           end
                   
                           AIReturnToBase(param1, param2, mcoord)
                   
                     elseif string.find(cmd, "lz")
             
                      then if DebugMode == true
                    
                            then trigger.action.outText("DEBUG: Helikopter-Landefunktion gestartet!", 10)
                    
                           end
                   
                           HeloLand(param1, param2, mcoord)      
             
                     elseif string.find(cmd, "orbit")
             
                      then if DebugMode == true
                    
                            then trigger.action.outText("DEBUG: Orbit-Funktion gestartet!", 10)
                    
                           end
                   
                           Orbit(param1, param2, param3, param4, mcoord)
              
                     elseif string.find(cmd, "esc")
             
                      then if DebugMode == true
                    
                            then trigger.action.outText("DEBUG: Eskorten-Funktion gestartet!", 10)
                    
                           end
                   
                           AirEscortAI(param1, param2, param3, mcoord)
                   
                     elseif string.find(cmd, "unboard")
             
                      then if DebugMode == true
                    
                            then trigger.action.outText("DEBUG: Aussteige-Funktion, mobile Gruppe gestartet!", 10)
                    
                           end
                   
                           CargoDrop(param1, mcoord)
                   
                     elseif string.find(cmd, "board")
             
                      then if DebugMode == true
                    
                            then trigger.action.outText("DEBUG: Pickup-Funktion, mobile Gruppe gestartet!", 10)
                    
                           end
                   
                           CargoPickup(param1, param2, mcoord)
             
                     elseif string.find(cmd, "sta")
             
                      then if DebugMode == true
              
                            then trigger.action.outText("DEBUG: Static Spawn-Funktion gestartet!", 10)
                    
                           end
                   
                           StaticSpawn(param1, param2, param3, param4, mcoord)
                           
                     elseif string.find(cmd, "ctldcr")
             
                      then if DebugMode == true
              
                            then trigger.action.outText("DEBUG: Funktion zum Spawnen von CTLD-Crates gestartet!", 10)
                    
                           end
                   
                           SpawnCTLDCrate(param1, param2, mcoord)
                           
                     elseif string.find(cmd, "ctldgr")
             
                      then if DebugMode == true
              
                            then trigger.action.outText("DEBUG: Funktion zum Spawnen von CTLD-Gruppen gestartet!", 10)
                    
                           end
                   
                           SpawnExtractableCTLD(param1, param2, param3, mcoord)
                     
                     elseif string.find(cmd, "s")
             
                      then if DebugMode == true
              
                            then trigger.action.outText("DEBUG: Spawn-Funktion gestartet!", 10)
                    
                           end
                   
                           Spawn(param1, param2, param3, param4, param5, param6, mcoord)
                   
                     elseif string.find(cmd, "act") 
      
                      then if DebugMode == true
              
                            then trigger.action.outText("DEBUG: Late Activation Funktion gestartet!", 10)
                    
                           end
                   
                           LateActivate(param1)
                           
                     elseif string.find(cmd, "?") 
      
                      then if DebugMode == true
              
                            then trigger.action.outText("DEBUG: Query Funktion gestartet!", 10)
                    
                           end
                           
                           WhatsThis(param1, mcoord)
              
                     end
             end
    end       
    
end
    
world.addEventHandler(MarkHandler)

trigger.action.outText( "Gamemaster_Functions loaded!", 10 )