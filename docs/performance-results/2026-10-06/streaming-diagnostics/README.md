# Entrada e memória do corredor — 2026-10-06

Inspiron 5547, i7-4510U, Radeon R7 M260, 16 GB instalados, Linux/Mesa 25.0.7, Godot 4.7.2. Compatibility, Legacy, 1280×720, foco solicitado, VSync desligado, sem queries de viewport, uma execução gráfica por vez. CPU/testes/exportações não rodaram simultaneamente. MB neste relatório são decimais.

## Entrada fria/reentrada

| Comparação | Entrada fria | Reentrada |
| --- | ---: | ---: |
| Primeiro par manual | 5,087 s | 0,460 s |
| Runner final `startup` | 5,117 s | 0,622 s |

No segundo par, latência até pronto 147,86/137,09 ms, instanciação 9,64/10,47 ms, anexação ~1 ms. Os maiores intervalos antes/do primeiro apoio são 2.040/2.715 ms frios e 121/150 ms reutilizando cache; RSS aquecido 402,8/251,5 MB. A grande diferença depende de caches/primeira utilização gráfica. Não atribuir exclusivamente a shader/GPU nem confundir o tempo de entrada total com I/O. Ainda há custo de entrada fria; este ensaio não o removeu do produto.

## Memória: seis idas/voltas a 220 km/h

Doze pernas por inputs, viradas por teleporte/heading declaradas, 169 s após aquecimento de 10 s. Ambas passaram com apoio contínuo, zero bloqueios durante as pernas, até três células residentes e doze liberações. Pastas/caches novos em ambas; o único hash de fonte diferente entre elas é `scripts/tools/benchmark_reference.sh`, pela adição do diagnóstico de entrada. Código/cenas/shaders da rota são idênticos.

| Ponto | Captura ligada, RSS MB | Desligada, RSS MB |
| --- | ---: | ---: |
| Antes da rota | 403,14 | 403,69 |
| Retorno 1 | 408,46 | 408,83 |
| Retorno 2 | 409,24 | 409,44 |
| Retorno 3 | 409,67 | 409,70 |
| Retorno 4 | 410,36 | 409,87 |
| Retorno 5 | 410,58 | 409,97 |
| Retorno 6 | 410,79 | 409,99 |
| Depois de salvar a captura | 411,64 | 409,99 |

Ligada: 35.192 intervalos e 336 linhas amostradas retidos; allocator no retorno 6 de 53,20 MB. Desligada: zero buffers, allocator de 52,08 MB. Todos os retornos têm 95 recursos, 1.051 nós e zero órfãos; render allocations sem captura se repetem em 23,96 MB. Crescimento de allocator sem captura, depois do primeiro retorno, ~0,13 MB; inclui telemetria de eventos ainda crescendo dentro do limite de 1.024. Não atribuir a totalidade do RSS ao allocator nem estimar VRAM por ele.

A subida inicial permanece sem captura: buffers do benchmark contribuem, mas não explicam tudo. O crescimento desacelera sem acúmulo de nós/recursos nesses pontos e com apenas ~12 KB adicionais de RSS entre os dois últimos retornos. Evidência de estabilização local, não prova de ausência de vazamentos, sessão longa ou 8 GB. Driver/caches/allocator têm residência distinta das cenas; não reescrever o streamer com base apenas no RSS inicial.

Captura ligada: 208,27 FPS médios, 1% low 102,42, P99 8,297 ms, pior 19,477 ms, zero quadros acima de 33,33/50 ms, 35.192/35.192 intervalos com foco. CSV completo, sem filtragem. Sem captura não há série nem aprovação de pacing/FPS.

`no-capture-six-wrapper-interrupted` preserva uma primeira execução cuja fixture terminou `passed=true legs=12`, mas o wrapper falhou ao retomar leitura do shell depois de ter sido editado enquanto aguardava Godot. Não é a referência concluída; `no-capture-six` é a repetição limpa. Erro e dados não foram apagados.

## Reprodução

```sh
GODOT_BIN=~/Downloads/Apps/Godot_v4.7.2-stable_linux.x86_64 DRI_PRIME=1 bash scripts/tools/benchmark_reference.sh /tmp/wave-memory-with-new streaming --cycles=6 --round-trip --speed-220 --foreground --no-vsync
GODOT_BIN=~/Downloads/Apps/Godot_v4.7.2-stable_linux.x86_64 DRI_PRIME=1 bash scripts/tools/benchmark_reference.sh /tmp/wave-memory-without-new streaming --cycles=6 --round-trip --speed-220 --no-capture --foreground --no-vsync
GODOT_BIN=~/Downloads/Apps/Godot_v4.7.2-stable_linux.x86_64 DRI_PRIME=1 bash scripts/tools/benchmark_reference.sh /tmp/wave-startup-new startup --foreground --no-vsync
```

O runner exige pasta nova. Somente a rota `startup` reutiliza suas raízes XDG isoladas entre cold/warm, salvando JSON e log próprios. Não usa preferências/cache pessoais. Limite de captura: 180 s; conferir duração/frames antes de considerar uma rota longa integralmente capturada. Aqui a série cobre todas as doze pernas.

Os arquivos preservam hashes, diff, contexto, logs, eventos/RSS e CSV. `startup-pair` é a primeira comparação manual, anterior ao comando dedicado; `startup-runner` valida a reprodução pelo comando final. A entrada medida começa antes da troca de cena e termina no primeiro apoio para movimento: não mede o lançamento inteiro do processo nem tempo exclusivo GPU. Ver resumo atualizado em [performance.md](../../../performance.md).

## Validação

Runner completo: **304 antes → 306 depois**, zero falhas/vazamentos reportados; mapas anteriores regenerados de forma equivalente. [Log anterior](checks-before.log), [log final](checks-after.log). Auditados contagem/duração/ordem/pior intervalo/1% low do CSV completo, as 24 pernas aceitas, contagens dos retornos e as quatro timelines de entrada. Erros de socket do editor no sandbox e falhas injetadas do loader ficam identificados nos logs; não são falhas das verificações.
