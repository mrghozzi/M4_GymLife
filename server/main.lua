local QBCore = exports['qb-core']:GetCoreObject()

-- Function to get player's metadata
local function GetPlayerMetadata(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player then
        return Player.PlayerData.metadata
    end
    return nil
end

-- Function to set player's metadata
local function SetPlayerMetadata(source, key, value)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player then
        Player.PlayerData.metadata[key] = value
        Player.Functions.SetMetaData(key, value)
    end
end

-- Check membership status on player connect/resource start
RegisterNetEvent('M4_GymLife:server:checkMembership', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local metadata = GetPlayerMetadata(src)
    local membershipExpires = metadata['gym_membership_expires'] or 0
    local hasActiveMembership = false

    if membershipExpires > os.time() then
        hasActiveMembership = true
    end

    TriggerClientEvent('M4_GymLife:client:setMembershipStatus', src, hasActiveMembership)

    -- Notify if membership is about to expire
    if hasActiveMembership then
        local timeLeft = membershipExpires - os.time()
        local daysLeft = math.ceil(timeLeft / (60 * 60 * 24))
        if daysLeft <= Config.MembershipNotificationDays and daysLeft > 0 then
            QBCore.Functions.Notify(src, string.format(Locales[Config.Locale]['gym_membership_expires_soon'], daysLeft), 'info')
        elseif daysLeft <= 0 then
            QBCore.Functions.Notify(src, Locales[Config.Locale]['gym_membership_expired'], 'error')
        end
    end
end)

-- Buy membership
RegisterNetEvent('M4_GymLife:server:buyMembership', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    if Player.Functions.RemoveMoney('bank', Config.MembershipPrice) then
        local newExpiry = os.time() + (Config.MembershipDuration * 24 * 60 * 60) -- Add days in seconds
        SetPlayerMetadata(src, 'gym_membership_expires', newExpiry)
        TriggerClientEvent('M4_GymLife:client:setMembershipStatus', src, true)
        QBCore.Functions.Notify(src, string.format(Locales[Config.Locale]['gym_membership_paid'], '$' .. Config.MembershipPrice), 'success')
    else
        QBCore.Functions.Notify(src, Locales[Config.Locale]['not_enough_money'], 'error')
    end
end)

-- Start exercise
RegisterNetEvent('M4_GymLife:server:startExercise', function(exerciseName, price)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local metadata = GetPlayerMetadata(src)
    local membershipExpires = metadata['gym_membership_expires'] or 0

    if membershipExpires < os.time() then
        QBCore.Functions.Notify(src, Locales[Config.Locale]['gym_membership_expired'], 'error')
        TriggerClientEvent('M4_GymLife:client:setMembershipStatus', src, false)
        return
    end

    if Player.Functions.RemoveMoney('cash', price) then
        TriggerClientEvent('M4_GymLife:client:doExercise', src, exerciseName)
    else
        QBCore.Functions.Notify(src, Locales[Config.Locale]['not_enough_money'], 'error')
    end
end)

-- Finish exercise and improve skills
RegisterNetEvent('M4_GymLife:server:finishExercise', function(exerciseName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local metadata = GetPlayerMetadata(src)
    local playerSkills = metadata['gym_skills'] or { stamina = 0, health = 0 }

    local exerciseData
    for _, gym in pairs(Config.GymLocations) do
        if gym.exercises[exerciseName] then
            exerciseData = gym.exercises[exerciseName]
            break
        end
    end

    if not exerciseData then return end

    for skill, xp_gain in pairs(exerciseData.xp_gain) do
        local currentSkill = playerSkills[skill] or 0
        local skillCap = Config.SkillCaps[skill] or 100

        if currentSkill < skillCap then
            local newSkill = math.min(currentSkill + xp_gain, skillCap)
            playerSkills[skill] = newSkill
            SetPlayerMetadata(src, 'gym_skills', playerSkills)

            -- Apply skill effects
            if skill == 'stamina' then
                Player.Functions.SetMetaData('max_stamina', newSkill) -- Example: Update max stamina
            elseif skill == 'health' then
                Player.Functions.SetMetaData('max_health', newSkill) -- Example: Update max health
            end

            TriggerClientEvent('M4_GymLife:client:skillImproved', src, skill)
        else
            TriggerClientEvent('M4_GymLife:client:maxSkillReached', src, skill)
        end
    end
end)

-- Periodically check and update membership status for all players
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(60 * 60 * 1000) -- Check every hour
        for _, Player in pairs(QBCore.Functions.GetPlayers()) do
            local src = Player
            local QBPlayer = QBCore.Functions.GetPlayer(src)
            if QBPlayer then
                local metadata = GetPlayerMetadata(src)
                local membershipExpires = metadata['gym_membership_expires'] or 0

                if membershipExpires < os.time() then
                    TriggerClientEvent('M4_GymLife:client:setMembershipStatus', src, false)
                    QBCore.Functions.Notify(src, Locales[Config.Locale]['gym_membership_expired'], 'error')
                end
            end
        end
    end
end)

-- Callback to check if player can afford membership
QBCore.Functions.CreateCallback('M4_GymLife:server:CanPurchaseMembership', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb(false) end
    
    if Player.PlayerData.money.bank >= Config.MembershipPrice then
        Player.Functions.RemoveMoney('bank', Config.MembershipPrice)
        local newExpiry = os.time() + (Config.MembershipDuration * 24 * 60 * 60) -- Add days in seconds
        SetPlayerMetadata(source, 'gym_membership_expires', newExpiry)
        cb(true)
    else
        cb(false)
    end
end)

-- Callback to check if player can pay for a single session
QBCore.Functions.CreateCallback('M4_GymLife:server:CanPayForSession', function(source, cb, price)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb(false) end
    
    if Player.PlayerData.money.cash >= price then
        Player.Functions.RemoveMoney('cash', price)
        cb(true)
    else
        cb(false)
    end
end)

-- Callback to get player stats
QBCore.Functions.CreateCallback('M4_GymLife:server:GetPlayerStats', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb(nil) end
    
    local metadata = GetPlayerMetadata(source)
    local playerSkills = metadata['gym_skills'] or { stamina = 0, health = 0 }
    cb(playerSkills)
end)

-- Check stats event handler
RegisterNetEvent('M4_GymLife:server:CheckStats', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local metadata = GetPlayerMetadata(src)
    local playerSkills = metadata['gym_skills'] or { stamina = 0, health = 0 }
    local membershipExpires = metadata['gym_membership_expires'] or 0
    local hasActiveMembership = membershipExpires > os.time()
    local membershipStatus = hasActiveMembership and Locales[Config.Locale]['gym_membership_active'] or Locales[Config.Locale]['no_active_membership']
    
    local daysLeft = ''
    if hasActiveMembership then
        daysLeft = string.format(Locales[Config.Locale]['membership_days_left'], math.floor((membershipExpires - os.time()) / 86400))
    end

    local message = string.format(
        "Fitness Stats:\n- Stamina: %d/%d\n- Health: %d/%d\n- Membership: %s %s",
        playerSkills.stamina, Config.SkillCaps.stamina,
        playerSkills.health, Config.SkillCaps.health,
        membershipStatus, daysLeft
    )

    TriggerClientEvent('QBCore:Notify', src, message, 'primary', 10000)
end)