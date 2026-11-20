fx_version 'cerulean'
game 'gta5'

name 'forge-smallresources'
author 'Forge Core'
description 'Colecao modular de pequenos recursos da Forge Core, integrada ao pr_bridge'
version '1.0.2'

shared_scripts {
    '@pr_bridge/init.lua',
    'shared/config.lua',
    'shared/init.lua',
    'tire_slash/shared.lua',
    'safezones/config.lua'
}

client_scripts {
    '**/client.lua'
}

server_scripts {
    '**/server.lua'
}

files {
    'locale/*.json',
    'safezones/zones.json',
    '**/config.json',
    '**/config.lua'
}

dependencies {
    'pr_bridge',
    'pr_mileage'
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'

server_script 'server/version.lua'
