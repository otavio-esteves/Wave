# Diagnóstico da travada na volta — Caminho da Serra

**Status preliminar:** o usuário informou que pode usar a máquina para outros jogos durante os ensaios. Não houve controle de uso exclusivo. A associação reproduzida à troca visual orienta investigação, mas custos, desempenho sustentado e causalidade interna precisam de confirmação numa janela combinada. A prioridade atual permite desenvolvimento localizado do cenário enquanto a otimização fica pendente.

O gatilho reproduzido é a **troca da representação distante para o detalhe da célula urbana `vale-0`**. A travada permanece com a captura normal desligada. Mudar apenas a distância de entrada do detalhe de 180 para 120 m deslocou o pico aproximadamente 60 m, para o quadro seguinte à nova troca visual. Não foi aplicada uma otimização ao jogo; a operação interna que ocupa esse intervalo ainda precisa ser isolada.

## Evidência

Inspiron 5547/i7-4510U, **16 GB**, Intel HD 4400 confirmada nos logs, Godot 4.7.2/Compatibility/Mesa 25.0.7, Econômico/854×480, VSync desligado, FPS ilimitado. O aviso de `DRI_PRIME=0` é preservado; a identidade da GPU vem do log e do relatório. Cada sessão usa preferências/cache novos, aquecimento inicial de 10 s, uma ida e uma volta com velocidade alvo de 108 km/h, e um único processo Godot. Não houve testes ou exportação simultâneos. O desktop e outros processos permaneceram ativos, registrados por telemetria externa a 1 Hz.

O observador mínimo é igual nos dois braços: intervalos monotônicos, número do quadro de processo, posição, célula e foco. Os buffers só são salvos depois das duas pernas. A captura normal continua salvando ao fim de cada perna, fora dos intervalos observados da outra. Sondagens/teleportes ficam fora das séries. Os intervalos iniciais/finais têm os limites da chamada da fixture; os CSVs permanecem completos.

### Três pares com captura ligada/desligada

Ordem executada: `1-on`, `1-off`, `2-off`, `2-on`, `3-on`, `3-off`. Todos os retornos reproduziram o pico principal com foco, sem evento de streaming no quadro ou nos quadros adjacentes.

| Sessão | Pior intervalo da volta (ms) | Posição z do pico (m) | Quadros >50 ms na volta | Quadros sem foco na volta |
| --- | ---: | ---: | ---: | ---: |
| 1-on | 284,178 | −375,617 | 1 | 0 |
| 1-off | 231,382 | −375,651 | 1 | 0 |
| 2-off | 227,050 | −375,918 | 5 | 160 |
| 2-on | 228,260 | −375,609 | 1 | 0 |
| 3-on | 225,694 | −375,609 | 1 | 0 |
| 3-off | 239,792 | −376,033 | 1 | 0 |

`1-on` também teve 42 quadros sem foco no início da ida. Os quatro picos adicionais de `2-off` ocorreram sem foco, em outro trecho; foram preservados. A primeira fixture ainda aceitava freio de mão/câmera físicos: não usar essas médias ou durações para quantificar overhead da captura. A versão seguinte isola todos os comandos de condução/câmera e recupera foco depois da aplicação gráfica. Algumas durações de ida também variam nos controles; o experimento testa localização do pico, não ganho de FPS nem equivalência temporal perfeita.

Nos três primeiros retornos, a célula urbana foi anexada em torno de `z = −435 m`, aproximadamente 60 m antes do pico; instanciação de 5,86–6,49 ms e anexação de 0,72–0,84 ms. A espera de recurso por thread foi de 125–134 ms, anterior ao pico e sem bloquear esse intervalo na thread principal. Isso não certifica todos os custos do streaming, mas separa esses eventos do pico reproduzido.

### Controle da distância de detalhe

Duas sessões seguintes com a mesma fixture corrigida, captura normal desligada e eventos HLOD registrados. A única variável gráfica do controle é `detail_enter_distance`; a saída continua em 200 m. Todos os intervalos das duas sessões mantiveram foco.

| Entrada de detalhe | z da troca HLOD (m) | z do pico (m) | Pico (ms) | Relação temporal |
| --- | ---: | ---: | ---: | --- |
| 180 m, padrão | −379,958 | −375,983 | 238,049 | Quadro seguinte à troca de `vale-0` para detalhe |
| 120 m, diagnóstico | −319,975 | −316,041 | 230,530 | Quadro seguinte à troca de `vale-0` para detalhe |

Deslocamento do pico: **59,942 m**. Não há evento de carga/instanciação/anexação/liberação adjacente nesses picos. O controle isola a troca visual como gatilho, mas não separa upload de malhas/MultiMeshes, preparação de materiais/shaders, driver ou apresentação. Nenhuma causa térmica é afirmada a partir das amostras de 1 Hz. Reduzir a distância apenas desloca a travada; **não é uma correção**.

## Artefatos e integridade

- `capture-ab/analysis.json` e `hlod-distance/analysis.json`: auditoria dos CSVs, estatísticas recalculadas, foco, eventos próximos e hardware amostrado. O analisador recusa cronologia quebrada, CSV incompleto, resumo divergente e GPUs/configurações diferentes.
- Cada sessão preserva `run.log`, `hardware.jsonl` e `data/godot/app_userdata/Wave/` com CSVs/JSONs; os braços `on` também têm os arquivos de `PerformanceCapture`.
- `source-hashes.json` registra a identidade dos arquivos no início de cada série. `measured-source/` preserva as duas revisões de fixture/observador e os scripts de streamer/HLOD, conferidos contra esses hashes. Testes/analisador foram desenvolvidos durante os ensaios; código de runtime medido permaneceu fixo dentro de cada série.
- Caches binários não foram adicionados ao repositório. `shader-cache-index.json` preserva nomes, tamanhos, datas e hashes; os caches originais continuam nos diretórios temporários dos ensaios.
- Nos ensaios arquivados, o wrapper iniciou `timeout` como filho: `game_pid`/`game_cpu_percent_one_core` descrevem esse wrapper, não Godot. Usar `top_cpu` para observar processos. O runner final coloca `timeout` fora do monitor, corrigindo isso para novas execuções.
- `intercity-smoke.log`: **16 checks, zero falhas** na fixture final headless. As oito sessões renderizadas concluíram com **13 checks, zero falhas cada**. Quatro testes novos de integridade e os seis testes anteriores de pacing passaram; sintaxe dos runners conferida. O runner completo de 338 checks não foi repetido nesta etapa.

## Reprodução

Três pares novos, cerca de 12 minutos, com saída que ainda não exista:

```sh
DRI_PRIME=0 GODOT_BIN=~/Downloads/Apps/Godot_v4.7.2-stable_linux.x86_64 \
  bash scripts/tools/benchmark_intercity_pacing.sh /tmp/wave-intercity-ab-new
python3 scripts/tools/analyze_intercity_pacing.py /tmp/wave-intercity-ab-new \
  --output /tmp/wave-intercity-ab-new/analysis.json
```

O runner aceita `--balanced` como segundo argumento para outro perfil; usar `DRI_PRIME=1`, outra pasta e confirmar a GPU. Esta etapa mediu apenas Intel/Econômico.

Controle de distância, uma janela por vez, sem outros ensaios concorrentes:

```sh
wave_diagnostic_root=/tmp/wave-intercity-distance-new
for distance in 180 120; do
  run="$wave_diagnostic_root/detail-$distance"
  mkdir -p "$run"
  DRI_PRIME=0 XDG_DATA_HOME="$run/data" XDG_CONFIG_HOME="$run/config" XDG_CACHE_HOME="$run/cache" \
    timeout 240 python3 scripts/tools/hardware_monitor.py --output "$run/hardware.jsonl" -- \
    ~/Downloads/Apps/Godot_v4.7.2-stable_linux.x86_64 --path . --rendering-method gl_compatibility \
    --script res://tests/intercity_smoke.gd -- --foreground --no-vsync \
    --pacing-diagnostic --no-capture "--detail-enter=$distance" > "$run/run.log" 2>&1 || break
done
python3 scripts/tools/analyze_intercity_pacing.py "$wave_diagnostic_root" \
  --output "$wave_diagnostic_root/analysis.json"
```

## Próximo ajuste e limites

Investigar a preparação do detalhe urbano após recarga e seu primeiro desenho. Comparar uma alteração por vez em recursos/MultiMeshes/materiais, preservando composição, colisões, teto de três células e continuidade do proxy; só declarar ganho com antes/depois reproduzível. A média de FPS destes ensaios não é comparação de otimização com as capturas antigas.

O pacing continua reprovado pelo pico. Faltam Radeon/Equilibrado nesta nova série, sessão longa contínua, 8 GB efetivos, Windows nativo e avaliação humana. O controle de 120 m existe apenas na fixture: o produto mantém entrada/saída de detalhe em 180/200 m.
