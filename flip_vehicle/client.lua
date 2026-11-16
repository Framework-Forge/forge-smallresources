if not ForgeSmall.isEnabled('flipVehicle') then return end

local config = pr_lib.loadJson('flip_vehicle.config')

---@param vehicle number? id of the vehicle, default closes vehicle
---@param flipTest boolean? costom fliping task
local function flipVehicle(vehicle, flipTest)
    if pr_lib.cache.vehicle then return end
    if not vehicle then vehicle = pr_lib.getClosestVehicle(GetEntityCoords(pr_lib.cache.ped), config.maxDistance, false) end
    if not vehicle then return ForgeSmall.notify(locale('error.no_vehicle_nearby'), 'error') end
    local peedCoords = GetEntityCoords(pr_lib.cache.ped)
    local vehicleCoords = GetEntityCoords(vehicle)

    if #(peedCoords - vehicleCoords) > config.maxDistance then
        return ForgeSmall.notify(locale('error.no_vehicle_nearby'), 'error')
    end

    if flipTest or pr_lib.progressBar({
        label = locale('progress.flipping_car'),
        duration = config.flipingTime,
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            mouse = false,
            combat = true
        },
        anim = {
            dict = 'mini@repair',
            clip = 'fixing_a_ped'
        },
    }) then
        SetVehicleOnGroundProperly(vehicle)
        ForgeSmall.notify(locale('success.flipped_car'), 'success')
    else
        ForgeSmall.notify(locale('error.canceled'), 'error')
    end
end

---@deprecated use FlipVehicle instead
exports('flipVehicle', flipVehicle)

exports('FlipVehicle', flipVehicle)
