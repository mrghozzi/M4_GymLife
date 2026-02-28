fx_version 'cerulean'
games { 'gta5' }

author       'MrGhozzi'
description  'M4_GymLife — QBCore gym system with membership, exercises, skill progression, and HUD.'
version      '1.1.0'

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

ui_page 'html/index.html'

files {
    'html/index.html'
}