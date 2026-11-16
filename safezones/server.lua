if not ForgeSmall.isEnabled('safezones') then return end

local config = ForgeSmall.SafezoneConfig or {}
local resourceName = GetCurrentResourceName()
local zones = {}
local stressCooldowns = {}

local function clamp(value, minimum, maximum)
    value = tonumber(value) or minimum
    return math.max(minimum, math.min(maximum, value))
end

local function roundSigned(value)
    value = tonumber(value) or 0
    return value >= 0 and math.floor(value + 0.5) or math.ceil(value - 0.5)
end

local function trim(value, maximum)
    value = tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if maximum and #value > maximum then value = value:sub(1, maximum) end
    return value
end

local function boolean(value, fallback)
    if value == nil then return fallback == true end
    if type(value) == 'boolean' then return value end
    local lowered = tostring(value):lower()
    return lowered == 'true' or lowered == '1' or lowered == 'yes' or lowered == 'sim'
end

local function copy(value)
    return json.decode(json.encode(value))
end

local function copyZones()
    return copy(zones) or {}
end

local function canManage(source)
    source = tonumber(source) or 0
    if source == 0 then return true end

    local permission = config.permission or 'group.admin'
    local allowed = false
    if pr_lib.framework and pr_lib.framework.HasPermission then
        local ok, result = pcall(pr_lib.framework.HasPermission, source, permission)
        allowed = ok and result == true
    end

    return allowed
        or IsPlayerAceAllowed(source, permission)
        or IsPlayerAceAllowed(source, 'command.' .. (config.command or 'forgezones'))
end

local function normalizeCoords(coords)
    if coords == nil then return end
    local x = tonumber(coords.x or coords[1])
    local y = tonumber(coords.y or coords[2])
    local z = tonumber(coords.z or coords[3])
    if not x or not y or not z then return end
    return { x = x + 0.0, y = y + 0.0, z = z + 0.0 }
end

local function normalizePoints(points)
    if type(points) ~= 'table' then return end
    local normalized = {}
    for i = 1, #points do
        local point = normalizeCoords(points[i])
        if point then normalized[#normalized + 1] = point end
    end
    if #normalized < 3 or #normalized > 64 then return end
    return normalized
end

local function polygonCenter(points)
    local x, y, z = 0.0, 0.0, 0.0
    for i = 1, #points do
        x, y, z = x + points[i].x, y + points[i].y, z + points[i].z
    end
    local count = math.max(1, #points)
    return { x = x / count, y = y / count, z = z / count }
end

local function sanitizeZone(input, id, owner, origin)
    if type(input) ~= 'table' then return nil, 'invalid_data' end

    local defaults = config.defaults or {}
    local zoneType = input.type == 'redzone' and 'redzone' or 'safezone'
    local shape = input.shape == 'poly' and 'poly' or 'sphere'
    local name = trim(input.name, 64)
    if name == '' then return nil, 'invalid_name' end

    local points
    local coords
    if shape == 'poly' then
        points = normalizePoints(input.points)
        if not points then return nil, 'invalid_points' end
        coords = polygonCenter(points)
    else
        coords = normalizeCoords(input.coords)
        if not coords then return nil, 'invalid_coords' end
    end

    local now = os.time()
    local stressAmount = roundSigned(clamp(input.stressAmount, -100, 100))
    owner = trim(owner or input.owner or resourceName, 96)
    -- The creator's origin survives later admin/API edits. Legacy files only
    -- have owner, so infer it without trusting origin from a client payload.
    if origin ~= 'local' and origin ~= 'api' then
        origin = (owner == resourceName or owner:match('^player:%d+$')) and 'local' or 'api'
    end

    return {
        id = tostring(id or input.id or ''),
        owner = owner,
        origin = origin,
        type = zoneType,
        shape = shape,
        name = name,
        coords = coords,
        points = points,
        radius = shape == 'sphere' and clamp(input.radius, 1.0, 1000.0) or nil,
        thickness = shape == 'poly' and clamp(input.thickness, 0.5, 1000.0) or nil,
        message = trim(input.message, 300),
        disableWeapons = boolean(input.disableWeapons, defaults.disableWeapons),
        disableAggression = boolean(input.disableAggression, defaults.disableAggression),
        disableRunning = boolean(input.disableRunning, defaults.disableRunning),
        stress = boolean(input.stress, defaults.stress),
        stressAmount = stressAmount,
        stressInterval = math.floor(clamp(input.stressInterval, 1, 3600)),
        notify = boolean(input.notify, defaults.notify),
        debug = boolean(input.debug, defaults.debug),
        active = boolean(input.active, defaults.active),
        createdAt = tonumber(input.createdAt) or now,
        updatedAt = now,
    }
end

local function saveZones()
    local encoded = json.encode(zones)
    if not encoded then return false, 'encode_failed' end

    local ok, result = pcall(SaveResourceFile, resourceName, config.dataFile or 'safezones/zones.json', encoded, -1)
    if not ok or result == false then return false, result or 'write_failed' end
    return true
end

local function loadZones()
    local raw = LoadResourceFile(resourceName, config.dataFile or 'safezones/zones.json')
    if not raw or raw == '' then
        zones = {}
        return saveZones()
    end

    local ok, decoded = pcall(json.decode, raw)
    if not ok or type(decoded) ~= 'table' then
        zones = {}
        if pr_lib.debug and pr_lib.debug.warn then pr_lib.debug.warn(locale('safezones.invalid_file')) end
        return false, 'invalid_file'
    end

    local loaded = {}
    for key, value in pairs(decoded) do
        if type(value) == 'table' then
            local legacyShape = value.shape == nil
            value.shape = value.shape or (type(value.points) == 'table' and 'poly' or 'sphere')
            if legacyShape then
                local legacyAmount = math.abs(tonumber(value.stressAmount) or 1)
                value.stressAmount = value.type == 'redzone' and legacyAmount or -legacyAmount
            end
            local id = trim(value.id or key, 96)
            if id ~= '' then
                local zone = sanitizeZone(value, id, value.owner, value.origin)
                if zone then
                    zone.createdAt = tonumber(value.createdAt) or zone.createdAt
                    zone.updatedAt = tonumber(value.updatedAt) or zone.updatedAt
                    loaded[id] = zone
                end
            end
        end
    end

    zones = loaded
    local saved = saveZones()
    return saved == true
end

local function syncZones(target)
    TriggerClientEvent('forge-smallresources:safezones:sync', target or -1, copyZones())
end

local function nextId(zoneType)
    local id
    repeat
        id = ('%s_%d_%06d'):format(zoneType or 'zone', os.time(), math.random(0, 999999))
    until not zones[id]
    return id
end

local function pointInPolygon(px, py, points)
    local inside = false
    local previous = #points
    for current = 1, #points do
        local a, b = points[current], points[previous]
        if ((a.y > py) ~= (b.y > py))
            and (px < (b.x - a.x) * (py - a.y) / ((b.y - a.y) + 0.0) + a.x)
        then
            inside = not inside
        end
        previous = current
    end
    return inside
end

local function contains(zone, coords, tolerance)
    tolerance = tonumber(tolerance) or 0.0
    if zone.shape == 'poly' then
        if not zone.points or #zone.points < 3 then return false end
        local halfThickness = (tonumber(zone.thickness) or 4.0) * 0.5 + tolerance
        local minZ, maxZ = math.huge, -math.huge
        for i = 1, #zone.points do
            minZ = math.min(minZ, zone.points[i].z)
            maxZ = math.max(maxZ, zone.points[i].z)
        end
        return coords.z >= minZ - halfThickness
            and coords.z <= maxZ + halfThickness
            and pointInPolygon(coords.x, coords.y, zone.points)
    end

    local dx = coords.x - zone.coords.x
    local dy = coords.y - zone.coords.y
    local dz = coords.z - zone.coords.z
    local radius = (tonumber(zone.radius) or 1.0) + tolerance
    return dx * dx + dy * dy + dz * dz <= radius * radius
end

local function upsertZone(input, requestedId, owner, origin)
    if type(input) ~= 'table' then return false, 'invalid_data' end

    local id = trim(requestedId or input.id, 96)
    local existing
    if id ~= '' then
        existing = zones[id]
        if not existing then return false, 'not_found' end
    else
        id = nextId(input.type)
    end

    input.createdAt = existing and existing.createdAt or input.createdAt
    local zone, reason = sanitizeZone(input, id, owner or (existing and existing.owner), existing and existing.origin or origin)
    if not zone then return false, reason end

    zones[id] = zone
    local saved, saveReason = saveZones()
    if not saved then
        zones[id] = existing
        return false, saveReason
    end

    stressCooldowns = {}
    syncZones()
    return true, copy(zone)
end

local function deleteZone(id)
    id = trim(id, 96)
    local removed = zones[id]
    if not removed then return false, 'not_found' end

    zones[id] = nil
    local saved, reason = saveZones()
    if not saved then
        zones[id] = removed
        return false, reason
    end

    stressCooldowns = {}
    syncZones()
    return true
end

pr_lib.callback.register('forge-smallresources:safezones:getZones', function(source)
    return copyZones(), canManage(source)
end)

pr_lib.callback.register('forge-smallresources:safezones:adminGetZones', function(source)
    if not canManage(source) then return false, 'no_permission' end
    return true, copyZones()
end)

pr_lib.callback.register('forge-smallresources:safezones:saveZone', function(source, input, apiResource)
    if not canManage(source) then return false, 'no_permission' end
    local external = type(apiResource) == 'string' and apiResource ~= '' and apiResource ~= resourceName
    return upsertZone(input, input and input.id, external and trim(apiResource, 96) or ('player:%s'):format(source), external and 'api' or 'local')
end)

pr_lib.callback.register('forge-smallresources:safezones:deleteZone', function(source, id)
    if not canManage(source) then return false, 'no_permission' end
    return deleteZone(id)
end)

pr_lib.callback.register('forge-smallresources:safezones:applyStress', function(source, id)
    source = tonumber(source)
    id = trim(id, 96)
    local zone = zones[id]
    if not source or not zone or not zone.active or not zone.stress then return false, 'not_available' end
    local getStatus = pr_lib.framework.GetPlayerStatus or pr_lib.framework.getPlayerStatus
    local addStatus = pr_lib.framework.AddPlayerStatus or pr_lib.framework.addPlayerStatus
    if type(getStatus) ~= 'function' or type(addStatus) ~= 'function' then return false, 'status_unavailable' end
    if zone.stressAmount == 0 then return true, tonumber(getStatus(source, 'stress')) or 0, 0 end

    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false, 'invalid_player' end
    local playerCoords = GetEntityCoords(ped)
    if not contains(zone, playerCoords, 2.0) then return false, 'outside_zone' end

    local now = os.time()
    stressCooldowns[source] = stressCooldowns[source] or {}
    local nextAllowed = stressCooldowns[source][id] or 0
    if now < nextAllowed then return false, 'rate_limited' end
    stressCooldowns[source][id] = now + zone.stressInterval

    local player = pr_lib.framework.GetPlayer and pr_lib.framework.GetPlayer(source)
    if not player then return false, 'invalid_player' end

    local current = tonumber(getStatus(source, 'stress')) or 0
    local applied, applyReason = addStatus(source, 'stress', zone.stressAmount)
    if applied ~= true then return false, applyReason or 'status_update_failed' end
    local newValue = tonumber(getStatus(source, 'stress')) or math.max(0, math.min(100, current + zone.stressAmount))

    if zone.debug and pr_lib.debug and pr_lib.debug.info then
        pr_lib.debug.info(('[forge-smallresources:safezones] source=%s zone=%s stress=%s delta=%s new=%s')
            :format(source, zone.id, current, zone.stressAmount, newValue))
    end

    return true, newValue, zone.stressAmount
end)

pr_lib.addCommand(config.command or 'forgezones', {
    help = locale('safezones.command_help'),
    restricted = config.permission or 'group.admin',
}, function(source)
    if source == 0 then return end
    TriggerClientEvent('forge-smallresources:safezones:openManager', source)
end)

AddEventHandler('playerDropped', function()
    stressCooldowns[source] = nil
end)

local function addExportZone(shape, data)
    data = copy(data) or {}
    data.shape = shape
    local owner = GetInvokingResource() or resourceName
    local ok, result = upsertZone(data, data.id, owner)
    if not ok then return nil, result end
    return result.id, result
end

local function updateExportZone(id, data)
    data = copy(data) or {}
    data.id = id
    local ok, result = upsertZone(data, id, GetInvokingResource() or resourceName)
    if not ok then return false, result end
    return true, result
end

local serverExports = {
    AddSphereZone = function(data) return addExportZone('sphere', data) end,
    addSphereZone = function(data) return addExportZone('sphere', data) end,
    AddPolyZone = function(data) return addExportZone('poly', data) end,
    addPolyZone = function(data) return addExportZone('poly', data) end,
    UpdateZone = updateExportZone,
    updateZone = updateExportZone,
    RemoveZone = deleteZone,
    removeZone = deleteZone,
    GetZone = function(id) return copy(zones[tostring(id)]) end,
    getZone = function(id) return copy(zones[tostring(id)]) end,
    GetZones = copyZones,
    getZones = copyZones,
}

local exportsRegistered, exportsReason = pr_lib.addExports(serverExports)
if not exportsRegistered then
    error(('Unable to register safezone server exports: %s'):format(tostring(exportsReason)))
end

loadZones()
