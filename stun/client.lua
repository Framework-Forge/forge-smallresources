if not ForgeSmall.isEnabled('stun') then return end

CreateThread(function()
    while true do
        if IsPedBeingStunned(pr_lib.cache.ped, 0) then
            SetPedMinGroundTimeForStungun(pr_lib.cache.ped, math.random(4000, 7000))
            Wait(0)
        else
            Wait(1000)
        end
    end
end)
