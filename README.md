# Wave

Jogo de direção arcade em evolução, com atmosfera brasileira e ciclo de dia e noite e otimização para o Dell Inspiron 5547. O desenvolvimento agora se concentra em **uma cidade piloto de 200 quarteirões em três bairros**, para definir física, jogabilidade e estética antes das cidades definitivas. **Need for Speed: Most Wanted (2012)** é a referência de qualidade percebida, densidade, composição e velocidade; não é fonte de assets ou propriedade intelectual. Wave ainda não atingiu essa qualidade.

**Bonito, divertido e leve.** Parecer graficamente mais caro por meio de texturas, iluminação, silhueta e ilusões baratas. Godot **4.7.2**, GDScript tipado e renderer principal **Compatibility**. A base atual é a **cidade piloto, com 200 quarteirões conectados**, ruas curvas e relevo. A revisão atual reúne Jardins do Vale (residencial de classe alta), Vila Aurora (bairro médio com comércio) e Centro Horizonte (arranha-céus e parque central); os mapas anteriores permanecem como laboratórios. A aprovação artística do vertical slice continua pendente.

## Abrir e dirigir

Para passear no trecho em construção, execute [Wave no Linux](builds/linux/Wave.x86_64) ou `builds/windows/Wave.exe` e escolha a primeira opção: **Dirigir na cidade piloto**. Ela abre três bairros conectados, com 200 quarteirões, 18 praças/parques e oficina, em uma área de 3.072 × 2.464 m — quatro vezes a área anterior de 72 quarteirões. O minimapa mostra ruas, parques e a posição do carro; **M / Share** abre o mapa completo, com zoom, marcador e atalhos para carro, praça e oficina. O HUD identifica o bairro atual. Os mapas anteriores continuam disponíveis no menu.

No editor, abra `project.godot` e pressione F5. Pelo terminal:

```sh
godot --path .
```

Nesta máquina, o executável está em `~/Downloads/Apps/Godot_v4.7.2-stable_linux.x86_64`; substitua `godot` pelo caminho correspondente se necessário.

| Ação | Teclado / mouse | DualShock 4 | Gamepad padrão |
| --- | --- | --- | --- |
| Acelerar | W / ↑ | R2 | Gatilho direito |
| Frear / ré | S / ↓ | L2 | Gatilho esquerdo |
| Virar | A/D / ←/→ | Analógico esquerdo | Analógico esquerdo |
| Girar câmera | Mover mouse | Analógico direito | Analógico direito |
| Centralizar câmera suavemente | Parar de mover o mouse | R3 | Clique do analógico direito |
| Freio de mão | Espaço | X / cruz | A |
| Ligar / desligar faróis | L | L1 | Ombro esquerdo |
| Mapa completo (cidade piloto) | M | Share | View / Back |
| Avançar horário em 3 horas (cidade piloto) | F6 | R1 | Ombro direito |
| Olhar para trás | C | Triângulo | Y |
| Câmera externa / capô | V | Quadrado | X |
| Reiniciar | R | Círculo | B |
| Pausar | Esc | Options | Start |
| Confirmar / voltar nos menus | Enter / Esc | X / Círculo | A / B |
| Diagnósticos / captura | F3 / F4 | — | — |

Mouse e analógico direito permitem olhar ao redor tanto na câmera externa quanto no capô. Após **1,2 segundo sem movimento**, a câmera volta suavemente ao acompanhamento automático; R3 inicia o retorno imediatamente. Há limite vertical para evitar colocar a câmera sob o carro. Olhar atrás permanece uma troca direta. O cursor é capturado ao dirigir e liberado ao pausar, voltar ao menu ou perder o foco da janela.

Frear continuamente para engatar ré após parar. Pedais aceitam intensidade analógica, com zona morta de 3%; direção usa 12% e câmera 18% para reduzir drift dos analógicos. Na pausa: áudio, gráficos, reset, mapas e menu. Preferências em `user://wave-settings.cfg` são mantidas ao reiniciar. O HUD reconhece conexão/desconexão do controle e atualiza as instruções. [Validação de câmera e DualShock](docs/development-results/2026-10-09/camera-gamepad/README.md).

## Cidade piloto

A cidade piloto reúne **430 trechos de rua e 200 quarteirões** em **7.569.408 m²**. O terreno tem quatro vezes a área da etapa anterior, preservada no [registro de 72 quarteirões](docs/development-results/2026-10-09/pilot-day-night/README.md). **Jardins do Vale** combina sobrados, jardins e ruas curvas em colinas. **Vila Aurora** reúne casas menores, prédios residenciais, padarias, mercados e cafés. **Centro Horizonte** usa uma malha mais reta e densa, avenidas largas, um conjunto de parques e torres com fachadas de vidro, tijolo ou pedra, recuos e coroamentos variados. A arquitetura é procedural original, inspirada na composição de Manhattan. As avenidas principais chegam a 24 metros. Um minimapa acompanha o carro e mostra os parques, enquanto o HUD identifica o bairro. As torres permanecem visíveis à distância e algumas janelas acendem à noite. Há **2.023 imóveis, 211 arranha-céus, 3.790 árvores em seis formas, 813 carros estacionados e 48.971 tufos de grama**. A revisão preenche as laterais dos quarteirões, reserva jardins internos e acrescenta **427 conjuntos de bancos/lixeiras**, alguns com abrigos de ônibus. Canteiros floridos, duas colinas adicionais, asfalto com tons por bairro e calçadas com variação de placas enriquecem a cidade existente. **M / Share** abre o mapa completo; arrastar/direcional move a vista, roda/L2/R2 controla zoom, clique/X coloca um marcador e Esc/Círculo retorna. O jogo e o relógio pausam durante a consulta. [Galeria atual](docs/art-results/2026-10-10/city-detail/index.html). Gramíneas, flores, bosques e caminhos preenchem os espaços livres. A [galeria dos três bairros](docs/art-results/2026-10-10/three-districts/index.html) mostra as novas vistas e a condução no pacote. Calçadas de três metros acompanham as curvas e se unem ao redor dos cruzamentos, com rebaixamentos nas entradas. Gramíneas ocupam os espaços livres; bases e muros acompanham o terreno, e os lotes são afastados para evitar sobreposição de casas. As entradas têm pavimento, portões, caixas de correio e numeração. Guias chanfradas e transições nas entradas suavizam a passagem do carro. O carro foi remodelado como um Gol 1000 quadrado de 1993: pintura branca, teto e tampa traseira corrigidos, grade larga com emblema, faróis retangulares, retrovisores pretos e rodas de aço. A carroceria está 6 cm mais alta, preservando o apoio das rodas e a condução. Faróis com feixes reais e lentes luminosas funcionam em todos os mapas; L ou L1 alterna o estado. Mantém verniz, vidros transmissivos, cabine modelada, lentes e pneus detalhados. A [comparação do Gol 1000](docs/art-results/2026-10-09/gol-1000/README.md) registra o resultado. Asfalto com grãos e desgaste, pedra com juntas, madeira e reboco acrescentam detalhe às superfícies. É uma cena gerada offline, salva em setores e recursos binários comprimidos, com o mesmo carro, câmera e HUD durante todo o passeio. Praça e oficina têm acessos pavimentados. O [plano atualizado](development-plan.md) concentra os próximos passos nesse lugar; a [revisão de árvores e realismo](docs/art-results/2026-10-08/jardins-realismo/README.md) reúne as novas comparações e medições. A [etapa com carroceria curva e materiais](docs/art-results/2026-10-08/jardins-mw2012/README.md) segue a direção visual de Most Wanted 2012. A [revisão das calçadas](docs/art-results/2026-10-08/jardins-do-vale/README.md) registra a etapa anterior. A [primeira versão](docs/development-results/2026-10-08/pilot-city/README.md) permanece como registro histórico.

O horário avança automaticamente: **24 minutos reais por dia completo**, começando às 16h30. Sol e lua percorrem o céu; a transição muda a luz ambiente, a névoa, os reflexos e as cores das nuvens. As estrelas aparecem à noite. Postes e janelas acendem gradualmente, com até oito luzes locais próximas ao carro. Pausar congela o relógio e as nuvens; F6/R1 avança três horas. O ciclo está integrado à cidade piloto; os laboratórios conservam seus ambientes anteriores. [Validação da expansão e do ciclo](docs/development-results/2026-10-09/pilot-day-night/README.md).

A [revisão de densidade de 2026-10-09](docs/art-results/2026-10-09/neighborhood-refresh/README.md) amplia as ruas para **11,5–14 m** e completa as frentes externas: **45 imóveis, 229 árvores volumétricas e 21 carros estacionados**, com telhados/alturas variados, jardins, conjuntos de árvores e massas distantes. O Hatch recebe para-choques arredondados, rodas abertas com discos/pinças, acabamento dos pneus/vidros, placas legíveis e lanternas de freio/ré funcionais. Céu original com nuvens alimenta os reflexos. [Comparação interativa antes/depois](docs/art-results/2026-10-09/neighborhood-refresh/compare.html). Equilibrado mostra sombras, mapas normais e reflexão local; Econômico conserva os modelos, texturas e céu. A densidade acrescentada ainda requer medição de desempenho na janela combinada.

## Laboratórios anteriores

No menu, **Viajar pelo Caminho da Serra** abre uma prova contínua: trecho urbano reutilizado da Avenida do Vale → 400 m rural → 400 m de rodovia com curvas suaves → 400 m de núcleo provisório do interior. Mesmo carro, câmera, céu e sessão; quatro células no manifesto e até três residentes. Aproximadamente 1,38 km entre os endpoints do teste. Não são duas cidades completas: piso plano, casas/árvores reaproveitadas e arte provisória. Bairro do Sol inteiro, relevo de serra, tráfego e atividades novos ainda não estão integrados.

A Vila da Serra recebeu [uma primeira revisão de autoria](docs/art-results/2026-10-07/vila-da-serra/README.md): calçadas, lotes variados, cruzamento e praça com abrigo/bancos. Quem chega encontra a praça à esquerda, depois do cruzamento; a entrada e a rua lateral são dirigíveis. Builds locais Linux/Windows atualizados; aprovação artística e custo gráfico desta revisão continuam pendentes.

O percurso também recebeu [placas e paradas mais legíveis](docs/art-results/2026-10-07/transicoes/README.md): parada rural à esquerda, refúgio rodoviário à direita com acesso pavimentado, cobertura e vagas, e orientação até a vila/praça e na volta ao Bairro do Sol. Árvores agrupadas substituem as filas regulares no campo/rodovia. Builds atualizados e acessos testados; avaliação humana em movimento continua pendente.

A [revisão de orientação de 2026-10-08](docs/art-results/2026-10-08/orientacao-das-paradas/README.md) acrescenta setas e avisos de entrada nos dois sentidos para a parada rural, o refúgio e a praça. Os painéis ficaram maiores; na volta, o aviso do Bairro do Sol foi afastado para deixar o refúgio visível. Builds Linux/Windows atualizados e acessos validados no pacote exportado; legibilidade em movimento continua pendente.

A [revisão com a câmera real durante a viagem](docs/art-results/2026-10-08/acessos-em-movimento/README.md) acrescenta limites e setas pintados nas três entradas e faz os pisos rural/rodoviário acompanharem a curva. As comparações usam condução por inputs com alvo de 80 km/h; entradas/saídas foram conferidas separadamente no projeto e no pacote exportado. Builds atualizados; avaliação humana de leitura, frenagem e manobra permanece pendente.

A [revisão das frentes das paradas](docs/art-results/2026-10-08/frentes-das-paradas/README.md) organiza a parada rural e o refúgio com balizadores laterais, limites pintados e quatro vagas em cada pátio; o refúgio também ganha piso distinto junto ao abrigo. Uma nova fixture freia a partir de 80 km/h, entra, para e volta à faixa na parada rural, no refúgio e na praça, nos dois sentidos: 19 checks, também aprovados no PCK. Builds Linux/Windows atualizados; avaliação humana de leitura e manobra continua pendente.

**Experimentar relevo da serra**, no menu, abre uma pista separada de 800 m: subida/descida de 18 m, quatro células e até três residentes. O loader reutiliza o ciclo existente e verifica colisão real sob o carro. [Prévias, testes e limites](docs/development-results/2026-10-07/elevation/README.md). É uma prova de apoio em altura com visual simples; a serra ainda não está integrada à viagem. O teste de ida/volta usa aproximadamente 65 km/h; avaliação humana e alta velocidade nesse relevo continuam pendentes.

A pista agora tem [curvas, acostamentos e balizadores](docs/development-results/2026-10-07/elevation-curves/README.md), além de asfalto com textura reaproveitada. A condução automatizada a 65 km/h e pelos dois acostamentos passa; a fixture de 108 km/h conserva apoio, mas sai da faixa e ainda não está aprovada. Builds locais atualizadas; avaliação humana continua pendente.

O laboratório recebeu também [paisagem e Mirante da Serra](docs/development-results/2026-10-07/serra-landscape/README.md): morros no horizonte, vegetação em grupos, chão texturizado e uma parada perto da crista. Na ida, procure a placa e entre à direita na área ampla ao lado do abrigo. Entrada/saída são dirigíveis; a pista continua separada do Caminho da Serra.

Ao abrir a pista, o HUD inicia o [Passeio ao Mirante](docs/development-results/2026-10-07/lookout-trip/README.md): siga a estrada, entre à direita e pare nas vagas marcadas por dois segundos. Segure Espaço para manter o freio de mão. A chegada aparece no HUD; R repete o passeio. Você pode continuar explorando depois de chegar. O progresso vale para a sessão atual.

A cena está em [drive_intercity.tscn](scenes/world/drive_intercity.tscn). Os builds locais Linux/Windows foram atualizados e o pacote passou 13 checks de acesso/apoio, incluindo a célula remota do interior; Windows nativo permanece pendente. Também é possível abrir com F5 ou `godot --path .`. [Auditoria, resultados e limitações](docs/reorientation-2026-10-07.md).

## O que existe hoje

Gol 1000 com geometria própria, controlador arcade em `CharacterBody3D`, limite de 220 km/h, aderência/freio de mão, colisões, contato de quatro rodas, degraus e suspensão visual; câmera com SpringArm/FOV e capô. Bairro do Sol gerado offline com ruas/casas/comércio/posto, Circuito do Sol de 3,24 km com checkpoints, rally de 1,52 km com terreno/LOD/poeira e pista técnica. Motor/ambiente/música provisórios sintetizados offline, menus, teclado/gamepad e testes automatizados.

A [primeira revisão de condução de 2026-10-09](docs/development-results/2026-10-09/arcade-handling/README.md) acrescenta entrada de curva gradual, recuperação de aderência sob aceleração, dissipação de derrapagem e transferência visual de peso. Após avaliação jogada, a [revisão seguinte](docs/development-results/2026-10-09/mw2012-acceleration/README.md) reduz o ganho de velocidade sob acelerador em cerca de 60%: 0–100 km/h em 8,0 s, antes 3,2 s, mantendo 220 km/h alcançáveis. Most Wanted 2012 passa a ser a referência de condução e arte; a equivalência de sensação permanece sujeita a avaliação jogada.

A **Avenida do Vale** acrescenta 600 m de avenida, duas ruas laterais, casas/sobrados, oficina, mercado, postes/fios, árvores em impostores, asfalto remendado e horizonte de fim de tarde. É gerada offline, com seed 5547, materiais simples e o mesmo carro.

Os mapas anteriores são laboratórios funcionais preservados. O rally possui um perfil experimental de pneus por eixo; ele não define a física do mundo aberto. Há uma prova de streaming com três células da Avenida do Vale, disponível em **Avenida do Vale · streaming**, preservando a versão estática. Ainda não há streaming integrado aos mapas antigos, tráfego, cidades definitivas ou vertical slice artístico aprovado. O bairro ainda carrega inteiro, embora use lotes espaciais para culling. Arte, timbre/mixagem e sensação exigem avaliação jogada.

## Gráficos e meta mínima

**Requisitos de produto:** Inspiron 5547/Haswell e 8 GB; Econômico na HD 4400 com 854×480 inicial e ≥30 FPS sustentados, Equilibrado na R7 M260 com 1280×720 inicial e ≥30 FPS sustentados. Qualidade para hardware moderno. A validação final desses perfis permanece aberta; a máquina medida tem 16 GB, não comprova o limite de 8 GB. Aprovação na Radeon não substitui o requisito econômico.

| Preset | Configuração inicial |
| --- | --- |
| Econômico (`economy`) | 854×480 ajustável, sem sombras/MSAA/efeitos caros |
| Equilibrado (`medium`) | 1280×720 ajustável, sombras e MSAA 2× |
| Qualidade (`high`) | 1920×1080, sombras/MSAA e cosméticos opcionais |
| Legacy (`legacy`, adicional) | 1280×720 sem sombras/MSAA, preservado para benchmarks e preferências anteriores |

Os IDs e preferências existentes permanecem compatíveis; o padrão sem preferências ainda é Legacy. Cada perfil precisa de rota gráfica própria e validação longa, conforme [performance.md](docs/performance.md).

Todos os presets funcionam em Compatibility e não trocam backend. Sombras e pós-processamento têm controles separados. HIGH não ativa SSIL/volumetria automaticamente. A opção desses cosméticos do rally só está disponível quando o processo foi iniciado em Forward+; nenhuma parte essencial do novo visual deverá depender dela. Tela cheia usa tamanho do monitor, registrado no benchmark. Preferências antigas de resolução/sombras/MSAA continuam válidas.

F4 registra até 180 s de condução: CSV amostrado, CSV por quadro e JSON com configuração, CPU/GPU, renderer, tamanho real, média, P95/P99, 1% low aproximado, picos e monitores de custo. Tempo CPU/GPU de viewport é opt-in em diagnóstico separado (`--profile-render-time`), pois as queries causaram stalls neste driver Intel. Pausa é excluída; alterar gráficos/trocar de mapa encerra a captura. Headless recusa FPS gráfico. Reprodução e limitações em [performance.md](docs/performance.md).

## Validar

O [preenchimento e mapa completo de 2026-10-10](docs/development-results/2026-10-10/city-detail/README.md) têm cobertura consolidada de **812 verificações Godot e dez testes Python**, com **193 verificações no pacote final**. A regeneração confere malhas, colocações e colisões; os seis circuitos mantêm apoio e asfalto. As [prévias atuais](docs/art-results/2026-10-10/city-detail/index.html) e a [comparação](docs/art-results/2026-10-10/city-detail/compare.html) permitem revisar o preenchimento. Linux e Windows foram atualizados; FPS sustentados e avaliação jogada continuam pendentes.

A [expansão de 2026-10-09](docs/development-results/2026-10-09/pilot-expansion/README.md) passou 739 verificações Godot e 10 testes Python no projeto, com retomada após isolar a entrada do controle físico na fixture da serra, e 316 verificações no pacote exportado. Linux e Windows estão atualizados; o Linux nativo iniciou corretamente. [Comparação do bairro ampliado](docs/art-results/2026-10-09/pilot-expansion/compare.html). Esta etapa valida geometria, acessos e comportamento; desempenho renderizado continua pendente para a janela combinada.

```sh
GODOT_BIN=~/Downloads/Apps/Godot_v4.7.2-stable_linux.x86_64 bash scripts/tools/check_project.sh
```

A revisão de árvores/realismo passou **202 verificações direcionadas**: cidade 32, travessias de calçada 56, direção 33, navegação 33, menu 29 e captura/configurações gráficas 19. A regeneração confere também as árvores instanciadas e seus LODs. O pacote exportado passou 103 verificações do bairro/guias/menu; o menu passou novamente com renderização real. Ambos os builds foram atualizados. A etapa de carroceria e materiais repetiu 103 verificações no pacote final, com 34,7 FPS na Intel/Econômico e 50,3 na Radeon/Equilibrado em diagnósticos curtos; a Intel ainda apresenta quedas abaixo de 30. [Etapa atual](docs/art-results/2026-10-08/jardins-mw2012/README.md). [Comparações, logs, custo visual e limites](docs/art-results/2026-10-08/jardins-realismo/README.md).

A validação da primeira versão da cidade aprovou **635 verificações de comportamento e dez testes Python**, retomando o runner após atualizar a seleção do mapa na fixture de streaming. O runner também verifica os laboratórios anteriores, áudio, configurações, física e ferramentas de pacing em diretórios temporários. Os testes usam cenas reais e inputs; não substituem benchmark renderizado, gamepad conectado, escuta ou avaliação humana de diversão.

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

A passagem por calçadas e mudanças de inclinação recebeu uma [correção no controlador](docs/development-results/2026-10-07/ground-navigation/README.md), com testes de guias em frente/ré/diagonal, em baixa velocidade e a 64,8 km/h, além das calçadas reais da avenida. A revisão seguinte [corrige o acesso ao Rally da Serra e verifica os oito mapas](docs/development-results/2026-10-07/rally-ground-access/README.md), incluindo bordas de asfalto/cascalho, acostamentos, rampas e calçadas.

## Pipeline offline e builds

Editar geradores, gerar → validar → salvar → carregar. O jogo não executa geração procedural pesada. O gerador da cidade piloto salva terreno, ruas, calçadas, lotes e colisões. Comandos:

```sh
godot --headless --path . --script res://scripts/tools/build_pilot_city.gd
python3 scripts/tools/build_corridor_signs.py
python3 scripts/tools/build_intercity_signs.py
godot --headless --path . --editor --quit
godot --headless --path . --script res://scripts/tools/build_corridor.gd
godot --headless --path . --script res://scripts/tools/build_corridor_cells.gd
godot --headless --path . --script res://scripts/tools/build_intercity.gd
godot --headless --path . --script res://scripts/tools/build_neighborhood.gd
godot --headless --path . --script res://scripts/tools/build_hatch_car.gd
godot --headless --path . --script res://scripts/tools/build_elevation.gd
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

Para validar entradas/saídas do rally e transições de chão nos outros sete mapas usando apenas os recursos do pacote:

```sh
GODOT_BIN=~/Downloads/Apps/Godot_v4.7.2-stable_linux.x86_64 bash scripts/tools/check_exported_access.sh
```

A [retomada da revisão de acesso](docs/development-results/2026-10-07/rally-ground-access/README.md) passou os 140 checks no PCK. A [revisão das frentes das paradas](docs/art-results/2026-10-08/frentes-das-paradas/README.md) amplia o runner para **174 checks funcionais**, incluindo 15 de acesso às paradas e 19 de aproximação/manobra, mais a guarda que exige recursos exportados. O runner usa fixtures externas e preferências isoladas; aceita outro PCK como primeiro argumento. Windows nativo e sensação de condução ainda exigem avaliação própria.

Templates locais em `tools/godot/export_templates` também são aceitos. Distribuir a pasta completa da plataforma, incluindo `Wave.pck`. Os launchers `Wave-quality` agora iniciam HIGH em Compatibility. Os builds locais Linux/Windows foram reexportados com a revisão das frentes das paradas; o PCK passou 174 verificações funcionais de acesso/manobra e 13 do menu/apoio remoto; Windows nativo continua pendente; a sessão longa documentada abaixo reprovou pacing.

## Plano e decisões

[Plano vigente](development-plan.md) · [Revisão arquitetural](docs/architecture.md) · [Contrato de streaming](docs/world-streaming.md) · [Direção de arte](docs/art-direction.md) · [Orçamento](docs/performance-budget.md) · [Medições](docs/performance.md) · [Histórico arquivado](docs/history.md).

A variante de células preserva silhuetas distantes com HLOD offline e troca visual com histerese. Oficina e mercado receberam uma primeira revisão de placas, acessos, pintura e desgaste com materiais existentes, preservando as colisões. [Comparações e custo medido](docs/performance-results/2026-10-06/hero-areas/README.md). A primeira otimização de entrada reduziu a média fria de 5,70 para 4,89 s na Radeon (**14,17%**), em três pares com fontes idênticas; [evidência](docs/performance-results/2026-10-06/startup-material/README.md). As duas capturas prolongadas novas preservaram apoio, mas tiveram picos; pacing/térmica continuam pendentes. Prioridade atual: continuar autoria localizada do percurso e avaliar a Vila da Serra. O diagnóstico dos picos permanece preliminar por uso concorrente da máquina; retomar medições e otimização numa janela combinada de uso exclusivo. Expansão, trânsito e atividades vêm depois dos gates de qualidade e pacing.

Prévia atual: [Mercado do Vale — Legacy 720p](docs/performance-results/2026-10-06/hero-areas/after-views/corridor-2.png). Fachadas e árvore originais via image_gen: [prompts e origem](assets/textures/corridor/provenance.json).

A prova de células tem [contrato e limites](docs/world-streaming.md), guard de apoio e telemetria de carga/ativação/liberação. O [diagnóstico de entrada/memória](docs/performance-results/2026-10-06/streaming-diagnostics/README.md) compara cache novo/reutilizado e doze travessias com/sem captura: contagens estáveis e RSS desacelerando, sem certificar sessões longas ou 8 GB. Ela usa piso plano; o fallback de atraso segura a condução e não deve ocorrer nas travessias normais.

HLOD da avenida: [comparações visuais, benchmarks e limites](docs/performance-results/2026-10-06/hlod/README.md). O custo adicional da entrada fria recebeu uma primeira redução por compartilhamento de variante de material, mas permanece pendente; continuidade distante e menor desenho durante a rota também foram medidos.

O menu inclui limite persistente de 30/60/120 FPS ou sem limite. A sessão automatizada com foco contínuo completou 44 pernas em dez minutos, mas teve 71 quadros >50 ms e lacunas na rotação dos arquivos de captura; estabilidade longa permanece pendente. [Telemetria, resultados e próximos ajustes](docs/performance-results/2026-10-06/pacing-thermal/README.md).

O [diagnóstico seguinte na Intel](docs/performance-results/2026-10-07/intercity-pacing/README.md) reproduziu o pico de retorno em seis sessões com/sem captura e isolou a troca para detalhe urbano como gatilho: mudar a distância apenas na fixture deslocou a travada 60 m. A correção do custo de desenho e os gates de estabilidade continuam pendentes. Runner reproduzível: `scripts/tools/benchmark_intercity_pacing.sh`.

A reorientação de 2026-10-07 usa marcos W0–W6 e acrescenta a fixture `tests/intercity_smoke.gd` ao runner. Medição gráfica da prova, com pastas de preferências isoladas e sem testes simultâneos:

```sh
DRI_PRIME=0 XDG_DATA_HOME=/tmp/wave-sol-serra-new godot --path . --rendering-method gl_compatibility --script res://tests/intercity_smoke.gd -- --foreground --no-vsync --previews
# Radeon / Equilibrado: DRI_PRIME=1, outra pasta XDG, acrescentar --balanced.
```

`--no-vsync` é condição explícita do ensaio, não mudança global do produto. Prévias e teleporte de sondagem ficam fora das capturas. Próximas prioridades: avaliar o bairro ampliado em movimento e concentrar a próxima etapa em carro, iluminação e acabamento gráfico. Pacing e medição por perfil ficam pendentes para uma janela combinada de uso exclusivo. [Plano vigente](development-plan.md).
