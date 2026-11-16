if not ForgeSmall.isEnabled('entityBlacklist') then return end

local config = pr_lib.load('entity_blacklist.config')
local bucketLockDownMode = GetConvar('forge:bucketlockdownmode', 'relaxed')
-- If you want to blacklist peds and vehicles from certaiin locations utilize Car gens ymaps as done in streams/car_gen_disablers, as entityCreating handler is very expensive compared to ymap.
if bucketLockDownMode ~= 'inactive' or table.type(config.blacklisted) == 'empty' then return end

-- Blacklisting entities can just be handled entirely server side with onesync events
-- No need to run coroutines to supress or delete these when we can simply delete them before they spawn
if type(config.blacklisted) ~= 'table' then
    pr_lib.print.warn(('[forge-smallresources:entity-blacklist] %s'):format(locale('debug.entity_blacklist_invalid')))
    return
end

AddEventHandler('entityCreating', function(handle)
    local entityModel = GetEntityModel(handle)

    if config.blacklisted[entityModel] then
        CancelEvent()
    end
end)

AddEventHandler('serverEntityCreated', function(handle)
    local entityModel = GetEntityModel(handle)

    if config.blacklisted[entityModel] then
        DeleteEntity(handle)
    end
end)
