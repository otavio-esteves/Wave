# Wave

Protótipo de um jogo de direção livre com atmosfera de fim de tarde. O projeto usa Godot 4.7.2, GDScript e o renderer Compatibility.

## Abrir

Abra `project.godot` no editor Godot, pressione **F5** e selecione **Dirigir no bairro**, **Circuito de corrida** ou **Pista técnica** no menu inicial para passear pelo **Bairro do Sol**. Também é possível iniciar pela raiz do projeto:

```sh
godot --path .
```

Se o executável tiver outro nome, substitua `godot` pelo caminho correspondente. Para verificar importação e scripts sem interface:

```sh
godot --headless --path . --editor --quit
```

Neste notebook, o executável está em `~/Downloads/Apps/Godot_v4.7.2-stable_linux.x86_64`. Ele pode permanecer fora do repositório.

## Controles do protótipo

| Ação | Teclado | Gamepad |
| --- | --- | --- |
| Acelerar | W ou ↑ | Gatilho direito |
| Frear / ré | S ou ↓ | Gatilho esquerdo |
| Virar | A/D ou ←/→ | Analógico esquerdo |
| Freio de mão | Espaço | Botão A |
| Olhar para trás | C | Botão Y |
| Reiniciar carro | R | Botão B |
| Pausar | Esc | Start |
| Mostrar / ocultar FPS | F3 | — |
| Iniciar / salvar medição de desempenho | F4 | — |

Segure o freio para parar; mantendo-o pressionado, o carro entra em ré após uma pequena pausa. Os gatilhos controlam a intensidade da aceleração, preservando o limite de velocidade. O freio de mão permite uma derrapagem em curvas. No menu de pausa é possível continuar, reiniciar o carro, trocar de mapa, ajustar áudio/gráficos, voltar ao menu inicial ou sair.

## Protótipo atual

- **Hatch 1000**, inspirado na aparência do Gol 1000 quadrado: duas portas, pintura branca, para-choques pretos, faróis retangulares e rodas de aço.
- Velocidade máxima de **220 km/h**, aceleração, frenagem, ré, aderência lateral e freio de mão. Carroceria e colisor seguem a inclinação do piso usando quatro contatos de rodas; suspensão visual tem curso limitado.
- Meios-fios baixos atravessáveis, com verificação de espaço acima e de apoio no destino. Barreiras e edifícios mantêm colisão.
- Câmera acompanha a direção com horizonte estável, proteção contra paredes, FOV por velocidade e visão traseira.
- Bairro com cinco vezes a área anterior: 1.127 × 1.127 m de ruas, piso de 1.199 × 1.199 m e 30 vias conectadas, casas, comércio, praça, posto e estacionamento. Geometria repetida dividida em setores para descarte fora da visão.
- **Circuito do Sol:** mapa dedicado de 1.200 × 1.060 m, volta fechada de 3.241 m, pista de 17 m, reta principal de aproximadamente 700 m, setor industrial e trecho arborizado. Largada/chegada, boxes conectados, arquibancada, zebras, guardrails e 16 checkpoints com última/melhor volta.
- Cronômetro, última volta e melhor volta da sessão. É preciso cruzar 16 checkpoints em ordem e no sentido correto; sair do traçado invalida a volta. R cancela a tentativa atual, preservando a melhor volta da sessão.
- Pista técnica com rampa, obstáculos e barreiras, mais uma área identificada de subida/topo/descida, calçada e inclinação lateral.

O veículo continua com física arcade cinemática em `CharacterBody3D`. O movimento acompanha o plano do terreno e preserva a velocidade de saída de rampas no ar; a gravidade influencia subidas e descidas, e o freio de mão segura o carro parado na ladeira; o contato das rodas controla a orientação e a suspensão visual. Direção e recuperação de aderência têm limites de força; o esterçamento suaviza em alta velocidade. Passos menores de contato/colisão mantêm o deslocamento total correto. Capotamento e transferência física de peso ainda não são simulados.

## Áudio

O motor acompanha aceleração e velocidade, com três faixas de marcha simuladas. Vento, pássaros e uma música instrumental original acompanham o passeio. Os áudios são provisórios, sintetizados para Wave sem samples externos.

Use **Esc → Áudio** para ajustar volume geral, motor, ambiente e música. Zero silencia a categoria. As preferências são salvas em `user://wave-settings.cfg` e permanecem ao trocar de mapa ou reabrir o jogo. A pausa suspende os sons; retome a direção para ouvir o ajuste. Sliders aceitam mouse e teclas direcionais.

## Gráficos

Use **Gráficos** no menu inicial ou na pausa para alterar tela cheia, resolução da janela, VSync e sombras. As preferências compartilham `user://wave-settings.cfg` com o áudio e permanecem após reiniciar. Em tela cheia, a resolução é a do monitor.

**Aplicar modo econômico** seleciona uma janela de 854×480 sem sombras. Esse perfil também é o padrão inicial da Intel HD Graphics 4400 quando não há preferências gráficas salvas. Outras GPUs começam em 1280×720 com sombras; preferências existentes têm prioridade.

F4 inicia e encerra uma captura de até 180 segundos, salvando CSV e resumo JSON em `user://performance`. O resumo registra GPU, renderer, tamanho real da janela e opções usadas. A pausa suspende a captura; alterar gráficos ou sair do mapa encerra e salva a amostra. Medições gráficas são recusadas no modo sem interface.

## Verificação

Execute todas as verificações com diretórios temporários, preservando suas preferências de jogo:

```sh
GODOT_BIN=~/Downloads/Apps/Godot_v4.7.2-stable_linux.x86_64 bash scripts/tools/check_project.sh
```

O teste abaixo executa 33 verificações com controles simulados na cena real, incluindo acelerador parcial, colisões, rampa, câmera e pausa:

```sh
godot --headless --path . --fixed-fps 60 --script res://tests/driving_smoke.gd
```

O teste do bairro acrescenta 26 verificações de percurso nas ruas centrais e nas vias externas ampliadas, acesso ao estacionamento, colisões, reset, troca de cenas, transformações dos pais e preservação da geometria ao salvar e recarregar o mapa:

```sh
godot --headless --path . --fixed-fps 60 --script res://tests/neighborhood_smoke.gd
```

O áudio acrescenta 18 verificações de reprodução, loops, resposta do motor, pausa, menu e volumes, mais duas em um novo processo para conferir persistência. Use um diretório separado para preservar suas preferências de jogo:

```sh
XDG_DATA_HOME=/tmp/wave-audio-check godot --headless --path . --fixed-fps 60 --script res://tests/audio_smoke.gd
XDG_DATA_HOME=/tmp/wave-audio-check godot --headless --path . --script res://tests/audio_smoke.gd -- --verify-persistence
```

Esses testes verificam dados e comportamento; o timbre e a mixagem precisam de avaliação ouvindo no desktop.

Menu e gráficos acrescentam 19 verificações de navegação, foco, transições, modo econômico, aplicação das sombras e validação de valores, mais uma de persistência em outro processo:

```sh
XDG_DATA_HOME=/tmp/wave-menu-check godot --headless --path . --fixed-fps 60 --script res://tests/menu_smoke.gd
XDG_DATA_HOME=/tmp/wave-menu-check godot --headless --path . --script res://tests/menu_smoke.gd -- --verify-persistence
```

Terreno acrescenta 21 verificações de subida, descida em ré, inclinação lateral, suspensão, calçadas, barreiras e movimento no ar. Corrida acrescenta 14, incluindo uma volta completa dirigida pelos controles reais do carro, cronômetro, invalidação de atalhos, reset e troca de mapas.

```sh
godot --headless --path . --fixed-fps 60 --script res://tests/terrain_smoke.gd
godot --headless --path . --fixed-fps 60 --script res://tests/race_smoke.gd
```

Alta velocidade acrescenta 12 verificações: limite padrão, área da cena salva, aceleração até 220 km/h, correspondência entre velocímetro e deslocamento real, coast, frenagem, barreira fina, limite de direção, aderência e reset.

```sh
godot --headless --path . --fixed-fps 60 --script res://tests/high_speed_smoke.gd
```

Total: **146 verificações**. Para medir a rota com controles automatizados e janela real, consulte [desempenho](docs/performance.md).

Para o teste jogado, faça duas voltas no circuito, experimente freio e ré na reta, use o freio de mão em uma curva, atravesse a rampa e confira a pausa. O resultado esperado é dirigir sem travamentos, recuperar aderência ao soltar o freio de mão e voltar à pista com R. Esses testes não substituem a avaliação da sensação de direção ou uma medição de FPS com renderização.

Para chegar a 220 km/h, use as avenidas externas mais largas, em x/z = ±490 m; há mais de 1 km de reta. Freie antes das curvas. No bairro, percorra as vias externas, atravesse as calçadas e entre no posto. No autódromo, cruze a linha no sentido de largada e complete uma volta sem cortar a pista para registrar o tempo. Use F3 para conferir FPS; a [rota de desempenho](docs/performance.md) permite comparar versões.

## Editar o bairro

A cena principal é `scenes/city/drive_neighborhood.tscn`. Ela combina mapa, iluminação, carro, câmera e HUD. A geometria do mapa é gerada antes da execução e salva como uma cena estática; não há geração por frame durante o jogo.

Edite `scripts/city/neighborhood_builder.gd` e regenere o mapa com:

```sh
godot --headless --path . --script res://scripts/tools/build_neighborhood.gd
```

O comando substitui `scenes/city/neighborhood_map.tscn`, portanto altere a geometria no gerador. Depois de salvar, ele recarrega o arquivo e verifica os dados de renderização e sua correspondência com o piso e os edifícios. Ajustes de iluminação e posição inicial ficam na cena principal.

## Editar carro e circuito

As malhas do hatch são geradas offline por `scripts/tools/build_hatch_car.gd`. As texturas do circuito são geradas com a biblioteca padrão de Python, sem downloads. O traçado do circuito está em `scripts/race/circuit_layout.gd`; a geometria é salva por `scripts/tools/build_race_track.gd`.

```sh
godot --headless --path . --script res://scripts/tools/build_hatch_car.gd
python3 scripts/tools/build_race_textures.py
godot --headless --path . --editor --quit
godot --headless --path . --script res://scripts/tools/build_race_track.gd
# Prévia com janela real:
godot --path . --script res://scripts/tools/build_car_preview.gd
```

Imagens de avaliação ficam em `builds/previews/`. As ferramentas de modelagem não são executadas durante o jogo.

## Estado

Hatch inspirado no Gol 1000, revisão de física, calçadas atravessáveis, bairro ampliado e autódromo implementados. As 149 verificações passaram em execuções separadas das suítes; a intermitência observada em alguns asserts antigos do runner está registrada no plano. Na Intel, a captura de 60 s do novo circuito em 854×480, sem sombras ou MSAA, registrou 51,9 FPS médios e mínimo amostrado de 26. A volta completa também foi validada com renderização; condições e limites estão em [desempenho](docs/performance.md). Os pontos e critérios de avaliação estão no [plano](development-plan.md). A aceleração foi reduzida em 20% (12 → 9,6 m/s² de torque inicial), mantendo os 220 km/h. O novo circuito começa a evolução visual rumo à referência Most Wanted 2005: texturas originais com normal maps, fachadas, vegetação recortada e luz diurna quente. A equivalência visual ainda não foi atingida; aparência e sensação de direção aguardam avaliação jogada.

## Builds Linux e Windows

Presets versionados em `export_presets.cfg`. Com templates Godot 4.7.2 instalados no editor, exporte ambos com:

```sh
GODOT_BIN=~/Downloads/Apps/Godot_v4.7.2-stable_linux.x86_64 bash scripts/tools/export_builds.sh
```

O script também aceita os templates locais em `tools/godot/export_templates/4.7.2.stable`, extraídos nesta máquina do pacote oficial. Essa pasta é ignorada pelo Git; em outro checkout, instale os templates pelo editor. Os builds ficam em `builds/linux` e `builds/windows`, também ignorados pelo Git.

Execute `builds/linux/Wave.x86_64` no Linux ou `builds/windows/Wave.exe` no Windows. Distribua a pasta completa de cada plataforma, incluindo `Wave.pck`. A inicialização foi verificada no Linux e pelo Wine; Wine não substitui uma avaliação nativa no Windows.

Para conferir a arte do circuito, gere vistas da largada, setor industrial, trecho arborizado e mapa completo:

```sh
godot --path . --script res://scripts/tools/build_race_previews.gd
```

Em **Gráficos**, “Suavizar contornos” ativa MSAA 2×. O modo econômico usa 854×480, sem sombras ou MSAA. As texturas desta etapa estão no circuito; o bairro preserva seus materiais anteriores.
