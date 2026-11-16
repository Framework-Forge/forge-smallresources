if not ForgeSmall.isEnabled('tireSlash') then return end

local rules = ForgeSmall.tireSlash
local prefix = 'forge-smallresources:tireSlash:'
local pending, locks, nextRequest = {}, {}, {}
local sequence = 0

local function clear(src)
    local request = pending[src]
    if request and locks[request.key] == request then locks[request.key] = nil end
    pending[src] = nil
end

local function validRequest(src, networkId, index)
    if type(networkId) ~= 'number' or networkId % 1 ~= 0 or networkId < 1 or networkId > 65535
        or not rules.byIndex[index] then return end
    local ped, vehicle = GetPlayerPed(src), NetworkGetEntityFromNetworkId(networkId)
    if ped == 0 or vehicle == 0 or not DoesEntityExist(ped) or not DoesEntityExist(vehicle)
        or GetEntityType(vehicle) ~= 2 or GetEntityHealth(ped) <= 0 then return end
    if GetVehiclePedIsIn(ped, false) ~= 0 or not rules.isWeaponAllowed(GetSelectedPedWeapon(ped)) then return end
    if GetPlayerRoutingBucket(src) ~= GetEntityRoutingBucket(vehicle) then return end
    if GetEntitySpeed(vehicle) > rules.maxVehicleSpeed
        or #(GetEntityCoords(ped) - GetEntityCoords(vehicle)) > rules.serverVehicleDistance then return end
    local metadata = pr_lib.framework.getPlayerMetadata
    if metadata(src, 'ishandcuffed') or metadata(src, 'isdead') or metadata(src, 'inlaststand') then return end
    return vehicle, ped
end

pr_lib.callback.register(prefix .. 'begin', function(src, networkId, index)
    local now = GetGameTimer()
    if now < (nextRequest[src] or 0) then return nil, 'unavailable' end
    nextRequest[src] = now + 500
    local vehicle, ped = validRequest(src, networkId, index)
    if not vehicle then return nil, 'unavailable' end
    if pending[src] and pending[src].expires > now then return nil, 'unavailable' end
    clear(src)
    local key = ('%s:%s'):format(networkId, index)
    if locks[key] and locks[key].expires > now then return nil, 'unavailable' end
    sequence = sequence + 1
    local request = {
        token = sequence, networkId = networkId, index = index, key = key,
        vehicle = vehicle, model = GetEntityModel(vehicle), ped = ped,
        earliest = now + rules.durationMs, expires = now + rules.durationMs + 15000,
    }
    pending[src], locks[key] = request, request
    SetTimeout(rules.durationMs + 15000, function()
        if pending[src] == request then clear(src) end
    end)
    return request.token
end)

pr_lib.callback.register(prefix .. 'finish', function(src, token)
    local request = pending[src]
    if not request or request.token ~= token then return false, 'unavailable' end
    local now = GetGameTimer()
    if now < request.earliest or now >= request.expires or request.finishing then return false, 'unavailable' end
    request.finishing = true
    local function apply()
        for _ = 1, 2 do
            local vehicle, ped = validRequest(src, request.networkId, request.index)
            if vehicle ~= request.vehicle or ped ~= request.ped or GetEntityModel(vehicle) ~= request.model then
                return false, 'unavailable'
            end
            local owner = NetworkGetEntityOwner(vehicle)
            if owner and owner > 0 then
                local applied, reason = pr_lib.callback.awaitClient(owner, prefix .. 'apply', 2000,
                    request.networkId, request.index, src)
                if applied then return true end
                if reason ~= 'owner_changed' then return false, reason or 'sync_failed' end
            end
            Wait(50) -- bounded retry if network ownership migrates during the RPC
        end
        return false, 'sync_failed'
    end
    local ok, applied, reason = pcall(apply)
    if pending[src] == request then clear(src) end
    if not ok then return false, 'sync_failed' end
    return applied, reason
end)

RegisterNetEvent(prefix .. 'cancel', function(token)
    local src = source
    local request = pending[src]
    if request and request.token == token and not request.finishing then clear(src) end
end)

AddEventHandler('playerDropped', function()
    clear(source)
    nextRequest[source] = nil
end)
