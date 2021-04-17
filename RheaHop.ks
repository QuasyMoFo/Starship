// SpaceX Starship Launch & Landing Script
// Version 0.1 - GNUGPL3
// 
// Contributers
// - QuasyMoFo


// PREFLIGHT -----------------------------------------------------------------------------------------
init().

function init {
    // Flight Parameters
    set tApogee to 10000.
    set staticFire to false.
    set starshipHeight to 20.73.
    set terminalCount to 5.

    // Vehicle Control
    set steeringManager:maxstoppingtime to 0.5.
    set steeringManager:rollts to 20.
    //lock trueApoapsis to ship:apoapsis - starshipHeight.
    lock g to body:mu / (body:radius + altitude) ^ 2.
    lock trueRadar to alt:radar - starshipHeight.
    lock p to 90 - vAng(ship:facing:vector, ship:up:vector).
    set aftFin1 to ship:partstagged("aftFin1")[0].
    set aftFin2 to ship:partstagged("aftFin2")[0].
    //set lowTanks to ship:partstagged("aftTanks")[0].
    //set highTanks to ship:partstagged("fwdTanks")[0].
    //set headerTankLfTXFER to transferAll("liquidfuel", lowTanks, highTanks).
    //set headerTankLoxTXFER to transferAll("oxidizer", lowTanks, highTanks).
    set aoa to 0.
    set errorScaling to 1.
    set done to false.
    
    set config:ipaddress to "25.106.23.51".
    set config:telnet to true.
    set config:ipu to 800.

    set vent1 to ship:partstagged("vent")[0].
    set vent2 to ship:partstagged("vent2")[0].
    set vent3 to ship:partstagged("vent3")[0].

    // Engine Control
    set leewardEngine to ship:partstagged("eng3")[0].
    set sideEngine1 to ship:partstagged("eng1")[0].
    set sideEngine2 to ship:partstagged("eng2")[0].

    // set leewardPivot to ship:partstagged("leewardpiv")[0].
    // set eng1Pivot to ship:partstagged("eng1piv")[0].
    // set eng2Pivot to ship:partstagged("eng2piv")[0].

    // Landing Pad
    set landingZone to latlng(5.66597063074963, 78.6971062340695).
    // lock latDiff to (landingZone:lat - addons:tr:impactpos:lat).

    // Setup
    if tApogee = 10000 {
        set sideEngineShutdown1 to 5750. 
        set sideEngineShutdown2 to 8250.
    } else if tApogee = 15000 {
        set sideEngineShutdown1 to 7500.
        set sideEngineShutdown2 to 9500. 
    } else if tApogee = 20000 {
        set sideEngineShutdown1 to 9500.
        set sideEngineShutdown2 to 16000.
    } else if tApogee = 50000 {
        set sideEngineShutdown1 to 20000.
        set sideEngineShutdown2 to 35000.
    }

    // Countdown
    on ag9 {
        ag9 off.
        ag10 off.
        lock throttle to 0.
        leewardEngine:shutdown.
        sideEngine1:shutdown.
        sideEngine2:shutdown.
        wait 0.1.
        reboot.
    }

    if staticFire = true {
        staticFireSeq().
    } else {
        launchCountdown().
    }
}


// FLIGHT SOFTWARE -----------------------------------------------------------------------------------
function liftoff {
    leewardEngine:activate.
    lock throttle to 1.1 * ship:mass * g / ship:availablethrust.
    wait 0.1.
    sideEngine1:activate.
    wait 0.3.
    sideEngine2:activate.
    set initFace to facing.
    lock steering to initFace.

    stage.
    wait 1.
    stage.

    wait until ship:altitude > 100.
    ascent().
}

function ascent {
    lock steering to heading(landingZone:heading, 90 + 2 * (ship:altitude / 7000)).

    // Engine Cutoff 1
    wait until trueRadar > sideEngineShutdown1.
    toggle ag1.
    sideEngine1:shutdown.
    lock throttle to 1.175 * ship:mass * g / ship:availablethrust.

    // Engine Cutoff 2
    wait until trueRadar > sideEngineShutdown2.
    toggle ag2.
    sideEngine2:shutdown.
    steeringManager:resettodefault().
    lock throttle to 1.25 * ship:mass * g / ship:availablethrust.

    // Apogee + Bellyflop
    wait until apoapsis > tApogee + 50.
    lock throttle to 0.1.
    toggle ag6.
    set steeringManager:maxstoppingtime to 0.75.
    
    wait until ship:apoapsis > tApogee - 150.
    wait 3.
    lock steering to heading(landingZone:heading, 0).
    //set headerTankLfTXFER:active to true.
    //set headerTankLoxTXFER:active to true.
    wait until ship:verticalspeed < 0.
    lock throttle to 0.
    leewardEngine:shutdown.

    wait 1.
    toggle ag1. // Gimbal Lock
    toggle ag2. // Gimbal Lock
    toggle ag3. // Gimbal Lock
    controlledDescent().
}

function controlledDescent {
    lock maxDecel to (ship:availablethrust / ship:mass) - g.
    lock stopDist to ship:verticalspeed ^ 2 / (2 * maxDecel).
    lock impactTime to trueRadar / abs(ship:verticalspeed).

    if lngError() > 0 {
        //set latErrorMulti to -25.
        set lngErrorMulti to -175.
    } else {
        //set latErrorMulti to 25.
        set lngErrorMulti to 175.
    }
    
    //lock descentHeading to 270 + (latError * 500).

    //lock latCorrection to (latError() * latErrorMulti).
    lock lngCorrection to (lngError() * lngErrorMulti).

    wait 3.
    toggle ag5.
    wait 4.

    when trueRadar < tApogee then {
        //lock latCorrection to (latError() * latErrorMulti).
        lock lngCorrection to (lngError() * lngErrorMulti * 2).
        preserve.
    }

    when trueRadar < 3500 then {
        //lock latCorrection to (latError() * latErrorMulti * 2.8).
        lock lngCorrection to (lngError() * lngErrorMulti * 5).
        preserve.
    }

    when trueRadar < 2000 then {
        sideEngine1:activate.
        set sideEngine1:thrustlimit to 100.
        sideEngine2:activate.
        set sideEngine2:thrustlimit to 100.
        leewardEngine:activate.
        set leewardEngine:thrustlimit to 100.
        toggle ag3. // Unlock Gimbal
    }

    lock steering to heading(landingZone:heading, (0 + lngCorrection)).
    set steeringManager:maxstoppingtime to 5.

    until (stopDist + 300) > trueRadar {
        wait 0.
    }

    leewardEngine:shutdown.
    sideEngine1:shutdown.
    sideEngine2:shutdown.

    rcs on.
    steeringManager:resettodefault().
 
    landing().
}

function landing {
    lock idealThrottle to stopDist / trueRadar.
    when impactTime < 3 then {gear on.}
    when impactTime < 0.75 then {set cf to facing. lock steering to cf.}

    toggle ag7.
    sideEngine1:activate.
    wait 0.1.
    lock throttle to (idealThrottle + 0.1).
    leewardEngine:activate.
    wait 0.2.
    sideEngine2:activate.
    toggle ag5.
    set ship:control:pitch to 5.
    aftFin1:getmodule("ModuleControlSurface"):setfield("Deploy Angle", -70).
    aftFin2:getmodule("ModuleControlSurface"):setfield("Deploy Angle", -70).
    until p > 65 {
        wait 0.
    }
    aftFin1:getmodule("ModuleControlSurface"):setfield("Deploy Angle", -60).
    aftFin2:getmodule("ModuleControlSurface"):setfield("Deploy Angle", -60).
    set ship:control:neutralize to true.
    lock steering to getSteering().
    set aoa to -4.
    wait 1.
    toggle ag7.
    lock throttle to (idealThrottle + 0.425).
    if ship:verticalspeed > -5 {
        lock throttle to (idealThrottle + 0.3).
    }
    set steeringManager:maxstoppingtime to 0.25.
    toggle ag5.
    set aoa to -0.75.
    toggle ag2.
    if alt:radar < starshipHeight + 30 {
        lock throttle to (idealThrottle + 0.2).
        set aoa to -0.25.
    }

    wait until ship:verticalspeed > -0.01.
    lock throttle to 0.
    wait 10.
    rcs off.
    set done to true.
    shutdown.
}


// FUNCTIONS -----------------------------------------------------------------------------------------
function launchCountdown {
    until terminalCount = 0 {
        clearscreen.
        print "Rhea Countdown".
        print "T-" + terminalCount.
        wait 1.
        set terminalCount to terminalCount - 1.

        if terminalCount = 55 {
            vent1:getmodule("MakeSteam"):doaction("toggle vapor vent", true).
            vent2:getmodule("MakeSteam"):doaction("toggle vapor vent", true).
            vent3:getmodule("MakeSteam"):doaction("toggle vapor vent", true).
        }

        if ag9 {
            ag9 off.
            ag10 off.
            lock throttle to 0.

            vent1:getmodule("MakeSteam"):doaction("toggle vapor vent", true).
            vent2:getmodule("MakeSteam"):doaction("toggle vapor vent", true).
            vent3:getmodule("MakeSteam"):doaction("toggle vapor vent", true).
            
            wait 0.1.
            reboot.
        }
    }

    when done = false then {
        clearscreen.

        print "Rhea Vehicle Telemetry".
        print "----------------------".
        print "Status: " + ship:status.
        print "IsDead: " + ship:isdead.
        print "MET: " + round(missionTime, 1).
        print "----------------------".
        print "Alt (M): " + round(alt:radar, 3).
        print "Apo (M): " + round(ship:apoapsis, 3).
        print "VSpd (M/S): " + round(ship:verticalspeed, 3).
        print "Throttle: " + round(throttle, 3). 
        print "Pitch (Deg): " + round(p, 3).
        print "----------------------".
        print "Lqd Methane (U): " + round(ship:lqdmethane, 3).
        print "Lqd Oxygen (U): " + round(ship:oxidizer, 3).
        print "Mass (T): " + round(ship:mass, 3).   
        print "----------------------". 
        print "Engine 1: " + sideEngine1:ignition.
        print "Engine 2: " + sideEngine2:ignition.
        print "Engine 3: " + leewardEngine:ignition.
        print "Eng 1 Fuel Flow: " + round(sideEngine1:fuelflow, 3).
        print "Eng 2 Fuel Flow: " + round(sideEngine2:fuelflow, 3).
        print "Eng 3 Fuel Flow: " + round(leewardEngine:fuelflow, 3).

        switch to 0.
        //log "MET: " + round(missionTime) + " | " + "Alt: " + round(altitude, 1) + " | " + "Apo: " + round(apoapsis, 1) + " | " + "Throt: " + round(throttle, 3) + " | " + "VSpd: " + round(verticalSpeed, 3) + " | " + "Pitch: " + round(p, 3) + " | " + "Methane: " + round(ship:lqdmethane, 1) + " | " + "Oxid: " + round(ship:oxidizer, 1) to rhea_Flight_Data.csv.

        if ag4 {
            log "FTS SYSTEM ENGAGED" to altradar.txt.
            log "FTS SYSTEM ENGAGED" to vertspeed.txt.
        }

        wait 0.05.
        preserve.
    }

    liftoff().

}

function staticFireSeq {
    wait 5.
    lock throttle to 1.
    leewardEngine:activate.
    wait 0.1.
    sideEngine1:activate.
    wait 0.2.
    sideEngine2:activate.

    wait 3.

    sideEngine1:shutdown.
    wait 0.2.
    leewardEngine:shutdown.
    wait 0.05.
    sideEngine2:shutdown.
    lock throttle to 0.
    
    ag10 off.
    reboot.
}

function getImpact {
    if addons:tr:hasimpact {
        return addons:tr:impactpos.
    }

    return ship:geoPosition.
}

function lngError {
    return getImpact():lng - landingZone:lng.
}

function latError {
    return getImpact():lat - landingZone:lat.
}

function errorVector {
    return getImpact():position - landingZone:position.
}

function getSteering {
    local errorVector is errorVector().
    local velVector is -ship:velocity:surface.
    local result is velVector + errorVector * errorScaling.

    if vAng(result, velVector) > aoa {
        set result to velVector:normalized + tan(aoa) * errorVector:normalized.
    }

    return lookDirUp(result, facing:topvector).
}


// EXTRAS --------------------------------------------------------------------------------------------
// No Extras Yet