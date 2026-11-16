ForgeSmall.SafezoneConfig = {
    command = 'forgezones',
    permission = 'group.admin',
    dataFile = 'safezones/zones.json',
    callbackTimeout = 10000,
    -- Apenas administradores: 'off' oculta todas; 'all' inclui zonas da API;
    -- 'individual' usa debug=true somente nas zonas proprias ao entrar.
    -- O menu altera apenas a visualizacao da sessao do administrador.
    debugMode = 'off',
    -- Distancia a partir da camera ativa (inclui camera livre/noclip).
    -- O tamanho da zona tambem e considerado para nao cortar suas bordas.
    debugDrawDistance = 1500.0,
    defaults = {
        type = 'safezone',
        shape = 'sphere',
        radius = 30.0,
        thickness = 4.0,
        polySize = 5.0,
        message = '',
        disableWeapons = true,
        disableAggression = true,
        disableRunning = false,
        stress = true,
        stressAmount = -1,
        stressInterval = 10,
        notify = true,
        debug = false,
        active = true,
    },
}
