# Desempenho

## Política vigente — baseline Compatibility / M0

Referência: Inspiron 5547/Haswell, **8 GB como alvo**, HD 4400, **1280×720 e 30 FPS estáveis**, com R7 M26x como perfil superior. A direção atual é Most Wanted 2005 como referência perceptiva brasileira. Resultados antigos de rally/Forward+ e 480p abaixo são **histórico**, não requisitos de produção nem comprovação da meta. Os arquivos brutos foram preservados.

A primeira etapa concreta da redefinição centraliza Legacy (720p sem sombras/MSAA/efeitos), Medium (720p sombras/MSAA) e High (1080p sem SSIL/volumetria automáticos). O fallback de 480p permanece para reproduzir o econômico antigo. Presets não trocam renderer; o launcher de qualidade usa Compatibility. [Orçamento e gates](performance-budget.md) orientam a próxima iteração.

### Captura schema 2

F4 continua iniciando/encerrando até 180 s de condução, excluindo pausa. Ao mudar gráficos ou mundo, a captura termina antes de alterar os valores. Arquivos em `user://performance`:

- `.csv`: FPS amostrado, draw calls, objetos/primitivas desenhados, tempo geral de processo/física, memória estática/render allocations e CPU/GPU do viewport quando habilitados em ensaio diagnóstico, a cada aproximadamente 0,5 s.
- `-frames.csv`: **todos** os intervalos em ordem cronológica, pelo relógio monotônico, para identificar hitches e fronteiras. O custo de gravar ocorre depois da captura, não a cada quadro.
- `.json`: snapshot de engine/OS/CPU/GPU/vendor/driver/renderer, tamanho real de janela/viewport, opções/preset, debug/release, rota e aquecimento quando informados pelo driver; média real, mediana, P95/P99, pior quadro, mínimo instantâneo, contagem >33,33/>50 ms e mínimos/médias/picos dos monitores amostrados.

`one_percent_low_fps = 1000 / média dos ceil(1%) intervalos mais lentos`. O JSON registra o método; não confundir com 1000/P99. FPS mínimo amostrado e mínimo instantâneo são métricas diferentes. Média real usa quadros/duração, não média das leituras do Engine. A medição CPU/GPU de viewport é **opt-in** (`--profile-render-time` nas fixtures), feita em ensaio separado: timestamp queries causaram intervalos de cerca de 1 s e valores inválidos na HD 4400 nesta revisão. Capturas normais deixam esses campos `null`. A captura problemática foi rejeitada, e os dados foram preservados como diagnóstico. Valores não finitos ou maiores que toda a janela máxima de captura são inválidos. GPU/CPU de viewport são tempos de renderização/submissão, não custo total do jogo. Memória é da Godot/render allocations, não RSS/VRAM total. Monitores indisponíveis viram `null`/campo vazio em CSV, não “custo zero”. Atribuição de gameplay, RAM total e streaming depende de profiler/medidores externos. [Monitores oficiais](https://docs.godotengine.org/en/4.7/classes/class_performance.html).

### Reprodução e rotas

O runner `GODOT_BIN=... bash scripts/tools/benchmark_reference.sh /tmp/wave-reference-new all` executa as seis fixtures Legacy sequencialmente em pastas novas, salva commit/status/diff, hashes de scripts/testes/cenas/recursos compartilhados/manifestos/shaders/texturas e imports (incluindo código não rastreado), identificação da máquina e RAM instalada. `urban|residential|vegetation|speed|corridor|streaming` seleciona uma única fixture. `startup` executa entrada fria e reentrada com as mesmas raízes XDG isoladas, salvando os dois JSON/logs; é a única rota que reutiliza caches deliberadamente. `DRI_PRIME` pode selecionar a GPU no Mesa; confira o nome real no JSON. Capturas/logs completos ficam em subpastas por rota.

Uma janela Godot por vez, sem runner/export simultâneo, sem `--headless`/`--fixed-fps`, pastas de usuário separadas. Guardar commit (`git rev-parse HEAD`), diff quando houver, driver/GPU confirmados no log, hardware/RAM real, estado térmico, tamanho real, duração/aquecimento, rota/seed e log de conclusão junto aos arquivos. As rotas removem eventos físicos dos controles da condução para evitar contaminação e verificam resolução depois do aquecimento.

```sh
# Centro urbano atual: cinco pontos, alvo de 12 m/s em retas e 6 nas curvas, warmup 10 s.
DRI_PRIME=0 XDG_DATA_HOME=/tmp/wave-m0-urban godot --path . --rendering-method gl_compatibility --script res://tests/rendered_route.gd -- --legacy
# Residencial: anel de ruas, novo percurso identificado; não comparar sua média à do centro.
DRI_PRIME=0 XDG_DATA_HOME=/tmp/wave-m0-residential godot --path . --rendering-method gl_compatibility --script res://tests/rendered_route.gd -- --legacy --residential
# Vegetação: fixture de rally, início na amostra 215, alvo 8 m/s, warmup 5 s e 30 s capturados.
DRI_PRIME=0 XDG_DATA_HOME=/tmp/wave-m0-vegetation godot --path . --rendering-method gl_compatibility --script res://tests/rally_rendered.gd -- --legacy
# Vista fixa para investigar custo visual; não representa condução.
DRI_PRIME=0 XDG_DATA_HOME=/tmp/wave-m0-vegetation-static godot --path . --rendering-method gl_compatibility --script res://tests/rally_rendered.gd -- --legacy --static
# Alta velocidade: aceleração/coast/frenagem até 220 km/h; avenida externa como proxy.
DRI_PRIME=0 XDG_DATA_HOME=/tmp/wave-m0-speed godot --path . --rendering-method gl_compatibility --script res://tests/high_speed_smoke.gd -- --legacy
```

No driver urbano, sem `--legacy`, o perfil é Medium; `--economy`, `--no-shadows`, `--no-aa`, `--low-resolution`, `--high` e `--check-display` permitem experiências explícitas. O novo anel residencial tem limite de 150 s; a rota histórica continua com limite de 90 s. A captura registra configuração efetiva e origem da rota. Rodovia real e tráfego não existem: seus benchmarks de produção são gates de M5/M7; não rotular mapas vazios como tráfego medido.

As capturas históricas do rally usavam qualidade de 900p. Para reproduzir esse conjunto após a revisão, acrescentar `--historical-quality` ao driver do rally. O perfil Medium atual desliga SSAO/glow; para o antigo equilibrado, usar `--historical-balanced`. Para repetir os tempos de viewport desses ensaios históricos na AMD, acrescentar também `--profile-render-time`; não fazer isso na Intel sem avaliar o custo da instrumentação. Use as preferências do JSON histórico para conferir qualquer reprodução, em vez de assumir que “quality” continuará significando o mesmo para sempre.

### Oficina e mercado — revisão próxima de 2026-10-06

Gerador v2 acrescenta pavimento, pintura, frisos e desgaste opaco localizado, reaproveitando materiais. **318 checks antes/depois**, mesmos 851 colisores, cenas estática/células regeneradas. [Vistas comparáveis, fontes e dados brutos](performance-results/2026-10-06/hero-areas/README.md).

R7 M260/Inspiron/16 GB/Linux, Compatibility Legacy720p, sem VSync, queries de viewport ou testes concorrentes; 10 s de aquecimento e caches isolados. Três passagens anteriores e três posteriores da mesma rota a 120 km/h/HLOD ativo, com todos os quadros focados:

| Caso | FPS médio | 1% low | P99 ms | Pior ms | >33,33 / >50 ms | Draw calls médios | Entrada ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| before-1 | 202.48 | 34.28 | 22.907 | 51.130 | 8 / 1 | 223.36 | 7413.1 |
| before-2 | 240.64 | 94.44 | 9.714 | 14.146 | 0 / 0 | 224.17 | 5390.4 |
| before-3 | 240.89 | 94.47 | 9.820 | 14.152 | 0 / 0 | 224.15 | 5414.0 |
| after-1 | 228.96 | 85.60 | 10.877 | 14.846 | 0 / 0 | 226.00 | 5601.7 |
| after-2 | 227.11 | 82.47 | 10.873 | 17.623 | 0 / 0 | 226.28 | 5840.6 |
| after-3 | 230.01 | 88.39 | 10.509 | 13.946 | 0 / 0 | 226.19 | 5909.8 |

A primeira passagem anterior teve picos e foi preservada. As três posteriores não tiveram quadros acima de 33,33 ms, bloqueios durante a condução ou perda de apoio. Custo de desenho subiu cerca de duas chamadas médias; FPS e 1% low ficaram abaixo das duas passagens anteriores mais estáveis. O ganho é artístico com custo aceitável no ensaio Radeon, sem reivindicar otimização de FPS ou causalidade para a variação anterior. Entrada fria posterior de 5,6–5,9 s continua aberta, fora da captura aquecida. HD 4400, 8 GB, Windows, Medium e sessões longas não foram certificados nesta etapa.

Adicionalmente, três idas/voltas com alvo de 220 km/h concluíram seis pernas em 84.47 s: 1% low 86.87, P99 10.705 ms, pior 20.796 ms, zero quadros >33,33/>50 ms, zero bloqueios durante condução, apoio contínuo e todos os quadros focados. Reversão por teleporte nos extremos; não equivale a manobra humana. Dados em `hero-areas/after-speed`.

### Validação da redefinição de 2026-10-05

Baseline automatizado antes das alterações: **225 verificações passaram**, em Godot 4.7.2, log preservado em `performance-results/2026-10-05/m0-compatibility`. Erros de socket do editor headless no sandbox estão no log, separados das verificações de comportamento. Testes gráficos não usam seus FPS.

O equipamento efetivamente disponível é Inspiron 5547, i7-4510U, HD 4400/R7 M260, **16 GB instalados**, Linux/Mesa 25.0.7. Isso não valida residência sob 8 GB. O runner completo final passou em **245 verificações**, incluindo resize da captura, proteção contra queries automáticas de viewport, arquivos de frame time e compatibilidade das preferências antigas. Logs antes/depois estão junto aos dados; uma execução intermediária de 243 checks e a suíte isolada de 16 também foram preservadas. M0 não certifica o vertical slice, a sensação de jogo nem a estabilidade térmica de uma sessão longa.

### Diretriz de avanço — Radeon também pode liberar o roadmap

Por orientação do projeto, desempenho jogável na Radeon R7 M26x do Inspiron em Compatibility/720p permite prosseguir com o vertical slice e a infraestrutura, sem esperar a aprovação da HD 4400. A integrada permanece alvo de otimização. O gate de pacing continua o mesmo, aplicado a cada GPU separadamente: vista fixa e média alta não substituem condução, repetições e sessão longa. O alvo de 8 GB e a avaliação humana permanecem pendentes.

### Radeon em condução — investigação após mudança de diretriz

Primeira passagem das quatro fixtures na R7 M260, Legacy/Compatibility/1280×720, VSync ligado, sem queries de viewport. Todas concluíram seus checks de condução; nenhuma passou o gate de pacing. Mesma máquina de 16 GB e driver já registrados, sem testes/exportação concorrentes. O foco não era instrumentado nesta passagem; uma consulta X11 durante a execução mostrou outra janela ativa. Havia outros aplicativos abertos, cuja carga não foi controlada. Alimentação AC ligada, leitura pontual de GPU em ~63 °C e clocks variáveis; essas observações não atribuem a causa da lentidão.

| Fixture | Média FPS | 1% low | P95 ms | P99 ms | Pior ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| Centro | 9,39 | 1,00 | 132,75 | 1000,01 | 1004,33 |
| Residencial | 10,64 | 1,29 | 124,07 | 211,64 | 1002,73 |
| Vegetação/condução | 13,00 | 0,98 | 118,51 | 1011,23 | 1036,69 |
| Alta velocidade | 17,07 | 1,54 | 104,16 | 258,21 | 1015,62 |

[Dados desta investigação](performance-results/2026-10-05/amd-advance/). Não comparar diretamente com a vista estática Medium de 53 FPS como ganho/perda de conteúdo: câmeras, condução e condições de sessão diferem. Investigar ambiente, apresentação/VSync e custo de desenho antes de decidir uma substituição arquitetural. A nova captura registra `window_focus` (contagem dos intervalos com/sem foco, sem filtrá-los). Foco é um sinal de contexto, não medidor de oclusão/custo GPU. Fixtures aceitam `--foreground` (solicita foco antes da captura) e `--no-vsync` (experimento separado, sem mudar presets do produto). O runner encaminha flags e registra argumentos/snapshot Linux de alimentação/clocks/temperatura; snapshot não mede térmica durante toda a rota. [API de foco da Godot](https://docs.godotengine.org/en/4.7/classes/class_window.html#class-window-method-has-focus).

```sh
GODOT_BIN=~/Downloads/Apps/Godot_v4.7.2-stable_linux.x86_64 DRI_PRIME=1 bash scripts/tools/benchmark_reference.sh /tmp/wave-amd-focused urban --foreground
GODOT_BIN=~/Downloads/Apps/Godot_v4.7.2-stable_linux.x86_64 DRI_PRIME=1 bash scripts/tools/benchmark_reference.sh /tmp/wave-amd-no-vsync urban --foreground --no-vsync
```

Repetição do centro com `--foreground`: 59,45 FPS médios, 1% low 29,20, P95 17,93 ms, P99 24,24 ms, pior 52,30 ms, **2258/2258 intervalos com foco**. A passagem seguinte com VSync desligado e foco confirmado: 206,79 FPS médios, 1% low 94,15, P99 9,82 ms, pior 14,38 ms, **7841/7841 intervalos com foco**. Porém uma nova passagem com VSync ligado e foco confirmado voltou a ~13 FPS: **foco sozinho não explica a variação**. São evidências de margem na GPU e de uma condição de apresentação/ambiente a investigar, não comprovação da causa no compositor/driver. Não trocar presets globalmente por esses ensaios; VSync continua uma opção persistida do usuário. Dados `urban-foreground.*` e `urban-no-vsync.*` na mesma pasta.

A extração seguinte da API offline passou no runner completo com **257 verificações** (246 antes da extração). Bairro, circuito e rally foram regenerados em `user://` e comparados com os arquivos preservados: hierarquia, transforms, geometria, colisões, bounds, materiais básicos e visibilidade equivalentes nos três. Logs `checks-before-assembly.log` e `checks-after-assembly.log`; 11 checks novos exercitam artefatos, isolamento e finalização idempotente. Nenhuma cena de produção foi alterada.

Repetição do conjunto completo com `--foreground --no-vsync`, Compatibility/Legacy/720p, sem queries de viewport:

| Fixture | Média FPS | 1% low | P95 ms | P99 ms | Pior ms | Quadros >50 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Centro | 155,80 | 39,43 | 11,93 | 18,59 | 58,15 | 3 |
| Residencial | 161,35 | 60,61 | 10,07 | 13,32 | 38,25 | 0 |
| Vegetação/condução | 132,16 | 35,43 | 13,51 | 17,79 | 62,11 | 3 |
| Alta velocidade v1, com screenshot | 171,42 | 43,10 | 9,74 | 12,92 | 250,66 | 1 |

Dados `*-no-vsync-repeat.*`. Foco pode ser perdido durante a rota: os intervalos foram mantidos, e as contagens estão nos JSON. Nenhum limite de FPS imposto, então médias acima de 60 **não são metas nem promessa para arte final**; validam margem neste conteúdo provisório. As três primeiras fixtures passaram os limites P95/P99/1% low desta passagem; hitches raros >50 ms permanecem visíveis. VSync ligado continuou variável e não aprovou o conjunto (`*-focused-repeat.*`), mesmo sem perder foco. A condição sem VSync permite avançar pela Radeon, mantendo avaliação jogada, repetições/térmica, 8 GB e vertical slice como gates futuros. VSync não foi desativado globalmente; verificar a opção no menu desta máquina/driver. A diferença entre as condições sugere apresentação/sessão como gargalo relevante, mas não identifica definitivamente o componente responsável.

**Correção da fixture de velocidade:** a v1 salva `car-220.png` antes de terminar a captura; readback GPU + encoding/gravação PNG são trabalho da ferramenta dentro da série. O pico de 250,66 ms não foi removido do arquivo. A v2 torna isso opt-in com `--screenshot-at-speed` e registra `screenshot_during_capture`; a captura normal não tira screenshot. Não usar o diagnóstico com screenshot para aprovar pacing do conteúdo. Repetição v2 é registrada separadamente, sem substituir os dados v1.

Alta velocidade **v2 sem screenshot**, mesmo Legacy/Compatibility/720p sem VSync: **222,51 FPS médios, 1% low 98,72, P95 7,46 ms, P99 9,15 ms, pior 16,62 ms, zero quadros >50 ms**. Todos os 4762 intervalos com foco; 14 checks renderizados e 13 headless passaram. Isso reforça que a screenshot contaminava a v1, embora a variação de sessão também impeça atribuir toda a diferença a uma única causa. Dados `speed-v2-no-vsync.*` e contexto próprio. O runner completo de 257 passou antes dessa correção pontual, seguida da suíte de velocidade em headless e com janela. Os CSV por quadro foram auditados contra contagem/duração/estatísticas dos JSON.

### Avenida do Vale — corredor visual de 600 m

Rota `avenue-do-vale-v1`, seed 5547, carro original com máximo de 220 km/h e alvo de 120 km/h por controles reais. Avenida atravessada por completo, incluindo duas interseções; cerca de 605 m em 21,1 s por passagem, após 10 s de aquecimento. Inspiron 5547/i7-4510U, **R7 M260**, 16 GB, Linux/Mesa 25.0.7, Compatibility/Legacy/**1280×720**, VSync desligado explicitamente, sem queries de viewport, screenshots ou testes/export concorrentes. Todas as passagens mantiveram foco e concluíram a rota com apoio no piso.

A primeira versão, com placas `Label3D`, teve **um pico de 283,55 / 284,18 / 304,04 ms nas três passagens**, aproximadamente 2,8 s após o começo, quando a placa da oficina entrava no alcance. As séries completas foram rejeitadas para pacing e preservadas em [rejected-first-use-signs](performance-results/2026-10-05/corridor/rejected-first-use-signs/), incluindo código/cena da versão. Nenhum quadro foi removido.

Substituição localizada: quatro placas rasterizadas offline em atlas opaco, usando quads e o mesmo caminho de material das fachadas. Nenhum outro conteúdo, controlador, limite de velocidade, preset ou rota mudou entre essas três capturas e as seguintes. Isso evita o custo de primeira exibição do caminho de texto 3D neste corredor; não determina isoladamente se o stall vinha de compilação, fonte ou outro trabalho interno. Não extrapolar para remover texto dos mapas antigos.

| Passagem AMD, placas offline | Média FPS | 1% low | P95 ms | P99 ms | Pior ms | Quadros >50 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 206,35 | 79,24 | 7,16 | 10,01 | 18,22 | 0 |
| 2 | 210,24 | 88,32 | 6,83 | 8,63 | 20,40 | 0 |
| 3 | 204,52 | 76,25 | 7,17 | 10,39 | 19,82 | 0 |

**As três rotas curtas passam o gate numérico de pacing na AMD** nessa condição. Nenhum intervalo excedeu 33,33 ms. FPS sem limite é margem, não meta para o visual final. Isso permite seguir pela diretriz Radeon; não certifica dez minutos jogados/térmica, VSync ligado, Medium, Windows nativo, 8 GB ou a HD 4400 neste novo trecho. Também não aprova a meta artística de Most Wanted. O teste automático mantém inputs e câmera controlados, não avalia diversão.

[Dados, logs e contexto completos](performance-results/2026-10-05/corridor/): `amd-r1..r3.json/csv`, `amd-r1..r3-frames.csv`, contextos e `asset-snapshot.json`. Os contextos dessas capturas guardam hashes de código/cena; o snapshot adicional registra PNGs/imports/shaders/geradores usados. O runner agora inclui esses recursos nos hashes automaticamente. As prévias finais são capturadas **em execução separada**, sem medir readback/encoding PNG como custo do jogo.

Validação automatizada antes/depois do corredor: **257 → 271 verificações**, sem falhas; logs na mesma pasta. Os três mapas anteriores regeneram de forma equivalente. O atlas de placas foi comparado com duas execuções determinísticas do gerador, e contagem/duração/pior intervalo dos CSV por quadro foram auditados contra os três JSON.

Monitores amostrados do primeiro ensaio corrigido: **109–329 draw calls**, 424–644 objetos renderizados, 15.754–28.866 primitivas, física média 2,62 ms/máximo 3,97 ms; allocator Godot ~53,7 MB e render allocations ~24,0 MB. São envelopes observados nessa rota, **não tetos aprovados** para o mundo ou RAM/VRAM totais. CPU geral de processo não isola gameplay; tempos exclusivos GPU não foram consultados. Profiler por método e novos ensaios permanecem necessários antes de atribuir gargalos futuros.

Reproduzir, com uma pasta nova por passagem:

```sh
GODOT_BIN=~/Downloads/Apps/Godot_v4.7.2-stable_linux.x86_64 DRI_PRIME=1 bash scripts/tools/benchmark_reference.sh /tmp/wave-corridor-new corridor --foreground --no-vsync
```

### Prova de streaming — três células da avenida

`vale-streaming-v1`: variante com arquivos independentes, horizonte persistente, preload/histerese e liberação real de nós/recursos. Mesma Avenida do Vale original; partição preserva props, colisores e landmarks, recortando superfícies nas fronteiras −200/−400 m. Materiais/primitivas comuns externos. O cenário estático permanece para comparação, sem conversão dos mapas anteriores.

**Inspiron 5547/i7-4510U/R7 M260, 16 GB**, Linux/Mesa 25.0.7; Compatibility/Legacy/1280×720, VSync desligado, 10 s de aquecimento, sem queries de viewport ou screenshots durante captura. GPU confirmada e todos os intervalos com foco. Sem testes/export ou outra Godot concorrente. As quatro medições abaixo têm hashes de código/conteúdo iguais. O alvo de 120/220 km/h é controle por inputs com aceleração desde parado, não velocidade constante durante toda a rota.

| Ensaio | Duração s | Média FPS | 1% low | P95 ms | P99 ms | Pior ms | Quadros >50 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Ida 120, r1 | 23,88 | 209,76 | 80,03 | 6,78 | 9,36 | 21,83 | 0 |
| Ida 120, r2 | 21,06 | 207,22 | 80,84 | 6,82 | 9,27 | 24,97 | 0 |
| Ida 120, r3 | 23,90 | 206,21 | 88,10 | 6,94 | 9,04 | 18,55 | 0 |
| Três idas/voltas, alvo 220 | 84,49 | 208,75 | 82,98 | 6,88 | 9,23 | 22,12 | 0 |

**Todas passam o gate numérico de pacing nessas condições.** Seis pernas atingiram ~219 km/h, com apoio contínuo e **zero bloqueios de segurança durante a condução**. A virada no extremo usa reset/heading no mesmo ponto, explicitamente registrada, para separar travessia de controle de U-turn; a captura inclui essas viradas. Não é sessão humana jogada nem seis viagens entre cidades. Nenhum intervalo passou de 33,33 ms. Não extrapolar médias acima de 200 FPS para arte final, VSync, Windows, Intel ou outro preset.

Residência: uma célula no spawn parado, até três no centro, duas no outro extremo; seis liberações no ensaio de três ciclos. Carro/câmera/HUD/áudio mantêm identidade. Um job solicitado/pronto e uma ativação **ou** liberação por quadro. Nos jobs **durante as quatro capturas**: latência até pronto **116,67–139,11 ms**, instanciação **3,38–6,11 ms**, anexação **0,74–1,64 ms**, liberação síncrona CPU **4,09–5,38 ms**. Latência inclui leitura/desserialização/espera de polling, não I/O puro. Upload/compilação podem ocorrer em outros momentos do quadro; não foram medidos como tempo exclusivo GPU. Eventos com posição/frame/tick e marcadores `capture_start/end` ficam nos relatórios de streaming.

**Entrada fria permanece aberta:** o primeiro apoio leva **4,67–4,99 s** desde o ready do streamer até liberar movimento. Há longos intervalos de primeira apresentação fora do trecho aquecido; não atribuir tudo a I/O (a espera até recurso é de ordem de 0,13 s). Logs completos preservam essa fase. Durante a viagem normal não houve espera, mas essa medição não aprova o custo de entrar no mundo pela primeira vez. Investigação de upload/shaders e preparação de entrada ainda necessária.

Memória no ensaio de três ciclos: RSS Linux **403,2 → 410,0 MB** (~6,8 MB de crescimento em 84,5 s). Endpoints de retorno: 408,5 / 409,4 / 410,0 MB. Captura, caches/allocator e driver podem contribuir; **não há evidência suficiente de convergência ou atribuição a vazamento**. Repetir ensaio mais longo com captura desligada e profiler antes de ampliar regiões. Leituras de RSS em endpoints levaram 0,19–0,23 ms e ficaram registradas. Allocator Godot amostrado 49,5–54,4 MB; render allocations 23,9–24,1 MB, distintos de RSS/VRAM total. Até 348 draw calls/663 objetos/28.654 primitivas, física amostrada média 1,53 ms/máximo 3,99 ms nessa rota; são envelopes, não budgets universais.

[Dados brutos, eventos, RSS, logs e contexto](performance-results/2026-10-05/streaming/). CSV por quadro auditados por contagem/duração/pior intervalo; nenhum frame filtrado. Primeira medição diagnóstica ficou em `/tmp/wave-streaming-amd-r1`; não é uma das três referências da tabela. Testes completos: **271 antes → 304 depois**, nenhuma falha ou referência vazada; erros intencionais de recurso ausente e warnings de falha estão identificados no log dos testes de injeção. A falha terminal do loader também é consumida para liberar o job, sem `get` durante `IN_PROGRESS`. Os três mapas anteriores regeneram de forma equivalente.

```sh
# Pasta nova, GPU confirmada no JSON; repetir três vezes em diretórios distintos.
GODOT_BIN=~/Downloads/Apps/Godot_v4.7.2-stable_linux.x86_64 DRI_PRIME=1 bash scripts/tools/benchmark_reference.sh /tmp/wave-streaming-new streaming --foreground --no-vsync
# Três viagens; viradas diagnósticas declaradas, seis pernas por inputs reais.
GODOT_BIN=~/Downloads/Apps/Godot_v4.7.2-stable_linux.x86_64 DRI_PRIME=1 bash scripts/tools/benchmark_reference.sh /tmp/wave-streaming-cycles-new streaming --foreground --no-vsync --speed-220 --round-trip --three-cycles
```

A prova é limitada ao piso plano. HLOD, crescimento/estabilidade de memória, entrada fria, dez minutos jogados/térmica, 8 GB e Windows nativo continuam pendentes. Não marca M1/M3 completos nem autoriza construir cidades agora.

### Diagnóstico de entrada e memória — 2026-10-06

Mesma máquina/Radeon/Mesa, Compatibility/Legacy/720p, foco solicitado, VSync desligado, sem queries de viewport e sem testes/exportação simultâneos. A fixture agora registra intervalos da entrada antes da troca de cena até liberar movimento, e RSS/allocator/render allocations/recursos/nós/órfãos/buffers nos endpoints. São medições de diagnóstico; nenhuma alteração de física, conteúdo ou streamer foi necessária.

| Entrada | Cache novo | Mesmo cache isolado reutilizado |
| --- | ---: | ---: |
| Comparação inicial | 5,087 s | 0,460 s |
| Comando `startup` final | 5,117 s | 0,622 s |

No comando final, os dois maiores intervalos passaram de **2.040/2.715 ms** para **121/150 ms**; latência até recurso pronto **147,86 → 137,09 ms**, instanciação **9,64 → 10,47 ms**, anexação ~1 ms. RSS depois do aquecimento **402,8 → 251,5 MB** entre esses processos. Os stalls dependem fortemente da primeira utilização/caches gráficos; compilação/upload/preparação do driver são hipóteses, sem atribuição exclusiva a shader ou GPU. Não são cinco segundos de I/O nem um ganho obtido ao reescrever o loader. Cache novo ainda custa ~5 s: tratar preparação/feedback de entrada antes de integrar o slice ao fluxo final. O observador não mede lançamento inteiro do processo.

Memória: **seis idas/voltas a 220 km/h**, doze pernas/~169 s, aquecimento de 10 s, pastas/caches novos, mesma rota com captura ligada/desligada. Ambas passaram, zero bloqueios nas pernas, residentes até três, doze liberações. O único hash de código diferente é o runner, pela adição do comando `startup`; fixture/cenas/shaders da rota idênticos.

| RSS em MB decimais | Captura ligada | Desligada |
| --- | ---: | ---: |
| Antes da rota | 403,14 | 403,69 |
| Primeiro retorno | 408,46 | 408,83 |
| Quarto retorno | 410,36 | 409,87 |
| Quinto retorno | 410,58 | 409,97 |
| Sexto retorno | 410,79 | 409,99 |
| Depois de salvar | 411,64 | 409,99 |

Todos os retornos: **95 recursos, 1.051 nós, zero órfãos**. Sem captura, render allocations ~23,96 MB repetidas; allocator **51,95 → 52,08 MB** entre primeiro/sexto retorno. Eventos ainda crescem até o limite de 1.024. Captura ligada retém **35.192 intervalos/336 linhas**, allocator final **53,20 MB**. Buffers contribuem, mas o crescimento inicial também existe sem eles. A desaceleração do RSS e contagens estáveis indicam estabilização local; não certificam ausência de vazamento, oito gigabytes ou sessões longas. Não substituir sistemas funcionais nem limpar caches indiscriminadamente para perseguir um número de RSS.

Com captura: **208,27 FPS médios, 1% low 102,42, P99 8,297 ms, pior 19,477 ms, zero quadros >33,33/50 ms**, todos com foco. Sem captura não há série nem gate de FPS. A captura de 180 s cobriu as doze pernas; nenhum frame foi filtrado. [Relatórios, séries completas, contexto, reprodução e execução rejeitada do wrapper](performance-results/2026-10-06/streaming-diagnostics/README.md). A primeira fixture sem captura concluiu, mas o wrapper foi alterado enquanto aguardava Godot e falhou ao retomar leitura; foi preservada e repetida com runner congelado.

`--cycles=1..6 --round-trip --speed-220 --no-capture` permite o par de memória; `startup --foreground --no-vsync` no runner reproduz o par de entrada. Runner completo: **304 antes → 306 depois**, zero falhas/vazamentos reportados, com os três mapas antigos regenerados de forma equivalente. Dois checks novos validam buffers retidos sem alterar os arquivos e cronologia/parada do observador quando há apoio. Logs antes/depois preservados junto aos dados. Estes ensaios liberam a próxima investigação de representação distante/HLOD, mantendo entrada fria, dez minutos jogados/térmica, memória de 8 GB e Windows como gates abertos.


### HLOD do corredor — 2026-10-06

A variante de células acrescenta representações distantes geradas offline: **1.324 triângulos no total**, três grupos com malha opaca e lote de árvores, sem sombras/colisões/referências a cenas detalhadas. `WorldHLOD` troca desenho com histerese a 180/200 m dos limites, conservando colisões residentes. A cena estática, física, áudio e mapas anteriores foram preservados. [Contrato](world-streaming.md).

Radeon/Compatibility/Legacy/720p, VSync desligado, sem queries de viewport, uma execução gráfica por vez, caches/preferências novos. Três pares **off/on** na rota de 120 km/h; todos os hashes de fontes idênticos. `--no-hlod` esconde proxies e desenha residentes completos, mas mantém os recursos distantes carregados: isola desenho, não RSS nem startup sem o artefato.

| Par | HLOD | Média FPS | 1% low | P99 ms | Pior ms | Draw calls médios amostrados |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| 1 | off | 209,82 | 108,54 | 7,975 | 14,158 | 241,36 |
| 1 | on | 211,44 | 117,37 | 7,467 | 13,489 | 224,28 |
| 2 | off | 209,85 | 108,89 | 7,872 | 15,164 | 241,21 |
| 2 | on | 207,15 | 91,04 | 8,675 | 16,782 | 224,13 |
| 3 | off | 203,40 | 88,89 | 8,731 | 18,493 | 241,09 |
| 3 | on | 210,22 | 97,83 | 7,743 | 29,081 | 224,06 |

Todas as seis rotas passaram, ~23,9 s após warmup de 10 s, apoio contínuo/zero bloqueios durante a perna, pico três células e uma liberação por passagem. Todos os intervalos com foco; **zero quadros >33,33/50 ms**, nenhum filtrado. Média das três médias amostradas de draw calls **241,22 → 224,16 (~7,1% menos)**. Leitura a cada ~0,5 s; não é contagem exaustiva por frame. FPS/1% low variam, inclusive pior 1% low ligado no par 2: não prometer ganho de FPS. O resultado é continuidade distante e redução de desenho mantendo pacing aprovado neste conteúdo.

Três idas/voltas a **220 km/h**, seis pernas por inputs/viradas declaradas: **84,48 s, 210,41 FPS médios, 1% low 111,18, P99 7,741 ms, pior 14,427 ms**, zero quadros >33,33/50 ms e 17.776/17.776 com foco. Apoio contínuo/zero bloqueios nas pernas, pico três células, seis liberações e 19 transições visuais. Endpoints de retorno têm **103 recursos/1.061 nós/zero órfãos**, repetidos nos três ciclos; RSS aquecido **416,4 → 422,5 MB** antes de salvar, com captura ativa. Não substituir o ensaio longo com/sem captura anterior por esta passagem mais curta para certificar memória.

Vistas fixas comparáveis, inspecionadas sem captura: com vizinho residente distante, **306 → 219 draw calls / 26.290 → 21.617 primitivas**; no spawn, **209 → 213 chamadas**, preservando conteúdo antes ausente. Descarregamento conserva silhuetas, árvores e piso; detalhe perto não muda. Sem promessa de economia em toda vista nem de qualidade final Most Wanted.

**Custo de entrada continua aberto:** referência anterior 4,612 s de entrada fria/403,2 MB de RSS aquecido; seis novas passagens **5,663–5,861 s/~416 MB**. Allocator inicial aumenta só ~0,12 MB (49,525 → ~49,644 MB); o restante do RSS não é tamanho das malhas. Material/primeira utilização/caches/driver são hipóteses, sem atribuição exclusiva GPU/compilação. Não é A/B isolado de material: a referência anterior tem outras fontes e uma passagem. O HLOD adicionou trabalho inicial; preparar entrada/investigar variantes antes de aprovar M1. A flag off/on é aplicada após os primeiros dez frames e não isola startup.

Runner completo: **306 antes → 318 depois**, zero falhas/vazamentos reportados, três mapas anteriores regenerados equivalentes. Uma passagem intermediária detectou referências de áudio no encerramento acelerado da fixture nova; verbose identificou WAV/playback aguardando mixer. Corrigida espera real na fixture, seguindo testes existentes; áudio do jogo preservado. [Dados brutos, todos os contextos/logs, comparações visuais e reprodução](performance-results/2026-10-06/hlod/README.md).

O runner `hlod --foreground --no-vsync` produz vistas/contadores sem gate de FPS. `streaming --no-hlod` e `streaming` permitem A/B; rota identificada `vale-streaming-hlod-v1`. Só os três proxies desta prova ficam residentes: HLOD por distrito/residência distante de cidades, entrada fria, sessão longa/térmica, 8 GB e Windows continuam pendentes. Próximo passo artístico: composição e materiais perto da oficina/mercado; não ampliar o mapa nem declarar M1/M3 completos.

### Baseline novo — Intel / Compatibility / Legacy 720p

Uma passagem por fixture, após aquecimento, **sem queries de viewport**, VSync ligado, sombras/MSAA/efeitos adicionais desligados, janela conferida de 1280×720. CPU i7-4510U, HD 4400, Inspiron 5547 com 16 GB instalados, Linux/Mesa 25.0.7. Não houve runner de testes/export ou outra Godot concorrente. Commit-base e hashes do código não commitado estão no contexto de execução. [Dados, logs e contexto](performance-results/2026-10-05/m0-compatibility/).

| Fixture | Duração (s) | FPS médio real | 1% low aprox. | P95 (ms) | P99 (ms) | Pior quadro (ms) | Quadros >50 ms |
| --- | --- | --- | --- | --- | --- | --- | --- |
| urban | 37.9 | 28.9 | 14.0 | 57.6 | 62.1 | 92.4 | 336 |
| residential | 84.0 | 29.5 | 14.9 | 56.9 | 59.8 | 81.3 | 765 |
| vegetation | 30.1 | 20.1 | 9.4 | 90.1 | 101.4 | 112.7 | 290 |
| speed | 21.6 | 30.6 | 11.1 | 52.5 | 58.8 | 258.9 | 123 |

As duas rotas urbanas alcançaram 5/5 pontos. Vegetação avançou da amostra 215 até 336, afastamento máximo de 1,13 m e apoio em 100% das amostras. Alta velocidade conferiu 220 km/h pelo deslocamento e passou em 14 checks renderizados, incluindo frenagem/barreira fina; somente aceleração/coast/frenagem entram na captura. Rodovia e tráfego ainda não têm conteúdo próprio.

**Nenhuma dessas passagens aprova 30 FPS estáveis em 720p.** Até a rota cuja média supera 30 tem cauda lenta. São baselines honestos, não ganho de otimização visual: geometria/densidade/física ficaram preservadas. Três repetições, térmica de dez minutos, avaliação jogada e limite efetivo de 8 GB ainda são pendentes. O baseline exploratório anterior (~30,2 FPS/P95 51,1 ms) também não aprovava pacing e não é comparação de ganho com este conjunto.

No centro: draw calls amostrados 205–277, objetos desenhados 631–782; física média amostrada 1,09 ms, pico 3,70 ms. Godot reportou ~78 MiB no allocator estático e ~22 MiB em render allocations; **não são RSS nem VRAM total**. Não permitem concluir que 8 GB já foi validado. Tempo do processo geral não atribui gameplay isoladamente. Sem timing de GPU confiável nesta Intel, o próximo experimento deve separar resolução/preenchimento, lotes e VSync/pacing, com vista fixa e profiler apropriado; não há evidência para reescrever a física.

A tentativa anterior com medição do viewport ativada atingiu ~1 FPS, intervalo mediano ~1.000 ms e reportou tempo GPU absurdo (~1,84×10¹³ ms), falhando 0/5 pontos. Foi **rejeitada como baseline** e guardada em `rejected-viewport-timing-intel`, incluindo motivo e dados brutos. Desativar essa instrumentação recuperou o comportamento gráfico da rota; timing de viewport permanece apenas opt-in para diagnóstico, e não deve contaminar ensaios de jogabilidade.

### Diagnóstico separado — R7 M260 / Medium / vista fixa

AMD Radeon R7 M260 via **radeonsi/OpenGL**, Compatibility, 1280×720, Medium (sombras/MSAA 2×, sem SSAO/glow/SSIL/volumetria), VSync, cinco segundos de aquecimento e 30 s na pose da amostra 215 do rally, física do carro congelada. `--balanced --static --profile-render-time`; não é uma rota de condução nem comparação direta com a Intel em movimento. Os tempos de viewport foram utilizáveis neste driver, ao contrário do diagnóstico Intel.

53,1 FPS médios; 1% low aproximado 45,4; P95 19,4 ms; P99 20,3 ms; pior quadro 28,8 ms. Monitores amostrados: submissão CPU do viewport média 0,99 ms e GPU 17,66 ms; o log também registra média por todos os quadros (~0,98/17,58 ms). Draw calls 148 e objetos desenhados 674 nesta vista. Não extrapolar para todo o mapa, High em 1080p, Windows ou sessão longa. [JSON](performance-results/2026-10-05/m0-compatibility/amd-medium-static.json) e CSV/log ao lado.

Reprodução isolada:

```sh
DRI_PRIME=1 XDG_DATA_HOME=/tmp/wave-m0-amd-diagnostic-new godot --path . --rendering-method gl_compatibility --script res://tests/rally_rendered.gd -- --balanced --static --profile-render-time
```

### Interface gráfica e repetição curta

O painel com presets/rolagem foi inspecionado em screenshot de 960×540, e a rota `--legacy --check-display` verificou ida/volta de tela cheia, restauração do tamanho e captura final em 1280×720. Concluiu 5/5 pontos. A segunda passagem urbana também não aprova pacing: 48.9 FPS médios, P99 58.4 ms e 1% low 16.1 FPS. Dados `intel-ui-repeat.*`; prévias locais em `builds/previews/m0-compatibility/`. Não houve teste de gamepad físico ou avaliação humana de diversão/mixagem.

---

## Medições e decisões históricas (preservadas)

As seções seguintes descrevem a configuração vigente em cada ensaio. A prioridade Assetto Corsa/Forward+ nelas foi substituída pelo plano atual; os resultados e limitações continuam úteis.


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
