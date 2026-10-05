# Desempenho

## Referência

- Godot 4.7.2, renderer Compatibility; 1280 × 720 como referência visual e modo econômico para GPU integrada.
- GPU de referência: Intel Haswell integrada detectada no notebook.
- Meta: manter pelo menos 30 FPS durante a condução, buscando 45–60 FPS quando possível.

## Física e otimização — 2026-10-05

O mapa conserva árvores, posições, troncos/galhos próximos, sombras, grama, texturas e todos os segmentos da estrada. Mudanças: mipmaps/compressão de GPU nas 19 texturas 3D, normal maps importadas adequadamente, cartões de árvores recortados na geometria pela silhueta alfa, malhas visuais do terreno com LOD e pista dividida em 24 trechos de até 32 amostras. Colisores mantêm todos os triângulos originais e o atrito de cada piso. O recorte troca dois triângulos por até 24 no cartão, para reduzir pixels transparentes processados nos passes de cor/sombra. A quantidade de triângulos isoladamente não descreve esse ganho.

Comparação principal: Linux/Mesa 25.0.7, AMD R7 M260, Forward+, **1600×900, VSync, MSAA 2×, sombras, SSAO, SSIL, glow e névoa volumétrica**. Pose fixa na amostra 215, idêntica em ambas as cenas, carro alinhado ao terreno e física congelada. Cinco segundos de aquecimento e 30 segundos por amostra, sem outro teste ou renderizador concorrente. O driver remove eventos físicos do teclado/gamepad para impedir interferência no aquecimento; a medição usa relógio monotônico. Baseline extraída de `a5ec4f9`, com o mesmo driver de benchmark e esquema de configurações.

| Métrica na mesma vista | Antes | Depois |
| --- | --- | --- |
| FPS médio real | 6,63 | 9,98 |
| Mediana do intervalo | 151,66 ms | 100,57 ms |
| P95 | 152,38 ms | 101,20 ms |
| Maior intervalo | 160,47 ms | 107,77 ms |
| Renderização média GPU do viewport | 145,93 ms | 94,87 ms |
| Submissão média CPU do viewport | 0,75 ms | 0,74 ms |

**50,6% de ganho de FPS** e **35,0% menos tempo GPU** nesta vista, mantendo resolução e efeitos. O perfil máximo continua lento nessa GPU; não atingiu 30 FPS. A CPU do viewport não inclui toda a física. As capturas anteriores exploratórias desta revisão foram excluídas: uma teve controles físicos no aquecimento e enquadramento diferente; outra ocorreu antes de todas as mudanças. Os números históricos de 2026-10-04 não constituem a base desta comparação.

O novo preset **equilibrado** mantém 1280×720, sombras e MSAA, com SSAO quando suportado. SSIL/névoa volumétrica ficam disponíveis no botão de efeitos cinematográficos; o preset de qualidade máxima os liga. O renderer comum permanece Compatibility.

| Perfil final | Teste | FPS médio | P95 | Maior intervalo |
| --- | --- | --- | --- | --- |
| Equilibrado, Forward+, 1280×720 | Vista fixa, 30 s | 25,63 | 39,63 ms | 49,08 ms |
| Equilibrado, Compatibility, 1280×720 | Percurso com inputs normais, 30 s | 39,20 | 28,66 ms | 33,58 ms |

O percurso avançou até a amostra 336, com afastamento máximo de 1,17 m e apoio em 100% das observações. Essas duas linhas usam perfis/rotas diferentes da referência máxima: **não são uma comparação antes/depois de 6,63 para 39,20 FPS**. São amostras curtas nesta GPU; não garantem a mesma fluidez em todos os mapas, vistas ou computadores. As imagens correspondentes foram inspecionadas: sombras, floresta e detalhes próximos permanecem; mipmaps reduzem o ruído visual à distância.

Dados brutos: [antes](performance-results/2026-10-05/static-before-full.json), [depois](performance-results/2026-10-05/static-after-full.json), [equilibrado Forward+](performance-results/2026-10-05/static-balanced-forward.json), [percurso Compatibility](performance-results/2026-10-05/driving-balanced-compat.json) e [condições](performance-results/2026-10-05/run-details.json), com CSVs ao lado. Prévias locais em `builds/previews/static-before-full.png`, `static-after-full.png` e `driving-balanced-compat.png`.

A física agora usa **4 consultas de rodas por tick em vez de até 32**, reutiliza objetos de consulta/colisão e separa amostragem de apoio dos subpassos de pneus. A subida de calçadas verifica espaço sobre o carro e apoio além do meio-fio, inclusive em baixa velocidade. O limite atravessável é 26 cm; testes usam 24 cm e mantêm barreiras de 1 m bloqueadas. Freios respeitam o atrito do piso, inclusive quando os dois pedais são acionados; o freio de mão equilibra a gravidade perto de zero. O motor aplica perdas sob aceleração e corta torque acima do limite sem frear abruptamente o movimento de descida.

O rally completo passou com apoio em 100% das amostras (9.110 ticks, 60 Hz). A suíte de condução reproduziu 13 falhas em 24 verificações na versão anterior — calçadas, arrancada em subida, freios e freio de mão — e passou após as correções. Logs do runner e da regressão estão na pasta de dados. A suíte ampliada também verifica tração e freio em piso de baixa aderência. Os testes sem interface **não medem FPS gráfico** nem substituem avaliação da sensação de direção.

Reprodução da versão final, sem testes concorrentes e com configurações temporárias:

```sh
XDG_DATA_HOME=/tmp/wave-opt-full godot --path . --rendering-method forward_plus --script res://tests/rally_rendered.gd -- --static
XDG_DATA_HOME=/tmp/wave-opt-balanced godot --path . --rendering-method forward_plus --script res://tests/rally_rendered.gd -- --static --balanced
XDG_DATA_HOME=/tmp/wave-opt-drive godot --path . --rendering-method gl_compatibility --script res://tests/rally_rendered.gd -- --balanced
```

Referências de implementação: [Godot: LOD de malhas](https://docs.godotengine.org/en/stable/classes/class_importermesh.html), [limites de visibilidade](https://docs.godotengine.org/en/stable/tutorials/3d/visibility_ranges.html) e [CharacterBody3D](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html).

## Estado de 2026-10-04

| Dado do Bairro do Sol | Valor |
| --- | --- |
| Lotes MultiMesh por setor | 2.540 |
| Instâncias de primitivas no mapa | 21.514 |
| Triângulos das primitivas | 321.824 |
| Formas de colisão estáticas | 2128 |
| Luzes dinâmicas | 1 direcional |
| FPS com renderização | Medido na AMD R7 M260 e Intel HD Graphics 4400; veja abaixo |

Esses números foram extraídos da cena pela Godot. A contagem de triângulos exclui texto, carro e passes de sombras. A quantidade de lotes não é uma medição de draw calls: fontes, carro e sombras acrescentam trabalho. Os testes sem interface validam comportamento e carregamento; os FPS desse modo não representam o desempenho gráfico.

## Rota para comparar versões

1. Execute o projeto com F5 em 1280 × 720 e aguarde dez segundos.
2. Aperte F3 para mostrar FPS, tempo médio por quadro derivado dos FPS e draw calls.
3. Siga pela via central até o cruzamento diante das casas ao norte.
4. Vire à direita e complete uma volta no circuito externo.
5. Volte à via central e entre no estacionamento do posto.
6. Registre o menor FPS observado, FPS típico, draw calls, renderer, GPU em uso e alterações de qualidade. Faça a mesma rota após mudanças relevantes.

Ao observar quedas, use o profiler da Godot para distinguir custo de renderização e física. O teste deve ser feito sem pausa e com a janela do jogo visível.

## Captura por F4

Após dez segundos de aquecimento, pressione F4, percorra a rota e pressione F4 novamente. O jogo salva um CSV de FPS/draw calls a cada meio segundo e um resumo JSON em `user://performance`. O resumo inclui média de FPS, mediana e percentil 95 dos intervalos de quadros, maior intervalo, GPU, renderer, tamanho real da janela e preferências gráficas. Desde a revisão de otimização, os intervalos usam relógio real monotônico e excluem as pausas; não são tempos exclusivos da GPU. Capturas históricas usam delta da engine, sujeito a suavização e limites em quadros lentos. O percentil 95 descreve os quadros mais lentos da amostra.

A pausa suspende a coleta; mudar gráficos ou trocar de mapa encerra e salva a captura, preservando a configuração registrada. O limite por captura é 180 segundos. O modo sem interface recusa a coleta gráfica.

## Rota automatizada

`tests/rendered_route.gd` abre o menu, inicia o bairro, aguarda dez segundos e dirige pela via central, pelo circuito externo e até o estacionamento do posto. O alvo é 12 m/s nas retas e 6 m/s nas curvas. Salva a captura e screenshots no diretório de usuário e encerra. Todos os cinco pontos devem ser alcançados; o limite de percurso é 90 segundos. É uma medição repetível com controles automatizados, sem avaliação da sensação de dirigir.

```sh
# GPU escolhida normalmente pela Godot (AMD dedicada neste notebook)
XDG_DATA_HOME=/tmp/wave-reference godot --path . --script res://tests/rendered_route.gd

# Intel integrada, perfil econômico
DRI_PRIME=0 XDG_DATA_HOME=/tmp/wave-reference-intel godot --path . --script res://tests/rendered_route.gd -- --economy
```

Argumentos opcionais: `--no-shadows`, `--low-resolution` (960×540), `--economy` (854×480 sem sombras) e `--check-display` (exercita tela cheia e verifica a restauração da resolução antes de medir). Não use `--headless` nem `--fixed-fps` nesta rota. Use pastas distintas para separar os resultados.

## Medições com janela em 2026-10-04

Linux, Mesa 25.0.7, Compatibility e VSync ativado. Cada perfil realizou uma passagem completa pelos cinco pontos, após aquecimento. Dados brutos em [performance-results/2026-10-04](performance-results/2026-10-04). O menor FPS é o menor valor amostrado a cada meio segundo; picos de um único quadro são apresentados separadamente no JSON.

| GPU | Janela real | Sombras | FPS médio | Menor FPS amostrado | P95 de quadro |
| --- | --- | --- | --- | --- | --- |
| AMD R7 M260 | 1280×720 | Sim | 52,0 | 45 | 27,7 ms |
| Intel HD 4400 | 1280×720 | Sim | 12,9 | 11 | 131,9 ms |
| Intel HD 4400 | 1280×683 | Não | 22,0 | 1 | 71,6 ms |
| Intel HD 4400 | 960×540 | Não | 31,8 | 27 | 40,6 ms |
| Intel HD 4400 — econômico | 854×480 | Não | 35,5 | 32 | 36,3 ms |
| Intel HD 4400 — Maré 68, econômico | 854×480 | Não | 34,1 | 30 | 38,5 ms |

A execução de 1280×683 foi solicitada como 1280×720, mas a restauração da janela após tela cheia reduziu sua altura; o valor real está no resumo. Foi acrescentada uma reaplicação da resolução após a restauração assíncrona pelo gerenciador de janelas. Essa amostra também contém um mínimo de 1 FPS, preservado no CSV; não deve ser tratado como comportamento típico.

Sombras e resolução têm impacto concreto na Intel. A configuração com sombras em 720p não atende à meta; 960×540 sem sombras ainda apresenta quedas abaixo de 30 FPS. O modo econômico manteve as amostras de FPS entre 32 e 39 na passagem final, com média de 35,5 FPS, janela confirmada em 854×480 e restauração após tela cheia verificada. Houve quadros isolados mais lentos (máximo de 90,9 ms); a meta não implica ausência de qualquer oscilação. Esse perfil oferece um compromisso mais leve, sem alterar as preferências já salvas. Essas passagens curtas não substituem uma sessão jogada de dez minutos ou garantem FPS em outras máquinas.

As cinco primeiras linhas usam o carro provisório. Com o novo Maré 68 (5.348 triângulos), a passagem completa repetida sem exportações simultâneas registrou 34,1 FPS médios, mínimo amostrado de 30 e máximo de 87,9 ms em um quadro. Dados em `intel-mare68-economy.csv/json`. Uma tentativa anterior durante a etapa de exportação não completou a rota automatizada e não foi usada como referência do percurso completo. O novo carro permanece dentro da meta amostrada nesta execução, com pouca margem na Intel; novas etapas de física e mapa precisam repetir a medição.

## Hatch, terreno e mapas ampliados

O mapa atual tem 504 × 504 m de ruas e 536 × 536 m de piso. Os lotes são divididos em setores de 84 m; as ruas também foram divididas em trechos. O Hatch 1000 tem 5.288 triângulos. A física faz quatro consultas de apoio por amostragem e projeta o movimento no plano do piso.

Linux, Intel HD Graphics 4400, Compatibility, 854×480, VSync ligado e sombras desligadas:

| Percurso | Duração | FPS médio | Menor FPS amostrado | P95 | Maior intervalo |
| --- | --- | --- | --- | --- | --- |
| Bairro ampliado: 5/5 pontos da rota original | 39.5 s | 39.8 | 30 | 37.8 ms | 59.0 ms |
| Autódromo: uma volta completa com 16 checkpoints | 104.9 s | 48.1 | 9 | 33.3 ms | 140.4 ms |

Dados: `intel-hatch-expanded-economy.csv/json` e `intel-hatch-race-economy.csv/json` em `performance-results/2026-10-04`. A rota do bairro preserva o percurso original para comparação; ela não percorre todo o mapa ampliado. As vias externas foram validadas quanto a condução e colisão em testes separados, sem usar FPS headless como medida gráfica. A volta do autódromo foi dirigida pelo controlador normal, a 12 m/s, com afastamento máximo de 1,72 m do eixo da pista. As médias superam 30 FPS, mas as amostras e os quadros isolados mais lentos mostram que não há garantia de 30 FPS em todos os momentos. Uma sessão jogada mais longa segue necessária.

Para repetir a volta renderizada, execute sem `--headless` e sem `--fixed-fps`:

```sh
DRI_PRIME=0 XDG_DATA_HOME=/tmp/wave-reference-race godot --path . --script res://tests/race_smoke.gd
```

Esse teste aplica o modo econômico em sua pasta temporária, aquece por cinco segundos e grava a volta em CSV/JSON, junto de `race-lap.png`. Também verifica cronometragem e transições após a captura.

## Mapa com cinco vezes a área e condução a 220 km/h

O piso passou de 536 × 536 m para 1.198,53 × 1.198,53 m (área multiplicada por cinco); as ruas ocupam 1.126,98 × 1.126,98 m. Há 30 vias, incluindo avenidas externas de 24 m. Os lotes têm origens locais por setor e props distantes têm limites de visibilidade. Referência da API: [GeometryInstance3D](https://docs.godotengine.org/en/stable/classes/class_geometryinstance3d.html#class-geometryinstance3d-property-visibility-range-end).

`tests/high_speed_smoke.gd` acelera o carro real até 220 km/h na avenida externa, confere a velocidade pelo deslocamento, testa coast e frenagem e verifica colisão com uma barreira fina. Em modo renderizado, aplica o perfil econômico na pasta temporária, aquece por cinco segundos e captura aceleração/coast/frenagem. Os exercícios posteriores de direção e aderência não entram nessa medição.

| GPU | Janela | Sombras | Duração | FPS médio | Menor FPS amostrado | P95 | Maior intervalo |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Intel HD 4400 | 854×480 | Não | 15.9 s | 33.9 | 31 | 40.3 ms | 144.6 ms |

Dados em `intel-220-five-area-economy.csv/json`. É uma passagem de alta velocidade pela região externa; não equivale à rota urbana anterior ou a uma sessão longa. As médias não garantem 30 FPS em todos os momentos. Screenshot em `builds/previews/car-220.png`.

```sh
DRI_PRIME=0 XDG_DATA_HOME=/tmp/wave-reference-220 godot --path . --script res://tests/high_speed_smoke.gd
```

## Circuito de 3,24 km com materiais texturizados

Intel HD Graphics 4400, Compatibility, VSync ligado, sem sombras e sem MSAA. A consulta de distância do cronômetro usa uma grade de setores de 64 m; o comprimento mostrado no HUD é calculado uma vez. O controle automatizado usa alvo de 16 m/s nesta versão renderizada.

| Janela real | Percurso capturado | Duração | FPS médio | Mínimo amostrado | P95 | Maior intervalo |
| --- | --- | --- | --- | --- | --- | --- |
| 1920×1011 | Primeiros 180 s da volta completa | 180,1 s | 21,1 | 1 | 74,8 ms | 150,0 ms |
| 854×480 | Reta principal e entrada do setor industrial | 60,0 s | 51,9 | 26 | 34,7 ms | 69,4 ms |

A primeira execução selecionou o perfil econômico, mas a janela acabou em 1920×1011; o tamanho real foi preservado no JSON. Essa medição não representa desempenho em 854×480. Uma volta completa foi concluída nessa execução com 15 verificações sem falhas e afastamento máximo de 4,17 m do eixo. A captura de F4 se encerrou automaticamente aos 180 s; o teste seguiu até terminar a volta.

A segunda execução reafirma as opções após o aquecimento, impede redimensionamento durante o benchmark e verifica a janela nativa antes de coletar dados. Seus nove checks passaram, com afastamento máximo de 2,58 m; é uma captura de trecho, não de uma volta inteira. Ela supera a meta em média, mas o mínimo de 26 FPS mostra que ainda há quedas abaixo de 30. Resolução, rota e velocidade diferem das medições históricas; as médias não devem ser comparadas como se fossem o mesmo percurso.

Dados: `intel-race-realism-large-window.csv/json` e `intel-race-realism-economy.csv/json`. Prévias em `builds/previews/circuit-driving.png`, `circuit-industrial.png`, `circuit-forest.png`, `circuit-overview.png` e `race-realism-economy.png`.

```sh
# Trecho de 60 segundos, com janela de 854×480 conferida.
DRI_PRIME=0 XDG_DATA_HOME=/tmp/wave-reference-realism godot --path . --script res://tests/race_smoke.gd -- --benchmark-only

# Volta completa; a captura automática permanece limitada a 180 segundos.
DRI_PRIME=0 XDG_DATA_HOME=/tmp/wave-reference-realism-full godot --path . --script res://tests/race_smoke.gd
```

O modo econômico agora reaplica as configurações mesmo quando os valores já coincidem, para restaurar uma janela que tenha sido redimensionada. As preferências salvas do jogador permanecem em sua própria pasta; os testes usam diretórios temporários.


## Rally da Serra — prioridade gráfica

Etapa de 1.516 m com relevo real, materiais de cascalho/pedra, floresta em planos recortados, tufos de grama, sombras e poeira. A escolha do usuário nesta revisão foi priorizar qualidade visual mesmo exigindo outra GPU. O backend comum permanece Compatibility; o launcher `Wave-quality` usa Forward+ e o perfil de 1600×900, MSAA 2× e sombras. No rally, Forward+ acrescenta SSIL e névoa volumétrica; oclusão ambiente e tratamento de exposição também são usados no perfil com sombras.

Captura renderizada **após corrigir a saída em subida**, na AMD R7 M260 via RADV, janela conferida e fixa de 1600×900, VSync habilitado, 5 s de aquecimento e 30,07 s de captura. Autopiloto por inputs comuns, limite de 8 m/s para conferir contato em cascalho. O percurso avançou da amostra 215 à 332 (aproximadamente 230 m), afastamento máximo amostrado de 1,12 m, apoio no piso em 99,6% das observações.

| Métrica | Resultado |
| --- | --- |
| FPS médio por quadros / duração | 7,52 |
| Quadros capturados | 226 |
| Mediana do intervalo | 133,01 ms |
| Percentil 95 | 144,44 ms |
| Maior intervalo | 150,00 ms |

Dados: [CSV](performance-results/2026-10-04/amd-rally-quality-forward-1600.csv) e [JSON](performance-results/2026-10-04/amd-rally-quality-forward-1600.json). A R7 M260 é insuficiente para condução fluida nesse perfil. Esta medição confirma o custo na máquina disponível, sem estimar FPS em GPU moderna. Não se compara diretamente às rotas anteriores do bairro/circuito ou à Intel em 854×480.

Antes da correção de arrancada, houve capturas exploratórias de 7,52 FPS em Forward+ e 10,76 em Compatibility, ambas em 1600×900. O recuo mínimo reiniciava a espera da ré e o carro ficou parado por boa parte dessas capturas; elas não validam direção e não foram usadas como referência da rota corrigida. Os dados temporários ficaram em `/tmp/wave-rally-quality-benchmark` e `/tmp/wave-rally-benchmark-compat`.

Repetir a rota curta, preservando preferências do jogador:

```sh
XDG_DATA_HOME=/tmp/wave-rally-benchmark godot --path . --rendering-method forward_plus --script res://tests/rally_rendered.gd
```

O script exige janela real e verifica tamanho, avanço, afastamento e contato. O teste sem interface de rally cobre o percurso completo e não mede FPS de GPU. Nenhuma medição desta revisão foi feita no Windows nativo.


## Realismo e otimização — comparação com relógio real

Mantidos **1600×900, Forward+, MSAA 2×, sombras, SSAO, SSIL, névoa volumétrica e VSync**, na mesma AMD R7 M260. A floresta conserva quantidade e posições. A revisão substitui três planos por árvore distante por um plano orientado para a câmera sem sombras, acrescenta troncos/galhos 3D próximos e reduz o trabalho da grama com fade por distância. Terreno usa uma projeção de textura; o cascalho ganha marcas de pneus e transição de acostamento, e as pedras ganham forma irregular compartilhada.

A correção do medidor é parte desta revisão. O delta da engine pode ser limitado pelo número máximo de passos de física, ocultando quadros realmente mais lentos. Todas as comparações **abaixo** usam `Time.get_ticks_usec()`, com `time_source=monotonic_wall_clock`. Os 7,52 FPS históricos do rally foram medidos pelo método anterior; não constituem a base deste ganho.

O mapa anterior foi extraído do commit `f90141a`. O mesmo runtime, controlador, roteiro e efeitos carregaram o mapa anterior e o novo, sem testes de CPU ou outra janela Godot concorrendo com as capturas aceitas.

### Vista fixa correspondente — comparação principal

Carro parado na mesma amostra 215, posição final aproximadamente (129,606; 26,731; −165,029), com câmera e contato assentados. Cerca de 30 s de captura por versão. Essa comparação mantém o enquadramento e evita que FPS mais baixo altere o setor da pista percorrido.

| Métrica | Antes | Depois |
| --- | --- | --- |
| FPS médio real | 5,71 | 10,09 |
| Mediana de intervalo | 169,89 ms | 99,51 ms |
| Percentil 95 | 172,06 ms | 101,88 ms |
| Maior intervalo | 763,11 ms | 116,46 ms |
| Renderização média GPU do viewport | 164,92 ms | 94,42 ms |
| Submissão média CPU do viewport | 0,89 ms | 0,86 ms |

**76,7% de ganho no FPS médio** nesta vista; custo médio GPU do viewport caiu cerca de 42,7%. O maior intervalo do teste anterior é um pico isolado, portanto não deve ser usado como redução típica. Tempo de CPU do viewport não inclui todo o processamento da física ou do jogo. A medição continua baixa para direção fluida: não representa atingir 30 FPS nem prevê resultado em GPU moderna.

Dados: [antes JSON](performance-results/2026-10-04/rally-optimization/static-before.json), [antes CSV](performance-results/2026-10-04/rally-optimization/static-before.csv), [depois JSON](performance-results/2026-10-04/rally-optimization/static-after.json), [depois CSV](performance-results/2026-10-04/rally-optimization/static-after.csv). Logs ao lado dos dados incluem os tempos de CPU/GPU medidos pelo viewport.

### Percurso com controles reais — conferência adicional

30 s de captura real, início na amostra 215, alvo de 8 m/s. Antes: 5,89 FPS e chegada à amostra 308; depois: 10,05 FPS e chegada à 332, afastamento máximo de 1,19 m, apoio no piso em 99,7% das observações. O intervalo real preservado torna visível o efeito da limitação dos passos de física: a versão mais lenta percorre menos distância. Por isso essa rota confirma condução e ganho em movimento, mas a vista fixa é a comparação principal de custo visual.

Dados em `rally-optimization/driving-before.*` e `driving-after.*`. A primeira tentativa de setores de 48 m para toda a vegetação elevou as chamadas de desenho e piorou a média para 5,03 FPS numa execução concorrente com testes; foi descartada como comparação aceita. A versão final usa 84 m para árvores e 48 m apenas para grama, preservando descarte próximo sem multiplicar lotes distantes.

Reprodução, com diretórios de usuário isolados e sem outra medição gráfica simultânea:

```sh
git show f90141a:scenes/rally/rally_map.tscn > /tmp/wave-opt-before-map.tscn
XDG_DATA_HOME=/tmp/wave-before godot --path . --rendering-method forward_plus --script res://tests/rally_rendered.gd -- --baseline-map --static
XDG_DATA_HOME=/tmp/wave-after godot --path . --rendering-method forward_plus --script res://tests/rally_rendered.gd -- --static
```

A memória/carga da máquina e variações do driver podem mudar os valores; comparar uma mesma vista é mais informativo que extrapolar essa única dupla de capturas para todo o mapa. As capturas são do editor/runtime Linux, não de Windows nativo.
