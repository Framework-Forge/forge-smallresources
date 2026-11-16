if not ForgeSmall.isEnabled("vehicleTrunk") then
    return
end

CreateThread(function()
    while not pr_lib or not pr_lib.interact do
        Wait(100)
    end

    local id = pr_lib.interact.AddGlobalVehicleInteraction({
        id = "pr_scriptTest:interact:trunk",
        name = "pr_scriptTest:interact:trunk",
        bone = "boot",
        distance = 5.0,
        interactDst = 1.5,
        showUI = false,
        options = {
            {
                name = "pr_scriptTest:interact:openTrunk",
                label = "Abrir porta-malas",
                canInteract = function(vehicle)
                    return vehicle ~= 0 and DoesEntityExist(vehicle) and GetVehiclePedIsIn(PlayerPedId(), false) == 0
                end,
                action = function(vehicle)
                    if GetVehicleDoorLockStatus(vehicle) > 1 then
                        return pr_lib.notify({
                            title = "Interact",
                            description = "O porta-malas esta trancado.",
                            type = "error",
                        })
                    end

                    if GetVehicleDoorAngleRatio(vehicle, 5) <= 0.0 then
                        SetVehicleDoorOpen(vehicle, 5, false, false)
                    end

                    local plate = GetVehicleNumberPlateText(vehicle)
                    pr_lib.inventory.openInventory("trunk", {
                        id = "trunk" .. plate,
                        netid = NetworkGetNetworkIdFromEntity(vehicle),
                        entityid = vehicle,
                        door = 5,
                    })
                end,
            },
        },
    })

    print(("^2[pr_scriptTest:interact] Porta-malas global registrado com id=%s.^0"):format(tostring(id)))
end)
