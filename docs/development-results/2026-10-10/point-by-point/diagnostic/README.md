# Diagnóstico gráfico — 10/11 de outubro de 2026

Quatro passagens, cada uma com 14 trechos da fixture `pilot-three-districts-v3`, concluíram o percurso com apoio no piso acima de 99%. Os dados incluem todos os frames, inclusive perda de foco e pausas longas. A máquina permaneceu disponível para o usuário: não há certificação de uso exclusivo, estabilidade a 30 FPS, alvo de 8 GB ou Windows nativo.

| GPU / preset | Versão | FPS ponderado | Pior P99 por trecho | Menor 1% low por trecho | Pico RSS observado | Frames sem foco |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Intel HD 4400 / Econômico | anterior | 18,48 | 116,64 ms | 5,27 FPS | 1.531 MiB | 16,5% |
| Intel HD 4400 / Econômico | atual | 17,41 | 141,40 ms | 3,96 FPS | 1.530 MiB | 86,2% |
| Radeon R7 M260 / Equilibrado | anterior | 39,76 | 414,61 ms | 2,07 FPS | 1.477 MiB | 0% |
| Radeon R7 M260 / Equilibrado | atual | 66,75 | 54,77 ms | 13,83 FPS | 1.479 MiB | 0% |

FPS ponderado é o total de frames dividido pela duração total das capturas; P99 e 1% low mostram o pior trecho, não um percentil calculado pela união de todas as amostras. RSS inclui o processo e seus mapeamentos; memória estática do Godot e alocações de render são métricas distintas. O intervalo atual de sólidos ativos na Intel foi de 1.593 a 2.720 formas, além de piso, ruas e guias permanentes.

A Radeon apresentou melhora nesta passagem; a Intel permaneceu abaixo da meta. A cauda de frames ainda falha nos critérios de estabilidade em ambas. Uma execução por GPU, concorrência e diferenças de foco não sustentam atribuição causal nem aprovação de produto. O RSS observado não indica redução material da memória residente: ativar física próxima não descarrega recursos.

A entrada direta na cena levou 31,17/15,38 segundos na Intel anterior/atual e 13,14/13,87 segundos na Radeon. A fixture usa mudança direta de cena: esses tempos não medem o clique e a preparação do menu com carregamento em background. Cache de disco, ordem e carga da máquina também afetam a comparação. A Intel anterior foi medida várias horas antes; as outras três passagens foram sequenciais depois dos testes funcionais.

O conteúdo dos PCKs foi executado pelo motor Godot 4.7.2 para permitir a fixture externa; os registros informam `debug_build: true`. O executável Linux exportado teve abertura/encerramento separado, sem benchmark automatizado. Janelas: 854×480 na Intel, 1280×720 na Radeon. O tamanho lógico do viewport também está preservado nos registros. VSync e limite de FPS desativados; câmera real de condução, horário 16h30, aquecimento de dez segundos.

As quatro passagens saíram com código zero. Todas registraram dois avisos de textura GLES3 ao encerrar, de 21.844 bytes cada; o pacote anterior também os apresenta. Esses avisos não são as referências de objetos resolvidas nos testes headless. A investigação isolada do renderer acompanha a validação; o relatório principal registra seu resultado.

[Resumo completo](summary.json), [métricas condensadas](metrics.json), [contexto e hashes](context.json), [auditoria](audit.log) e [evidência bruta comprimida](raw-evidence.tar.gz). O arquivo comprimido inclui fixtures, CSVs de frames/monitores, JSONs, telemetria por segundo, logs, screenshots e diff do código rastreado. As novas fontes estão identificadas nos [hashes do código](../validation/source-sha256.json).
