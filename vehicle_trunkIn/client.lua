if not ForgeSmall.isEnabled("vehicleTrunkIn") then
    return
end

local trunk = {
    inside = false,
    vehicle = nil,
    netId = nil,
    pending = false,
}

-- Veículos ocupados sincronizados pelo servidor.
-- [netId] = true
local occupiedTrunks = {}

local MAX_EXIT_SPEED = 40.0 -- km/h

-- =========================================================
-- UTILS
-- =========================================================

local function Notify(message, notifyType)
    notifyType = notifyType or "inform"
    if pr_lib and type(pr_lib.notify) == "function" then
        pr_lib.notify({
            title = "Porta-malas",
            description = message,
            type = notifyType == "erro" and "error" or notifyType == "sucesso" and "success" or notifyType,
            duration = 5000,
        })
        return
    end
    TriggerEvent("Notify", notifyType, "Porta-malas", message, 5000)
end

local function GetVehicleSpeedKMH(vehicle)
    if not vehicle or vehicle == 0 then
        return 0.0
    end
    return GetEntitySpeed(vehicle) * 3.6
end

local function GetTrunkBone(vehicle)
    if not vehicle or vehicle == 0 then
        return -1
    end
    local bone = GetEntityBoneIndexByName(vehicle, "boot")
    if bone == -1 then
        bone = GetEntityBoneIndexByName(vehicle, "chassis")
    end
    return bone
end

local function HasTrunk(vehicle)
    if not vehicle or vehicle == 0 then
        return false
    end
    return GetEntityBoneIndexByName(vehicle, "boot") ~= -1
end

local function IsTrunkOpen(vehicle)
    if not vehicle or vehicle == 0 then
        return false
    end
    return GetVehicleDoorAngleRatio(vehicle, 5) > 0.10
end

local function IsVehicleUnlocked(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return false
    end
    -- Mesma regra usada para abrir o bau: qualquer estado acima de 1 bloqueia.
    return GetVehicleDoorLockStatus(vehicle) <= 1
end

local function IsVehicleOccupied(vehicle)
    if not vehicle or vehicle == 0 then
        return false
    end

    if not NetworkGetEntityIsNetworked(vehicle) then
        return false
    end
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    return netId and netId > 0 and occupiedTrunks[netId] == true
end

local function SetTrunkPedVisibility(vehicle)
    if not trunk.inside then
        return
    end
    local ped = PlayerPedId()
    if IsTrunkOpen(vehicle) then
        SetEntityVisible(ped, true, false)
    else
        SetEntityVisible(ped, false, false)
    end
end

-- =========================================================
-- ANIMAÇÃO
-- =========================================================

local function PlayTrunkAnimation()
    local ped = PlayerPedId()
    local dict = "timetable@floyd@cryingonbed@base"
    local anim = "base"
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(10)
    end
    TaskPlayAnim(ped, dict, anim, 8.0, -8.0, -1, 2, 0.0, false, false, false)
end

-- =========================================================
-- ENTRAR NO PORTA-MALAS
-- =========================================================

local function EnterTrunk(vehicle, netId)
    if trunk.inside then
        return
    end
    if not DoesEntityExist(vehicle) then
        TriggerServerEvent("pr_trunk:leave", netId)
        return
    end
    if not IsVehicleUnlocked(vehicle) then
        TriggerServerEvent("pr_trunk:leave", netId)
        Notify("O porta-malas está trancado.", "erro")
        return
    end
    if not IsTrunkOpen(vehicle) then
        TriggerServerEvent("pr_trunk:leave", netId)
        Notify("Abra o porta-malas antes de entrar.", "erro")
        return
    end
    local ped = PlayerPedId()
    trunk.inside = true
    trunk.vehicle = vehicle
    trunk.netId = netId
    trunk.pending = false
    -- Garante controle básico do ped.
    ClearPedTasksImmediately(ped)
    -- A tampa já foi validada como aberta antes da autorização.
    Wait(250)
    local bone = GetTrunkBone(vehicle)
    if bone == -1 then
        trunk.inside = false
        trunk.vehicle = nil
        trunk.netId = nil
        TriggerServerEvent("pr_trunk:leave", netId)
        Notify("Este veículo não possui porta-malas compatível.", "erro")
        return
    end
    -- Anexa o personagem ao porta-malas.
    --
    -- Esses offsets podem ser ajustados por modelo se necessário.
    AttachEntityToEntity(
        ped,
        vehicle,
        bone,

        0.0, -- X
        -0.15, -- Y
        0.10, -- Z

        0.0, -- rotX
        0.0, -- rotY
        180.0, -- rotZ

        false,
        false,
        false,
        false,
        2,
        true
    )
    SetEntityCollision(ped, false, false)
    PlayTrunkAnimation()
    -- Fecha depois que entrou.
    Wait(600)
    if trunk.inside and DoesEntityExist(vehicle) then
        SetVehicleDoorShut(vehicle, 5, false)
    end
    SetTrunkPedVisibility(vehicle)
    Notify("Você entrou no porta-malas. Pressione [C] para sair.", "sucesso")
end

-- =========================================================
-- PED RAGDOLL / ARREMESSO
-- =========================================================

local function ThrowPedFromVehicle(vehicle)
    local ped = PlayerPedId()
    local velocity = GetEntityVelocity(vehicle)
    local forward = GetEntityForwardVector(vehicle)
    local speed = GetEntitySpeed(vehicle)
    -- Mantém a velocidade que o carro já possuía e acrescenta
    -- um pequeno impulso para fora do porta-malas.
    local multiplier = math.min(speed / 10.0, 2.5)
    SetEntityVelocity(
        ped,
        velocity.x - (forward.x * multiplier),
        velocity.y - (forward.y * multiplier),
        velocity.z + 1.0 + (speed * 0.04)
    )
    -- Deixa o personagem com física "solta", semelhante
    -- ao corpo desacordado/morto.
    SetPedToRagdoll(ped, 5000, 5000, 0, true, true, false)
end

-- =========================================================
-- SAIR DO PORTA-MALAS
-- =========================================================

local function ExitTrunk()
    if not trunk.inside then
        return
    end
    local vehicle = trunk.vehicle
    local netId = trunk.netId
    if not vehicle or not DoesEntityExist(vehicle) then
        local ped = PlayerPedId()
        DetachEntity(ped, true, true)
        SetEntityVisible(ped, true, false)
        SetEntityCollision(ped, true, true)
        trunk.inside = false
        trunk.vehicle = nil
        trunk.netId = nil
        TriggerServerEvent("pr_trunk:leave", netId)
        return
    end
    local speed = GetVehicleSpeedKMH(vehicle)
    -- =====================================================
    -- LIMITE DE 40 KM/H
    -- =====================================================
    if speed > MAX_EXIT_SPEED then
        Notify(
            ("Você não pode sair do porta-malas acima de %.0f km/h. Velocidade atual: %.0f km/h."):format(
                MAX_EXIT_SPEED,
                speed
            ),
            "erro"
        )
        return
    end

    local ped = PlayerPedId()
    trunk.inside = false
    ClearPedTasksImmediately(ped)
    DetachEntity(ped, true, true)
    SetEntityVisible(ped, true, false)
    SetEntityCollision(ped, true, true)
    -- Coloca o personagem atrás do carro.
    local exitCoords = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, -2.5, 0.2)
    SetEntityCoords(ped, exitCoords.x, exitCoords.y, exitCoords.z, false, false, false, false)
    -- Se o carro estiver andando, aplica física proporcional.
    if speed > 2.0 then
        ThrowPedFromVehicle(vehicle)
    end
    trunk.vehicle = nil
    trunk.netId = nil
    TriggerServerEvent("pr_trunk:leave", netId)
    Notify("Você saiu do porta-malas.", "sucesso")
end

-- =========================================================
-- RESPOSTA DO SERVIDOR PARA ENTRADA
-- =========================================================

RegisterNetEvent("pr_trunk:enterResult", function(success, netId, reason)
    trunk.pending = false
    if not success then
        if reason then
            Notify(reason, "erro")
        end
        return
    end
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        TriggerServerEvent("pr_trunk:leave", netId)
        return
    end
    EnterTrunk(vehicle, netId)
end)

-- =========================================================
-- SINCRONIZAÇÃO DOS PORTA-MALAS OCUPADOS
-- =========================================================

RegisterNetEvent("pr_trunk:sync", function(data)
    occupiedTrunks = data or {}
end)

RegisterNetEvent("pr_trunk:setOccupied", function(netId, state)
    if state then
        occupiedTrunks[netId] = true
    else
        occupiedTrunks[netId] = nil
    end
end)

-- =========================================================
-- TARGET
-- =========================================================

pr_lib.target.addGlobalVehicle({
    -- =====================================================
    -- ENTRAR
    -- =====================================================
    {
        name = "pr_trunk_enter",
        label = "Entrar no porta-malas",
        icon = "fa-solid fa-car-rear",
        bones = {
            "boot",
        },
        distance = 2.0,
        canInteract = function(entity, distance, coords, name, bone)
            if trunk.inside or trunk.pending then
                return false
            end
            if not entity or entity == 0 then
                return false
            end
            if IsPedInAnyVehicle(PlayerPedId(), false) then
                return false
            end
            if not HasTrunk(entity) then
                return false
            end
            if not IsTrunkOpen(entity) then
                return false
            end
            if not IsVehicleUnlocked(entity) then
                return false
            end
            if IsVehicleOccupied(entity) then
                return false
            end
            return true
        end,
        onSelect = function(data)
            local vehicle = data.entity
            if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) or trunk.pending then
                return
            end
            if not HasTrunk(vehicle) then
                return Notify("Este veículo não possui porta-malas compatível.", "erro")
            end
            if not IsTrunkOpen(vehicle) then
                return Notify("Abra o porta-malas antes de entrar.", "erro")
            end
            if not IsVehicleUnlocked(vehicle) then
                return Notify("O porta-malas está trancado.", "erro")
            end
            if IsVehicleOccupied(vehicle) then
                return Notify("Já existe alguém dentro deste porta-malas.", "erro")
            end
            if not NetworkGetEntityIsNetworked(vehicle) then
                return Notify("Não foi possível sincronizar este veículo.", "erro")
            end

            local netId = NetworkGetNetworkIdFromEntity(vehicle)
            if not netId or netId <= 0 or not NetworkDoesNetworkIdExist(netId) then
                return Notify("Não foi possível sincronizar este veículo.", "erro")
            end

            trunk.pending = true
            TriggerServerEvent("pr_trunk:requestEnter", netId)
        end,
    },
    -- =====================================================
    -- INFORMA QUE EXISTE ALGUÉM DENTRO
    -- =====================================================
    {
        name = "pr_trunk_occupied",
        label = "Há alguém no porta-malas",
        icon = "fa-solid fa-person",
        bones = {
            "boot",
        },
        distance = 2.0,
        canInteract = function(entity, distance, coords, name, bone)
            if not entity or entity == 0 then
                return false
            end
            -- Só revela que existe alguém quando
            -- o porta-malas estiver aberto.
            if not IsTrunkOpen(entity) then
                return false
            end
            return IsVehicleOccupied(entity)
        end,
        onSelect = function(data)
            -- Apenas informação.
        end,
    },
})

-- =========================================================
-- TECLA C
-- =========================================================

pr_lib.addKeybind({
    name = "pr_trunk_exit",
    description = "Sair do porta-malas",
    defaultKey = "X",
    onPressed = function()
        if trunk.inside then
            ExitTrunk()
        end
    end,
})

-- =========================================================
-- CONTROLE DO PLAYER DENTRO
-- =========================================================

CreateThread(function()
    while true do
        if trunk.inside then
            Wait(100)
            local vehicle = trunk.vehicle
            local ped = PlayerPedId()
            -- Veículo deixou de existir.
            if not vehicle or not DoesEntityExist(vehicle) then
                local oldNetId = trunk.netId
                trunk.inside = false
                trunk.vehicle = nil
                trunk.netId = nil
                DetachEntity(ped, true, true)
                SetEntityVisible(ped, true, false)
                SetEntityCollision(ped, true, true)
                TriggerServerEvent("pr_trunk:leave", oldNetId)
            else
                -- =================================================
                -- INVISÍVEL FECHADO
                -- VISÍVEL ABERTO
                -- =================================================
                SetTrunkPedVisibility(vehicle)
                -- Garante que continue anexado.
                if not IsEntityAttachedToEntity(ped, vehicle) then
                    local bone = GetTrunkBone(vehicle)
                    if bone ~= -1 then
                        AttachEntityToEntity(
                            ped,
                            vehicle,
                            bone,
                            0.0,
                            -0.15,
                            0.10,
                            0.0,
                            0.0,
                            180.0,
                            false,
                            false,
                            false,
                            false,
                            2,
                            true
                        )
                    end
                end
                -- Se a animação parar, inicia novamente.
                if not IsEntityPlayingAnim(ped, "timetable@floyd@cryingonbed@base", "base", 3) then
                    PlayTrunkAnimation()
                end
            end
        else
            Wait(1000)
        end
    end
end)

-- =========================================================
-- SOLICITA ESTADO AO INICIAR
-- =========================================================
CreateThread(function()
    Wait(1500)
    TriggerServerEvent("pr_trunk:requestSync")
end)

-- =========================================================
-- RESOURCE STOP
-- =========================================================
AddEventHandler("onResourceStop", function(resource)
    if resource ~= GetCurrentResourceName() then
        return
    end
    if trunk.inside then
        local ped = PlayerPedId()
        DetachEntity(ped, true, true)
        SetEntityVisible(ped, true, false)
        SetEntityCollision(ped, true, true)
    end
end)
