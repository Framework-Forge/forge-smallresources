if not ForgeSmall.isEnabled('vehicleThrottleControl') then return end

local settings = ForgeSmallConfig.vehicleThrottleControl or {}
local active = false
local controlledVehicle = 0

local function isEligibleVehicle(vehicle)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return false end
    if GetPedInVehicleSeat(vehicle, -1) ~= ForgeSmall.getPed() then return false end
    return (settings.allowedClasses or {})[GetVehicleClass(vehicle)] == true
end

local function restoreVehicle()
    if controlledVehicle ~= 0 and DoesEntityExist(controlledVehicle) then
        SetVehicleEngineTorqueMultiplier(controlledVehicle, 1.0)
    end
    controlledVehicle = 0
    active = false
end

local function applyThrottleControl()
    local vehicle = ForgeSmall.getVehicle()
    if not isEligibleVehicle(vehicle) then
        restoreVehicle()
        return
    end

    if controlledVehicle ~= 0 and controlledVehicle ~= vehicle then restoreVehicle() end
    controlledVehicle = vehicle
    active = true

    local currentSpeed = GetEntitySpeed(vehicle) * 3.6
    local maximumSpeed = tonumber(settings.maxSpeedKmh) or 80.0
    if currentSpeed <= maximumSpeed then
        -- O torque e aplicado no mesmo frame em que a tecla e pressionada e
        -- mantido enquanto ela estiver segurada. Diferente do RPM, ele reduz
        -- a forca que chega as rodas e impede a patinagem na arrancada.
        local torque = math.max(0.05, math.min(1.0, tonumber(settings.torqueMultiplier) or 0.35))
        SetVehicleEngineTorqueMultiplier(vehicle, torque)
        SetVehicleReduceGrip(vehicle, false)
    else
        SetVehicleEngineTorqueMultiplier(vehicle, 1.0)
    end

    -- O controle nao bloqueia o acelerador nem altera o handling do veiculo.
    -- Enquanto o LShift estiver pressionado, reduz tambem o RPM atual em
    -- ate 10%, mantendo um piso para que o carro continue saindo do lugar.
    local currentRpm = GetVehicleCurrentRpm(vehicle)
    if currentRpm > 0 then
        local reduction = math.max(0, math.min(0.5, tonumber(settings.rpmReduction) or 0.10))
        local minimum = math.max(0, math.min(1, tonumber(settings.minimumRpm) or 0.15))
        SetVehicleCurrentRpm(vehicle, math.max(minimum, currentRpm * (1.0 - reduction)))
    end
end

pr_lib.addKeybind({
    name = 'forge_vehicle_throttle_control',
    description = 'Controle temporario de aceleracao e tracao',
    defaultKey = settings.key or 'LSHIFT',
    onPressed = function()
        active = true
        applyThrottleControl()
    end,
    onReleased = restoreVehicle,
})

CreateThread(function()
    while true do
        if active then
            applyThrottleControl()
            Wait(0)
        else
            Wait(200)
        end
    end
end)

pr_lib.onCache('vehicle', function(vehicle)
    if active and controlledVehicle ~= 0 and vehicle ~= controlledVehicle then restoreVehicle() end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then restoreVehicle() end
end)
