if not ForgeSmall.isEnabled("vehicleTrunkIn") then
    return
end

-- =============================================
-- [netId] = source
-- =============================================
local occupiedTrunks = {}
-- =============================================
-- [source] = netId
-- =============================================
local playerTrunks = {}
-- =========================================================
-- UTILS
-- =========================================================
local function SendEnterResult(source, success, netId, reason)
    TriggerClientEvent("pr_trunk:enterResult", source, success, netId, reason)
end

local function SetOccupied(netId, source)
    occupiedTrunks[netId] = source
    playerTrunks[source] = netId
    TriggerClientEvent("pr_trunk:setOccupied", -1, netId, true)
end

local function RemoveOccupied(netId, source)
    if netId then
        occupiedTrunks[netId] = nil
    end
    if source then
        playerTrunks[source] = nil
    end
    if netId then
        TriggerClientEvent("pr_trunk:setOccupied", -1, netId, false)
    end
end

-- =========================================================
-- SOLICITAR ENTRADA
-- =========================================================
RegisterNetEvent("pr_trunk:requestEnter", function(netId)
    local source = source
    netId = tonumber(netId)
    if not netId or netId <= 0 or netId % 1 ~= 0 then
        SendEnterResult(source, false, netId, "Veículo inválido.")
        return
    end
    -- =============================================
    -- JOGADOR JÁ ESTÁ EM OUTRO PORTA-MALAS
    -- =============================================
    if playerTrunks[source] then
        SendEnterResult(source, false, netId, "Você já está dentro de um porta-malas.")
        return
    end
    -- =============================================
    -- PORTA-MALAS JÁ OCUPADO
    -- =============================================
    local occupant = occupiedTrunks[netId]
    if occupant then
        local occupantPed = GetPlayerPed(occupant)
        if occupantPed and occupantPed > 0 and DoesEntityExist(occupantPed) then
            SendEnterResult(source, false, netId, "Já existe alguém dentro deste porta-malas.")
            return
        end
        RemoveOccupied(netId, occupant)
    end
    -- =============================================
    -- VALIDA VEÍCULO
    -- =============================================
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2 then
        SendEnterResult(source, false, netId, "Veículo inválido.")
        return
    end

    local lockOk, lockStatus = pcall(GetVehicleDoorLockStatus, vehicle)
    if not lockOk or type(lockStatus) ~= "number" then
        SendEnterResult(source, false, netId, "Não foi possível verificar a trava do veículo.")
        return
    end
    if lockStatus > 1 then
        SendEnterResult(source, false, netId, "O porta-malas está trancado.")
        return
    end
    -- =============================================
    -- VALIDA PLAYER
    -- =============================================
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then
        return
    end
    -- =============================================
    -- DISTÂNCIA - SEGURANÇA SERVER SIDE
    -- =============================================
    if GetPlayerRoutingBucket(source) ~= GetEntityRoutingBucket(vehicle) then
        SendEnterResult(source, false, netId, "Você não está na mesma instância do veículo.")
        return
    end

    local playerCoords = GetEntityCoords(ped)
    local vehicleCoords = GetEntityCoords(vehicle)
    local distance = #(playerCoords - vehicleCoords)
    if distance > 6.0 then
        SendEnterResult(source, false, netId, "Você está muito longe do veículo.")
        return
    end
    -- =============================================
    -- NÃO PODE ESTAR DENTRO DE VEÍCULO
    -- =============================================
    if GetVehiclePedIsIn(ped, false) ~= 0 then
        SendEnterResult(source, false, netId, "Você já está dentro de um veículo.")
        return
    end
    -- =============================================
    -- RESERVA O PORTA-MALAS
    -- =============================================
    SetOccupied(netId, source)
    SendEnterResult(source, true, netId)
end)

-- =========================================================
-- SAIR
-- =========================================================
RegisterNetEvent("pr_trunk:leave", function(netId)
    local source = source
    local currentNetId = playerTrunks[source]
    if not currentNetId then
        return
    end
    -- Não confiamos no netId enviado pelo client.
    netId = currentNetId
    RemoveOccupied(netId, source)
end)

-- =========================================================
-- SINCRONIZAR
-- =========================================================
RegisterNetEvent("pr_trunk:requestSync", function()
    local source = source
    local sync = {}
    for netId in pairs(occupiedTrunks) do
        sync[netId] = true
    end
    TriggerClientEvent("pr_trunk:sync", source, sync)
end)

-- =========================================================
-- PLAYER DESCONECTOU
-- =========================================================
AddEventHandler("playerDropped", function()
    local source = source
    local netId = playerTrunks[source]
    if not netId then
        return
    end
    RemoveOccupied(netId, source)
end)
