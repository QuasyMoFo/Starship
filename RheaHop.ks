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
    set starshipHeight to 20.74.
    set terminalCount to 10.

    // Vehicle Control
    set steeringManager:maxstoppingtime to 0.5.
    set steeringManager:rollts to 20.
    //lock trueApoapsis to ship:apoapsis - starshipHeight.
    set g to constant:g * body:mass / body:radius^2.
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
    
    // Engine Control
    set leewardEngine to ship:partstagged("eng3")[0].
    set sideEngine1 to ship:partstagged("eng1")[0].
    set sideEngine2 to ship:partstagged("eng2")[0].

    // Landing Pad
    set landingZone to latlng(-8.8548168830479, -83.5023510574945).
    // lock latDiff to (landingZone:lat - addons:tr:impactpos:lat).


    // Throttle Control
    set throt to 0.
    lock throttle to throt.

    // Setup
    if tApogee = 10000 {
        set sideEngineShutdown1 to 4000.
        set sideEngineShutdown2 to 6250.
    } else if tApogee = 20000 {
        set sideEngineShutdown1 to 12500.
        set sideEngineShutdown2 to 15000. 
    }


    // Countdown
    on ag9 {
        ag9 off.
        ag10 off.
        set throt to 0.
        wait 0.1.
        reboot.
    }
    launchCountdown().
}


// FLIGHT SOFTWARE -----------------------------------------------------------------------------------
function liftoff {
    stage.
    set throt to 1.05 * ship:mass * g / ship:availablethrust.
    set initFace to facing.
    lock steering to initFace.

    wait 3.
    stage.

    wait until ship:altitude > 100.
    ascent().
}

function ascent {
    lock steering to heading(landingZone:heading, 90 + 1 * (ship:altitude / 9000)).

    // Engine Cutoff 1
    wait until trueRadar > sideEngineShutdown1.
    toggle ag1.
    sideEngine1:shutdown.

    // Engine Cutoff 2
    wait until trueRadar > sideEngineShutdown2.
    toggle ag2.
    sideEngine2:shutdown.
    steeringManager:resettodefault().

    // Apogee + Bellyflop
    wait until trueRadar > tApogee - 600.
    engineSpool(0.1).
    set steeringManager:maxstoppingtime to 0.75.
    
    wait until ship:apoapsis > tApogee.
    wait 1.
    lock steering to heading(landingZone:heading, 0).
    //set headerTankLfTXFER:active to true.
    //set headerTankLoxTXFER:active to true.
    wait until ship:verticalspeed < 0.
    engineSpool(0).
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

    set lngErrorMulti to 175.

    //lock descentHeading to 270 + (latError * 500).

    //lock latCorrection to (latError() * latErrorMulti).
    lock lngCorrection to (lngError() * lngErrorMulti).

    rcs on.
    toggle ag6.
    wait 3.
    toggle ag5.
    wait 4.

    when trueRadar < tApogee then {
        //lock latCorrection to (latError() * latErrorMulti * 3).
        lock lngCorrection to (lngError() * lngErrorMulti * 4).
    }

    when trueRadar < 3500 then {
        //lock latCorrection to (latError() * latErrorMulti * 4.5).
        lock lngCorrection to (lngError() * lngErrorMulti * 8).

        sideEngine1:activate.
        set sideEngine1:thrustlimit to 100.
        sideEngine2:activate.
        set sideEngine2:thrustlimit to 100.
        leewardEngine:activate.
        set leewardEngine:thrustlimit to 100.
        toggle ag3. // Unlock Gimbal
    }

    lock steering to heading(landingZone:heading, (0 + lngCorrection)).

    until (stopDist + 300) > trueRadar {
        wait 0.
    }

    steeringManager:resettodefault().
 
    landing().
}

function landing {
    lock idealThrottle to stopDist / trueRadar.
    when impactTime < 3 then {gear on.}
    when impactTime < 1.5  then {lock finalFace to facing. lock steering to finalFace.}

    lock throttle to (idealThrottle + 0.4).
    wait 0.2.
    set ship:control:pitch to 10.
    toggle ag5.
    aftFin1:getmodule("ModuleControlSurface"):setfield("Deploy Angle", -65).
    aftFin2:getmodule("ModuleControlSurface"):setfield("Deploy Angle", -65).
    wait until p > 75.
    set ship:control:neutralize to true.
    set aoa to -7.
    set steeringManager:maxstoppingtime to 0.75.
    lock steering to getSteering().
    wait until ship:verticalspeed > -42.5.
    leewardEngine:shutdown.
    wait 1.
    toggle ag5.
    toggle ag1.
    lock throttle to (idealThrottle + 0.2).
    toggle ag2.

    wait until ship:verticalspeed > -30.
    set aoa to -0.5.
    toggle ag2.

    wait until ship:verticalspeed > -12.5.
    //sideEngine2:shutdown.
    lock landAng to facing.
    lock steering to landAng.

    wait until ship:verticalspeed > -0.01.
    lock throttle to 0.
    set done to true.
    wait 1.
    toggle ag5.
    toggle ag6.
    wait 10.
    rcs off.
    shutdown.
}


// FUNCTIONS -----------------------------------------------------------------------------------------
function launchCountdown {
    until terminalCount = 1 {
        clearscreen.
        print "T-" + terminalCount.
        wait 1.
        set terminalCount to terminalCount - 1.

        if ag9 {
            ag9 off.
            ag10 off.
            lock throttle to 0.
            
            wait 0.1.
            reboot.
        }
    }

    when done = false then {
        switch to 0.
        log "Alt (M): " + round(alt:radar, 1) to altradar.txt.
        log "Spd (M/S): " + round(verticalSpeed, 1) to vertspeed.txt.

        if ag4 {
            log "FTS SYSTEM ENGAGED" to altradar.txt.
            log "FTS SYSTEM ENGAGED" to vertspeed.txt.
        }

        wait 0.2.
        preserve.
    }

    liftoff().

}

function engineSpool {
    parameter tgt, ullage is false.
    local startTime is time:seconds.
    local throttleStep is 0.0111111.

    if (ullage) {
        rcs on.
        set ship:control:fore to 0.5.

        when (time:seconds > startTime + 2) then {
            set ship:control:neutralize to true.
            rcs off.
        }
    }

    if (throt < tgt) {
        if (ullage) {
            set throt to 0.025. 
            wait 0.5.
        }
        until throttle >= tgt {
            set throt to throt + throttleStep.
        } 
    } else {
        until throttle <= tgt {
            set throt to throt - throttleStep.
        }
    }

    set throt to tgt.
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