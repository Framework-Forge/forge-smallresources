if not ForgeSmall.isEnabled('vehicleSmoke') then return end

local settings = ForgeSmallConfig.vehicleSmoke or {}
local particleAsset = 'scr_recartheft'
local particleEffect = 'scr_wheel_burnout'
local activeEffects = {}
local nextSmokeAt = 0

local function requestParticleAsset()
    if HasNamedPtfxAssetLoaded(particleAsset) then return true end
    RequestNamedPtfxAsset(particleAsset)
    local deadline = GetGameTimer() + 3000
    while not HasNamedPtfxAssetLoaded(particleAsset) and GetGameTimer() < deadline do Wait(0) end
    return HasNamedPtfxAssetLoaded(particleAsset)
end

local function wheelBones()
    if settings.rearWheelsOnly ~= false then return { 'wheel_lr', 'wheel_rr' } end
    return { 'wheel_lr', 'wheel_rr', 'wheel_lf', 'wheel_rf' }
end

local function stopEffects(effectId)
    local particles = activeEffects[effectId]
    if not particles then return end
    activeEffects[effectId] = nil
    for _, particle in ipairs(particles) do
        if particle and particle ~= 0 then StopParticleFxLooped(particle, true) end
    end
end

local function startSmoke(vehicle, effectId)
    if vehicle == 0 or not DoesEntityExist(vehicle) or activeEffects[effectId] then return end
    if not requestParticleAsset() then return end

    local particles = {}
    local density = math.max(1, math.min(5, math.floor(tonumber(settings.smokeDensity) or 2)))
    local scale = math.max(0.05, math.min(2.0, tonumber(settings.smokeSize) or 0.22))

    for _ = 1, density do
        for _, boneName in ipairs(wheelBones()) do
            local bone = GetEntityBoneIndexByName(vehicle, boneName)
            if bone ~= -1 then
                UseParticleFxAssetNextCall(particleAsset)
                local particle = StartParticleFxLoopedOnEntityBone(
                    particleEffect, vehicle, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    bone, scale, 0.0, 0.0, 20.0
                )
                if particle and particle ~= 0 then particles[#particles + 1] = particle end
            end
        end
    end

    if #particles == 0 then return end
    activeEffects[effectId] = particles
    SetTimeout(math.max(100, tonumber(settings.durationMs) or 850), function()
        stopEffects(effectId)
    end)
end

local function driftAngle(vehicle)
    local velocity = GetEntityVelocity(vehicle)
    local length = math.sqrt(velocity.x * velocity.x + velocity.y * velocity.y)
    if length < 0.5 then return 0 end

    local forward = GetEntityForwardVector(vehicle)
    local dot = math.max(-1.0, math.min(1.0, (forward.x * velocity.x + forward.y * velocity.y) / length))
    return math.deg(math.acos(dot))
end

local function shouldCreateSmoke(vehicle)
    local speed = GetEntitySpeed(vehicle) * 3.6
    if speed < (tonumber(settings.minimumSpeedKmh) or 5.0) then return false end
    return IsVehicleInBurnout(vehicle) or driftAngle(vehicle) >= (tonumber(settings.minimumDriftAngle) or 8.0)
end

RegisterNetEvent('forge-smallresources:vehicleSmoke:play', function(networkId)
    networkId = tonumber(networkId)
    if not networkId or networkId <= 0 or not NetworkDoesNetworkIdExist(networkId) then return end
    local vehicle = NetworkGetEntityFromNetworkId(networkId)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end
    startSmoke(vehicle, ('net:%s'):format(networkId))
end)

CreateThread(function()
    while true do
        local vehicle = ForgeSmall.getVehicle()
        local ped = ForgeSmall.getPed()
        if vehicle ~= 0 and DoesEntityExist(vehicle) and GetPedInVehicleSeat(vehicle, -1) == ped and shouldCreateSmoke(vehicle) then
            local now = GetGameTimer()
            if now >= nextSmokeAt then
                nextSmokeAt = now + math.max(150, tonumber(settings.cooldownMs) or 700)
                local networkId = NetworkGetNetworkIdFromEntity(vehicle)
                if networkId and networkId > 0 then
                    TriggerServerEvent('forge-smallresources:vehicleSmoke:request', networkId)
                else
                    startSmoke(vehicle, ('local:%s'):format(vehicle))
                end
            end
            Wait(0)
        else
            Wait(150)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for effectId in pairs(activeEffects) do stopEffects(effectId) end
end)
