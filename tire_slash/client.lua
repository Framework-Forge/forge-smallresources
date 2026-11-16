if not ForgeSmall.isEnabled('tireSlash') then return end

local rules, busy = ForgeSmall.tireSlash, false
local prefix = 'forge-smallresources:tireSlash:'
local interactions = {}

local function burstTyre(vehicle, index)
    if GetResourceState('pr_mileage') ~= 'started' then return false, 'sync_failed' end
    local ok, applied, reason = pcall(function()
        return exports['pr_mileage']:burstTyre(vehicle, index)
    end)
    if not ok then return false, 'sync_failed' end
    return applied == true, reason
end

local function wheelCoords(vehicle, wheel)
    local bone = GetEntityBoneIndexByName(vehicle, wheel.bone)
    if bone == -1 then return end
    return GetWorldPositionOfEntityBone(vehicle, bone)
end

local function validPed(ped)
    return DoesEntityExist(ped) and not IsPedDeadOrDying(ped, true)
        and not IsPedInAnyVehicle(ped, true) and not IsPedCuffed(ped)
        and not IsPedRagdoll(ped) and not IsPedSwimming(ped)
        and rules.isWeaponAllowed(GetSelectedPedWeapon(ped))
end

local function validWheel(vehicle, wheel, ped, tolerance)
    if vehicle == 0 or not DoesEntityExist(vehicle) or not IsEntityAVehicle(vehicle) then return false end
    if GetEntitySpeed(vehicle) > rules.maxVehicleSpeed or not GetVehicleTyresCanBurst(vehicle) then return false end
    if IsVehicleTyreBurst(vehicle, wheel.index, false) then return false end
    local coords = wheelCoords(vehicle, wheel)
    return coords ~= nil and #(GetEntityCoords(ped) - coords) <= rules.interactDistance + (tolerance or 0.0)
end

local function canSlash(vehicle, wheel)
    if busy or pr_lib.progressActive() then return false end
    local ped = ForgeSmall.getPed()
    if not validPed(ped) or ForgeSmall.getMetadata('ishandcuffed', false)
        or ForgeSmall.getMetadata('isdead', false) or ForgeSmall.getMetadata('inlaststand', false) then return false end
    return validWheel(vehicle, wheel, ped)
end

local function notify(reason, kind)
    if reason ~= 'success' and reason ~= 'canceled' and reason ~= 'unavailable' then reason = 'sync_failed' end
    ForgeSmall.notify(locale('tire_slash.' .. (reason or 'unavailable')), kind or 'error')
end

-- The server routes this RPC to the current network owner, not just the driver.
-- Do not steal control of an occupied vehicle or change its mission status.
pr_lib.callback.register(prefix .. 'apply', function(networkId, index, actorId)
    local wheel = rules.byIndex[index]
    if not wheel or not NetworkDoesNetworkIdExist(networkId) then return false, 'unavailable' end
    local vehicle = NetworkGetEntityFromNetworkId(networkId)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return false, 'unavailable' end
    if not NetworkHasControlOfEntity(vehicle) then return false, 'owner_changed' end
    local player = GetPlayerFromServerId(actorId)
    if player == -1 then return false, 'unavailable' end
    local ped = GetPlayerPed(player)
    if not validPed(ped) or not validWheel(vehicle, wheel, ped, 0.25) then return false, 'unavailable' end
    return burstTyre(vehicle, index)
end)

local function slash(vehicle, wheel)
    if not canSlash(vehicle, wheel) then return end
    busy = true
    CreateThread(function()
        local token
        local ok = pcall(function()
            local ped = ForgeSmall.getPed()
            local networked = NetworkGetEntityIsNetworked(vehicle)
            local networkId = networked and NetworkGetNetworkIdFromEntity(vehicle) or nil
            if networked then
                local reason
                token, reason = pr_lib.callback.await(prefix .. 'begin', 5000, networkId, wheel.index)
                if not token then return notify(reason) end
            end

            local coords = wheelCoords(vehicle, wheel)
            if not coords then return notify('unavailable') end
            TaskTurnPedToFaceCoord(ped, coords.x, coords.y, coords.z, 250)
            local completed = pr_lib.progressBar({
                label = locale('tire_slash.progress'),
                duration = rules.durationMs,
                canCancel = true,
                disable = { move = true, car = true, combat = true },
                anim = { dict = 'melee@knife@streamed_core_fps', clip = 'ground_attack_on_spot', flag = 15 },
            })
            if not completed then return notify('canceled', 'inform') end
            if ForgeSmall.getPed() ~= ped or not validPed(ped) or not validWheel(vehicle, wheel, ped) then
                return notify('unavailable')
            end

            local applied, reason
            if networked then
                applied, reason = pr_lib.callback.await(prefix .. 'finish', 6000, token)
                token = nil
            else
                applied, reason = burstTyre(vehicle, wheel.index)
            end
            notify(applied and 'success' or reason or 'sync_failed', applied and 'success' or 'error')
        end)
        if token then TriggerServerEvent(prefix .. 'cancel', token) end
        busy = false
        if not ok then notify('sync_failed') end
    end)
end

for _, entry in ipairs(rules.wheels) do
    local wheel = entry
    local id = prefix .. wheel.bone
    interactions[#interactions + 1] = pr_lib.interact.AddGlobalVehicleInteraction({
        id = id,
        bone = wheel.bone,
        distance = rules.distance,
        interactDst = rules.interactDistance,
        options = {
            {
                name = id,
                label = locale('tire_slash.label'),
                icon = 'bi bi-scissors',
                canInteract = function(vehicle) return canSlash(vehicle, wheel) end,
                action = function(vehicle) slash(vehicle, wheel) end,
            },
        },
    })
end

AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, id in ipairs(interactions) do pr_lib.interact.RemoveGlobalVehicleInteraction(id) end
end)
