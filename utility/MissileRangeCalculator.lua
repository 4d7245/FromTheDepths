--[[
    From the Depths Missile Range Calculator
   
    Based on:
    Range Calculation by HerpeDerp      https://www.fromthedepthsgame.com/forum/showthread.php?tid=35722
    Missile module Data from Wiki       https://fromthedepths.gamepedia.com/Missile#Missile_modules
    A code example of how to traverse Lua Transceivers and Missiles from the Forum, I sadly can't find again.

    Requirements:
    Launchers need a Lua Transceiver (one per Launcher-Group should be enough, no need to recalculate for the same missiles).
    Missiles have to be launched and range is only calculated while flying. (Sounds stupid to calc instead of just waiting 
    and watching the result, but it beats firing the missiles manually and following them with a stopwatch)
   
    Warning:
    This code has not been tested beyond the point of it printing data to the HUD, use at own risk!
    
    TODOs:
    Drag calculation might walk through missiles in the wrong order (more tests needed).
    Data (drag) in missile_module_table might be outdated.
    Check Missile mass calculation.
    Check for possibility to get number of ejectors from game instead of hardcoding.
--]]

-- BEGIN CONFIG AREA

-- Calculate air resistance based off of current missile height instead of the default value
-- Warning: firing missiles across big altitude differentials will show wrong calculated range (Calculation will asume the missile to stay at the current altitude)
local use_current_height = true;
-- default height at which the missile will fly. The range will depend on this because the drag depends on the height.
local default_height = 50;

-- show comparison between calculated and current actual missile data
local compare_with_actual = true;

-- draw Missile in addition to writing data to hud
local draw_missile  = true;

-- Number of Ejectors attached to each Launchpad. Hardcoded since I have no idea how to find this in Lua.
-- Actually helpful in case of using 4 ejectors, when one has to be removed for the Lua Transceiver.
local numberOfEjectors = 2;

-- How long after a Missile was destroyed should its info be displayed (in seconds)
local time_to_print = 30

-- END CONFIG AREA


-- Globals
local API;
local Missiles = {};

local missile_module_table = {};
missile_module_table["missile body"] =                        { name = "Body", 	                      drag = 0.01, icon = "[]", };
missile_module_table["missile fins"] =                        { name = "Fins", 	                      drag = 0.05, icon = ">>", };
missile_module_table["missile fuel tank"] =                   { name = "Fuel Tank", 	                drag = 0.02, icon = "[O]", };
missile_module_table["missile short range thruster"] =        { name = "Short Range Thruster", 	      drag = 0.02, icon = "+>", };
missile_module_table["missile explosive warhead"] =           { name = "Explosive Warhead", 	        drag = 0.02, icon = "[X]", };
missile_module_table["missile predicted"] =                   { name = "Target Prediction Guidance", 	drag = 0.02, icon = "[tp]", };
missile_module_table["missile APN"] =                         { name = "APN Guidance", 	              drag = 0.05, icon = "[ap]", };
missile_module_table["missile IR seeker"] =                   { name = "Infra-Red Seeker", 	          drag = 0.05, icon = "[ir]", };
missile_module_table["missile beam rider"] =                  { name = "Laser Beam Rider Receiver", 	drag = 0.02, icon = "[br]", };
missile_module_table["missile laser designator receiver"] =   { name = "Laser Designator Receiver", 	drag = 0.05, icon = "[ls]", };
missile_module_table["missile radar seeker"] =                { name = "Radar Seeker",                drag = 0.05, icon = "[rs]", };
missile_module_table["missile proximity fuse"] =              { name = "Proximity Fuse", 	            drag = 0.05, icon = "[|]", };
missile_module_table["missile fuse safety"] =                 { name = "Safety Fuse", 	              drag = 0.02, icon = "[s]", };
missile_module_table["missile one turn"] =                    { name = "One Turn", 	                  drag = 0.02, icon = "[^]", };
missile_module_table["missile propeller"] =                   { name = "Torpedo Propeller", 	        drag = 0.02, icon = "[*]", };
missile_module_table["missile sonar"] =                       { name = "Torpedo Sonar", 	            drag = 0.05, icon = "[@]", };
missile_module_table["missile magnet"] =                      { name = "Magnet", 	                    drag = 0.05, icon = "[U]", };
missile_module_table["missile ballast"] =                     { name = "Ballast Tanks", 	            drag = 0.02, icon = "[~]", };
missile_module_table["missile regulator"] =                   { name = "Regulator", 	                drag = 0.02, icon = "[+]", };
missile_module_table["missile frag warhead"] =                { name = "Fragmentation Warhead", 	    drag = 0.02, icon = "[F]", };
missile_module_table["missile camera"] =                      { name = "Camera", 	                    drag = 0.05, icon = "[o]", };
missile_module_table["missile cable drum"] =                  { name = "Cable Drum", 	                drag = 0.05, icon = "[/]", };
missile_module_table["missile harpoon"] =                     { name = "Harpoon", 	                  drag = 0.02, icon = "[>>]", };
missile_module_table["missile sticky flare"] =                { name = "Sticky Flare", 	              drag = 0.05, icon = "[f]", };
missile_module_table["missile EMP warhead"] =                 { name = "EMP Warhead", 	              drag = 0.02, icon = "[~]", };
missile_module_table["missile simple IR seeker"] =            { name = "Single-Pixel IR Seeker", 	    drag = 0.00, icon = "[.]", };
missile_module_table["missile interceptor"] =                 { name = "Missile Interceptor", 	      drag = 0.01, icon = "[i]", };
missile_module_table["missile variable speed thruster"] =     { name = "Variable Thruster", 	        drag = 0.02, icon = "~>", };
missile_module_table["missile thumper head"] =                { name = "Thumper Head", 	              drag = 0.00, icon = "}", };
missile_module_table["missile lua receiver"] =                { name = "LUA Receiver", 	              drag = 0.01, icon = "[#]", };
missile_module_table["missile radar buoy"] =                  { name = "radar buoy", 	                drag = 0.02, icon = "(r)", };
missile_module_table["missile sonar buoy"] =                  { name = "sonar buoy", 	                drag = 0.02, icon = "(s)", };


-- MAIN
function Update(I)
  API = I;
  API:ClearLogs();
  
  local message = "";
  if compare_with_actual then
    message = "| CalcRange | ActualRange | FuelTime | RegulatorTime | ActualTime |\n";
  else
    message = "| CalcRange | FuelTime | RegulatorTime |\n";
  end
  
  local now = API:GetTimeSinceSpawn();
  
  for id,Missile in pairs(Missiles) do
    local age = now - Missile["last_seen"];
    if age > time_to_print then
      Missiles[id] = nil;
    else
      message = message .. Missile["text"];
    end
  end
  
  for pad = 0, API:GetLuaTransceiverCount()-1 do
      for msl = 0, API:GetLuaControlledMissileCount(pad)-1 do
          local MissileInfo = API:GetMissileInfo(pad, msl);
          local MissileWarningInfo = API:GetLuaControlledMissileInfo(pad, msl);
          local id = MissileWarningInfo.Id;
          local text = "";
          local missile = Missiles[id];
          if use_current_height or compare_with_actual then
            -- calculates data based on current altitude and writes result to Missiles[] 
            -- but does not print to avoid printing twice
            GetMissileText(MissileWarningInfo, MissileInfo);
          elseif missile == nil then
            text = GetMissileText(MissileWarningInfo, MissileInfo);
            message = message .. text;
          end
      end
  end
  Print(message);
end


function GetMissileText(MissileWarningInfo, MissileInfo)
  local Parts = MissileInfo.Parts;
  local ascii_missile = "";
  local Data = {
    length = 0,
    initialSpeed = numberOfEjectors * 70,
    displayedThrust = 0,
    thrust = 0,
    drag = 0.1,
    dragCoefficient = 0,
    fuelTime = 0,
    regulatorTime = 45,
 -- GUI reading 60 is wrong
    effectiveTime = 0,
    flightDistance = 0,
    mass = 0,
  };
  
  for _,Part in pairs(Parts) do
    local name = Part.Name;
    API:Log("Part: " .. name);
    Data.length = Data.length + 1;
    Data.mass = Data.mass + 0.1;
    local module_data = missile_module_table[name];
    Data.drag = Data.drag + module_data["drag"] / Data.length;
    
    if name == "missile thumper head" then
      Data.mass = Data.mass + 0.2; -- additional to the mass added for each module above
    elseif name == "missile short range thruster" then
      Data.displayedThrust = Data.displayedThrust + 1000;
      Data.initialSpeed = Data.initialSpeed + 15;
    elseif name == "missile variable speed thruster" then
      Data.displayedThrust = Data.displayedThrust + Part.Registers[2];
      Data.initialSpeed = Data.initialSpeed + 15;
    elseif name == "missile torpedo propeller" then
      Data.displayedThrust = Data.displayedThrust + 500;
      Data.initialSpeed = Data.initialSpeed + 50;
    elseif name == "missile fuel tank" then
      Data.fuelTime = Data.fuelTime + 5000;
    elseif name == "missile regulator" then
      Data.regulatorTime  = Data.regulatorTime + 180;
    end
    
    if draw_missile then
      ascii_missile = DrawPart(Part) .. ascii_missile;
    end
  end
  
  Data.dragCoefficient = Data.drag / 100
  Data.thrust = Data.displayedThrust / 40;
  Data.initialSpeed = Data.initialSpeed + 0.75 / Data.mass;
  Data.fuelTime = Data.fuelTime / Data.displayedThrust;
  Data.effectiveTime = math.min(Data.fuelTime, Data.regulatorTime);
  
  local altitude = 0;
  if use_current_height then
    altitude = MissileWarningInfo.Position.y;
    --API:Log("alt: " .. altitude);
  else
    altitude = default_height;
  end
  Data.flightDistance = getDistanceAfterTime(Data, Data.effectiveTime, altitude);
  
  local text = "";
  if compare_with_actual then
    text = "| " .. Format(Data.flightDistance, 10) .. "m | " .. 
                   Format(MissileWarningInfo.Range, 13) .. "m | " .. 
                   Format(Data.fuelTime, 11) .. "s | " .. 
                   Format(Data.regulatorTime, 19) .. "s | " .. 
                   Format(MissileWarningInfo.TimeSinceLaunch, 13) .. "s |";
  else
    text = "| " .. Format(Data.flightDistance, 10) .. "m | " .. 
                   Format(Data.fuelTime, 11) .. "s | " .. 
                   Format(Data.regulatorTime, 19) .. "s |";
  end
  
  if draw_missile then
    text = text .. " " .. ascii_missile .. "\n";
  else
    text = text .. "\n";
  end

  for k,v in pairs(Data) do
    API:Log(k .. " " .. v);
  end

  local Missile = {};
  Missile["data"] = Data;
  Missile["text"] = text;
  Missile["last_seen"] = API:GetTimeSinceSpawn()
  Missiles[MissileWarningInfo.Id] = Missile;
  return text;
end


function DrawPart(Part)
    local name = Part.Name;
    local mod = missile_module_table[name];
    if mod ~= nil then
      return mod["icon"] .. " ";
    else
      return name .. ", ";
    end
end


function Format(num, len)
  return string.format("%" .. len .. ".2f", num);
end



function Print(message)
    API:LogToHud(message);
    API:LogToHud(" ");
    API:LogToHud("  ");
    API:LogToHud("   ");
    API:LogToHud("    ");
    API:LogToHud("     ");
end


function getDistanceAfterTime(m, totalFlightTime, height)
  local distanceTraveled = 0;
  local velocityMagnitude = 0;
  local timeStep = 0.025
  local time = 0
  while time < totalFlightTime do
    local accelerationMagnitude = getAcceleration(m, height, velocityMagnitude, timeStep)
    velocityMagnitude = velocityMagnitude + accelerationMagnitude * timeStep
    distanceTraveled = distanceTraveled + velocityMagnitude * timeStep
    time = time + timeStep
  end
  return distanceTraveled;
end


function getAcceleration(m, height, speed, timeStep)
  local newSpeed = speed + getThrustAccelerationMagnitude(m) * timeStep;
  return getThrustAccelerationMagnitude(m) - getDragAccelerationMagnitude(m, height, speed, newSpeed)
end


function getDragAccelerationMagnitude(m, height, speed, newSpeed)
  local airDensity = getAirDensityAtAltitude(height)
  local dragMagnitudePerVelocity = math.max(0.1, airDensity * speed * m.dragCoefficient)
  local dragMagnitude = dragMagnitudePerVelocity * newSpeed
  return dragMagnitude
end


function getThrustAccelerationMagnitude(m)
  return m.thrust / m.mass
end


function getAirDensityAtAltitude(altitude)
  if altitude < 0 then
    return 7
  elseif altitude < 275 then
    return 1 - altitude / 550
  else
    return 0.5 * math.pow(0.01, (altitude - 275) / (1200 - 275));
  end
end

