# Diagnóstico de pacing prolongado — 2026-10-06

Radeon R7 M260 no Inspiron 5547, 16 GB instalados, Linux/Mesa, Godot 4.7.2, Compatibility, Legacy 1280×720, limite de 60 FPS, VSync desligado, sem queries de viewport. Telemetria externa somente leitura, aproximadamente 1 Hz; nenhuma outra janela Godot, teste ou export concorrente. Aplicativos do usuário permaneceram em execução. Aquecimento de 10 s, caches/preferências isolados. O usuário manteve a janela em foco até o encerramento automático.

**O percurso passou; pacing reprovou.** A sessão solicitada de 600 s completou 44 pernas (22 idas/voltas) a alvo de 220 km/h em 620,021 s, encerrando no fim da volta. Não houve bloqueio de segurança durante as pernas conduzidas, perda de piso ou evento de instanciação/anexação/liberação de CPU acima de 25 ms; pico de três células residentes. O contador global inclui 44 bloqueios nas esperas deliberadas de apoio após reposicionamento/início, fora das pernas conduzidas; não significa 44 travadas ao dirigir. São voltas automatizadas com reposicionamento nas extremidades, não avaliação humana de dirigibilidade. O campo `cycles=64` é o limite de iterações da fixture; as pernas registradas dão o número efetivamente concluído.

| Intervalos capturados | Resultado |
| --- | ---: |
| Duração / quadros | 619,338 s / 36.296 |
| FPS médio / 1% low | 58,60 / 23,02 |
| P99 / pior intervalo | 32,719 / 137,920 ms |
| Quadros >33,33 / >50 ms | 337 / 71 |
| Quadros sem foco | 0 |

O primeiro segmento de 180 s não teve quadros >50 ms (pior 43,675 ms). Os seguintes tiveram 10, 54 e 7. A GPU foi observada de 90 a 99 °C e o clock ativo de 980 para 850 MHz. Nove picos do segundo segmento ficaram próximos de amostras com processos Chrome consumindo CPU e frequência de CPU perto de 800 MHz. Isso orienta investigação, mas amostras de aproximadamente 1 Hz não provam throttling, atribuição causal ou custo exclusivo do jogo. O ensaio não separa efeitos de calor, aplicativos externos, cap de FPS e driver. A coleta externa também tem custo.

A gravação atual dos CSV/JSON é síncrona. As três trocas de captura deixaram **76,346, 227,557 e 260,159 ms** entre o fim de uma captura e o início da próxima, fora dos CSVs por quadro. O total fora da captura foi 0,683 s, incluindo fechamento final. As diferenças usam relógio de sistema entre âncoras; os intervalos de quadro usam relógio monotônico. Essas lacunas não devem ser omitidas nem contadas como fluidez validada. O analisador reprova lacunas >50 ms, sobreposição ou falta de âncoras; a próxima revisão deve reduzir o custo de gravação e observar o intervalo de rotação continuamente.

`ten-minute/` contém contexto/hashes de fontes no início, diff, log, streaming, quatro conjuntos CSV/JSON, hardware JSONL e análise. Os scripts/cenas não foram alterados durante esse ensaio. Depois dele foram refinados o analisador, seus testes e a rolagem por foco do menu; os hashes de entrega são separados dos hashes da medição. `exploratory-cap60/` e `exploratory-vsync/` preservam as primeiras tentativas: 97% e 18% dos quadros sem foco, respectivamente. Não são comparação controlada entre configurações e não certificam pacing.

Reproduzir com janela em primeiro plano e nova pasta:

```bash
DRI_PRIME=1 GODOT_BIN=/caminho/godot bash scripts/tools/benchmark_reference.sh /tmp/wave-long-new streaming --telemetry --fps-limit=60 --no-vsync --speed-220 --duration=600 --foreground
python3 scripts/tools/analyze_pacing.py /tmp/wave-long-new/streaming --output /tmp/wave-long-new/analysis.json
# Recalcular a evidência arquivada:
python3 scripts/tools/analyze_pacing.py docs/performance-results/2026-10-06/pacing-thermal/ten-minute --output /tmp/wave-long-reanalysis.json
```

`--duration=60..900` encerra depois de uma ida/volta completa; o tempo real pode exceder o solicitado. F4 manual continua limitado a 180 s. `--fps-limit=0|30|60|120`, `--vsync` e `--no-vsync` permitem ensaios separados. FPS/VSync efetivos ficam no JSON. Nenhum resultado desta revisão certifica HD 4400, 8 GB, gamepad físico ou Windows nativo, nem fecha M1.
