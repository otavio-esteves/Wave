# Primeira entrada: material HLOD compartilhado — 2026-10-06

Inspiron 5547, i7-4510U, Radeon R7 M260, 16 GB instalados, Linux/Mesa 25.0.7, Godot 4.7.2, Compatibility/Legacy, 1280×720, VSync desligado. Uma execução gráfica por vez, sem testes/exportações concorrentes. Preferências e caches isolados, novos em cada par; a reentrada reutiliza as raízes de sua entrada fria. O tempo começa antes da troca de cena e termina no primeiro apoio para condução; não inclui o lançamento inteiro do processo.

## Mudança

O material opaco do HLOD usava `vertex_color_is_srgb=true`. A [implementação da Godot](https://github.com/godotengine/godot/blob/4.7-stable/scene/resources/material.cpp) gera código adicional para essa flag, mas executa a conversão somente quando `OUTPUT_IS_SRGB` é falso. Em Compatibility, a conversão fica inativa; a flag ainda distingue o shader gerado. O artefato e o gerador agora usam o valor padrão, permitindo compartilhar a variante já usada pelo carro. `WorldHLOD` reativa a flag nos renderers que trabalham em espaço linear, preservando o comportamento anterior nesses backends.

As cores, vértices, materiais restantes, colisões, distâncias e loader não mudaram. Não converter cores para linear offline em Compatibility: isso alteraria o visual. `distant.tscn` perdeu apenas a propriedade redundante.

`StartupObserver` acrescenta marcas da chamada de troca de cena, anexação e apoio, além dos intervalos entre `frame_pre_draw` e `frame_post_draw`. Esses intervalos incluem submissão/driver e não representam tempo exclusivo GPU. Não há queries de timestamp GPU.

## Três pares com fontes idênticas

Os seis contextos têm exatamente os mesmos hashes de scripts/cenas/assets. A flag diagnóstica `--reference-hlod-srgb` restaura o material anterior **antes do primeiro desenho**, depois de `scene_changed`; o JSON registra o valor efetivamente usado. Nenhuma fonte foi editada durante esses seis pares. As temperaturas iniciais de GPU registradas nos contextos variam de 75 a 94 °C; a comparação não pressupõe um sistema termicamente frio. Todos terminaram com apoio pronto, uma célula residente e zero falhas do streamer.

| Par | Fria anterior, ms | Fria atual, ms | Reentrada anterior, ms | Reentrada atual, ms |
| --- | ---: | ---: | ---: | ---: |
| 1 | 5753,697 | 4830,088 | 729,170 | 665,219 |
| 2 | 5638,646 | 4965,131 | 733,519 | 686,204 |
| 3 | 5696,479 | 4871,355 | 722,759 | 665,770 |
| Média | 5696,274 | 4888,858 | 728,483 | 672,398 |

**Entrada fria: redução média de 14,17% (~807 ms). Reentrada: 7,70% (~56 ms).** O maior intervalo de desenho frio cai de 3247–3347 ms para 2480–2573 ms. A associação com preparação/compilação de shader é uma inferência apoiada pela mudança isolada e pelo código da engine; não há contador exclusivo do compilador/GPU. O custo restante ainda é alto e não foi ocultado por mover a espera para o menu.

Somas dos intervalos cronológicos foram conferidas contra o tempo de entrada. Dados derivados em `comparison.json`; relatórios, logs, hashes e diffs em `before-1..3` e `after-1..3`.

## Experimentos descartados

`exploratory/` preserva os ensaios que orientaram a comparação final. A redução da radiância do céu para 32 não ajudou (5,816 s frios versus 5,710 s da referência exploratória) e foi revertida. Uma tentativa de converter cores offline foi descartada ao verificar a condição de espaço de cor da engine. A primeira versão sem variante extra registrou 5,054 s; ela motivou os três pares controlados.

Esses ensaios têm fontes diferentes; durante os ensaios iniciais também houve edição da opção de captura de imagem entre processos. Seus contextos representam o início de cada ensaio, não garantem identidade de fontes entre suas entradas fria/reutilizada. Não são a evidência controlada da conclusão; a conclusão usa somente os seis contextos de hashes idênticos.

## Reprodução

```sh
GODOT_BIN=~/Downloads/Apps/Godot_v4.7.2-stable_linux.x86_64 DRI_PRIME=1 bash scripts/tools/benchmark_reference.sh /tmp/wave-entry-before-new startup --reference-hlod-srgb --foreground --no-vsync
GODOT_BIN=~/Downloads/Apps/Godot_v4.7.2-stable_linux.x86_64 DRI_PRIME=1 bash scripts/tools/benchmark_reference.sh /tmp/wave-entry-after-new startup --foreground --no-vsync
GODOT_BIN=~/Downloads/Apps/Godot_v4.7.2-stable_linux.x86_64 DRI_PRIME=1 bash scripts/tools/benchmark_reference.sh /tmp/wave-entry-views-before-new hlod --reference-hlod-srgb --foreground --no-vsync
GODOT_BIN=~/Downloads/Apps/Godot_v4.7.2-stable_linux.x86_64 DRI_PRIME=1 bash scripts/tools/benchmark_reference.sh /tmp/wave-entry-views-after-new hlod --foreground --no-vsync
```

## Comparação visual e primeira rota prolongada

As seis vistas fixas antes/depois têm **PNGs idênticos byte a byte**, com hashes em `visual-comparison.json`; câmeras e condições iguais, HLOD ligado/desligado. A vista atual também foi inspecionada. Isso valida a preservação dessas vistas em Compatibility, sem aprovar a direção de arte final.

A primeira rota após as comparações (`speed-three-cycles-hot`) passou seis pernas a 220 km/h com apoio contínuo, zero bloqueios nas pernas, três células no pico e seis liberações. **Pacing insuficiente:** 84,460 s, 124,27 FPS médios, P99 24,071 ms, pior 89,490 ms, 35 quadros >33,33 ms e sete >50 ms. Todos os 10.496 intervalos tiveram foco; série completa auditada contra o CSV.

O contexto começou com GPU a **93 °C**, contra 61 °C na referência histórica de alta velocidade. Isso é evidência de condições térmicas diferentes, não prova de que temperatura explica cada pico. O sucesso geométrico não aprova o pacing. O resultado desfavorável permanece publicado; sessões longas/térmica continuam abertas.

A repetição após a bateria headless (`speed-three-cycles-repeat`) começou a **67 °C** e completou as seis pernas sem bloqueios, com três residentes no pico e seis liberações. Pacing também insuficiente: 84,700 s, 180,54 FPS médios, P99 36,146 ms, pior 236,395 ms, 175 quadros >33,33 ms e 79 >50 ms. Dos 15.292 intervalos, 1.673 ficaram sem foco; nenhum foi descartado. Essa perda de foco impede comparar o resultado como aprovação nas mesmas condições do primeiro ensaio. Durante a rota, uma leitura manual do mesmo sensor mostrou 98 °C; não é série térmica contínua nem prova causal.

As duas capturas não aprovam pacing prolongado nem isolamento térmico. Não continuar acumulando ensaios gráficos sem controle de temperatura/foco. A próxima validação precisa acompanhar temperatura/clocks ao longo da rota, distinguir a influência de foco e incluir sessões com a configuração efetiva de VSync/limite de FPS. Não mudar a opção persistida do usuário para obter um resultado melhor.

## Limites

A primeira entrada continua em 4,83–4,97 s neste diagnóstico. Ganho parcial, não aprovação de M1 nem remoção de todos os stalls de primeira utilização. Não certifica Intel HD 4400, Windows nativo, memória de 8 GB, sessões longas/térmica ou avaliação humana de arte/áudio/diversão. Próximo passo: investigar as demais variantes e o trabalho dos primeiros desenhos, preservando a aparência e a segurança do apoio.

## Regressões automatizadas

A bateria final passou **319 verificações, zero falhas**, incluindo geração/determinismo de HLOD, estados/falhas/teleporte de streaming, menus/persistência e equivalência offline dos três mapas antigos. Log em `checks-final.log`.

## Builds

Linux e Windows foram reexportados após a mudança. Hashes/tamanhos e identidade das fontes em `source-and-builds.json`; as fontes coincidem com os seis pares controlados. O harness do editor abriu o PCK Linux fora do repositório com preferências isoladas: **9 checks passaram** para menu, manifesto empacotado, Enter, células, condução e retorno. Isso valida acesso aos recursos exportados, sem substituir Windows nativo ou benchmark do executável release. Logs em `export.log` e `exported-pack.log`.
