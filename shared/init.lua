ForgeSmall = ForgeSmall or {}

local config = ForgeSmallConfig or {}
local modules = config.modules or {}

function ForgeSmall.isEnabled(name)
    return modules[name] ~= false
end

function ForgeSmall.notify(message, kind, duration)
    return pr_lib.notify({
        title = locale('common.notify_title'),
        description = message,
        type = kind or 'inform',
        duration = duration,
    })
end

function ForgeSmall.getMetadata(key, fallback)
    local value = pr_lib.framework.getPlayerMetadata(key)
    if value == nil then return fallback end
    return value
end

function ForgeSmall.getPed()
    return pr_lib.cache.get('ped', PlayerPedId())
end

function ForgeSmall.getVehicle()
    return pr_lib.cache.get('vehicle')
end

function ForgeSmall.getPlayerId()
    return pr_lib.cache.get('playerId', PlayerId())
end

function ForgeSmall.getServerId()
    return pr_lib.cache.get('serverId', GetPlayerServerId(PlayerId()))
end

function ForgeSmall.getVehicleState(vehicle, key, fallback)
    local value = pr_lib.fivem.vehicleCache.getState(vehicle, key)
    if value == nil then return fallback end
    return value
end

ForgeSmall.locale = pr_lib.locale()
locale = ForgeSmall.locale