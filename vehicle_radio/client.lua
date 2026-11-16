if not ForgeSmall.isEnabled('vehicleRadio') then return end

local config = pr_lib.loadJson('vehicle_radio.config')
local radioEnabled = not config.disableRadioByDefault

local function toggleVehicleRadio()
    local currentVehicle = ForgeSmall.getVehicle()
    if not currentVehicle or currentVehicle == 0 then return end

    radioEnabled = not radioEnabled

    if radioEnabled then
        ForgeSmall.notify(locale('success.vehicle_radio_on'), 'success')
        SetUserRadioControlEnabled(true)
        return
    end

    ForgeSmall.notify(locale('error.vehicle_radio_off'), 'error')
    SetVehRadioStation(currentVehicle, 'OFF')
    SetUserRadioControlEnabled(false)
end

RegisterCommand(config.toggleCommand, toggleVehicleRadio, false)

if config.toggleKey then
    pr_lib.addKeybind({
        name = 'forge_vehicle_radio',
        description = locale('keybind.vehicle_radio'),
        defaultKey = config.toggleKey,
        onReleased = toggleVehicleRadio,
    })
end

pr_lib.onCache('vehicle', function(currentVehicle)
    if currentVehicle and currentVehicle ~= 0 then
        SetUserRadioControlEnabled(radioEnabled)
        if not radioEnabled then
            SetVehRadioStation(currentVehicle, 'OFF')
        end
        return
    end

    SetUserRadioControlEnabled(true)
end)