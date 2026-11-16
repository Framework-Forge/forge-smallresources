if not ForgeSmall.isEnabled('vehicleSmoke') then return end

local settings = ForgeSmallConfig.vehicleSmoke or {}
local nextRequestAt = {}

local function validDriverVehicle(src, networkId)
    networkId = tonumber(networkId)
    if not networkId or networkId <= 0 then return nil end

    local vehicle = NetworkGetEntityFromNetworkId(networkId)
    local ped = GetPlayerPed(src)
    if vehicle == 0 or ped == 0 or not DoesEntityExist(vehicle) then return nil end
    if GetVehiclePedIsIn(ped, false) ~= vehicle or GetPedInVehicleSeat(vehicle, -1) ~= ped then return nil end
    return vehicle, networkId
end

RegisterNetEvent('forge-smallresources:vehicleSmoke:request', function(networkId)
    local src = source
    local now = GetGameTimer()
    local cooldown = math.max(150, tonumber(settings.cooldownMs) or 700)
    if now < (nextRequestAt[src] or 0) then return end

    local vehicle
    vehicle, networkId = validDriverVehicle(src, networkId)
    if not vehicle then return end
    nextRequestAt[src] = now + cooldown

    local coords = GetEntityCoords(vehicle)
    local range = math.max(25.0, tonumber(settings.syncDistance) or 200.0)
    local rangeSquared = range * range
    for _, playerId in ipairs(GetPlayers()) do
        local target = tonumber(playerId)
        local targetPed = target and GetPlayerPed(target) or 0
        if targetPed ~= 0 then
            local targetCoords = GetEntityCoords(targetPed)
            local dx, dy, dz = coords.x - targetCoords.x, coords.y - targetCoords.y, coords.z - targetCoords.z
            if dx * dx + dy * dy + dz * dz <= rangeSquared then
                TriggerClientEvent('forge-smallresources:vehicleSmoke:play', target, networkId)
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    nextRequestAt[source] = nil
end)
