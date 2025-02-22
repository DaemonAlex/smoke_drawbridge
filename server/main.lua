local sharedConfig = require 'config.shared'
local config = require 'config.server'
local math = lib.math
local bridgeTimers = {}

CreateThread(function()
    for i = 1, #sharedConfig.bridges do
        GlobalState['bridges:state:' .. i] = false
        GlobalState['bridges:cooldown:' .. i] = false
        GlobalState['bridges:coords:' .. i] = sharedConfig.bridges[i].normalState
    end
end)

local function calculateTravelTime(currentCoords, targetCoords, index)
    local bridge = sharedConfig.bridges[index]
    local totalTime = bridge.movementDuration
    local currentDistance = #(currentCoords - targetCoords)
    local totalDistance = #(bridge.normalState - bridge.openState)
    local mod = (totalDistance - currentDistance) / totalDistance

    return totalTime - math.floor(totalTime * mod)
end

local function toggleBridge(index, state)
    CreateThread(function()
        local bridge = sharedConfig.bridges[index]
        local from = state and bridge.normalState or bridge.openState
        local to = state and bridge.openState or bridge.normalState
        local duration = calculateTravelTime(from, to, index)

        if bridgeTimers[index] then
            bridgeTimers[index]:forceEnd(false)
        end

        GlobalState['bridges:state:' .. index] = state
        GlobalState['bridges:cooldown:' .. index] = true
        lib.timer(config.bridgeSettings.cooldown, function()
            GlobalState['bridges:cooldown:' .. index] = false
        end, true)

        CreateThread(function()
            for interp in math.lerp(from, to, duration) do
                GlobalState['bridges:coords:' .. index] = interp
            end

            bridgeTimers[index] = lib.timer(config.bridgeSettings.timeout, function()
                toggleBridge(index, false)
                bridgeTimers[index] = nil
            end, true)
        end)
    end)
end

---@diagnostic disable-next-line: undefined-global
SetInterval(function()
    if math.random(1, 100) <= config.bridgeSettings.chance then
        for index = 1, #sharedConfig.bridges do
            if GlobalState['bridges:state:' .. index] then return end
            toggleBridge(true, index)
        end
    end
end, config.bridgeSettings.interval)

RegisterNetEvent('smoke_drawbridge:server:hackBridge', function(index)
    local config = sharedConfig.bridges[index].hackBridge
    if not config.enabled then return end
    local coords = GetEntityCoords(GetPlayerPed(source))
    local distance = #(coords - config.coords)
    if distance > 3 then return end
    if GlobalState['bridges:state:' .. index] then return end
    toggleBridge(index, true)
end)

if config.enableCommands then
    lib.addCommand('portbridges', {
        help = 'Open or view status of bridge',
        params = {
            {
                name = 'action',
                type = 'string',
                help = 'open, close or status',
            }
        },
        restricted = 'group.admin'
    }, function(source, args)
        if args.action == 'open' then
            for index = 1, #sharedConfig.bridges do
                toggleBridge(index, true)
            end
        elseif args.action == 'close' then
            for index = 1, #sharedConfig.bridges do
                toggleBridge(index)
            end
        elseif args.action == 'status' then
            local status = ('Vehicle Bridge: %s  \nRailway Bridge: %s'):format(GlobalState['bridges:state:1'] and 'open' or 'closed',
                GlobalState['bridges:state:2'] and 'open' or 'closed')
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Smoke Bridge',
                description = status,
                type = 'info'
            })
        else
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Smoke Bridge',
                description = 'Invalid state',
                type = 'error'
            })
        end
    end)
end

lib.versionCheck('BigSmoKe07/smoke_drawbridge')
-- Exports
exports('toggleBridge', toggleBridge)
