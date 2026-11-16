if not ForgeSmall.isEnabled('weaponRecoil') then return end

local recoils = pr_lib.load('weapon_recoil.config')

local function recoilLoop()
    CreateThread(function()
        while pr_lib.cache.weapon do
            if IsPedShooting(pr_lib.cache.ped) and not IsPedDoingDriveby(pr_lib.cache.ped) then
                local _, wep = GetCurrentPedWeapon(pr_lib.cache.ped, true)
                if recoils[wep] and recoils[wep] ~= 0 then
                    -- luacheck: ignore
                    local tv = 0
                    if GetFollowPedCamViewMode() ~= 4 then
                        repeat
                            Wait(0)
                            local p = GetGameplayCamRelativePitch()
                            SetGameplayCamRelativePitch(p + 0.1, 0.2)
                            tv = tv + 0.1
                        until tv >= recoils[wep]
                    else
                        repeat
                            Wait(0)
                            local p = GetGameplayCamRelativePitch()
                            if recoils[wep] > 0.1 then
                                SetGameplayCamRelativePitch(p + 0.6, 1.2)
                                tv = tv + 0.6
                            else
                                SetGameplayCamRelativePitch(p + 0.016, 0.333)
                                tv = tv + 0.1
                            end
                        until tv >= recoils[wep]
                    end
                end
            end
            Wait(350) -- might be able to reduce time here for more recoil
        end
    end)
end

pr_lib.onCache('weapon', function(weapon)
    Wait(5)
    if not weapon then return end
    recoilLoop()
end)