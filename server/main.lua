local QBCore = exports['qb-core']:GetCoreObject()

-- ============================================================
--  Helper Functions
-- ============================================================

local function GetPlayerMetadata(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player then
        return Player.PlayerData.metadata
    end
    return nil
end

local function SetPlayerMetadata(source, key, value)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player then
        Player.PlayerData.metadata[key] = value
        Player.Functions.SetMetaData(key, value)
    end
end

-- Track who has already been notified about expiry this session (avoid spam)
local notifiedExpired = {}

-- ============================================================
--  Check Membership on Connect
-- ============================================================

RegisterNetEvent('M4_GymLife:server:checkMembership', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local metadata     = GetPlayerMetadata(src)
    local expires      = metadata['gym_membership_expires'] or 0
    local isActive     = expires > os.time()
    local daysLeft     = isActive and math.ceil((expires - os.time()) / 86400) or 0

    TriggerClientEvent('M4_GymLife:client:setMembershipStatus', src, isActive, daysLeft)

    if isActive then
        if daysLeft <= Config.MembershipNotificationDays and daysLeft > 0 then
            QBCore.Functions.Notify(src,
                string.format(Locales[Config.Locale]['gym_membership_expires_soon'], daysLeft), 'warning')
        end
    else
        if expires > 0 and not notifiedExpired[src] then
            -- Only notify if membership existed before (not brand-new player)
            QBCore.Functions.Notify(src, Locales[Config.Locale]['gym_membership_expired'], 'error')
            notifiedExpired[src] = true
        end
    end
end)

-- ============================================================
--  Buy Membership  (single authoritative handler)
-- ============================================================

RegisterNetEvent('M4_GymLife:server:buyMembership', function()
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    -- Check if player already has an active membership
    local metadata = GetPlayerMetadata(src)
    local expires  = metadata['gym_membership_expires'] or 0
    if expires > os.time() then
        QBCore.Functions.Notify(src, Locales[Config.Locale]['gym_membership_already_active'], 'error')
        return
    end

    if Player.Functions.RemoveMoney('bank', Config.MembershipPrice) then
        local newExpiry = os.time() + (Config.MembershipDuration * 86400)
        SetPlayerMetadata(src, 'gym_membership_expires', newExpiry)
        notifiedExpired[src] = nil  -- Reset notification flag

        local daysLeft = Config.MembershipDuration
        TriggerClientEvent('M4_GymLife:client:setMembershipStatus', src, true, daysLeft)
        QBCore.Functions.Notify(src,
            string.format(Locales[Config.Locale]['gym_membership_paid'], '$' .. Config.MembershipPrice), 'success')
    else
        QBCore.Functions.Notify(src, Locales[Config.Locale]['not_enough_money'], 'error')
    end
end)

-- ============================================================
--  Start Exercise
--  ✅ FIX: price is now read SERVER-SIDE from Config, not from client
-- ============================================================

RegisterNetEvent('M4_GymLife:server:startExercise', function(gymKey, exerciseName)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    -- Validate gym & exercise exist in config (anti-cheat)
    local gym = Config.GymLocations[gymKey]
    if not gym then
        print('[M4_GymLife] WARN: Invalid gymKey from player ' .. src)
        return
    end
    local exerciseData = gym.exercises[exerciseName]
    if not exerciseData then
        print('[M4_GymLife] WARN: Invalid exerciseName from player ' .. src)
        return
    end

    -- Membership check
    local metadata = GetPlayerMetadata(src)
    local expires  = metadata['gym_membership_expires'] or 0
    if Config.RequireMembership and expires < os.time() then
        QBCore.Functions.Notify(src, Locales[Config.Locale]['gym_membership_expired'], 'error')
        TriggerClientEvent('M4_GymLife:client:setMembershipStatus', src, false, 0)
        return
    end

    -- Server-side cooldown check
    local cooldowns = metadata['gym_cooldowns'] or {}
    local lastTime  = cooldowns[exerciseName] or 0
    if (os.time() - lastTime) < exerciseData.cooldown then
        local remaining = exerciseData.cooldown - (os.time() - lastTime)
        QBCore.Functions.Notify(src,
            string.format(Locales[Config.Locale]['exercise_cooldown'], remaining), 'error')
        return
    end

    -- Charge from server-side price (✅ no longer trusting client price)
    if Player.Functions.RemoveMoney('cash', gym.price) then
        -- Save cooldown server-side
        cooldowns[exerciseName] = os.time()
        SetPlayerMetadata(src, 'gym_cooldowns', cooldowns)

        TriggerClientEvent('M4_GymLife:client:doExercise', src, exerciseName)
    else
        QBCore.Functions.Notify(src, Locales[Config.Locale]['not_enough_money'], 'error')
    end
end)

-- ============================================================
--  Finish Exercise & Apply Skill Gains
-- ============================================================

RegisterNetEvent('M4_GymLife:server:finishExercise', function(exerciseName)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    -- Find exercise data from config (not from client)
    local exerciseData
    local gymKey
    for k, gym in pairs(Config.GymLocations) do
        if gym.exercises[exerciseName] then
            exerciseData = gym.exercises[exerciseName]
            gymKey = k
            break
        end
    end
    if not exerciseData then return end

    -- Validate cooldown (double-check anti-cheat)
    local metadata   = GetPlayerMetadata(src)
    local cooldowns  = metadata['gym_cooldowns'] or {}
    local lastTime   = cooldowns[exerciseName] or 0
    -- Allow some tolerance (progress bar duration + 5s buffer)
    local minElapsed = (Config.ProgressBar.duration / 1000) - 5
    if (os.time() - lastTime) < minElapsed and lastTime > 0 then
        print('[M4_GymLife] WARN: Player ' .. src .. ' tried to finish exercise too fast!')
        return
    end

    local playerSkills = metadata['gym_skills'] or { stamina = 0, health = 0 }

    for skill, xpGain in pairs(exerciseData.xp_gain) do
        local current  = playerSkills[skill] or 0
        local cap      = Config.SkillCaps[skill] or 100

        if current < cap then
            playerSkills[skill] = math.min(current + xpGain, cap)
            SetPlayerMetadata(src, 'gym_skills', playerSkills)

            if skill == 'stamina' then
                Player.Functions.SetMetaData('max_stamina', playerSkills[skill])
            elseif skill == 'health' then
                Player.Functions.SetMetaData('max_health', playerSkills[skill])
            end

            TriggerClientEvent('M4_GymLife:client:skillImproved', src, skill, playerSkills[skill], cap)
        else
            TriggerClientEvent('M4_GymLife:client:maxSkillReached', src, skill)
        end
    end

    -- Send updated stats to UI
    TriggerClientEvent('M4_GymLife:client:updateStats', src, playerSkills)
end)

-- ============================================================
--  Periodic Membership Check (Hourly)
--  ✅ FIX: No longer spams notifications every hour
-- ============================================================

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(3600 * 1000)
        for _, src in pairs(QBCore.Functions.GetPlayers()) do
            local QBPlayer = QBCore.Functions.GetPlayer(src)
            if QBPlayer then
                local metadata = GetPlayerMetadata(src)
                local expires  = metadata['gym_membership_expires'] or 0

                if expires > 0 and expires < os.time() then
                    TriggerClientEvent('M4_GymLife:client:setMembershipStatus', src, false, 0)
                    -- Only notify once per session
                    if not notifiedExpired[src] then
                        QBCore.Functions.Notify(src, Locales[Config.Locale]['gym_membership_expired'], 'error')
                        notifiedExpired[src] = true
                    end
                elseif expires > os.time() then
                    local daysLeft = math.ceil((expires - os.time()) / 86400)
                    TriggerClientEvent('M4_GymLife:client:setMembershipStatus', src, true, daysLeft)
                    if daysLeft <= Config.MembershipNotificationDays then
                        QBCore.Functions.Notify(src,
                            string.format(Locales[Config.Locale]['gym_membership_expires_soon'], daysLeft), 'warning')
                    end
                end
            end
        end
    end
end)

-- Clean up when player drops
AddEventHandler('playerDropped', function()
    notifiedExpired[source] = nil
end)

-- ============================================================
--  Callbacks
-- ============================================================

-- Get player stats
QBCore.Functions.CreateCallback('M4_GymLife:server:GetPlayerStats', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb(nil) end

    local metadata     = GetPlayerMetadata(source)
    local playerSkills = metadata['gym_skills'] or { stamina = 0, health = 0 }
    local expires      = metadata['gym_membership_expires'] or 0
    local isActive     = expires > os.time()
    local daysLeft     = isActive and math.floor((expires - os.time()) / 86400) or 0

    cb({
        skills     = playerSkills,
        membership = { active = isActive, daysLeft = daysLeft }
    })
end)

-- ============================================================
--  Check Stats Command Handler
-- ============================================================

RegisterNetEvent('M4_GymLife:server:CheckStats', function()
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local metadata     = GetPlayerMetadata(src)
    local playerSkills = metadata['gym_skills'] or { stamina = 0, health = 0 }
    local expires      = metadata['gym_membership_expires'] or 0
    local isActive     = expires > os.time()
    local daysLeft     = isActive and math.floor((expires - os.time()) / 86400) or 0

    local membershipStatus = isActive
        and string.format(Locales[Config.Locale]['membership_days_left'], daysLeft)
        or  Locales[Config.Locale]['no_active_membership']

    local message = string.format(
        "🏋️ Fitness Stats\n▸ Stamina: %d/%d\n▸ Health: %d/%d\n▸ Membership: %s",
        playerSkills.stamina, Config.SkillCaps.stamina,
        playerSkills.health,  Config.SkillCaps.health,
        membershipStatus
    )

    TriggerClientEvent('QBCore:Notify', src, message, 'primary', 10000)
end)