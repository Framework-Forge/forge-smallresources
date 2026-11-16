if not ForgeSmall.isEnabled('disableServices') then return end

local config = pr_lib.load('disable_services.config')

CreateThread(function()
    SetMaxWantedLevel(config.maxWantedLevel)
    for key, value in ipairs(config.enabledServices) do
        EnableDispatchService(key, value)
    end
end)