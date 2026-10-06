# Oficina e mercado — primeira revisão próxima (2026-10-06)

Gerador do corredor v2, seed 5547. Placas na borda dos toldos, pavimento de acesso, pintura de segurança/vagas, rodapés/colunas e manchas de uso opacas por vertex color. Mesmos materiais e texturas, sem novos shaders, transparências, luzes ou colisores. Cenas estática e particionadas regeneradas offline. Não é aprovação da qualidade percebida de Most Wanted.

## Comparação visual

Quatro câmeras fixas, Legacy/Compatibility/720p, mesmo script de previews; capturas não usadas para medir FPS. Oficina e mercado ganham leitura de placa e diferenciação de uso do piso. Casas, paredes laterais, vegetação próxima e horizonte ainda têm repetição/simplificação evidentes. Não houve avaliação humana de diversão ou sessão longa nesta etapa.

| Vista | Antes | Depois |
| --- | --- | --- |
| Entrada | [PNG](before-views/corridor-0.png) | [PNG](after-views/corridor-0.png) |
| Oficina | [PNG](before-views/corridor-1.png) | [PNG](after-views/corridor-1.png) |
| Mercado | [PNG](before-views/corridor-2.png) | [PNG](after-views/corridor-2.png) |
| Residencial/horizonte | [PNG](before-views/corridor-3.png) | [PNG](after-views/corridor-3.png) |

## Preservação e conteúdo

Runner completo: **318 checks antes e 318 depois**, logs ao lado. Os logs incluem restrições de socket do editor no sandbox e erros esperados do ensaio de célula ausente; nenhum check falhou. Não se adicionaram testes que apenas reproduzem os valores da decoração. Os contratos existentes de determinismo, partição, acesso à oficina, direção, alta velocidade, streaming e HLOD continuam passando; mapas antigos regeneram de forma equivalente.

[Inventário CPU](inventory.json) compara o gerador anterior arquivado e o atual: **851 colisores**, transformações/tamanhos iguais e mesmo SHA256; mesmos 24 nomes de materiais. Root nodes 506 → 515, instâncias batched 1702 → 1729, triângulos standalone 2378 → 2454. Acréscimo de 400 triângulos autorados (27 caixas × 12 + 76 standalone); não confundir esse total com primitivas efetivamente desenhadas. Quatro malhas de desgaste têm culling a 100 m. As representações distantes mantêm 1324 triângulos e omitem esse detalhe localizado. A decoração nova é executada após todos os sorteios, sem mover lotes/árvores.

Fontes em `source-before` e `source-after`; ferramenta do inventário em `inventory.gd.txt` (copiar para `.gd` e executar headless com `--script`). `generator_version: 2` também aparece no manifesto, mantendo `version: 1` do contrato. Carro, áudio, loader e HLOD runtime não foram alterados nesta revisão.

## Medição na Radeon

Inspiron 5547, i7-4510U, R7 M260 confirmada pelo log, **16 GB instalados**, Linux/Mesa 25.0.7, Godot 4.7.2 debug. Compatibility, Legacy, 1280×720 nativos, sem VSync, sombras/MSAA/pós-processamento ou queries de viewport. Dez segundos de aquecimento; raízes XDG novas por execução. Sem testes/export concorrentes. Todos os quadros capturados mantiveram foco. Hashes de fontes iguais dentro de cada grupo de três; antes/depois diferem pelos geradores e artefatos revisados. Rotas por inputs, HLOD ativo, 120 km/h; não são sessões de 30/60 FPS limitados.

| Caso | FPS médio | 1% low | P99 ms | Pior ms | >33,33 / >50 ms | Draw calls médios | Entrada ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| before-1 | 202.48 | 34.28 | 22.907 | 51.130 | 8 / 1 | 223.36 | 7413.1 |
| before-2 | 240.64 | 94.44 | 9.714 | 14.146 | 0 / 0 | 224.17 | 5390.4 |
| before-3 | 240.89 | 94.47 | 9.820 | 14.152 | 0 / 0 | 224.15 | 5414.0 |
| after-1 | 228.96 | 85.60 | 10.877 | 14.846 | 0 / 0 | 226.00 | 5601.7 |
| after-2 | 227.11 | 82.47 | 10.873 | 17.623 | 0 / 0 | 226.28 | 5840.6 |
| after-3 | 230.01 | 88.39 | 10.509 | 13.946 | 0 / 0 | 226.19 | 5909.8 |

O primeiro ensaio anterior teve oito quadros acima de 33,33 ms, um de 51,13 ms e entrada de 7,41 s. Foi preservado, não descartado nem escondido na média. As outras duas passagens anteriores tiveram pacing melhor. Isso evidencia variação de execução; não atribuir sua melhora à nova arte. As três passagens posteriores ficaram abaixo de 33,33 ms, sem bloqueio durante condução e com apoio no piso.

Nos ensaios posteriores há aproximadamente duas draw calls médias adicionais. FPS médio e 1% low ficaram menores que nas duas passagens anteriores mais estáveis: a revisão tem custo, não é uma otimização de FPS. Há margem no cenário medido para conservar o ganho visual. Não extrapolar para bairros, tráfego, Medium, HD 4400, 8 GB ou Windows. A entrada de 5,6–5,9 s é separada da captura aquecida e continua sendo gargalo a tratar; não representa travada em fronteira durante a rota.


Ensaio adicional `after-speed`: três idas/voltas com alvo de 220 km/h (pico real 219,03), seis pernas dirigidas e reversão por teleporte. 84.466 s, 19361 quadros, 229.22 FPS médios, 1% low 86.87, P99 10.705 ms e pior 20.796 ms. **Zero quadros >33,33/>50 ms**, todos focados, zero bloqueios nas pernas e apoio contínuo. Pico de três células residentes, seis liberações, zero falhas; RSS de 397,79 para 404,60 MiB (inclui buffers da captura), sem certificação de sessão longa.

Arquivos brutos CSV por quadro/amostrados, JSON e `streaming.json`, logs, contexto de hardware, commit/diff/status e hashes em cada pasta. [Resumo estruturado](summary.json). Tempos CPU/GPU de viewport ficam indisponíveis (`null`); alocações da Godot não equivalem à VRAM total. RSS aparece no relatório de streaming e não certifica ausência de vazamento em sessão longa.

## Reprodução

Usar pasta de saída nova, confirmar GPU no log. Não executar testes ou exportação simultaneamente.

```sh
GODOT_BIN=~/Downloads/Apps/Godot_v4.7.2-stable_linux.x86_64 DRI_PRIME=1 bash scripts/tools/benchmark_reference.sh /tmp/wave-hero-new-views corridor --previews --foreground --no-vsync
GODOT_BIN=~/Downloads/Apps/Godot_v4.7.2-stable_linux.x86_64 DRI_PRIME=1 bash scripts/tools/benchmark_reference.sh /tmp/wave-hero-new-route streaming --foreground --no-vsync
GODOT_BIN=~/Downloads/Apps/Godot_v4.7.2-stable_linux.x86_64 DRI_PRIME=1 bash scripts/tools/benchmark_reference.sh /tmp/wave-hero-new-speed streaming --three-cycles --round-trip --speed-220 --foreground --no-vsync
```

A reversão do benchmark usa teleporte nos extremos; cada perna é dirigida por inputs normais. Não equivale a manobra humana ou circuito fechado. Próximo trabalho: reduzir custo da primeira entrada, depois continuar autoria residencial/áudio no trecho existente. M1 exige avaliação humana, gamepad/áudio e pelo menos dez minutos jogados/térmica.
