if not ForgeSmall.isEnabled('itemPickup') then return end

local config = pr_lib.loadJson('item_pickup.config')

if #config.disabledPickups == 0 then return end

CreateThread(function()
    for _, hash in ipairs(config.disabledPickups) do
        ToggleUsePickupsForPlayer(ForgeSmall.getPlayerId(), hash, false)
    end
end)
