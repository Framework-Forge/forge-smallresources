if not ForgeSmall.isEnabled('tackle') then return end

pr_lib.addKeybind({
    name = 'forge_tackle',
    description = locale('keybind.tackle'),
    defaultKey = 'E',
    onReleased = function(self)
        if pr_lib.cache.vehicle then return end
        if ForgeSmall.getMetadata('ishandcuffed', false) then return end
        if IsPedSprinting(pr_lib.cache.ped) or IsPedRunning(pr_lib.cache.ped) then
            local coords = GetEntityCoords(pr_lib.cache.ped)
            local targetId, targetPed, _ = pr_lib.getClosestPlayer(coords, 1.6, false)
            if not targetPed then return end
            if IsPedInAnyVehicle(targetPed, true) then return end
            self:disable(true)
            TriggerServerEvent('forge-smallresources:server:tackle', GetPlayerServerId(targetId))
            pr_lib.requestAnimDict('swimming@first_person@diving')
            TaskPlayAnim(pr_lib.cache.ped, 'swimming@first_person@diving', 'dive_run_fwd_-45_loop', 3.0, 3.0, -1, 49, 0, false, false, false)
            Wait(250)
            ClearPedTasks(pr_lib.cache.ped)
            SetPedToRagdoll(pr_lib.cache.ped, 150, 150, 0, 0, 0, 0)
            RemoveAnimDict('swimming@first_person@diving')
            SetTimeout(1000, function ()
                self:disable(false)
            end)
        end
    end
})

RegisterNetEvent('forge-smallresources:client:tackled', function()
    SetPedToRagdoll(pr_lib.cache.ped, 7000, 7000, 0, 0, 0, 0)
end)
