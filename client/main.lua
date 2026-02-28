local QBCore = exports['qb-core']:GetCoreObject()

local PlayerData          = {}
local HasActiveMembership = false
local MembershipDaysLeft  = 0
local isUIShowing         = false
local ClientCooldowns     = {} -- client-side visual cooldown (UI only, real check is server-side)

-- ============================================================
--  Player Data
-- ============================================================

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

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
    TriggerServerEvent('M4_GymLife:server:checkMembership')
end)

RegisterNetEvent('QBCore:Client:OnPlayerDataChange', function(newData)
    PlayerData = newData
end)

-- ============================================================
--  Membership Status  (✅ FIX: daysLeft now comes from server)
-- ============================================================

RegisterNetEvent('M4_GymLife:client:setMembershipStatus', function(status, daysLeft)
    HasActiveMembership  = status
    MembershipDaysLeft   = daysLeft or 0

    if not isUIShowing then return end

    SendNUIMessage({
        type       = 'updateMembership',
        membership = {
            active   = HasActiveMembership,
            daysLeft = MembershipDaysLeft
        }
    })
end)

-- ============================================================
--  Receive updated stats from server after exercise
-- ============================================================

RegisterNetEvent('M4_GymLife:client:updateStats', function(skills)
    if not isUIShowing then return end
    SendNUIMessage({
        type  = 'updateStats',
        stats = {
            stamina    = skills.stamina    or 0,
            staminaCap = Config.SkillCaps.stamina,
            health     = skills.health     or 0,
            healthCap  = Config.SkillCaps.health
        }
    })
end)

-- ============================================================
--  Gym Location Markers & Interaction
-- ============================================================

Citizen.CreateThread(function()
    -- Setup qb-target zones if enabled
    if Config.UseTarget then
        for gymKey, gym in pairs(Config.GymLocations) do
            exports['qb-target']:AddCircleZone(
                'M4_GymLife_' .. gymKey,
                gym.coords,
                Config.TargetOptions.distance,
                { name = 'M4_GymLife_' .. gymKey, debugPoly = false },
                {
                    options = {
                        {
                            type    = 'client',
                            event   = 'M4_GymLife:client:openGymMenuByKey',
                            icon    = 'fas fa-dumbbell',
                            label   = gym.label,
                            gymKey  = gymKey,
                        }
                    },
                    distance = Config.TargetOptions.distance
                }
            )
        end
        return -- Don't run the marker loop
    end

    -- Marker-based interaction
    while true do
        Citizen.Wait(0)
        local playerPed    = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local inRange      = false

        for gymKey, gym in pairs(Config.GymLocations) do
            local dist = #(playerCoords - gym.coords)

            if dist < Config.TargetOptions.distance + 5.0 then
                -- Draw blip marker
                DrawMarker(1,
                    gym.coords.x, gym.coords.y, gym.coords.z - 1.0,
                    0.0, 0.0, 0.0,
                    0.0, 0.0, 0.0,
                    1.5, 1.5, 0.8,
                    0, 160, 255, 100,
                    false, true, 2, false, nil, nil, false)
            end

            if dist < Config.TargetOptions.distance then
                inRange = true
                DrawText3D(gym.coords.x, gym.coords.y, gym.coords.z + 0.5,
                    Locales[Config.Locale]['press_to_interact'])

                if IsControlJustReleased(0, 38) then
                    OpenGymMenu(gymKey, gym)
                end
            end
        end

        if not inRange then Citizen.Wait(200) end
    end
end)

-- For qb-target event
RegisterNetEvent('M4_GymLife:client:openGymMenuByKey', function(data)
    local gymKey = data.gymKey
    local gym    = Config.GymLocations[gymKey]
    if gym then
        OpenGymMenu(gymKey, gym)
    end
end)

-- ============================================================
--  Gym Menu  (✅ FIX: gymKey passed to server, not price)
-- ============================================================

function OpenGymMenu(gymKey, gym)
    local elements = {}

    table.insert(elements, {
        header      = gym.label,
        txt         = HasActiveMembership
            and string.format('✅ %s (%d days left)',
                Locales[Config.Locale]['gym_membership_active'], MembershipDaysLeft)
            or  '❌ ' .. Locales[Config.Locale]['no_active_membership'],
        isMenuHeader = true
    })

    if not HasActiveMembership then
        table.insert(elements, {
            header = string.format(Locales[Config.Locale]['buy_membership'], '$' .. Config.MembershipPrice),
            txt    = 'Purchase a ' .. Config.MembershipDuration .. '-day gym membership.',
            params = {
                event    = 'M4_GymLife:server:buyMembership',
                isServer = true
            }
        })
    end

    table.insert(elements, {
        header      = Locales[Config.Locale]['select_exercise'],
        isMenuHeader = true
    })

    for exerciseName, exerciseData in pairs(gym.exercises) do
        -- Client-side cooldown display
        local lastTime   = ClientCooldowns[exerciseName] or 0
        local elapsed    = (GetGameTimer() / 1000) - lastTime
        local onCooldown = elapsed < exerciseData.cooldown
        local cdText     = onCooldown
            and string.format(' (ready in %ds)', math.ceil(exerciseData.cooldown - elapsed))
            or  ''

        table.insert(elements, {
            header = exerciseData.label .. cdText,
            txt    = string.format('Cost: $%d | Stamina +%d | Health +%d',
                gym.price,
                exerciseData.xp_gain.stamina or 0,
                exerciseData.xp_gain.health  or 0),
            params = {
                isAction = true,
                event    = function()
                    if onCooldown then
                        QBCore.Functions.Notify(
                            string.format(Locales[Config.Locale]['exercise_cooldown'],
                                math.ceil(exerciseData.cooldown - elapsed)), 'error')
                        return
                    end
                    -- ✅ Send gymKey instead of price — server reads price from Config
                    TriggerServerEvent('M4_GymLife:server:startExercise', gymKey, exerciseName)
                    ClientCooldowns[exerciseName] = GetGameTimer() / 1000
                end
            }
        })
    end

    table.insert(elements, {
        header = Locales[Config.Locale]['check_stats'],
        txt    = 'View your current fitness progress.',
        params = {
            isAction = true,
            event    = function()
                TriggerServerEvent('M4_GymLife:server:CheckStats')
            end
        }
    })

    table.insert(elements, {
        header = Locales[Config.Locale]['toggle_ui'],
        txt    = isUIShowing and 'Hide the HUD overlay.' or 'Show the HUD overlay.',
        params = {
            isAction = true,
            event    = function()
                if isUIShowing then HideStatsUI() else ShowStatsUI() end
            end
        }
    })

    exports['qb-menu']:openMenu(elements)
end

-- ============================================================
--  Exercise Animation  (✅ FIX: uses exerciseData.animationName)
-- ============================================================

RegisterNetEvent('M4_GymLife:client:doExercise', function(exerciseName)
    local playerPed    = PlayerPedId()
    local exerciseData

    for _, gym in pairs(Config.GymLocations) do
        if gym.exercises[exerciseName] then
            exerciseData = gym.exercises[exerciseName]
            break
        end
    end
    if not exerciseData then return end

    -- Load animation
    RequestAnimDict(exerciseData.animation)
    while not HasAnimDictLoaded(exerciseData.animation) do
        Citizen.Wait(0)
    end

    -- ✅ FIX: use exerciseData.animationName, not hardcoded 'base'
    local animName = exerciseData.animationName or 'base'
    TaskPlayAnim(playerPed, exerciseData.animation, animName,
        8.0, -8.0, -1, 1, 0, false, false, false)

    -- Prop
    local prop
    if exerciseData.prop then
        local propHash = GetHashKey(exerciseData.prop)
        RequestModel(propHash)
        while not HasModelLoaded(propHash) do Citizen.Wait(0) end
        prop = CreateObject(propHash, GetEntityCoords(playerPed), true, false, false)
        AttachEntityToEntity(prop, playerPed,
            GetPedBoneIndex(playerPed, 28422),
            0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
            false, false, false, false, 2, true)
        SetModelAsNoLongerNeeded(propHash)
    end

    -- Progress bar
    QBCore.Functions.Progressbar('gym_exercise', Config.ProgressBar.label,
        Config.ProgressBar.duration, false, true,
        {
            disableMovement    = true,
            disableCarMovement = true,
            disableMouse       = false,
            disableCombat      = true,
        },
        {
            animDict = exerciseData.animation,
            anim     = animName,
            flags    = 49,
        },
        {}, {},
        function(cancelled)
            ClearPedTasks(playerPed)
            if prop then DeleteObject(prop) end
            if not cancelled then
                TriggerServerEvent('M4_GymLife:server:finishExercise', exerciseName)
            else
                QBCore.Functions.Notify('Exercise cancelled!', 'error')
            end
        end
    )
end)

-- ============================================================
--  Skill Notifications  (✅ now includes new value and cap)
-- ============================================================

RegisterNetEvent('M4_GymLife:client:skillImproved', function(skillName, newValue, cap)
    QBCore.Functions.Notify(
        string.format('💪 %s improved! (%d/%d)',
            skillName:gsub("^%l", string.upper), newValue, cap),
        'success')
end)

RegisterNetEvent('M4_GymLife:client:maxSkillReached', function(skillName)
    QBCore.Functions.Notify(
        string.format(Locales[Config.Locale]['max_skill_reached'], skillName), 'info')
end)

-- ============================================================
--  NPC Trainers
-- ============================================================

Citizen.CreateThread(function()
    local trainerPeds = {}
    local anims = {
        'WORLD_HUMAN_MUSCLE_FLEX',
        'WORLD_HUMAN_MUSCLE_FREE_WEIGHTS',
        'WORLD_HUMAN_YOGA',
        'WORLD_HUMAN_STAND_IMPATIENT'
    }

    for _, trainerData in ipairs(Config.NPCTrainers) do
        local hash = GetHashKey(trainerData.model)
        RequestModel(hash)
        while not HasModelLoaded(hash) do Citizen.Wait(0) end

        local ped = CreatePed(4, hash,
            trainerData.coords.x, trainerData.coords.y,
            trainerData.coords.z - 1.0, trainerData.coords.w,
            false, true)

        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        FreezeEntityPosition(ped, true)
        SetPedFleeAttributes(ped, 0, false)
        SetPedCombatAttributes(ped, 46, true)
        TaskStartScenarioInPlace(ped, anims[math.random(#anims)], 0, true)
        SetModelAsNoLongerNeeded(hash)

        table.insert(trainerPeds, { ped = ped, coords = trainerData.coords })

        -- Register qb-target on NPC if enabled
        if Config.UseTarget then
            exports['qb-target']:AddTargetEntity(ped, {
                options = {
                    {
                        type  = 'client',
                        event = 'M4_GymLife:client:openTrainerMenu',
                        icon  = 'fas fa-dumbbell',
                        label = 'Talk to Trainer',
                    }
                },
                distance = 2.5
            })
        end
    end

    if Config.UseTarget then return end

    while true do
        Citizen.Wait(0)
        local playerCoords = GetEntityCoords(PlayerPedId())
        local inRange      = false

        for _, td in ipairs(trainerPeds) do
            if td and td.coords then
                local pos  = vector3(td.coords.x, td.coords.y, td.coords.z)
                local dist = #(playerCoords - pos)

                if dist < 2.0 then
                    inRange = true
                    DrawText3D(pos.x, pos.y, pos.z + 1.2,
                        Locales[Config.Locale]['press_to_interact'])

                    if IsControlJustReleased(0, 38) then
                        OpenTrainerMenu()
                    end
                end
            end
        end

        if not inRange then Citizen.Wait(300) end
    end
end)

RegisterNetEvent('M4_GymLife:client:openTrainerMenu', function()
    OpenTrainerMenu()
end)

function OpenTrainerMenu()
    local elements = {
        {
            header      = '🏋️ Personal Trainer',
            txt         = HasActiveMembership
                and string.format('✅ Active membership (%d days left)', MembershipDaysLeft)
                or  '❌ No active membership',
            isMenuHeader = true
        },
    }

    if not HasActiveMembership then
        table.insert(elements, {
            header = string.format(Locales[Config.Locale]['buy_membership'], '$' .. Config.MembershipPrice),
            txt    = 'Purchase a ' .. Config.MembershipDuration .. '-day membership.',
            params = { event = 'M4_GymLife:server:buyMembership', isServer = true }
        })
    end

    table.insert(elements, {
        header = Locales[Config.Locale]['check_stats'],
        txt    = 'View your current fitness progress.',
        params = {
            isAction = true,
            event    = function() TriggerServerEvent('M4_GymLife:server:CheckStats') end
        }
    })

    table.insert(elements, {
        header = Locales[Config.Locale]['toggle_ui'],
        txt    = isUIShowing and 'Hide the HUD overlay.' or 'Show the HUD overlay.',
        params = {
            isAction = true,
            event    = function()
                if isUIShowing then HideStatsUI() else ShowStatsUI() end
            end
        }
    })

    exports['qb-menu']:openMenu(elements)
end

-- ============================================================
--  DrawText3D helper
-- ============================================================

function DrawText3D(x, y, z, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry('STRING')
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(x, y, z, 0)
    DrawText(0.0, 0.0)
    local factor = string.len(text) / 370
    DrawRect(0.0, 0.0125, 0.017 + factor, 0.03, 0, 0, 0, 75)
    ClearDrawOrigin()
end

-- ============================================================
--  Stats UI
--  ✅ FIX: ShowStatsUI works even when Config.UI.showStatsHUD = false
--          (manual calls bypass the auto-hide flag)
-- ============================================================

function ShowStatsUI(force)
    if not force and not Config.UI.showStatsHUD then return end

    QBCore.Functions.TriggerCallback('M4_GymLife:server:GetPlayerStats', function(data)
        if not data then return end

        SendNUIMessage({
            type       = 'showUI',
            position   = Config.UI.hudPosition,
            scale      = Config.UI.hudScale,
            stats      = {
                stamina    = data.skills.stamina    or 0,
                staminaCap = Config.SkillCaps.stamina,
                health     = data.skills.health     or 0,
                healthCap  = Config.SkillCaps.health
            },
            membership = data.membership
        })
        isUIShowing = true
    end)
end

function HideStatsUI()
    SendNUIMessage({ type = 'hideUI' })
    isUIShowing = false
end

function UpdateStatsUI()
    if not isUIShowing then return end
    QBCore.Functions.TriggerCallback('M4_GymLife:server:GetPlayerStats', function(data)
        if not data then return end
        SendNUIMessage({
            type  = 'updateStats',
            stats = {
                stamina    = data.skills.stamina    or 0,
                staminaCap = Config.SkillCaps.stamina,
                health     = data.skills.health     or 0,
                healthCap  = Config.SkillCaps.health
            }
        })
    end)
end

-- ============================================================
--  Commands
-- ============================================================

RegisterCommand('gymstats', function()
    TriggerServerEvent('M4_GymLife:server:CheckStats')
end, false)

RegisterCommand('gymui', function()
    if isUIShowing then
        HideStatsUI()
    else
        ShowStatsUI(true)  -- force = true, bypasses showStatsHUD flag
    end
end, false)

-- ============================================================
--  Auto-show HUD if enabled in config
-- ============================================================

Citizen.CreateThread(function()
    Wait(5000)
    if Config.UI.showStatsHUD then
        ShowStatsUI()
    end
end)