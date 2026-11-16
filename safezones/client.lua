if not ForgeSmall.isEnabled('safezones') then return end

local config = ForgeSmall.SafezoneConfig or {}
local timeout = tonumber(config.callbackTimeout) or 10000
local zones, runtimeZones, targetZones, activeZones, stressDue = {}, {}, {}, {}, {}
local weaponSwitchBlocked = false
local managerParentMenu, managerParentResource
local debugAllowed, debugInitialized = false, false
local debugMode = config.debugMode == 'all' and 'all' or config.debugMode == 'individual' and 'individual' or 'off'
local individualDebug = {}
local debugProviders = {}

local function syncDebugProviders()
    local mode = debugAllowed and debugMode or 'off'
    for resource, provider in pairs(debugProviders) do
        if mode == 'off' then provider.selected = {} end
        local selected = {}
        for id, enabled in pairs(provider.selected) do selected[id] = enabled end
        if not pcall(provider.callback, mode, selected) then debugProviders[resource] = nil end
    end
end

local function isManagedZone(zone)
    if zone.origin then return zone.origin == 'local' end
    local owner = tostring(zone.owner or GetCurrentResourceName())
    return owner == GetCurrentResourceName() or owner:match('^player:%d+$') ~= nil
end

local function debugVisible(id, zone)
    return debugAllowed and (debugMode == 'all'
        or (debugMode == 'individual' and isManagedZone(zone) and individualDebug[tostring(id)] == true))
end

local function copy(value)
    return json.decode(json.encode(value))
end

local function sortedZones(source)
    local list = {}
    for _, zone in pairs(source or {}) do list[#list + 1] = zone end
    table.sort(list, function(left, right)
        local leftName, rightName = tostring(left.name or ''), tostring(right.name or '')
        if leftName == rightName then return tostring(left.id) < tostring(right.id) end
        return leftName:lower() < rightName:lower()
    end)
    return list
end

local function vector(coords)
    return vec3(tonumber(coords.x) or 0.0, tonumber(coords.y) or 0.0, tonumber(coords.z) or 0.0)
end

local function vectorPoints(points)
    local output = {}
    for i = 1, #(points or {}) do output[i] = vector(points[i]) end
    return output
end

local function zoneDefaultMessage(zone)
    local key = zone.type == 'redzone' and 'safezones.enter_redzone' or 'safezones.enter_safezone'
    return locale(key, zone.name)
end

local function notifyZone(zone)
    if not zone.notify then return end
    ForgeSmall.notify(zone.message ~= '' and zone.message or zoneDefaultMessage(zone), zone.type == 'redzone' and 'error' or 'success', 5000)
end

local function clearRuntimeZones()
    for _, point in pairs(runtimeZones) do
        if point and point.remove then point:remove() end
    end
    for _, targetId in pairs(targetZones) do
        if pr_lib.target and pr_lib.target.removeZone then
            pcall(pr_lib.target.removeZone, targetId, true)
        end
    end
    runtimeZones, targetZones, activeZones, stressDue = {}, {}, {}, {}
end

local function registerTargetGeometry(zoneId, zone, points)
    if not pr_lib.target then return end

    local data = {
        name = 'forge_smallresources_zone_' .. zoneId,
        -- One local renderer owns visualization; the Target must not expose
        -- persisted/API debug flags to other players or duplicate the drawing.
        debug = false,
        drawSprite = false,
        distance = math.max(2.0, tonumber(zone.radius) or 2.0),
        options = {},
    }

    local ok, targetId
    if zone.shape == 'poly' and pr_lib.target.addPolyZone then
        data.points = points
        data.thickness = tonumber(zone.thickness) or 4.0
        ok, targetId = pcall(pr_lib.target.addPolyZone, data)
    elseif pr_lib.target.addSphereZone then
        data.coords = vector(zone.coords)
        data.radius = tonumber(zone.radius) or 1.0
        ok, targetId = pcall(pr_lib.target.addSphereZone, data)
    end

    if ok and targetId then targetZones[zoneId] = targetId end
end

local function rebuildZones(payload)
    clearRuntimeZones()
    zones = type(payload) == 'table' and payload or {}

    for id, zone in pairs(zones) do
        if zone.active ~= false and type(zone.coords) == 'table' then
            local zoneId, zoneData = tostring(id), zone
            local pointData = {
                debug = false,
                onEnter = function()
                    activeZones[zoneId] = zoneData
                    stressDue[zoneId] = GetGameTimer()
                    notifyZone(zoneData)
                end,
                onExit = function()
                    activeZones[zoneId] = nil
                    stressDue[zoneId] = nil
                end,
            }

            if zone.shape == 'poly' and type(zone.points) == 'table' and #zone.points >= 3 then
                local points = vectorPoints(zone.points)
                pointData.points = points
                pointData.thickness = tonumber(zone.thickness) or 4.0
                runtimeZones[zoneId] = pr_lib.zones.poly(pointData)
                registerTargetGeometry(zoneId, zone, points)
            else
                pointData.coords = vector(zone.coords)
                pointData.radius = tonumber(zone.radius) or 1.0
                runtimeZones[zoneId] = pr_lib.zones.sphere(pointData)
                registerTargetGeometry(zoneId, zone)
            end
        end
    end
end

local function loadZones()
    local ok, payload, allowed = pcall(function()
        return pr_lib.callback.await('forge-smallresources:safezones:getZones', timeout)
    end)
    if ok and type(payload) == 'table' then
        debugAllowed = allowed == true
        syncDebugProviders()
        rebuildZones(payload)
        if not debugInitialized then
            debugInitialized = true
            if debugMode == 'individual' then
                for id, zone in pairs(zones) do
                    if isManagedZone(zone) and zone.debug == true then individualDebug[tostring(id)] = true end
                end
            end
        end
        return true
    end
    return false
end

RegisterNetEvent('forge-smallresources:safezones:sync', function(payload)
    rebuildZones(payload)
end)

CreateThread(function()
    for _ = 1, 10 do
        if loadZones() then return end
        Wait(1000)
    end
    ForgeSmall.notify(locale('safezones.sync_failed'), 'error')
end)

local function restrictions()
    local result = { weapons = false, aggression = false, running = false }
    for _, zone in pairs(activeZones) do
        result.weapons = result.weapons or zone.disableWeapons == true
        result.aggression = result.aggression or zone.disableAggression == true
        result.running = result.running or zone.disableRunning == true
    end
    return result
end

CreateThread(function()
    while true do
        if next(activeZones) then
            Wait(0)
            local current = restrictions()
            local ped, playerId = ForgeSmall.getPed(), ForgeSmall.getPlayerId()

            if current.weapons then
                DisablePlayerFiring(playerId, true)
                DisableControlAction(0, 37, true)
                SetPedCanSwitchWeapon(ped, false)
                if GetSelectedPedWeapon(ped) ~= GetHashKey('WEAPON_UNARMED') then
                    SetCurrentPedWeapon(ped, GetHashKey('WEAPON_UNARMED'), true)
                end
                weaponSwitchBlocked = true
            elseif weaponSwitchBlocked then
                SetPedCanSwitchWeapon(ped, true)
                weaponSwitchBlocked = false
            end

            if current.weapons or current.aggression then
                DisablePlayerFiring(playerId, true)
                for _, control in ipairs({ 24, 25, 69, 70, 91, 92, 140, 141, 142, 143, 257, 263, 264, 331 }) do
                    DisableControlAction(0, control, true)
                end
            end

            if current.running then DisableControlAction(0, 21, true) end
        else
            if weaponSwitchBlocked then
                SetPedCanSwitchWeapon(ForgeSmall.getPed(), true)
                weaponSwitchBlocked = false
            end
            Wait(500)
        end
    end
end)

CreateThread(function()
    while true do
        if next(activeZones) then
            local now = GetGameTimer()
            for id, zone in pairs(activeZones) do
                if zone.stress == true and tonumber(zone.stressAmount) ~= 0 and now >= (stressDue[id] or 0) then
                    local zoneId, zoneData = id, zone
                    stressDue[zoneId] = now + math.max(1, tonumber(zoneData.stressInterval) or 10) * 1000
                    CreateThread(function()
                        local ok, applied, value, delta = pcall(function()
                            return pr_lib.callback.await('forge-smallresources:safezones:applyStress', timeout, zoneId)
                        end)
                        if zoneData.debug and pr_lib.debug and pr_lib.debug.info then
                            pr_lib.debug.info(('[forge-smallresources:safezones] zone=%s ok=%s applied=%s value=%s delta=%s')
                                :format(zoneId, ok, applied, value, delta))
                        end
                    end)
                end
            end
            Wait(250)
        else
            Wait(1000)
        end
    end
end)

local function drawPolyDebug(zone)
    local points = zone.points or {}
    if #points < 3 then return end
    local half = (tonumber(zone.thickness) or 4.0) * 0.5
    for i = 1, #points do
        local current = points[i]
        local following = points[i % #points + 1]
        DrawLine(current.x, current.y, current.z - half, following.x, following.y, following.z - half, 255, 42, 24, 220)
        DrawLine(current.x, current.y, current.z + half, following.x, following.y, following.z + half, 255, 42, 24, 220)
        DrawLine(current.x, current.y, current.z - half, current.x, current.y, current.z + half, 255, 42, 24, 180)
    end
end

CreateThread(function()
    while true do
        local drew = false
        local cameraCoords = GetFinalRenderedCamCoord()
        for id, zone in pairs(zones) do
            if zone.active ~= false and debugVisible(id, zone) and type(zone.coords) == 'table' then
                local center = vector(zone.coords)
                local distance = #(cameraCoords - center)
                local runtime = runtimeZones[tostring(id)]
                local extent = tonumber(runtime and runtime.radius) or tonumber(zone.radius) or 0.0
                local viewDistance = math.max(100.0, tonumber(config.debugDrawDistance) or 1500.0) + extent
                if distance <= viewDistance then
                    drew = true
                    if zone.shape == 'poly' then
                        drawPolyDebug(zone)
                    else
                        local diameter = (tonumber(zone.radius) or 1.0) * 2.0
                        DrawMarker(28, center.x, center.y, center.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                            diameter, diameter, diameter, 255, 42, 24, 45, false, false, 2, false, nil, nil, false)
                    end
                end
            end
        end
        Wait(drew and 0 or 500)
    end
end)

local function failureMessage(reason)
    local known = {
        no_permission = 'safezones.no_permission',
        invalid_name = 'safezones.invalid_name',
        invalid_coords = 'safezones.invalid_coords',
        invalid_points = 'safezones.invalid_points',
        not_found = 'safezones.not_found',
    }
    return locale(known[reason] or 'safezones.save_failed')
end

local function captureCoords()
    local coords = GetEntityCoords(ForgeSmall.getPed())
    return { x = coords.x + 0.0, y = coords.y + 0.0, z = coords.z + 0.0 }
end

local function defaultPolyPoints()
    local center = captureCoords()
    local size = tonumber(config.defaults and config.defaults.polySize) or 5.0
    return {
        { x = center.x - size, y = center.y - size, z = center.z },
        { x = center.x + size, y = center.y - size, z = center.z },
        { x = center.x + size, y = center.y + size, z = center.z },
        { x = center.x - size, y = center.y + size, z = center.z },
    }
end

local function encodePoints(points)
    return json.encode(points or defaultPolyPoints())
end

local function decodePoints(value)
    if type(value) == 'table' then return value end
    local ok, points = pcall(json.decode, tostring(value or ''))
    if not ok or type(points) ~= 'table' or #points < 3 then return end
    local normalized = {}
    for i = 1, #points do
        local point = points[i]
        local x, y, z = tonumber(point.x or point[1]), tonumber(point.y or point[2]), tonumber(point.z or point[3])
        if not x or not y or not z then return end
        normalized[#normalized + 1] = { x = x, y = y, z = z }
    end
    return normalized
end

local function centerOf(points)
    local x, y, z = 0.0, 0.0, 0.0
    for i = 1, #points do
        x, y, z = x + points[i].x, y + points[i].y, z + points[i].z
    end
    return { x = x / #points, y = y / #points, z = z / #points }
end

local function movePointsToPlayer(points)
    local oldCenter, newCenter = centerOf(points), captureCoords()
    local dx, dy, dz = newCenter.x - oldCenter.x, newCenter.y - oldCenter.y, newCenter.z - oldCenter.z
    for i = 1, #points do
        points[i] = { x = points[i].x + dx, y = points[i].y + dy, z = points[i].z + dz }
    end
    return points
end

local openManager
local showDebugMenu

local function authorizeDebug()
    local ok, allowed = pcall(function()
        return pr_lib.callback.await('forge-smallresources:safezones:adminGetZones', timeout)
    end)
    debugAllowed = ok and allowed == true
    if not debugAllowed then
        debugMode, individualDebug = 'off', {}
        syncDebugProviders()
        ForgeSmall.notify(locale('safezones.no_permission'), 'error')
    end
    return debugAllowed
end

showDebugMenu = function()
    syncDebugProviders()
    local options = {
        {
            title = locale('safezones.debug_all'),
            description = locale('safezones.debug_all_description'),
            icon = 'globe',
            checked = debugMode == 'all',
            onSelect = function()
                if not authorizeDebug() then return end
                if debugMode == 'all' then debugMode, individualDebug = 'off', {}
                else debugMode = 'all' end
                showDebugMenu()
            end,
        },
        {
            title = locale('safezones.debug_hide_all'),
            description = locale('safezones.debug_hide_description'),
            icon = 'eye-slash',
            onSelect = function()
                if not authorizeDebug() then return end
                debugMode, individualDebug = 'off', {}
                showDebugMenu()
            end,
        },
    }
    for _, zone in ipairs(sortedZones(zones)) do
        if isManagedZone(zone) then
            local id = tostring(zone.id)
            options[#options + 1] = {
                title = zone.name,
                description = locale('safezones.debug_individual_description'),
                icon = zone.type == 'redzone' and 'biohazard' or 'shield-halved',
                iconColor = zone.type == 'redzone' and '#ef4444' or '#22c55e',
                checked = debugMode == 'individual' and individualDebug[id] == true,
                onSelect = function()
                    if not authorizeDebug() then return end
                    if not zones[id] or not isManagedZone(zones[id]) then return end
                    if debugMode ~= 'individual' then individualDebug = {} end
                    debugMode = 'individual'
                    individualDebug[id] = not individualDebug[id] or nil
                    showDebugMenu()
                end,
            }
        end
    end
    pr_lib.registerContext({
        id = 'forge-smallresources:safezones:debug',
        menu = 'forge-smallresources:safezones:manager',
        title = locale('safezones.debug_menu'),
        options = options,
    })
    pr_lib.showContext('forge-smallresources:safezones:debug')
end

local function selectZoneSetup()
    local result = pr_lib.inputDialog(locale('safezones.create_title'), {
        {
            type = 'select',
            label = locale('safezones.field_shape'),
            required = true,
            default = 'sphere',
            options = {
                { value = 'sphere', label = locale('safezones.shape_sphere') },
                { value = 'poly', label = locale('safezones.shape_poly') },
            },
        },
        {
            type = 'select',
            label = locale('safezones.field_type'),
            required = true,
            default = 'safezone',
            options = {
                { value = 'safezone', label = locale('safezones.type_safezone') },
                { value = 'redzone', label = locale('safezones.type_redzone') },
            },
        },
    })
    if not result then return end
    return result[1], result[2]
end

local function saveZoneDialog(existing, requestedShape, requestedType, geometry)
    local defaults = config.defaults or {}
    local editing = type(existing) == 'table'
    local shape = editing and existing.shape or requestedShape
    if shape ~= 'poly' then shape = 'sphere' end
    local zone = copy(existing or defaults) or {}
    if type(geometry) == 'table' then
        if shape == 'poly' then
            zone.points = copy(geometry.points)
            zone.thickness = tonumber(geometry.thickness) or tonumber(zone.thickness) or tonumber(defaults.thickness) or 4.0
            zone.coords = centerOf(zone.points)
        else
            zone.coords = copy(geometry.coords)
            zone.radius = tonumber(geometry.radius) or tonumber(zone.radius) or 30.0
        end
    end

    if not editing then
        zone.type = requestedType == 'redzone' and 'redzone' or 'safezone'
        local defaultAmount = math.abs(tonumber(defaults.stressAmount) or 1)
        zone.stressAmount = zone.type == 'redzone' and defaultAmount or -defaultAmount
    end
    local rows = {
        {
            type = 'select', label = locale('safezones.field_type'), required = true,
            default = zone.type or 'safezone',
            options = {
                { value = 'safezone', label = locale('safezones.type_safezone') },
                { value = 'redzone', label = locale('safezones.type_redzone') },
            },
        },
        { type = 'input', label = locale('safezones.field_name'), required = true, min = 2, max = 64, default = zone.name or '' },
        { type = 'textarea', label = locale('safezones.field_message'), min = 0, max = 300, default = zone.message or '' },
        { type = 'checkbox', label = locale('safezones.field_disable_weapons'), checked = zone.disableWeapons == true },
        { type = 'checkbox', label = locale('safezones.field_disable_aggression'), checked = zone.disableAggression == true },
        { type = 'checkbox', label = locale('safezones.field_disable_running'), checked = zone.disableRunning == true },
        { type = 'checkbox', label = locale('safezones.field_stress'), checked = zone.stress == true },
        {
            type = 'number',
            label = locale('safezones.field_stress_amount'),
            description = locale('safezones.field_stress_amount_description'),
            required = true,
            min = -100,
            max = 100,
            default = tonumber(zone.stressAmount) or (zone.type == 'redzone' and 1 or -1),
        },
        { type = 'number', label = locale('safezones.field_stress_interval'), required = true, min = 1, max = 3600, default = tonumber(zone.stressInterval) or 10 },
        { type = 'checkbox', label = locale('safezones.field_notify'), checked = zone.notify == true },
        { type = 'checkbox', label = locale('safezones.field_active'), checked = zone.active ~= false },
        {
            type = 'checkbox', label = locale('safezones.field_debug'), checked = zone.debug == true,
            disabled = not isManagedZone(zone),
            description = locale(isManagedZone(zone) and 'safezones.debug_field_description' or 'safezones.debug_api_only'),
        },
    }

    if shape == 'poly' then
        rows[#rows + 1] = {
            type = 'textarea',
            label = locale('safezones.field_points'),
            description = locale('safezones.field_points_description'),
            required = true,
            autosize = true,
            default = encodePoints(zone.points),
        }
        rows[#rows + 1] = {
            type = 'number',
            label = locale('safezones.field_thickness'),
            required = true,
            min = 0.5,
            max = 1000,
            default = tonumber(zone.thickness) or tonumber(defaults.thickness) or 4,
        }
    else
        rows[#rows + 1] = {
            type = 'number',
            label = locale('safezones.field_radius'),
            required = true,
            min = 1,
            max = 1000,
            default = tonumber(zone.radius) or 30,
        }
    end

    if editing then
        rows[#rows + 1] = { type = 'checkbox', label = locale('safezones.field_move_here'), checked = false }
    end

    local title = editing and locale('safezones.edit_title', zone.name)
        or locale('safezones.create_shape_title', shape == 'poly' and locale('safezones.shape_poly') or locale('safezones.shape_sphere'))
    local result = pr_lib.inputDialog(title, rows, { size = 'lg' })
    if not result then return openManager() end

    local payload = {
        id = editing and zone.id or nil,
        shape = shape,
        type = result[1],
        name = result[2],
        message = tostring(result[3] or ''),
        disableWeapons = result[4] == true,
        disableAggression = result[5] == true,
        disableRunning = result[6] == true,
        stress = result[7] == true,
        stressAmount = tonumber(result[8]),
        stressInterval = tonumber(result[9]),
        notify = result[10] == true,
        active = result[11] == true,
        debug = result[12] == true,
        createdAt = zone.createdAt,
    }

    if shape == 'poly' then
        payload.points = decodePoints(result[13])
        if not payload.points then
            ForgeSmall.notify(locale('safezones.invalid_points'), 'error')
            return saveZoneDialog(existing, shape)
        end
        payload.thickness = tonumber(result[14])
        if editing and result[15] == true then payload.points = movePointsToPlayer(payload.points) end
    else
        payload.radius = tonumber(result[13])
        payload.coords = zone.coords or captureCoords()
        if editing and result[14] == true then payload.coords = captureCoords() end
    end

    local ok, saved, response = pcall(function()
        return pr_lib.callback.await('forge-smallresources:safezones:saveZone', timeout, payload)
    end)
    if not ok or saved ~= true then
        ForgeSmall.notify(failureMessage(response), 'error')
        return openManager()
    end

    ForgeSmall.notify(locale(editing and 'safezones.updated' or 'safezones.created', response.name), 'success')
    if isManagedZone(response) and (not editing or response.debug ~= zone.debug) then
        individualDebug[tostring(response.id)] = response.debug == true or nil
        if response.debug == true and debugMode == 'off' then debugMode = 'individual' end
    end
    Wait(100)
    openManager()
end

local function openZoneCreator(shape, zoneType, existing)
    local devtools = pr_lib.devtools or pr_lib.devTools
    if type(devtools) ~= 'table' then
        ForgeSmall.notify(locale('safezones.creator_unavailable'), 'error')
        return openManager()
    end

    local options = {
        freezePlayer = true,
        radius = existing and tonumber(existing.radius) or tonumber(config.defaults and config.defaults.radius) or 5.0,
        wallHeight = existing and tonumber(existing.thickness) or tonumber(config.defaults and config.defaults.thickness) or 4.0,
    }

    local function cancelled()
        ForgeSmall.notify(locale('safezones.creator_cancelled'), 'inform')
        openManager()
    end

    if shape == 'poly' then
        local creator = devtools.createPolyzone or devtools.drawPolyzone3D or devtools.DrawPolyzone3D
        if type(creator) ~= 'function' then
            ForgeSmall.notify(locale('safezones.creator_unavailable'), 'error')
            return openManager()
        end

        local started = creator(options, function(points, bounds)
            if type(points) ~= 'table' or #points < 3 then return cancelled() end
            saveZoneDialog(existing, 'poly', zoneType, {
                points = points,
                thickness = bounds and bounds.thickness or options.wallHeight,
            })
        end)
        if started == false then cancelled() end
        return
    end

    local creator = devtools.createSphereZone or devtools.drawSphereZone3D or devtools.DrawSphereZone3D
    if type(creator) ~= 'function' then
        ForgeSmall.notify(locale('safezones.creator_unavailable'), 'error')
        return openManager()
    end

    local started = creator(options, function(result)
        if type(result) ~= 'table' or type(result.coords) ~= 'table' then return cancelled() end
        saveZoneDialog(existing, 'sphere', zoneType, result)
    end)
    if started == false then cancelled() end
end

local function deleteZone(zone)
    local confirmed = pr_lib.alertDialog({
        header = locale('safezones.delete_title'),
        content = locale('safezones.delete_confirm', zone.name),
        centered = true,
        cancel = true,
    }) == 'confirm'
    if not confirmed then return openManager() end

    local ok, deleted, reason = pcall(function()
        return pr_lib.callback.await('forge-smallresources:safezones:deleteZone', timeout, zone.id)
    end)
    if not ok or deleted ~= true then
        ForgeSmall.notify(failureMessage(reason), 'error')
        return openManager()
    end

    ForgeSmall.notify(locale('safezones.deleted', zone.name), 'success')
    Wait(100)
    openManager()
end

local function zoneMetric(zone)
    if zone.shape == 'poly' then
        return locale('safezones.points_summary', #(zone.points or {}))
    end
    return locale('safezones.radius_summary', tonumber(zone.radius) or 0)
end

local function openZoneMenu(zone)
    local kind = zone.type == 'redzone' and locale('safezones.type_redzone') or locale('safezones.type_safezone')
    local shape = zone.shape == 'poly' and locale('safezones.shape_poly') or locale('safezones.shape_sphere')
    pr_lib.registerContext({
        id = 'forge-smallresources:safezones:zone:' .. zone.id,
        menu = 'forge-smallresources:safezones:manager',
        title = zone.name,
        options = {
            {
                title = kind,
                description = locale('safezones.zone_summary', shape, zoneMetric(zone), zone.active ~= false and locale('safezones.enabled') or locale('safezones.disabled')),
                icon = zone.type == 'redzone' and 'biohazard' or 'shield-halved',
                iconColor = zone.type == 'redzone' and '#ef4444' or '#22c55e',
                readOnly = true,
            },
            {
                title = locale('safezones.edit_action'),
                description = locale('safezones.edit_description'),
                icon = 'pen-to-square',
                onSelect = function() saveZoneDialog(zone, zone.shape, zone.type) end,
            },
            {
                title = locale('safezones.creator_action'),
                description = locale('safezones.creator_description'),
                icon = 'draw-polygon',
                iconColor = '#22c55e',
                onSelect = function() openZoneCreator(zone.shape, zone.type, zone) end,
            },
            {
                title = locale('safezones.delete_action'),
                description = locale('safezones.delete_description'),
                icon = 'trash',
                iconColor = '#ef4444',
                onSelect = function() deleteZone(zone) end,
            },
        },
    })
    pr_lib.showContext('forge-smallresources:safezones:zone:' .. zone.id)
end

openManager = function()
    local ok, allowed, payload = pcall(function()
        return pr_lib.callback.await('forge-smallresources:safezones:adminGetZones', timeout)
    end)
    if not ok or allowed ~= true then
        debugAllowed, debugMode, individualDebug = false, 'off', {}
        syncDebugProviders()
        return ForgeSmall.notify(failureMessage(payload), 'error')
    end
    debugAllowed = true
    syncDebugProviders()

    local options = {
        {
            title = locale('safezones.debug_menu'),
            description = locale('safezones.debug_menu_description'),
            icon = 'bug',
            onSelect = function() if authorizeDebug() then showDebugMenu() end end,
        },
        {
            title = locale('safezones.create_action'),
            description = locale('safezones.create_description'),
            icon = 'circle-plus',
            iconColor = '#22c55e',
            onSelect = function()
                local shape, zoneType = selectZoneSetup()
                if not shape then return openManager() end
                openZoneCreator(shape, zoneType)
            end,
        },
    }

    for _, zone in ipairs(sortedZones(payload)) do
        local zoneData = zone
        local kind = zoneData.type == 'redzone' and locale('safezones.type_redzone') or locale('safezones.type_safezone')
        local shape = zoneData.shape == 'poly' and locale('safezones.shape_poly') or locale('safezones.shape_sphere')
        options[#options + 1] = {
            title = zoneData.name,
            description = locale('safezones.list_description', kind, shape, zoneMetric(zoneData)),
            icon = zoneData.type == 'redzone' and 'biohazard' or 'shield-halved',
            iconColor = zoneData.active ~= false and (zoneData.type == 'redzone' and '#ef4444' or '#22c55e') or '#6b7280',
            arrow = true,
            onSelect = function() openZoneMenu(zoneData) end,
        }
    end

    pr_lib.registerContext({
        id = 'forge-smallresources:safezones:manager',
        title = locale('safezones.manager_title'),
        menu = managerParentMenu,
        menuResource = managerParentResource,
        searchPlaceholder = locale('safezones.search_placeholder'),
        options = options,
    })
    pr_lib.showContext('forge-smallresources:safezones:manager')
end

local function openAdminMenu(parentMenu, parentResource)
    managerParentMenu = type(parentMenu) == 'string' and parentMenu ~= '' and parentMenu or nil

    local invokingResource = GetInvokingResource()
    managerParentResource = type(parentResource) == 'string' and parentResource ~= '' and parentResource
        or (type(invokingResource) == 'string' and invokingResource ~= '' and invokingResource)
        or nil

    if managerParentResource == GetCurrentResourceName() then managerParentResource = nil end
    return openManager()
end

RegisterNetEvent('forge-smallresources:safezones:openManager', function(parentMenu, parentResource)
    openAdminMenu(parentMenu, parentResource)
end)

local function clientSaveZone(shape, data)
    data = copy(data) or {}
    data.shape = shape
    return pr_lib.callback.await('forge-smallresources:safezones:saveZone', timeout, data, GetInvokingResource())
end

local function clientUpdateZone(id, data)
    data = copy(data) or {}
    data.id = id
    return pr_lib.callback.await('forge-smallresources:safezones:saveZone', timeout, data, GetInvokingResource())
end

local function clientRemoveZone(id)
    return pr_lib.callback.await('forge-smallresources:safezones:deleteZone', timeout, id)
end

-- Client-only integration for resources that own their functional PR zones.
-- The callback controls drawing only; no zone/effect is recreated or persisted.
local function registerZoneDebugProvider(callback)
    local resource = GetInvokingResource()
    if not resource or resource == GetCurrentResourceName() or type(callback) ~= 'function' then return false end
    local previous = debugProviders[resource]
    debugProviders[resource] = { callback = callback, selected = previous and previous.selected or {} }
    syncDebugProviders()
    return debugProviders[resource] ~= nil
end

local function setZoneDebugSelection(id, enabled)
    local provider = debugProviders[GetInvokingResource()]
    if not provider or type(id) ~= 'string' or id == '' or #id > 192 then return false end
    if not authorizeDebug() then return false end
    if debugMode ~= 'individual' then
        individualDebug = {}
        for _, current in pairs(debugProviders) do current.selected = {} end
    end
    debugMode = 'individual'
    provider.selected[id] = enabled == true or nil
    syncDebugProviders()
    return true
end

local clientExports = {
    RegisterZoneDebugProvider = registerZoneDebugProvider,
    SetZoneDebugSelection = setZoneDebugSelection,
    OpenAdminMenu = openAdminMenu,
    openAdminMenu = openAdminMenu,
    AddSphereZone = function(data) return clientSaveZone('sphere', data) end,
    addSphereZone = function(data) return clientSaveZone('sphere', data) end,
    AddPolyZone = function(data) return clientSaveZone('poly', data) end,
    addPolyZone = function(data) return clientSaveZone('poly', data) end,
    UpdateZone = clientUpdateZone,
    updateZone = clientUpdateZone,
    RemoveZone = clientRemoveZone,
    removeZone = clientRemoveZone,
    GetZones = function() return copy(zones) or {} end,
    getZones = function() return copy(zones) or {} end,
    GetActiveZones = function() return copy(activeZones) or {} end,
    getActiveZones = function() return copy(activeZones) or {} end,
    IsInZone = function(id) return activeZones[tostring(id)] ~= nil end,
    isInZone = function(id) return activeZones[tostring(id)] ~= nil end,
}

local exportsRegistered, exportsReason = pr_lib.addExports(clientExports)
if not exportsRegistered then
    error(('Unable to register safezone client exports: %s'):format(tostring(exportsReason)))
end

for _, event in ipairs({ 'QBCore:Client:OnPlayerUnload', 'esx:onPlayerLogout' }) do
    RegisterNetEvent(event, function()
        debugAllowed, debugMode, individualDebug = false, 'off', {}
        syncDebugProviders()
    end)
end

AddEventHandler('onResourceStop', function(stoppedResource)
    debugProviders[stoppedResource] = nil
    if stoppedResource ~= GetCurrentResourceName() then return end
    debugAllowed = false
    syncDebugProviders()
    clearRuntimeZones()
    if weaponSwitchBlocked then SetPedCanSwitchWeapon(ForgeSmall.getPed(), true) end
end)
