if not ForgeSmall.isEnabled('crouch') then return end

local cacheKey = 'forge-smallresources:crouched'
local crouchAnimSet = 'move_Ped_crouched'

local function applyCrouch(enabled)
    local ped = ForgeSmall.getPed()
    if not ped or ped == 0 then return end

    if enabled then
        if not pr_lib.requestAnimSet(crouchAnimSet) then return end
        SetPedMovementClipset(ped, crouchAnimSet, 1.0)
        SetPedStrafeClipset(ped, 'move_Ped_crouched_strafing')
        RemoveAnimSet(crouchAnimSet)
        return
    end

    ResetPedMovementClipset(ped, 1.0)
    ResetPedWeaponMovementClipset(ped)
    ResetPedStrafeClipset(ped)
    SetPedStealthMovement(ped, false, 'DEFAULT_ACTION')
end

pr_lib.onCache(cacheKey, function(enabled)
    applyCrouch(enabled == true)
end)

pr_lib.addKeybind({
    name = 'forge_crouch',
    description = locale('keybind.crouch'),
    defaultKey = 'K',
    onReleased = function()
        if ForgeSmall.getVehicle() then return end
        pr_lib.cache.set(cacheKey, not pr_lib.cache.get(cacheKey, false))
    end,
})

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    applyCrouch(false)
    pr_lib.cache.clear(cacheKey)
end)