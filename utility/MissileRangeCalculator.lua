
missileComposition = {
  length = 2,
  thumper = false,
  seekerHead = true, --set this to true if the missile has a radar seeker, infrared seeker (not the single pixel seeker) or laser designator receiver (not the beam rider receiver)
  singlePixelSeeker = false, --set this to true only if the missile has a single pixel ir seeker
  numberOfLowDragComponents = 0, --number of components with 0.01 base drag (should all be at the front, but behind the thumper or seeker if there is one)
  numberOfHighDragComponents = 1, --number of components with 0.05 base drag (should all be at the end of the missle)
  numberOfEjectors = 2,
  numberOfTorpedoPropellers = 0,
  numberOfThrusters = 1,
  displayedThrust = 1000,
  numberOfFuelTanks = 1,
  numberOfRegulators = 0
}

height = 10 --height at which the missile will fly. The range will depend on this because the drag depends on the height.


--------------------------------------------------------------------------------------------------------------------------------------------------

local firstTime = true;
function Update(I)
  if firstTime then
    local flightDistance = getDistanceAfterTime(missileComposition, missileComposition.effectiveTime, height);
    I:Log("Missile will fly " .. flightDistance .. "m in " .. missileComposition.effectiveTime .. "s.");
    firstTime = false;
  end
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

function setMass(m)
  if m.thumper then
    m.mass = 0.2 * (m.length + 1)
  else
    m.mass = 0.2 * m.length
  end
end

function setThrust(m)
  m.thrust = m.displayedThrust / 40
end

function setInitialSpeed(m)
  m.initialSpeed = 0.75 / m.mass + m.numberOfEjectors * 70 + m.numberOfTorpedoPropellers * 50 + m.numberOfThrusters * 15
end

function setDragCoefficient(m)
  local i = 1
  local a = 0.1
  if m.thumper or m.singlePixelSeeker then
    i = i + 1
  else
    if m.seekerHead then
      a = a + 0.05 / i
      i = i + 1
    end
  end
  for j = 1, m.numberOfLowDragComponents do
    a = a + 0.01 / i
    i = i + 1
  end
  while i <= m.length * 2 - m.numberOfHighDragComponents do
    a = a + 0.02 / i
    i = i + 1
  end
  for j = 1, m.numberOfHighDragComponents do
    a = a + 0.05 / i
    i = i + 1
  end
  a = a / 100
  m.dragCoefficient = a
end

function setEffectiveTime(m)
  local fuelTime = m.numberOfFuelTanks * 5000 / m.displayedThrust;
  local regulatorTime = m.numberOfRegulators * 180 + 30;
  m.effectiveTime = math.min(fuelTime, regulatorTime);
end


setMass(missileComposition)
setThrust(missileComposition)
setInitialSpeed(missileComposition)
setDragCoefficient(missileComposition)
setEffectiveTime(missileComposition)