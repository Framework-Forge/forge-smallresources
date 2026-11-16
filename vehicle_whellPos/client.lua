if not ForgeSmall.isEnabled("vehicleWhellPos") then
    return
end

local currentVehicle = 0
local currentAngle = 0.0
local currentSteeringLock = 35.0
local exitCaptureLocked = false
local parkedVehicles = {}

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function getSteeringLock(vehicle)
    local value = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fSteeringLock")
    if type(value) ~= "number" or value < 1.0 then
        return 35.0
    end
    return value
end

local function rememberVehicle(vehicle)
    if vehicle <= 0 or not DoesEntityExist(vehicle) then return end

    parkedVehicles[vehicle] = {
        angle = currentAngle,
        bias = clamp(currentAngle / currentSteeringLock, -1.0, 1.0),
        model = GetEntityModel(vehicle),
    }
end

-- Detecta diretamente a entrada e a saída do banco do motorista. A captura é
-- congelada ao iniciar a saída para o jogo não substituir o ângulo por zero.
CreateThread(function()
    while true do
        Wait(0)

        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        local isDriving = vehicle ~= 0
            and DoesEntityExist(vehicle)
            and GetPedInVehicleSeat(vehicle, -1) == ped

        if isDriving then
            if currentVehicle ~= vehicle then
                if currentVehicle > 0 then
                    rememberVehicle(currentVehicle)
                end

                currentVehicle = vehicle
                currentAngle = GetVehicleSteeringAngle(vehicle)
                currentSteeringLock = getSteeringLock(vehicle)
                exitCaptureLocked = false
                parkedVehicles[vehicle] = nil
            end

            if IsControlJustPressed(0, 75) or GetIsTaskActive(ped, 151) then
                exitCaptureLocked = true
            end

            if not exitCaptureLocked then
                currentAngle = GetVehicleSteeringAngle(vehicle)
            end
        elseif currentVehicle > 0 then
            rememberVehicle(currentVehicle)
            currentVehicle = 0
            currentAngle = 0.0
            currentSteeringLock = 35.0
            exitCaptureLocked = false
        end
    end
end)

-- SET_VEHICLE_STEER_BIAS precisa ser chamado a cada frame para manter as
-- rodas esterçadas depois que o motorista deixa o veículo.
CreateThread(function()
    while true do
        if not next(parkedVehicles) then
            Wait(500)
        else
            Wait(0)

            for vehicle, data in pairs(parkedVehicles) do
                local shouldForget = not DoesEntityExist(vehicle)
                    or GetEntityModel(vehicle) ~= data.model
                    or GetPedInVehicleSeat(vehicle, -1) ~= 0
                    or GetEntitySpeed(vehicle) >= 0.5

                if shouldForget then
                    parkedVehicles[vehicle] = nil
                else
                    SetVehicleSteerBias(vehicle, data.bias)
                    SetVehicleSteeringAngle(vehicle, data.angle)
                end
            end
        end
    end
end)

AddEventHandler("onResourceStop", function(resource)
    if resource ~= GetCurrentResourceName() then return end

    currentVehicle = 0
    currentAngle = 0.0
    currentSteeringLock = 35.0
    exitCaptureLocked = false
    parkedVehicles = {}
end)