if not ForgeSmall.isEnabled('vehiclePush') then return end

---@alias Direction 'right' | 'left' | 'front' | 'back' | nil

local config = pr_lib.loadJson('vehicle_push.config')
local dict = 'missfinale_c2ig_11'
local pushState = pr_lib.fivem.vehicleState.channel('smallresources')
local pressed = {
    e = false,
    shift = false
}

---@type Direction
local pushingControl = nil

---@param vehicle number
---@return boolean
local function checkClass(vehicle)
    local classes = config.blacklistedClasses
    local currentClass = GetVehicleClass(vehicle)

    for i = 1, #classes do
        if currentClass == classes[i] then
            return false
        end
    end

    return true
end

---@param vehicle number
---@param value Direction
local function vehicleControl(vehicle, value)
    if not pushingControl then -- initial loop for new owner
        local oldDirection = value -- save old front | back direction for new owner

        CreateThread(function()
            local ped = pr_lib.cache.ped
            local playerId = pr_lib.cache.playerId

            pushingControl = value

            while DoesEntityExist(vehicle) and pushingControl and NetworkGetEntityOwner(vehicle) == playerId do
                Wait(0)
                if pushingControl == 'left' then
                    TaskVehicleTempAction(ped, vehicle, 11, 1)
                elseif pushingControl == 'right' then
                    TaskVehicleTempAction(ped, vehicle, 10, 1)
                end

                SetVehicleForwardSpeed(vehicle, value == 'front' and -1.0 or 1.0)

                if HasEntityCollidedWithAnything(vehicle) then
                    SetVehicleOnGroundProperly(vehicle)
                end
            end

            if DoesEntityExist(vehicle) and NetworkGetEntityOwner(vehicle) ~= playerId and pushingControl then -- handle changing owner in the middle of pushing
                TriggerServerEvent('forge-smallresources:server:vehiclePush', {
                    direction = oldDirection,
                    netId = VehToNet(vehicle)
                })
            end
        end)
    end

    pushingControl = value
end

---@param vehicle number
local function isVehicleValid(vehicle)
    local engineHealth = GetVehicleEngineHealth(vehicle)

    return ((engineHealth >= 0 and engineHealth <= config.damageNeeded) or ForgeSmall.getVehicleState(vehicle, 'fuel', 100) < 3) and IsVehicleSeatFree(vehicle, -1) and checkClass(vehicle)
end

---@param vehicle number
local function vehicleValidityThread(vehicle)
    CreateThread(function()
        while pressed.e and pressed.shift do
            Wait(500)
            if not isVehicleValid(vehicle) then
                pressed.e = false
                pressed.shift = false
            end
        end
    end)
end

---@param vehicle number
---@param direction Direction
local function taskControlVehicle(vehicle, direction)
    local playerId = ForgeSmall.getPlayerId()

    if NetworkGetEntityOwner(vehicle) == playerId then
        vehicleControl(vehicle, direction)
    end

    if direction == nil or NetworkGetEntityOwner(vehicle) ~= playerId then
        TriggerServerEvent('forge-smallresources:server:vehiclePush', {
            direction = direction,
            netId = VehToNet(vehicle)
        })
    end
end

local function pushVehicle()
    if pr_lib.cache.vehicle then return end

    local ped = pr_lib.cache.ped
    local vehicle, vehicleCoords = pr_lib.getClosestVehicle(GetEntityCoords(ped), 3.0)
    if not vehicle then return end

    if IsEntityAttachedToEntity(pr_lib.cache.ped, vehicle) or not isVehicleValid(vehicle) then return end

    vehicleValidityThread(vehicle)

    if not pressed.e or not pressed.shift then return end

    local pedCoords = GetEntityCoords(ped)
    local boneIndex = GetPedBoneIndex(ped, 6286)
    local dimensions = GetModelDimensions(GetEntityModel(vehicle))
    local vehicleForwardVector = GetEntityForwardVector(vehicle)
    local isInFront = #(vehicleCoords - pedCoords + vehicleForwardVector) < #(vehicleCoords - pedCoords - vehicleForwardVector)

    if isInFront then
        AttachEntityToEntity(ped, vehicle, boneIndex, 0.0, dimensions.y * -1 + 0.1, dimensions.z + 1.0, 0.0, 0.0, 180.0,
            false, false, false, true, 0, true)
    else
        AttachEntityToEntity(ped, vehicle, boneIndex, 0.0, dimensions.y - 0.3, dimensions.z + 1.0, 0.0, 0.0, 0.0, false,
            false, false, true, 0, true)
    end

    pr_lib.playAnim(ped, dict, 'pushcar_offcliff_m', 2.0, -8.0, -1, 35, 0, false, false, false)

    local direction = isInFront and 'front' or 'back'
    taskControlVehicle(vehicle, direction)

    CreateThread(function()
        local wheelsDirection = ''
        while pressed.shift and not pr_lib.cache.vehicle do
            local newDirection = nil

            if IsDisabledControlPressed(0, 34) then
                newDirection = 'left'
            elseif IsDisabledControlPressed(0, 9) then
                newDirection = 'right'
            end

            if newDirection and wheelsDirection ~= newDirection then
                wheelsDirection = newDirection
                taskControlVehicle(vehicle, wheelsDirection)
            end

            Wait(0)
        end

        DetachEntity(ped, false, false)
        StopAnimTask(ped, dict, 'pushcar_offcliff_m', 2.0)
        FreezeEntityPosition(ped, false)
        taskControlVehicle(vehicle)

        pushingControl = nil
    end)

    return vehicle
end

pushState.watchAny('pushDirection', function(value, _, _, entity)
    if NetworkGetEntityOwner(entity) ~= pr_lib.cache.playerId then return end

    if not value then
        pushingControl = nil
        return
    end

    vehicleControl(entity, value)
end)

pr_lib.addKeybind({
    name = 'forge_push_vehicle_action',
    description = locale('keybind.push_action'),
    defaultKey = 'E',
    onPressed = function()
        pressed.e = true
        if not pressed.shift then return end

        pushVehicle()
    end,
    onReleased = function()
        pressed.e = false
    end
})

pr_lib.addKeybind({
    name = 'forge_push_vehicle_modifier',
    description = locale('keybind.push_modifier'),
    defaultKey = 'LSHIFT',
    onPressed = function(self)
        pressed.shift = true
        if not pressed.e then return end

        self.vehicle = pushVehicle()
    end,
    onReleased = function(self)
        pressed.shift = false
        if self.vehicle then
            taskControlVehicle(self.vehicle)
        end
    end
})
