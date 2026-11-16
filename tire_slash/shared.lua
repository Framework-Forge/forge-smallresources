if not ForgeSmall.isEnabled('tireSlash') then return end

local config = ForgeSmallConfig.tireSlash or {}
local function number(value, fallback, minimum, maximum)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then value = fallback end
    return math.max(minimum, math.min(maximum, value))
end

local rules = {
    interactDistance = number(config.interactDistance, 1.2, 0.5, 2.0),
    durationMs = math.floor(number(config.durationMs, 2000, 500, 10000)),
    maxVehicleSpeed = number(config.maxVehicleSpeed, 1.0, 0.0, 3.0),
    serverVehicleDistance = number(config.serverVehicleDistance, 6.0, 2.0, 15.0),
    wheels = {
        { bone = 'wheel_lf', index = 0 }, { bone = 'wheel_rf', index = 1 },
        { bone = 'wheel_lm1', index = 2 }, { bone = 'wheel_rm1', index = 3 },
        { bone = 'wheel_lm2', index = 45 }, { bone = 'wheel_rm2', index = 47 },
        { bone = 'wheel_lm3', index = 46 }, { bone = 'wheel_rm3', index = 48 },
        { bone = 'wheel_lr', index = 4 }, { bone = 'wheel_rr', index = 5 },
    },
    byIndex = {},
}
rules.distance = math.max(rules.interactDistance, number(config.distance, 4.0, 0.5, 10.0))
for _, wheel in ipairs(rules.wheels) do rules.byIndex[wheel.index] = wheel end

local weapons = {}
for _, name in ipairs(config.allowedWeapons or {}) do
    local hash = type(name) == 'string' and joaat(name) or tonumber(name)
    if hash and math.tointeger(hash) then weapons[hash & 0xffffffff] = true end
end
function rules.isWeaponAllowed(hash)
    return type(hash) == 'number' and math.tointeger(hash) ~= nil and weapons[hash & 0xffffffff] == true
end

ForgeSmall.tireSlash = rules
