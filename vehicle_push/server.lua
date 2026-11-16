if not ForgeSmall.isEnabled('vehiclePush') then return end

local pushState = pr_lib.fivem.vehicleState.channel('smallresources', {
    replicated = true,
    authority = 'server',
    maxPayloadBytes = 128,
})

local validDirections = {
    left = true,
    right = true,
    front = true,
    back = true,
}

RegisterNetEvent('forge-smallresources:server:vehiclePush', function(data)
    local src = source
    if type(data) ~= 'table' then return end

    local direction = data.direction
    if direction ~= nil and not validDirections[direction] then return end

    local netId = tonumber(data.netId)
    if not netId or netId <= 0 then return end

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if vehicle == 0 or not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2 then return end

    local ped = GetPlayerPed(src)
    if ped == 0 or not DoesEntityExist(ped) then return end

    local pedCoords = GetEntityCoords(ped)
    local vehicleCoords = GetEntityCoords(vehicle)
    if #(pedCoords - vehicleCoords) > 6.0 then return end

    pushState.set(vehicle, 'pushDirection', direction, {
        replicated = true,
        authority = 'server',
        force = true,
    })
end)