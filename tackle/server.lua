if not ForgeSmall.isEnabled('tackle') then return end

RegisterNetEvent('forge-smallresources:server:tackle', function(target)
    local src = source
    target = tonumber(target)

    if not target or target <= 0 or target == src then return end

    local srcPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(target)
    if srcPed == 0 or targetPed == 0 then return end
    if not DoesEntityExist(srcPed) or not DoesEntityExist(targetPed) then return end

    local srcCoords = GetEntityCoords(srcPed)
    local targetCoords = GetEntityCoords(targetPed)
    if #(srcCoords - targetCoords) > 2.0 then return end

    TriggerClientEvent('forge-smallresources:client:tackled', target)
end)