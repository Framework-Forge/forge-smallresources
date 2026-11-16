if not ForgeSmall.isEnabled('hudComponents') then return end

local config = pr_lib.load('hud_components.config')
local disableHudComponents = config.disable.hudComponents
local disableControls = config.disable.controls
local displayAmmo = config.disable.displayAmmo

CreateThread(function()
    for i = 1, #disableHudComponents do
        SetHudComponentSize(disableHudComponents[i],0.0,0.0)
    end

    while true do
        for i = 1, #disableControls do
            DisableControlAction(2, disableControls[i], true)
        end
        Wait(0)
    end
end)

if config.disable.recticle then
    pr_lib.onCache('weapon', function(weapon)
        if not weapon then return end

        CreateThread(function()
            while pr_lib.cache.weapon ~= weapon do Wait(1) end -- Wait for pr_lib.cache.weapon to update

            while pr_lib.cache.weapon == weapon do
                if not IsFirstPersonAimCamActive() then
                    HideHudComponentThisFrame(14)
                end
                Wait(0)
            end
        end)
    end)
end

local function addDisableHudComponents(hudComponents)
    local hudComponentsType = type(hudComponents)
    if hudComponentsType == 'number' then
        disableHudComponents[#disableHudComponents+1] = hudComponents
        SetHudComponentSize(hudComponents,0.0,0.0)
    elseif hudComponentsType == 'table' and table.type(hudComponents) == 'array' then
        for i = 1, #hudComponents do
            disableHudComponents[#disableHudComponents+1] = hudComponents[i]
            SetHudComponentSize(hudComponents[i],0.0,0.0)
        end
    end
end

---@deprecated use AddDisableHudComponents instead
exports('addDisableHudComponents', addDisableHudComponents)
exports('AddDisableHudComponents', addDisableHudComponents)

local function removeDisableHudComponents(hudComponents)
    local values = type(hudComponents) == 'table' and hudComponents or { hudComponents }

    for valueIndex = 1, #values do
        local component = values[valueIndex]
        if type(component) == 'number' then
            for index = #disableHudComponents, 1, -1 do
                if disableHudComponents[index] == component then
                    table.remove(disableHudComponents, index)
                end
            end
            ResetHudComponentValues(component)
        end
    end
end

---@deprecated use RemoveDisableHudComponents instead
exports('removeDisableHudComponents', removeDisableHudComponents)
exports('RemoveDisableHudComponents', removeDisableHudComponents)

local function getDisableHudComponents()
    return disableHudComponents
end

---@deprecated use GetDisableHudComponents instead
exports('getDisableHudComponents', getDisableHudComponents)
exports('GetDisableHudComponents', getDisableHudComponents)

local function addDisableControls(controls)
    local controlsType = type(controls)
    if controlsType == 'number' then
        disableControls[#disableControls+1] = controls
    elseif controlsType == 'table' and table.type(controls) == 'array' then
        for i = 1, #controls do
            disableControls[#disableControls+1] = controls[i]
        end
    end
end

---@deprecated use AddDisableControls instead
exports('addDisableControls', addDisableControls)
exports('AddDisableControls', addDisableControls)

local function removeDisableControls(controls)
    local values = type(controls) == 'table' and controls or { controls }

    for valueIndex = 1, #values do
        local control = values[valueIndex]
        if type(control) == 'number' then
            for index = #disableControls, 1, -1 do
                if disableControls[index] == control then
                    table.remove(disableControls, index)
                end
            end
        end
    end
end

---@deprecated use RemoveDisableControls instead
exports('removeDisableControls', removeDisableControls)
exports('RemoveDisableControls', removeDisableControls)

local function getDisableControls()
    return disableControls
end

---@deprecated use GetDisableControls instead
exports('getDisableControls', getDisableControls)
exports('GetDisableControls', getDisableControls)

local function setDisplayAmmo(bool)
    displayAmmo = bool
end

---@deprecated use SetDisplayAmmo instead
exports('setDisplayAmmo', setDisplayAmmo)
exports('SetDisplayAmmo', setDisplayAmmo)

local function getDisplayAmmo()
    return displayAmmo
end

---@deprecated use GetDisplayAmmo instead
exports('getDisplayAmmo', getDisplayAmmo)
exports('GetDisplayAmmo', getDisplayAmmo)
