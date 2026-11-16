if not ForgeSmall.isEnabled('noShuffle') then return end

local config = pr_lib.loadJson('no_shuffle.config')

---Disables auto seat switching
---@param seatIndex number
local function disableAutoShuffle(seatIndex)
    SetPedConfigFlag(pr_lib.cache.ped, 184, true)

    if pr_lib.cache.vehicle and not pr_lib.cache.seat then
        SetPedIntoVehicle(pr_lib.cache.ped, pr_lib.cache.vehicle, seatIndex)
    end
end

pr_lib.onCache('seat', disableAutoShuffle)

---Makes the player ped shuffle to the next vehicle seat. 
local function shuffleSeat(self)
    if ForgeSmall.getMetadata('ishandcuffed', false) then
        return ForgeSmall.notify(locale('error.is_handcuffed'), 'error')
    end

    if pr_lib.cache.get('seatbelt', false) then
        return ForgeSmall.notify(locale('error.is_fastened'), 'error')
    end

    self:disable(true)
    if pr_lib.cache.vehicle and pr_lib.cache.seat then
        TaskShuffleToNextVehicleSeat(pr_lib.cache.ped, pr_lib.cache.vehicle)
        repeat
            Wait(0)
        until not GetIsTaskActive(pr_lib.cache.ped, 165)
    end
    self:disable(false)
end

pr_lib.addKeybind({
    name = 'forge_shuffle_seat',
    description = locale('info.shuffleSeat'),
    defaultKey = config.shuffleSeatKey,
    onPressed = shuffleSeat
})
