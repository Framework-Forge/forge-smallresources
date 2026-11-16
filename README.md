# forge-smallresources

Pacote modular de pequenos recursos da Forge Core.

## Dependencias

- pr_bridge
- pr_mileage

PlayerData, metadata, cache, callbacks, menus, TextUI, progressos, streaming,
proximidade, notificacoes e estado veicular passam pelo pr_bridge. O dano aos
pneus usa o export client `pr_mileage:burstTyre(vehicle, index)`.

## Modulos

- crouch: agachar por keybind e cache local.
- disable_services: servicos de despacho e nivel de procurado.
- editor: comandos do Rockstar Editor.
- entity_blacklist: bloqueio opcional de entidades.
- flip_vehicle: desvirar veiculos com progresso.
- hud_components: componentes e controles nativos da HUD.
- item_pickup: pickups nativos desativados.
- no_shuffle: troca manual de banco, respeitando algema e cinto.
- remove_entities: remocao periodica de objetos configurados.
- safezones: zonas seguras e zonas de risco criadas e gerenciadas in-game.
- static_emitters: controle e painel administrativo de emissores.
- stun: tempo de stun gun.
- tackle: tackle validado no servidor.
- teleports: zonas e menus de teleporte.
- tire_slash: rasgar pneus com arma cortante empunhada e Interact do PR Bridge.
- vehicle_push: empurrar veiculo com estado veicular replicado pelo pr_bridge.
- vehicle_radio: radio veicular.
- weapon_recoil: recuo configuravel.
- world_cleanup: cenarios, geradores, armas corpo a corpo e ambiente.

## Ativar ou desativar

Edite shared/config.lua. Cada modulo pode ser desligado separadamente sem alterar o manifesto.

### Rasgar pneus

`modules.tireSlash = true` ativa a função. Em `tireSlash`, configure as armas
permitidas, alcance por pneu, duração da ação e velocidade máxima do veículo.
Por padrão aceita faca, garrafa, adaga, machadinha, facão e canivete.

Aproxime-se de um pneu intacto com uma dessas armas **empunhada**. O Interact
global do PR Bridge mostra “Rasgar pneu” junto à roda; use a tecla de interação
configurada no bridge (por padrão E). Guardar a arma esconde a opção. A ação usa
animação e progresso cancelável do bridge, sem DrawText3D, target externo ou
loops adicionais de busca/controle no smallresources.

O veículo deve estar parado ou quase parado (até 1 m/s por padrão), com pneus
que possam furar. Pneus já rasgados, rodas inexistentes, jogador morto, algemado
ou dentro de veículo não oferecem a opção. Cancelar ou perder as condições
antes de concluir não rasga o pneu. Todos os textos estão nos quatro locales.

Em veículos de rede, o servidor valida arma atual, distância ao centro, bucket,
tempo de ação e roda permitida. O cliente responsável pelo veículo revalida a
distância ao pneu e chama o export do pr_mileage, com uma tentativa adicional se a posse
de rede mudar. Não há roubo de controle, eventos arbitrários para um motorista
informado pelo jogador, nem novos statebags. Veículos locais usam o mesmo export,
sem RPC. Se o pr_mileage estiver indisponível, a ação falha com o aviso traduzido,
sem aplicar dano por um caminho alternativo.

O pr_mileage não repara mais pneus ao entrar no veículo nem ao limpar sintomas
de desgaste. A instalação confirmada de pneus novos continua reparando-os.
O export não altera a quilometragem ou o registro de peças no banco, e não salva
a perfuração entre despawn/respawn do veículo.

Reinicie `pr_mileage` e depois `forge-smallresources`. Teste com e sem arma
empunhada, pneus diferentes, cancelamento e um segundo jogador dirigindo um
veículo parado. Depois de rasgar, entre, saia e entre novamente: o dano deve
continuar. Teste também o reparo com a instalação de pneus novos.
Não é necessário iniciar o `wasabi_tireslash` da pasta de referências.

Teste isolado: `lua tests/tire_slash_test.lua` (na pasta deste resource). Ele
simula as APIs do jogo e do bridge; não substitui o teste multiplayer no FiveM.
O mapeamento das rodas e o dano de 1000 usam a
[referência nativa da Cfx](https://github.com/citizenfx/natives/blob/master/VEHICLE/SetVehicleTyreBurst.md).
O servidor verifica a arma atual sincronizada, conforme a
[API server-side da Cfx](https://github.com/citizenfx/fivem/blob/master/ext/native-decls/GetSelectedPedWeapon.md).

## Inicializacao

Inicie pr_bridge, pr_mileage e forge-smallresources, nessa ordem. O server.cfg
da base já inicia o pr_mileage antes do smallresources.

Para o blacklist de entidades, use set forge:bucketlockdownmode inactive. Outros valores mantem o modulo sem handlers de criacao.

## Idiomas

Os textos exibidos ao jogador e os avisos de diagnóstico usam o tradutor do pr_bridge. Os pacotes completos ficam em locale/:

- pt-br.json: português do Brasil
- en-us.json: inglês
- es.json: espanhol
- fr.json: francês

Defina o idioma pelo mecanismo global do pr_bridge. Se a sigla configurada não existir, o bridge aplica seu fallback seguro. Arquivos Lua internos são carregados por pr_lib.load; o recurso não usa require.

## Safezones e redzones

Administradores com a permissao group.admin podem usar /forgezones para abrir o gerenciador. A criacao usa a posicao atual do jogador e permite configurar individualmente:

- bloqueio de armas;
- bloqueio de agressoes;
- bloqueio de corrida;
- aumento de stress em redzones ou reducao em safezones;
- intervalo e quantidade da alteracao de stress;
- aviso de entrada com mensagem personalizada;
- raio, nome, tipo e estado ativo da zona.

As zonas ficam persistidas em safezones/zones.json. Edicao, exclusao, menus, formularios, notificacoes, callbacks, permissao, zonas de proximidade e metadata do jogador usam o pr_bridge.
### Formatos e stress

Cada zona pode usar sphere ou poly. A geometria de target e registrada por pr_lib.target.addSphereZone ou pr_lib.target.addPolyZone; a deteccao de entrada e saida usa pr_lib.zones.sphere ou pr_lib.zones.poly.

O valor de stress e um delta literal:

- valor positivo aumenta o stress;
- valor negativo reduz o stress;
- zero nao altera o stress;
- a opcao Alterar stress precisa estar marcada.

O debug desenha o volume da esfera ou as bordas e altura do poligono. Para PolyZone, o painel aceita uma lista JSON com 3 a 64 pontos contendo x, y e z.

### Depuracao visual

Abra `/forgezones` e selecione **Depuracao visual**. A visualizacao pertence somente a sessao do administrador que a ativou, com verificacao de permissao no servidor; nao aparece para outros administradores ou jogadores.

- **Mostrar todas as zonas (inclui APIs)**: desenha todas as safezones e redzones ativas do modulo, inclusive as registradas por outros recursos pela API. Desmarcar oculta todas, mesmo que os cadastros tenham `debug=true`.
- **Ocultar todas as zonas**: desliga o desenho e limpa a selecao individual desta sessao.
- **Selecao individual**: marque apenas as zonas proprias que deseja visualizar. Zonas criadas pela API nao aparecem nessa selecao; somente no modo global.

O padrao esta em `ForgeSmall.SafezoneConfig.debugMode`, no arquivo `safezones/config.lua`: `'off'` oculta todas, `'all'` inclui todas (inclusive APIs) e `'individual'` inicia com as zonas proprias que tenham `debug=true` no cadastro. Somente administradores autorizados enxergam esses padroes. As trocas pelo menu nao gravam os JSONs, nao recriam a deteccao das zonas e nao alteram stress, notificacoes ou restricoes. Ao sair do personagem, a visualizacao e encerrada.

`ForgeSmall.SafezoneConfig.debugDrawDistance` controla o alcance do desenho (padrao: 1500 metros). A referencia e a camera ativa, inclusive camera livre/noclip, e o tamanho da zona e somado ao alcance para nao cortar poligonos grandes pelo centro. Esse alcance afeta apenas a depuracao, nao a deteccao ou os efeitos das zonas.

A origem `local`/`api` e preservada ao editar. Registros legados sao reconhecidos pelo campo `owner`; os exports de cliente tambem informam o recurso que fez a chamada. O Target e a zona de proximidade nao recebem flags de desenho independentes, evitando que uma zona externa contorne o controle visual deste modulo. Zonas registradas diretamente em outro provider, sem usar a API de safezones do Forge Smallresources, nao pertencem a este controle.

Integracoes que ja possuem suas proprias zonas PR podem registrar um provider visual no cliente, sem duplicar geometria ou efeitos:

```lua
exports['forge-smallresources']:RegisterZoneDebugProvider(function(mode, selected)
    for id, zone in pairs(myRuntimeZones) do
        zone:setDebug(mode == 'all' or (mode == 'individual' and selected[id] == true))
    end
end)

-- A chamada identifica o recurso automaticamente e verifica a permissao
-- administrativa no servidor antes de mudar a selecao deste cliente.
exports['forge-smallresources']:SetZoneDebugSelection('my-zone-id', true)
```

`mode` e `'off'`, `'all'` ou `'individual'`. Cada recurso recebe somente sua propria selecao. Ocultar todas, desmarcar o global e sair do personagem limpam tambem as selecoes dos providers. Os providers precisam registrar novamente ao iniciar o Smallresources e desligar seu desenho se ele parar. A integracao do `ps-dispatch` usa esse contrato: todas as zonas de despacho acompanham o global, e o painel do Dispatch pode selecionar individualmente suas areas publicadas. Elas nao sao adicionadas a lista individual do gerenciador de Safe Zones. `Config.Debug` do Dispatch mantem seu comportamento nao visual, mas nao força o desenho das zonas.

### API de zonas

Exports server-side persistem e sincronizam as zonas:

    local sphereId = exports['forge-smallresources']:AddSphereZone({
        name = 'Hospital',
        type = 'safezone',
        coords = vec3(307.0, -595.0, 43.0),
        radius = 35.0,
        disableWeapons = true,
        disableAggression = true,
        stress = true,
        stressAmount = -2,
        stressInterval = 10,
        notify = true,
        debug = false,
        active = true,
    })

    local polyId = exports['forge-smallresources']:AddPolyZone({
        name = 'Area de conflito',
        type = 'redzone',
        points = {
            vec3(100.0, 100.0, 30.0),
            vec3(125.0, 100.0, 30.0),
            vec3(125.0, 125.0, 30.0),
            vec3(100.0, 125.0, 30.0),
        },
        thickness = 8.0,
        stress = true,
        stressAmount = 3,
        stressInterval = 5,
        debug = true,
    })

Exports de servidor: AddSphereZone, AddPolyZone, UpdateZone, RemoveZone, GetZone e GetZones. Todos possuem alias com inicial minuscula.

Exports de cliente: OpenAdminMenu(parentMenu), GetZones, GetActiveZones, IsInZone, alem dos exports de mutacao protegidos pela permissao administrativa do servidor. Para criacao automatica por outro resource, prefira os exports server-side.
### Criador de safezones/redzones

O menu administrativo usa o modo criador 3D do `pr_bridge` para SphereZone e PolyZone. O valor de stress e assinado: positivo aumenta e negativo reduz. A aplicacao usa o cache de status autoritativo do framework por `pr_lib.framework.AddPlayerStatus`, sem statebags. Os exports client/server desta funcionalidade sao publicados por `pr_lib.addExports`.
