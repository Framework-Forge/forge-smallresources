if not ForgeSmall.isEnabled('vehicleArmOut') then return end

local relaxedRidingFlag = 424
local motorcycleRelaxedEnabled = true
local flagAppliedPed = 0
local flagAppliedState = false

local armAnimations = {
    [-1] = {
        window = 0,
        dict = 'anim@veh@lowrider@std@ds@arm@base',
        clip = 'sit_low_lowdoor',
    },
    [0] = {
        window = 1,
        dict = 'anim@veh@lowrider@std@ps@arm@base',
        clip = 'sit_low_lowdoor',
    },
}

local active = false
local activePed = 0
local activeVehicle = 0
local activeSeat = nil
local activeAnimation = nil

local function isMotorcycle(vehicle)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return false end

    local model = GetEntityModel(vehicle)
    return IsThisModelABike(model) or GetVehicleClass(vehicle) == 8
end

local function getSupportedCarSeat(ped, vehicle)
    for seat = -1, 0 do
        if GetPedInVehicleSeat(vehicle, seat) == ped then
            return seat
        end
    end
end

local function setRelaxedRidingFlag(ped, enabled, logChange)
    if ped == 0 or not DoesEntityExist(ped) then return false end

    SetPedConfigFlag(ped, relaxedRidingFlag, enabled == true)
    local applied = GetPedConfigFlag(ped, relaxedRidingFlag, true) == (enabled == true)

    if logChange then
        print(('[forge-smallresources:vehicleArmOut] ped=%s flag424 requested=%s applied=%s'):format(
            ped,
            tostring(enabled == true),
            tostring(applied)
        ))
    end

    return applied
end

local function stopCarArmAnimation()
    if activePed ~= 0 and DoesEntityExist(activePed) and activeAnimation then
        StopAnimTask(activePed, activeAnimation.dict, activeAnimation.clip, 2.0)
    end

    active = false
    activePed = 0
    activeVehicle = 0
    activeSeat = nil
    activeAnimation = nil
end

local function isPedSafe(ped, vehicle)
    if ped == 0 or not DoesEntityExist(ped) or IsEntityDead(ped) or IsPedDeadOrDying(ped, true) then
        return false
    end
    if vehicle == 0 or not DoesEntityExist(vehicle) or not IsPedInVehicle(ped, vehicle, false) then
        return false
    end
    if IsPedRagdoll(ped) or IsPedFalling(ped) or IsPedBeingStunned(ped, 0) or IsPedInParachuteFreeFall(ped) then
        return false
    end
    if GetIsTaskActive(ped, 2) or GetIsTaskActive(ped, 160) or GetIsTaskActive(ped, 161) then
        return false
    end

    return true
end

local function playCarArmAnimation()
    if not activeAnimation or not pr_lib.requestAnimDict(activeAnimation.dict, 5000) then
        return false
    end

    TaskPlayAnim(
        activePed,
        activeAnimation.dict,
        activeAnimation.clip,
        8.0,
        -8.0,
        -1,
        49,
        0.0,
        false,
        false,
        false
    )

    return true
end

local function startCarArmAnimation(ped, vehicle)
    local seat = getSupportedCarSeat(ped, vehicle)
    local animation = seat and armAnimations[seat]
    if not animation or not isPedSafe(ped, vehicle) then return end

    activePed = ped
    activeVehicle = vehicle
    activeSeat = seat
    activeAnimation = animation

    RollDownWindow(vehicle, animation.window)
    if not playCarArmAnimation() then
        stopCarArmAnimation()
        return
    end

    active = true
end

local function toggleArmMode()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if isMotorcycle(vehicle) and GetPedInVehicleSeat(vehicle, -1) == ped then
        motorcycleRelaxedEnabled = not motorcycleRelaxedEnabled
        local applied = setRelaxedRidingFlag(ped, motorcycleRelaxedEnabled, true)
        flagAppliedPed = ped
        flagAppliedState = motorcycleRelaxedEnabled and applied
        return
    end

    if active then
        stopCarArmAnimation()
    elseif vehicle ~= 0 and not isMotorcycle(vehicle) then
        startCarArmAnimation(ped, vehicle)
    end
end

pr_lib.addKeybind({
    name = 'forge_vehicle_arm_out',
    description = 'Alternar postura com o braço para fora',
    defaultKey = 'Q',
    onReleased = toggleArmMode,
})

-- Prepara a flag durante a tarefa de entrada e confirma sua permanência
-- enquanto o jogador pilota. Isso permite ao jogo escolher a postura relaxada
-- desde o início da animação de condução.
CreateThread(function()
    while true do
        Wait(100)

        local ped = PlayerPedId()
        local currentVehicle = GetVehiclePedIsIn(ped, false)
        local enteringVehicle = GetVehiclePedIsTryingToEnter(ped)
        local targetVehicle = currentVehicle ~= 0 and currentVehicle or enteringVehicle
        local shouldApply = motorcycleRelaxedEnabled and isMotorcycle(targetVehicle)

        if shouldApply and currentVehicle ~= 0 and GetPedInVehicleSeat(currentVehicle, -1) ~= ped then
            shouldApply = false
        end

        local stateChanged = flagAppliedPed ~= ped or flagAppliedState ~= shouldApply
        if stateChanged or shouldApply then
            local applied = setRelaxedRidingFlag(ped, shouldApply, stateChanged)
            flagAppliedPed = ped
            flagAppliedState = shouldApply and applied
        end
    end
end)

CreateThread(function()
    while true do
        if not active then
            Wait(500)
        else
            Wait(100)

            local valid = isPedSafe(activePed, activeVehicle)
                and armAnimations[activeSeat] ~= nil
                and GetPedInVehicleSeat(activeVehicle, activeSeat) == activePed

            if not valid then
                stopCarArmAnimation()
            elseif not IsEntityPlayingAnim(activePed, activeAnimation.dict, activeAnimation.clip, 3) then
                playCarArmAnimation()
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    stopCarArmAnimation()
    local ped = PlayerPedId()
    if ped ~= 0 and DoesEntityExist(ped) then
        SetPedConfigFlag(ped, relaxedRidingFlag, false)
    end
end)