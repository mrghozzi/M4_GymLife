fx_version 'cerulean'
games { 'gta5' }

author 'MrGhozzi'
description 'M4_GymLife is a QBCore resource that provides a comprehensive in-game gym system, allowing players to improve their physical skills like stamina and health through exercises at various gym locations.'
version '1.0.0'


shared_scripts {
    '@qb-core/shared/locale.lua',
    'config.lua',
    'locales/*.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}
