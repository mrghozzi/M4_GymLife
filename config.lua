Config = {}

Config.GymLocations = {
    -- Vespucci Beach Gym
    ['vespucci'] = {
        label = 'Vespucci Beach Muscle Gym',
        coords = vector3(-1202.0, -1567.0, 4.6), -- Vespucci Beach outdoor gym
        heading = 130.0,
        price = 50, -- Price per exercise session
        blip = true, -- Show on map
        exercises = {
            ['bench_press'] = {
                label = 'Bench Press',
                coords = vector3(-1198.92, -1564.99, 4.61), -- Specific location for this exercise
                heading = 125.0,
                xp_gain = { stamina = 5, health = 2 },
                cooldown = 60, -- Cooldown in seconds
                animation = 'amb@world_human_muscle_free_weights@male@barbell@base',
                animationName = 'base',
                prop = 'prop_curl_bar_01',
            },
            ['push_ups'] = {
                label = 'Push Ups',
                coords = vector3(-1203.26, -1570.31, 4.61),
                heading = 35.0,
                xp_gain = { stamina = 3, health = 3 },
                cooldown = 45,
                animation = 'amb@world_human_push_ups@male@base',
                animationName = 'base',
                prop = nil,
            },
            ['chin_ups'] = {
                label = 'Chin Ups',
                coords = vector3(-1204.82, -1563.85, 4.61),
                heading = 215.0,
                xp_gain = { stamina = 4, health = 4 },
                cooldown = 60,
                animation = 'amb@prop_human_muscle_chin_ups@male@base',
                animationName = 'base',
                prop = nil,
            },
        },
    },
    
    -- Downtown Gym
    ['downtown'] = {
        label = 'Downtown Fitness Center',
        coords = vector3(246.61, -1190.0, 29.3), -- Downtown gym location
        heading = 310.0,
        price = 75, -- More expensive than beach gym
        blip = true,
        exercises = {
            ['treadmill'] = {
                label = 'Treadmill',
                coords = vector3(242.48, -1186.54, 29.3),
                heading = 310.0,
                xp_gain = { stamina = 6, health = 1 },
                cooldown = 90,
                animation = 'amb@world_human_jog_standing@male@base',
                animationName = 'base',
                prop = nil,
            },
            ['weights'] = {
                label = 'Free Weights',
                coords = vector3(249.38, -1187.85, 29.3),
                heading = 40.0,
                xp_gain = { stamina = 2, health = 5 },
                cooldown = 60,
                animation = 'amb@world_human_muscle_free_weights@male@barbell@base',
                animationName = 'base',
                prop = 'prop_barbell_01',
            },
            ['yoga'] = {
                label = 'Yoga',
                coords = vector3(246.0, -1186.0, 29.3),
                heading = 130.0,
                xp_gain = { stamina = 3, health = 3 },
                cooldown = 75,
                animation = 'amb@world_human_yoga@male@base',
                animationName = 'base',
                prop = nil,
            },
        },
    },
    
    -- Premium Gym
    ['premium'] = {
        label = 'Rockford Hills Premium Gym',
        coords = vector3(-1361.0, -1524.0, 4.3), -- Premium gym location
        heading = 30.0,
        price = 100, -- Most expensive
        blip = true,
        exercises = {
            ['advanced_weights'] = {
                label = 'Advanced Weight Training',
                coords = vector3(-1358.0, -1520.0, 4.3),
                heading = 30.0,
                xp_gain = { stamina = 4, health = 7 },
                cooldown = 120,
                animation = 'amb@world_human_muscle_free_weights@male@barbell@base',
                animationName = 'base',
                prop = 'prop_barbell_20kg',
            },
            ['advanced_cardio'] = {
                label = 'Advanced Cardio',
                coords = vector3(-1364.0, -1526.0, 4.3),
                heading = 210.0,
                xp_gain = { stamina = 8, health = 3 },
                cooldown = 120,
                animation = 'amb@world_human_jog_standing@male@base',
                animationName = 'base',
                prop = nil,
            },
            ['pilates'] = {
                label = 'Pilates',
                coords = vector3(-1362.0, -1523.0, 4.3),
                heading = 120.0,
                xp_gain = { stamina = 5, health = 5 },
                cooldown = 90,
                animation = 'amb@world_human_yoga@male@base',
                animationName = 'base',
                prop = nil,
            },
        },
    },
}

Config.MembershipPrice = 1000 -- Monthly membership price
Config.MembershipDuration = 30 -- Days
Config.MembershipNotificationDays = 3 -- Notify X days before expiration
Config.RequireMembership = true -- Set to true to require membership for exercises

Config.SkillCaps = {
    stamina = 100,
    health = 100,
}

Config.Locale = 'en' -- Default locale

Config.UseTarget = true -- Set to true to use qb-target, false to use markers

Config.TargetOptions = {
    distance = 2.5,
}

Config.ProgressBar = {
    duration = 20000, -- Duration of the progress bar in milliseconds
    label = 'Exercising...', -- Label for the progress bar
}

Config.QBCore = true -- Set to true for QBCore compatibility

-- NPC Trainer Configuration
Config.NPCTrainers = {
    {
        model = 'a_m_y_musclbeac_01', -- Beach muscle guy
        coords = vector4(-1202.0, -1570.0, 4.6, 130.0), -- Vespucci Beach
    },
    {
        model = 'a_f_y_fitness_02', -- Female fitness trainer
        coords = vector4(246.61, -1192.0, 29.3, 310.0), -- Downtown
    },
    {
        model = 'a_m_y_runner_01', -- Male runner
        coords = vector4(-1361.0, -1526.0, 4.3, 30.0), -- Premium gym
    },
}

-- UI Configuration
Config.UI = {
    showStatsHUD = false, -- Whether to show stats HUD
    hudPosition = 'right', -- Position of the HUD (left, right, top, bottom)
    hudScale = 0.5, -- Scale of the HUD
}