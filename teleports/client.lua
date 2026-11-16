if not ForgeSmall.isEnabled('teleports') then return end

---@class Teleport
---@field coords vector3 | vector4
---@field localeKey string?
---@field drawText string? Legacy fallback
---@field allowVehicle boolean?
---@field ignoreGround boolean?

---@type { teleports: Teleport[][] }
local config = pr_lib.loadJson('teleports.config')
if #config.teleports == 0 then return end

local buttonTemplate = '[%s] %s'
local keybind

local function getTeleportLabel(teleport)
    if teleport.localeKey then return locale(teleport.localeKey) end
    return teleport.drawText or locale('teleports.default')
end

-- Sort out all elevators with only 1 or 0 levels to make sure no elevators are made with nowhere to go
-- Also convert coords arrays to vectors
local toRemove = {}
for i = 1, #config.teleports do
    local passage = config.teleports[i]
    if #passage > 1 then
        for level = 1, #passage do
            local data = passage[level]
            if #data.coords == 4 then
                data.coords = vec4(data.coords[1], data.coords[2], data.coords[3], data.coords[4])
            else
                data.coords = vec3(data.coords[1], data.coords[2], data.coords[3])
            end
        end
    else
        toRemove[#toRemove + 1] = i
    end
end

if #toRemove ~= 0 then
    for i = 1, #toRemove do
        table.remove(config.teleports, toRemove[i])
    end
end

local zones = {}

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    for i = 1, #zones do
        zones[i]:remove()
    end
end)

-- {teleportIndex, levelNum}
local currentLevel = {0, 0}

CreateThread(function()
    for i = 1, #config.teleports do
        local passage = config.teleports[i]
        for level = 1, #passage do
            local entrance = passage[level]
            zones[#zones + 1] = pr_lib.zones.sphere({
                coords = entrance.coords.xyz,
                radius = 2,
                onEnter = function()
                    pr_lib.showTextUI(buttonTemplate:format(keybind.currentKey, getTeleportLabel(entrance)))

                    currentLevel = {i, level}
                end,
                onExit = function()
                    currentLevel = {0, 0}
                    if pr_lib.getOpenMenu() == 'forge-smallresources:teleports' then
                        pr_lib.hideMenu(true)
                    end
                    pr_lib.hideTextUI()
                end
            })
        end
    end
end)

local function onPressed()
    if currentLevel[1] == 0 or currentLevel[2] == 0 then return end

    keybind:disable(true)

    local teleports = config.teleports[currentLevel[1]]
    local curTeleport = teleports[currentLevel[2]]
    local teleportOptions = {}

    for i = 1, #teleports do
        local isCurrentLevel = i == currentLevel[2]
        teleportOptions[#teleportOptions + 1] = {
            label = ('%s%s'):format(locale('info.teleport_level_select', i), isCurrentLevel and (' %s'):format(locale('info.teleport_current_level_indication')) or ''),
            args = {not isCurrentLevel and i or nil},
            close = not isCurrentLevel
        }
    end

    pr_lib.registerMenu({
        id = 'forge-smallresources:teleports',
        title = getTeleportLabel(curTeleport),
        onClose = function()
            keybind:disable(false)
        end,
        options = teleportOptions
    }, function(_, _, args)
        if not args or table.type(args) == 'empty' then return end

        local newLevel = args[1]
        local destination = teleports[newLevel]
        local coordZ = destination.coords.z

        if not destination.ignoreGround then
            local isSafe, z = GetGroundZFor_3dCoord(
                destination.coords.x,
                destination.coords.y,
                destination.coords.z,
                false
            )

            if isSafe then coordZ = z end
        end

        if destination.allowVehicle and pr_lib.cache.vehicle then
            SetPedCoordsKeepVehicle(
                pr_lib.cache.ped,
                destination.coords.x,
                destination.coords.y,
                coordZ
            )

            SetVehicleOnGroundProperly(pr_lib.cache.vehicle)
        else
            SetEntityCoords(
                pr_lib.cache.ped,
                destination.coords.x,
                destination.coords.y,
                coordZ,
                true, false, false, false
            )
        end

        if type(destination.coords) == 'vector4' then
            SetEntityHeading(pr_lib.cache.ped, destination.coords.w)
        end

        currentLevel[2] = newLevel

        Wait(250) -- Make sure we can't spam teleport and we have been teleported completely

        keybind:disable(false)
    end)

    pr_lib.showMenu('forge-smallresources:teleports')
end

keybind = pr_lib.addKeybind({
    name = 'forge_teleport_interact',
    description = locale('keybind.teleport'),
    defaultKey = 'E',
    secondaryMapper = 'PAD_DIGITALBUTTONANY',
    secondaryKey = 'RRIGHT_INDEX',
    onPressed = onPressed
})
