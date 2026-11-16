if not ForgeSmall.isEnabled('staticEmitters') then return end

local config = pr_lib.load('static_emitters.config')
local currentGameBuild = GetGameBuildNumber()
local setStaticEmitterEnabled = SetStaticEmitterEnabled

if not config.enabled then return end

local emitterGroupsData = {}

local function registerMenus()
    local mainOptions = {}
    local submenus = {}

    for gameBuild, emitterGroups in pairs(config.gameBuild) do
        if currentGameBuild >= gameBuild then
            for emitterGroup in pairs(emitterGroups) do
                if not mainOptions[emitterGroup] then
                    local groupTitle = emitterGroup:gsub('%f[%a].', string.upper)
                    mainOptions[emitterGroup] = {
                        label = groupTitle,
                        description = locale('static_emitters.game_build', gameBuild),
                        icon = 'folder',
                    }
                    submenus[#submenus + 1] = emitterGroup
                end
            end
        end
    end

    local mainMenuOptions = {}
    for i = 1, #submenus do
        mainMenuOptions[i] = mainOptions[submenus[i]]
    end

    pr_lib.registerMenu({
        id = 'forge-smallresources:staticEmitters',
        title = locale('static_emitters.title'),
        position = 'top-right',
        options = mainMenuOptions,
    }, function(selected)
        local group = submenus[selected]
        if group then
            pr_lib.showMenu('forge-smallresources:staticEmitters:' .. group, 1)
        end
    end)

    for gameBuild, emitterGroups in pairs(config.gameBuild) do
        if currentGameBuild >= gameBuild then
            for emitterGroup, emitterGroupOptions in pairs(emitterGroups) do
                local groupDisable = emitterGroupOptions.disable
                local submenuOptions = {}
                local optionIndex = 0
                local emitters = {}

                for emitterName, emitterOptions in pairs(emitterGroupOptions.emitters) do
                    optionIndex = optionIndex + 1
                    local emitterDisable = groupDisable or emitterOptions.disable
                    local pos = emitterOptions.position
                    local posStr = ('%.2f, %.2f, %.2f'):format(pos.x, pos.y, pos.z)

                    setStaticEmitterEnabled(emitterName, not emitterDisable)

                    submenuOptions[optionIndex] = {
                        label = emitterName,
                        description = ('%s | %s'):format(locale(emitterDisable and 'static_emitters.disabled' or 'static_emitters.enabled'), posStr),
                        icon = emitterDisable and 'toggle-off' or 'toggle-on',
                    }

                    emitters[#emitters + 1] = {
                        name = emitterName,
                        position = pos,
                        disabled = emitterDisable,
                    }
                end

                emitterGroupsData[emitterGroup] = emitters

                pr_lib.registerMenu({
                    id = 'forge-smallresources:staticEmitters:' .. emitterGroup,
                    title = emitterGroup:gsub('%f[%a].', string.upper),
                    position = 'top-right',
                    menu = 'forge-smallresources:staticEmitters',
                    options = submenuOptions,
                    onClose = function()
                        pr_lib.showMenu('forge-smallresources:staticEmitters')
                    end,
                }, function(selected)
                    local idx = 0
                    for emName in pairs(emitterGroupOptions.emitters) do
                        idx = idx + 1
                        if idx == selected then
                            local pos = emitterGroupOptions.emitters[emName].position
                            local posStr = ('%.2f, %.2f, %.2f'):format(pos.x, pos.y, pos.z)
                            if config.menu.copyToClipboard then pr_lib.setClipboard(posStr) end
                            SetEntityCoords(pr_lib.cache.ped, pos.x, pos.y, pos.z, true, false, false, false)
                            break
                        end
                    end
                end)
            end
        end
    end
end

CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(500) end

    local isAllowed = pr_lib.callback.await('forge-smallresources:server:isStaticEmitterAdmin', false)

    if isAllowed then
        registerMenus()
        RegisterCommand('staticemitters', function()
            pr_lib.showMenu('forge-smallresources:staticEmitters', 1)
            CreateThread(function()
                while pr_lib.getOpenMenu() do
                    local playerPos = GetEntityCoords(pr_lib.cache.ped)
                    for _, group in pairs(emitterGroupsData) do
                        for i = 1, #group do
                            local em = group[i]
                            local pos = em.position
                            if #(playerPos - pos) < 200.0 then
                                local color = em.disabled and { r = 255, g = 50, b = 50 } or { r = 50, g = 255, b = 50 }
                                DrawMarker(28, pos.x, pos.y, pos.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, color.r, color.g, color.b, 100, false, false, 0, true, false, false, false)
                                pr_lib.drawtext.draw3d({coords = pos, text = em.name})
                            end
                        end
                    end
                    Wait(0)
                end
            end)
        end, false)
    end
end)
