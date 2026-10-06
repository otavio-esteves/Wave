# HLOD do corredor — 2026-10-06

Inspiron 5547/i7-4510U, Radeon R7 M260, 16 GB instalados, Linux/Mesa 25.0.7, Godot 4.7.2. Compatibility/Legacy, 1280×720, VSync desligado, sem queries de viewport. Uma execução gráfica por vez; nenhum teste/exportação concorrente. Caches/preferências novos por execução. Todos os intervalos das seis passagens tiveram foco; nenhum frame filtrado.

## Implementação e revisão visual

`distant.tscn`: três grupos residentes, 1.324 triângulos no total, uma superfície opaca com vertex colors e um lote de cards de árvore por célula; sem sombras, colisões ou cenas detalhadas referenciadas. Arquivo textual ~126 KiB, não uma estimativa de RAM. Piso, vias, corpos/telhados/galpões e árvores preservam a composição distante. Detalhes locais ficam na cena original preservada.

Troca pelo jogador aos limites da célula: detalhe a 180 m, simplificação acima de 200 m; faixa conserva estado anterior. Sem nó detalhado, proxy continua disponível. Esconder raiz visual não remove a colisão residente. Há três proxies sempre carregados nesta prova; não é estratégia de residência para duas cidades completas.

As seis imagens em `previews/` foram inspecionadas em pares. Preservam massas/árvores/vias em áreas antes vazias; fachadas próximas continuam iguais. Existe simplificação de materiais e ausência de props distantes, com transição opaca e valores experimentais. Não certificam arte final, ausência de popping em toda câmera ou qualidade percebida de Most Wanted. Layout próximo ainda é repetitivo e requer revisão.

| Vista fixa | HLOD ligado/desligado: chamadas | Primitivas ligado/desligado |
| --- | ---: | ---: |
| Spawn: uma célula detalhada | 213 / 209 | 21.545 / 20.655 |
| Retorno: duas residentes, primeira descarregada | 270 / 268 | 20.355 / 19.921 |
| Vizinho residente distante | 219 / 306 | 21.617 / 26.290 |

Esses contadores descrevem vistas fixas, sem série nem gate de FPS. Readback/PNG acontece fora das capturas. O spawn ganha conteúdo e quatro chamadas; simplificar uma célula residente economiza desenho. Não prometer economia em toda vista.

## Três pares na mesma rota a 120 km/h

Ordem off/on, três repetições em raízes novas. **Todos os hashes de fontes são idênticos nos seis contextos**; muda apenas `--no-hlod`. Artefato distante permanece carregado mesmo desligado: A/B de desenho, não redução de memória nem comparação de entrada sem o artefato. A flag é aplicada depois dos primeiros dez frames; os pares não isolam custo de startup on/off.

| Par | HLOD | Média FPS | 1% low | P99 ms | Pior ms | Chamadas médias amostradas |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| 1 | off | 209.82 | 108.54 | 7.975 | 14.158 | 241.36 |
| 1 | on | 211.44 | 117.37 | 7.467 | 13.489 | 224.28 |
| 2 | off | 209.85 | 108.89 | 7.872 | 15.164 | 241.21 |
| 2 | on | 207.15 | 91.04 | 8.675 | 16.782 | 224.13 |
| 3 | off | 203.40 | 88.89 | 8.731 | 18.493 | 241.09 |
| 3 | on | 210.22 | 97.83 | 7.743 | 29.081 | 224.06 |

Seis rotas passaram com apoio contínuo, zero bloqueios nas pernas, até três células e uma liberação por passagem. Todas têm zero quadros >33,33/50 ms. Duração capturada ~23,9 s por rota após aquecimento de 10 s. Séries completas/contagem/duração/pior intervalo/1% low foram auditados contra os CSV.

Média entre as três médias amostradas de draw calls: **241,22 → 224,16 (~7,1% menos)**. São leituras a cada ~0,5 s, não contagem exaustiva por quadro. FPS/1% low variam; o par 2 tem 1% low menor ligado. O ganho sustentado aqui é menor custo de desenho e continuidade distante com pacing dentro do gate, não uma promessa de FPS maior.

## Três idas/voltas a 220 km/h

Seis pernas por inputs, viradas por teleporte/heading declaradas; mesma identidade de fonte dos seis pares. **84.48 s, 210.41 FPS médios, 1% low 111.18, P99 7.741 ms, pior 14.427 ms**, 0 quadros >33,33 ms e 0 >50 ms. Todos os 17776 intervalos com foco. Apoio contínuo e zero bloqueios nas pernas, pico três células, seis liberações e 19 transições visuais. Eventos permitem cruzar mudança de representação com frames/clock/posição; séries completas preservadas em `fast-three-cycles/`.

## Entrada e memória: custo adicional visível

Referência original anterior à mudança: entrada fria 4,612 s, RSS aquecido 403,22 MB, allocator 49,525 MB. As seis execuções novas: entrada fria 5,663–5,861 s; allocator inicial ~49,644–49,645 MB. Exemplos do par 1: RSS aquecido off/on 416,53/416,24 MB. O aumento de allocator é ~0,12 MB, mas o RSS sobe ~13 MB: não atribuir esse custo todo às malhas nem a vazamento. Material/primeira utilização/caches/driver precisam de investigação; não há timing exclusivo GPU/compilador. A referência original tem outro conjunto de fontes e uma passagem: comparação de startup/RSS é diagnóstica, não A/B isolado do material.

O HLOD não resolve entrada fria; adicionou trabalho nessa fase. Antes de aprovar M1, medir reutilização de cache/preparação de entrada e considerar variantes de material mais baratas/preparo offline. Alvo de 8 GB, Windows e sessão longa/térmica permanecem pendentes.

## Testes e reprodução

**306 antes → 318 depois**, zero falhas e vazamentos reportados no runner final, mapas anteriores regenerados de forma equivalente. `checks-intermediate-audio-shutdown.log` preserva uma passagem em que os checks passaram mas o encerramento acelerado do teste novo não deu tempo real à parada do mixer. Verbose identificou seis referências de WAV/playback. A fixture passou a esperar como os testes existentes; comportamento de áudio do jogo não mudou. `hlod-verbose-final.log` e `checks-after.log` não apresentam esse aviso.

```sh
GODOT_BIN=~/Downloads/Apps/Godot_v4.7.2-stable_linux.x86_64 DRI_PRIME=1 bash scripts/tools/benchmark_reference.sh /tmp/wave-hlod-views-new hlod --foreground --no-vsync
GODOT_BIN=~/Downloads/Apps/Godot_v4.7.2-stable_linux.x86_64 DRI_PRIME=1 bash scripts/tools/benchmark_reference.sh /tmp/wave-hlod-off-new streaming --no-hlod --foreground --no-vsync
GODOT_BIN=~/Downloads/Apps/Godot_v4.7.2-stable_linux.x86_64 DRI_PRIME=1 bash scripts/tools/benchmark_reference.sh /tmp/wave-hlod-on-new streaming --foreground --no-vsync
GODOT_BIN=~/Downloads/Apps/Godot_v4.7.2-stable_linux.x86_64 DRI_PRIME=1 bash scripts/tools/benchmark_reference.sh /tmp/wave-hlod-fast-new streaming --speed-220 --round-trip --three-cycles --foreground --no-vsync
```

Contextos/hashes, logs, eventos, RSS e séries são preservados por pasta. [Contrato](../../../world-streaming.md), [resumo de performance](../../../performance.md). Próximo ganho visual: composição e kit perto da oficina/mercado, sem aumentar o mapa. Não declarar M1/M3 completos.
