local QBCore = exports['qb-core']:GetCoreObject()

local PlayerData = {} -- Initialize PlayerData
local HasActiveMembership = false
local LastExerciseTime = {} -- Cooldown system
local isUIShowing = false

-- Function to get player data
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        PlayerData = QBCore.Functions.GetPlayerData()
        if PlayerData.citizenid then
            TriggerServerEvent('M4_GymLife:server:checkMembership')
            break
        end
    end
end)

-- Update PlayerData when it changes
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
    TriggerServerEvent('M4_GymLife:server:checkMembership')
end)

RegisterNetEvent('QBCore:Client:OnPlayerDataChange', function(newData)
    PlayerData = newData
end)

-- Receive membership status from server
RegisterNetEvent('M4_GymLife:client:setMembershipStatus', function(status)
    HasActiveMembership = status
    
    if not isUIShowing then return end
    
    local metadata = PlayerData.metadata or {}
    local membershipExpires = metadata['gym_membership_expires'] or 0
    local daysLeft = 0
    
    if HasActiveMembership then
        daysLeft = math.floor((membershipExpires - os.time()) / 86400)
    end
    
    SendNUIMessage({
        type = 'updateMembership',
        membership = {
            active = HasActiveMembership,
            daysLeft = daysLeft
        }
    })
end)

-- Check stats event handler
RegisterNetEvent('M4_GymLife:client:CheckStats', function()
    TriggerServerEvent('M4_GymLife:server:CheckStats')
end)

-- Display gym locations and handle interaction
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local inRange = false

        for _, gym in pairs(Config.GymLocations) do
            local dist = #(playerCoords - gym.coords)

            if dist < Config.TargetOptions.distance then
                inRange = true
                -- Use our custom DrawText3D function
                local coords = gym.coords
                DrawText3D(coords.x, coords.y, coords.z, Locales[Config.Locale]['press_to_interact'])

                if IsControlJustReleased(0, 38) then -- E key
                    OpenGymMenu(gym)
                end
            end
        end

        if not inRange then
            Citizen.Wait(500)
        end
    end
end)

function OpenGymMenu(gym)
    local elements = {}

    -- Membership option
    table.insert(elements, {
        header = Locales[Config.Locale]['current_membership'],
        txt = HasActiveMembership and Locales[Config.Locale]['gym_membership_active'] or Locales[Config.Locale]['no_active_membership'],
        isMenuHeader = true
    })

    if not HasActiveMembership then
        table.insert(elements, {
            header = string.format(Locales[Config.Locale]['buy_membership'], '$' .. Config.MembershipPrice),
            txt = 'Purchase a monthly gym membership.',
            params = {
                event = 'M4_GymLife:server:buyMembership',
                isServer = true
            }
        })
    end

    -- Exercise options
    table.insert(elements, {
        header = Locales[Config.Locale]['select_exercise'],
        isMenuHeader = true
    })

    for exerciseName, exerciseData in pairs(gym.exercises) do
        table.insert(elements, {
            header = exerciseData.label,
            txt = 'Improve your skills with ' .. exerciseData.label .. '.', -- More descriptive text
            params = {
                isAction = true,
                event = function()
                    local lastTime = LastExerciseTime[exerciseName] or 0
                    if (GetGameTimer() / 1000) - lastTime < exerciseData.cooldown then
                        QBCore.Functions.Notify(string.format(Locales[Config.Locale]['exercise_cooldown'], exerciseData.cooldown - math.floor((GetGameTimer() / 1000) - lastTime)), 'error')
                        return
                    end
                    TriggerServerEvent('M4_GymLife:server:startExercise', exerciseName, gym.price)
                    LastExerciseTime[exerciseName] = GetGameTimer() / 1000
                end
            }
        })
    end

    exports['qb-menu']:openMenu(elements)
end

-- Handle exercise animation and progress bar
RegisterNetEvent('M4_GymLife:client:doExercise', function(exerciseName)
    local playerPed = PlayerPedId()
    local exerciseData

    for _, gym in pairs(Config.GymLocations) do
        if gym.exercises[exerciseName] then
            exerciseData = gym.exercises[exerciseName]
            break
        end
    end

    if not exerciseData then return end

    -- Load animation dictionary
    RequestAnimDict(exerciseData.animation)
    while not HasAnimDictLoaded(exerciseData.animation) do
        Citizen.Wait(0)
    end

    -- Play animation
    TaskPlayAnim(playerPed, exerciseData.animation, 'base', 8.0, -8.0, -1, 1, 0, false, false, false)

    -- Create prop if exists
    local prop
    if exerciseData.prop then
        prop = CreateObject(GetHashKey(exerciseData.prop), GetEntityCoords(playerPed), true, false, false)
        AttachEntityToEntity(prop, playerPed, GetPedBoneIndex(playerPed, 28422), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
    end

    -- Progress bar
    QBCore.Functions.Progressbar('gym_exercise', Config.ProgressBar.label, Config.ProgressBar.duration, false, true, {
        disableMovement = false,
        disableCarMovement = false,
        disableMouse = false,
        disableCombat = true,
    }, {
        animDict = exerciseData.animation,
        anim = 'base',
        flags = 49,
    }, {}, {}, function(cancelled) -- onFinish
        if not cancelled then
            ClearPedTasks(playerPed)
            if prop then DeleteObject(prop) end
            TriggerServerEvent('M4_GymLife:server:finishExercise', exerciseName)
            UpdateStatsUI() -- Update UI after exercise
        else
            ClearPedTasks(playerPed)
            if prop then DeleteObject(prop) end
            QBCore.Functions.Notify('Exercise cancelled!', 'error')
        end
    end)
end)

-- Receive skill improvement notification
RegisterNetEvent('M4_GymLife:client:skillImproved', function(skillName)
    QBCore.Functions.Notify(string.format(Locales[Config.Locale]['skill_improved'], skillName), 'success')
    UpdateStatsUI() -- Update UI after skill improvement
end)

RegisterNetEvent('M4_GymLife:client:maxSkillReached', function(skillName)
    QBCore.Functions.Notify(string.format(Locales[Config.Locale]['max_skill_reached'], skillName), 'info')
end)

-- NPC Trainers
Citizen.CreateThread(function()
    local trainerPeds = {}
    
    -- Create all trainer NPCs
    for i, trainerData in ipairs(Config.NPCTrainers) do
        local trainerHash = GetHashKey(trainerData.model)
        
        RequestModel(trainerHash)
        while not HasModelLoaded(trainerHash) do
            Citizen.Wait(0)
        end
        
        local trainerPed = CreatePed(4, trainerHash, trainerData.coords.x, trainerData.coords.y, trainerData.coords.z - 1, trainerData.coords.w, false, true)
        SetEntityInvincible(trainerPed, true)
        SetBlockingOfNonTemporaryEvents(trainerPed, true)
        FreezeEntityPosition(trainerPed, true)
        SetPedFleeAttributes(trainerPed, 0, false)
        SetPedCombatAttributes(trainerPed, 46, true)
        
        -- Add some random animations for the trainers
        local anims = {
            'WORLD_HUMAN_MUSCLE_FLEX',
            'WORLD_HUMAN_MUSCLE_FREE_WEIGHTS',
            'WORLD_HUMAN_YOGA',
            'WORLD_HUMAN_STAND_IMPATIENT'
        }
        
        TaskStartScenarioInPlace(trainerPed, anims[math.random(1, #anims)], 0, true)
        
        table.insert(trainerPeds, {
            ped = trainerPed,
            coords = trainerData.coords
        })
        
        SetModelAsNoLongerNeeded(trainerHash)
    end
    
    -- Handle interaction with trainers
    while true do
        Citizen.Wait(0)
        local playerCoords = GetEntityCoords(PlayerPedId())
        local inRange = false
        
        for i, trainerData in ipairs(trainerPeds) do
            if trainerData and trainerData.coords then
                local trainerPos = vector3(trainerData.coords.x, trainerData.coords.y, trainerData.coords.z)
                local dist = #(playerCoords - trainerPos)
                
                if dist < 2.0 then
                    inRange = true
                    -- Use DrawText3D directly instead of QBCore.Functions.DrawText3D
                    local coordsAbove = vector3(trainerPos.x, trainerPos.y, trainerPos.z + 1.0)
                    DrawText3D(coordsAbove.x, coordsAbove.y, coordsAbove.z, Locales[Config.Locale]['press_to_interact'])
                    
                    if IsControlJustReleased(0, 38) then -- E key
                        OpenTrainerMenu()
                    end
                end
            end
        end
        
        if not inRange then
            Citizen.Wait(500)
        end
    end
end)

-- Custom DrawText3D function
function DrawText3D(x, y, z, text)
    -- Set up the basic parameters of the text
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(x, y, z, 0)
    DrawText(0.0, 0.0)
    local factor = (string.len(text)) / 370
    DrawRect(0.0, 0.0+0.0125, 0.017+ factor, 0.03, 0, 0, 0, 75)
    ClearDrawOrigin()
end

function OpenTrainerMenu()
    local elements = {}

    table.insert(elements, {
        header = Locales[Config.Locale]['current_membership'],
        txt = HasActiveMembership and Locales[Config.Locale]['gym_membership_active'] or Locales[Config.Locale]['no_active_membership'],
        isMenuHeader = true
    })

    if not HasActiveMembership then
        table.insert(elements, {
            header = string.format(Locales[Config.Locale]['buy_membership'], '$' .. Config.MembershipPrice),
            txt = 'Purchase a monthly gym membership.',
            params = {
                event = 'M4_GymLife:server:buyMembership',
                isServer = true
            }
        })
    end

    table.insert(elements, {
        header = "Check My Stats",
        txt = "View your current fitness stats",
        params = {
            event = 'M4_GymLife:client:CheckStats'
        }
    })

    table.insert(elements, {
        header = "Toggle Stats UI",
        txt = "Show/Hide the stats UI",
        params = {
            isAction = true,
            event = function()
                if isUIShowing then
                    HideStatsUI()
                else
                    ShowStatsUI()
                end
            end
        }
    })

    exports['qb-menu']:openMenu(elements)
end

-- Command to check stats
RegisterCommand('gymstats', function()
    TriggerEvent('M4_GymLife:client:CheckStats')
end, false)

-- Toggle stats UI
RegisterCommand('gymui', function()
    if isUIShowing then
        HideStatsUI()
    else
        ShowStatsUI()
    end
end, false)

-- Show stats UI
function ShowStatsUI()
    if not Config.UI.showStatsHUD then return end
    
    QBCore.Functions.TriggerCallback('M4_GymLife:server:GetPlayerStats', function(stats)
        if not stats then return end
        
        local metadata = PlayerData.metadata or {}
        local membershipExpires = metadata['gym_membership_expires'] or 0
        local hasActiveMembership = membershipExpires > os.time()
        local daysLeft = 0
        
        if hasActiveMembership then
            daysLeft = math.floor((membershipExpires - os.time()) / 86400)
        end
        
        SendNUIMessage({
            type = 'showUI',
            position = Config.UI.hudPosition,
            stats = {
                stamina = stats.stamina or 0,
                staminaCap = Config.SkillCaps.stamina,
                health = stats.health or 0,
                healthCap = Config.SkillCaps.health
            },
            membership = {
                active = hasActiveMembership,
                daysLeft = daysLeft
            }
        })
        
        isUIShowing = true
    end)
end

-- Hide stats UI
function HideStatsUI()
    SendNUIMessage({
        type = 'hideUI'
    })
    
    isUIShowing = false
end

-- Update stats UI
function UpdateStatsUI()
    if not isUIShowing then return end
    
    QBCore.Functions.TriggerCallback('M4_GymLife:server:GetPlayerStats', function(stats)
        if not stats then return end
        
        SendNUIMessage({
            type = 'updateStats',
            stats = {
                stamina = stats.stamina or 0,
                staminaCap = Config.SkillCaps.stamina,
                health = stats.health or 0,
                healthCap = Config.SkillCaps.health
            }
        })
    end)
end

-- Auto-show UI if enabled in config
Citizen.CreateThread(function()
    Wait(5000) -- Wait for player to fully load
    
    if Config.UI.showStatsHUD then
        ShowStatsUI()
    end
end)