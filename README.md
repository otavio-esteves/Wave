# Wave

Jogo de direção arcade em evolução para um pequeno mundo aberto brasileiro: **duas cidades fictícias ligadas por rodovia**, atmosfera de fim de tarde e otimização para o Dell Inspiron 5547. **Need for Speed: Most Wanted (2005)** é a referência de qualidade percebida, densidade, composição e velocidade; não é fonte de assets ou propriedade intelectual. Wave ainda não atingiu essa qualidade.

**Bonito, divertido e leve.** Parecer graficamente mais caro por meio de texturas, iluminação, silhueta e ilusões baratas. Godot **4.7.2**, GDScript tipado e renderer principal **Compatibility**. A primeira base desse trecho é a **Avenida do Vale, com 600 m**, antes de ampliar cidades. A aprovação artística do vertical slice continua pendente.

## Abrir e dirigir

Para passear no trecho em construção, execute [Wave no Linux](builds/linux/Wave.x86_64) ou `builds/windows/Wave.exe` e escolha a primeira opção: **Passear na cidade em construção**. Ela abre a Avenida do Vale de 600 m com ruas laterais e streaming; ainda não é uma cidade completa. Os mapas anteriores continuam disponíveis no menu.

No editor, abra `project.godot` e pressione F5. Pelo terminal:

```sh
godot --path .
```

Nesta máquina, o executável está em `~/Downloads/Apps/Godot_v4.7.2-stable_linux.x86_64`; substitua `godot` pelo caminho correspondente se necessário.

| Ação | Teclado | Gamepad |
| --- | --- | --- |
| Acelerar | W / ↑ | Gatilho direito |
| Frear / ré | S / ↓ | Gatilho esquerdo |
| Virar | A/D / ←/→ | Analógico esquerdo |
| Freio de mão | Espaço | A |
| Olhar para trás | C | Y |
| Câmera externa / capô | V | X |
| Reiniciar | R | B |
| Pausar | Esc | Start |
| Diagnósticos / captura | F3 / F4 | — |

Frear continuamente para engatar ré após parar. Pedais aceitam intensidade analógica. Na pausa: áudio, gráficos, reset, mapas e menu. Preferências em `user://wave-settings.cfg` são mantidas ao reiniciar.

## O que existe hoje

Hatch 1000 original, controlador arcade em `CharacterBody3D`, limite de 220 km/h, aderência/freio de mão, colisões, contato de quatro rodas, degraus e suspensão visual; câmera com SpringArm/FOV e capô. Bairro do Sol gerado offline com ruas/casas/comércio/posto, Circuito do Sol de 3,24 km com checkpoints, rally de 1,52 km com terreno/LOD/poeira e pista técnica. Motor/ambiente/música provisórios sintetizados offline, menus, teclado/gamepad e testes automatizados.

A **Avenida do Vale** acrescenta 600 m de avenida, duas ruas laterais, casas/sobrados, oficina, mercado, postes/fios, árvores em impostores, asfalto remendado e horizonte de fim de tarde. É gerada offline, com seed 5547, materiais simples e o mesmo carro.

Os mapas anteriores são laboratórios funcionais preservados. O rally possui um perfil experimental de pneus por eixo; ele não define a física do mundo aberto. Há uma prova de streaming com três células da Avenida do Vale, disponível em **Passear na cidade em construção**, preservando a versão estática. Ainda não há streaming integrado aos mapas antigos, tráfego, duas cidades conectadas ou vertical slice artístico aprovado. O bairro ainda carrega inteiro, embora use lotes espaciais para culling. Arte, timbre/mixagem e sensação exigem avaliação jogada.

## Gráficos e meta mínima

**Meta:** Haswell móvel, 8 GB RAM, HD 4400, **720p e 30 FPS estáveis**, com 45–60 desejáveis. A R7 M26x é perfil legacy superior. Essa meta **ainda não foi atingida com estabilidade comprovada**; resultados históricos em 480p não a validam. A máquina disponível tem 16 GB instalados, portanto também falta validar o limite de 8 GB. **Diretriz de avanço:** a Radeon do Inspiron pode liberar o desenvolvimento se passar no gate de condução em Compatibility/720p; a HD 4400 continua alvo de otimização, sem bloquear sozinha as próximas etapas.

| Preset | Configuração inicial |
| --- | --- |
| LOW / Legacy (padrão sem preferências) | 1280×720, sem sombras dinâmicas/MSAA/pós-processamento adicional |
| MEDIUM | 1280×720, sombras e MSAA 2× |
| HIGH | 1920×1080, sombras/MSAA e SSAO/glow opcionais no rally |
| Econômico histórico | 854×480, fallback sem sombras/MSAA; não cumpre a meta de resolução |

No corredor de 600 m, três passagens na Radeon desta máquina/Linux em Legacy/720p **sem VSync** registraram P99 de 8,63–10,39 ms e pior quadro de 20,40 ms, sem picos acima de 50 ms; VSync ligado apresentou grande variação. A opção existe no menu e seus valores continuam sendo escolha persistida do usuário. Isso não certifica o visual final nem sessões longas. Condições e dados em [performance.md](docs/performance.md).

Todos os presets funcionam em Compatibility e não trocam backend. Sombras e pós-processamento têm controles separados. HIGH não ativa SSIL/volumetria automaticamente. A opção desses cosméticos do rally só está disponível quando o processo foi iniciado em Forward+; nenhuma parte essencial do novo visual deverá depender dela. Tela cheia usa tamanho do monitor, registrado no benchmark. Preferências antigas de resolução/sombras/MSAA continuam válidas.

F4 registra até 180 s de condução: CSV amostrado, CSV por quadro e JSON com configuração, CPU/GPU, renderer, tamanho real, média, P95/P99, 1% low aproximado, picos e monitores de custo. Tempo CPU/GPU de viewport é opt-in em diagnóstico separado (`--profile-render-time`), pois as queries causaram stalls neste driver Intel. Pausa é excluída; alterar gráficos/trocar de mapa encerra a captura. Headless recusa FPS gráfico. Reprodução e limitações em [performance.md](docs/performance.md).

## Validar

```sh
GODOT_BIN=~/Downloads/Apps/Godot_v4.7.2-stable_linux.x86_64 bash scripts/tools/check_project.sh
```

A bateria atual passou no runner completo com **319 verificações** (318 antes da correção de acesso ao trecho), além de rotas renderizadas e conferência da interface. Os 14 checks do corredor cobrem determinismo/salvamento do corredor, bounds, placas offline, acesso pelo menu, avenida/lateral, oficina, sombra barata, reset e saída. Mais 46 checks validam partição/regeneração, streaming, cronologia da entrada e troca HLOD, incluindo atraso, falha, teleporte, pausa e destruição. O runner importa o projeto e verifica direção, terreno, handling, alta velocidade, bairro, circuito, rally, LOD/serialização visual, áudio, menus/persistência e estatísticas/arquivos de performance, em diretórios temporários. Os testes dirigem cenas reais por inputs. Não substituem benchmark renderizado, gamepad conectado, escuta ou teste humano de diversão.

Para executar as seis fixtures sequencialmente e guardar contexto/identidade do código em uma pasta nova:

```sh
DRI_PRIME=0 GODOT_BIN=~/Downloads/Apps/Godot_v4.7.2-stable_linux.x86_64 bash scripts/tools/benchmark_reference.sh /tmp/wave-reference-new all
```

O runner aceita `urban`, `residential`, `vegetation`, `speed`, `corridor` ou `streaming` no lugar de `all`. Rotas individuais com janela, sem `--headless` ou `--fixed-fps`, uma execução por vez:

```sh
DRI_PRIME=0 XDG_DATA_HOME=/tmp/wave-urban godot --path . --rendering-method gl_compatibility --script res://tests/rendered_route.gd -- --legacy
DRI_PRIME=0 XDG_DATA_HOME=/tmp/wave-residential godot --path . --rendering-method gl_compatibility --script res://tests/rendered_route.gd -- --legacy --residential
DRI_PRIME=0 XDG_DATA_HOME=/tmp/wave-vegetation godot --path . --rendering-method gl_compatibility --script res://tests/rally_rendered.gd -- --legacy
DRI_PRIME=0 XDG_DATA_HOME=/tmp/wave-speed godot --path . --rendering-method gl_compatibility --script res://tests/high_speed_smoke.gd -- --legacy
```

`DRI_PRIME` é específico do Linux/Mesa; confirme a GPU no log/JSON. Use pastas distintas e nunca compartilhe preferências pessoais com ensaios. Rodovia/tráfego próprios aguardam conteúdo; a avenida externa e o rally são fixtures identificadas, não provas do mundo futuro.

## Pipeline offline e builds

Editar geradores, gerar → validar → salvar → carregar. O jogo não executa geração procedural pesada. Comandos preservados:

```sh
python3 scripts/tools/build_corridor_signs.py
godot --headless --path . --editor --quit
godot --headless --path . --script res://scripts/tools/build_corridor.gd
godot --headless --path . --script res://scripts/tools/build_corridor_cells.gd
godot --headless --path . --script res://scripts/tools/build_neighborhood.gd
godot --headless --path . --script res://scripts/tools/build_hatch_car.gd
python3 scripts/tools/build_race_textures.py
godot --headless --path . --script res://scripts/tools/build_race_track.gd
python3 scripts/tools/build_rally_textures.py
godot --headless --path . --script res://scripts/tools/build_rally_stage.gd
python3 scripts/tools/build_audio.py
```

Bairro, circuito, rally e corredor usam a API compartilhada `OfflineSceneBuilder`, sem depender dos internos do layout do bairro. Os três geradores aceitam `-- --output=user://teste.tscn` para regeneração isolada; o runner usa essa opção e compara geometria, colisões e visibilidade com as cenas preservadas.

Geradores sobrescrevem seus artefatos: autoria deve entrar no layout/parâmetros/overrides, não se perder ao regenerar. O pinheiro produzido por IA é um PNG independente preservado. Origem dos recursos em [assets.md](docs/assets.md). Prévias usam scripts `build_*_previews.gd` com janela e ficam em `builds/previews`.

Exportar Linux/Windows com templates 4.7.2 instalados:

```sh
GODOT_BIN=~/Downloads/Apps/Godot_v4.7.2-stable_linux.x86_64 bash scripts/tools/export_builds.sh
```

O pacote inclui explicitamente os manifestos JSON de `scenes/world/cells/`. Para verificar o menu, o carregamento das células, a condução e o retorno usando os recursos exportados (com a engine do editor como harness, não como benchmark):

```sh
wave_repo="$PWD"
cd /tmp
XDG_DATA_HOME=/tmp/wave-pack-access godot --headless --main-pack "$wave_repo/builds/linux/Wave.pck" --script "$wave_repo/tests/exported_menu_smoke.gd"
```

Templates locais em `tools/godot/export_templates` também são aceitos. Distribuir a pasta completa da plataforma, incluindo `Wave.pck`. Os launchers `Wave-quality` agora iniciam HIGH em Compatibility. Builds existentes precisam ser reexportados para incluir esta revisão; Windows nativo e sessões longas continuam pendentes.

## Plano e decisões

[Plano vigente](development-plan.md) · [Revisão arquitetural](docs/architecture.md) · [Contrato de streaming](docs/world-streaming.md) · [Direção de arte](docs/art-direction.md) · [Orçamento](docs/performance-budget.md) · [Medições](docs/performance.md) · [Histórico arquivado](docs/history.md).

A variante de células preserva silhuetas distantes com HLOD offline e troca visual com histerese. Oficina e mercado receberam uma primeira revisão de placas, acessos, pintura e desgaste com materiais existentes, preservando as colisões. [Comparações e custo medido](docs/performance-results/2026-10-06/hero-areas/README.md). Próxima etapa: reduzir o custo da primeira entrada antes de acrescentar conteúdo; depois, continuar a autoria dos lotes e do áudio no mesmo corredor. Expansão, trânsito e atividades vêm depois dos gates de qualidade e pacing.

Prévia atual: [Mercado do Vale — Legacy 720p](docs/performance-results/2026-10-06/hero-areas/after-views/corridor-2.png). Fachadas e árvore originais via image_gen: [prompts e origem](assets/textures/corridor/provenance.json).

A prova de células tem [contrato e limites](docs/world-streaming.md), guard de apoio e telemetria de carga/ativação/liberação. O [diagnóstico de entrada/memória](docs/performance-results/2026-10-06/streaming-diagnostics/README.md) compara cache novo/reutilizado e doze travessias com/sem captura: contagens estáveis e RSS desacelerando, sem certificar sessões longas ou 8 GB. Ela usa piso plano; o fallback de atraso segura a condução e não deve ocorrer nas travessias normais.

HLOD da avenida: [comparações visuais, benchmarks e limites](docs/performance-results/2026-10-06/hlod/README.md). A entrada fria ganhou custo adicional e continua pendente; o ganho medido é continuidade distante e menor desenho durante a rota.
