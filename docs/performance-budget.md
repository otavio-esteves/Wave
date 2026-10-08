# Orçamento de performance

## Gate do console de referência

Inspiron 5547/Haswell, **8 GB como alvo**. Gate Econômico: HD 4400/Compatibility/854×480 inicial; gate Equilibrado: R7 M260/Compatibility/1280×720 inicial. Ambas precisam sustentar 30 FPS; Radeon não substitui o requisito Intel. Legacy/720p é fixture adicional preservada. A máquina disponível tem 16 GB; validar memória sob 8 GB e Windows nativo antes de aprovação final. Prova pequena com gates abertos não autoriza expandir cidades.
30 FPS correspondem a **33,33 ms de intervalo de quadro**. Não somar tempos CPU/GPU como se fossem necessariamente sequenciais. Gate provisório de W1/W4, aplicado separadamente aos dois perfis obrigatórios: P95/P99 ≤33,33 ms, 1% low aproximado ≥30 FPS, ausência de hitches recorrentes >50 ms e nenhum pico >100 ms causado pelo conteúdo/streaming em três passagens da rota + sessão jogada de dez minutos. Os limites de cauda e de 50/100 ms são critérios de aceitação iniciais de pacing, não capacidade medida do hardware; revisar com avaliação jogada, sem relaxá-los para aprovar um mapa lento. Meta desejável: 16,67–22,22 ms.

## Recursos finitos e experimentos

Não há teto de draw calls/vegetação/texturas universal aprovado. Cada limite começa **a medir** e será preenchido com rota/commit/evidência, mantendo margem para carro, HUD, áudio e futuras células. Não usar total de triângulos da cena como proxy único de custo.

| Recurso | Medição disponível / experimento para estabelecer limite | Política inicial |
| --- | --- | --- |
| Draw calls/objetos/primitivas desenhados | CSV/JSON schema 2; variar tamanho de lote e material na mesma vista | Lotes espaciais, materiais compartilhados, culling e depois HLOD |
| Transparência/overdraw | Profiler GPU/experimento A/B com folhagem/partículas ocultas; não há contador direto confiável no capture | Alpha scissor, silhouette cards, pouca sobreposição; não simular custo por número de folhas |
| Shadow casters | Inventário offline por lote/instância; comparar sombras off/on e distância | Legacy sem sombras dinâmicas; Medium seletivas/próximas |
| Luzes | Inventário por cena/célula e teste com quantidade crescente | Uma solar; postes/janelas emissivos, sem centenas de luzes |
| Partículas | Quantidade, vida e área da tela; A/B com poeira | CPUParticles pequenas; custo CPU/transparência contado |
| Veículos/tráfego | CPU de gameplay/física e GPU com N veículos nas três faixas | Limite configurável por perfil; ainda sem tráfego implementado |
| Vegetação | Próximo/médio/impostor por célula; A/B por representação | Distantes sem sombras; cull ou horizonte além do alcance |
| Texturas | Inventário por resolução/formato/mip; bytes estimados e render allocations | Reutilizar atlas; atuais 512/1024 não são recomendação universal |
| VRAM | Monitor de allocations Godot + ferramenta do driver quando possível | Valor zero indisponível vira null; não equivale à VRAM total; Intel compartilha RAM |
| RAM | Godot static allocator + RSS/pico externo após viagens repetidas | Conjunto residente limitado; medir 8 GB efetivos e caches |
| CPU de física | TIME_PHYSICS_PROCESS + profiler com script/physics separados | Quatro consultas de apoio/tick já preservadas; evitar física distante |
| CPU de gameplay | TIME_PROCESS como contexto; profiler por método/custom timings | Não chamar o tempo geral do processo de custo exato de gameplay |
| Streaming | I/O/instantiate/add_child/free por fase + série cronométrica | Pré-carregar corredor; budget por frame medido, sem fila ilimitada |

O bairro histórico já possui 2.540 lotes, 21.514 instâncias e 2.128 formas estáticas; **inventário não é budget aprovado**. As capturas históricas em 480p e as quedas em 720p estão em [performance.md](performance.md). Os mapas antigos mantêm densidade/artefatos. A nova Avenida do Vale usa layout e kit próprios para calibrar a produção sem multiplicar a cidade.

## Procedimento de calibração

1. Escolher vista fixa e rota representativa; registrar hardware real, driver, renderer, tamanho real, opções, seed, commit e estado térmico.
2. Aquecer; executar três passagens sem teste/export ou segunda Godot concorrente. Registrar também o começo frio de carregamento em ensaio separado.
3. Verificar pacing e separar CPU/GPU com profiler. Variar **uma** dimensão: resolução, MSAA, sombras, distância, quantidade, material ou lote.
4. Encontrar a região onde P95/P99/cauda deixam de cumprir o gate; reduzir conteúdo e reservar margem. Limite resultante deve citar condições/dados, não virar regra geral para qualquer vista.
5. Repetir dirigindo rápido, atravessando células, com HUD/áudio/tráfego quando existirem; medir memória depois de ida/volta. Reprovar média que esconda travadas.

## Rotas e maturidade

| ID | Fixture disponível | O que falta |
| --- | --- | --- |
| urban-center-v1 | `rendered_route.gd --legacy`, centro/posto, cinco pontos, 12/6 m/s | Substituir por rota do slice mantendo a antiga |
| residential-v1 | `rendered_route.gd --legacy --residential`, anel de ruas ±140/210 m | Arte brasileira final e validação contínua de pacing |
| highway | Reta do circuito/avenida externa são proxies identificados | Rota própria só ao construir a rodovia, M5 |
| vegetation-drive-v1 / vegetation-static-v1 | `rally_rendered.gd --legacy` / `--legacy --static`, 30 s | Vegetação urbana regional, não pinheiral como padrão |
| traffic | Sem fixture: não inventar uma captura “com tráfego” vazia | Benchmark com contagens/seed e níveis de simulação, M7 |
| high-speed-v1 | `high_speed_smoke.gd --legacy`, avenida externa, até 220 km/h | Travessia de células no protótipo M1/M3 e rodovia M5 |

Os monitores nativos podem atrasar e faltar em release. Timestamp queries do viewport não são ativadas na captura normal: nesta HD 4400 houve stalls e valor inválido; use `--profile-render-time` apenas em ensaio separado de custo da instrumentação. Frame intervals são relógio real, não tempo exclusivo GPU. O 1% low é o inverso da média dos ceil(1%) intervalos mais lentos, registrado no JSON; isso não é o mesmo que 1000/P99. O CSV por quadro permite auditar ambos. A captura também registra intervalos com/sem foco, sem descartar os lentos. Nos ensaios Radeon atuais, verificar VSync/apresentação em condições repetíveis; uma mudança grande ao desligar VSync não comprova sozinha o componente responsável. [Referência dos monitores da Godot](https://docs.godotengine.org/en/4.7/classes/class_performance.html).

## Primeiro envelope do corredor, ainda não capacidade máxima

Avenida do Vale: **506 filhos da raiz, 1.702 instâncias em lotes e 851 colisores box**, layout estático de 600 m. Uma solar; luminárias emissivas, sem luzes pontuais. Fachadas/placas opacas; árvores alpha-scissor sem sombras; um quad transparente pequeno para contato do carro. Tráfego e partículas próprios do trecho: ausentes. Esse inventário também não equivale a objetos visíveis em cada quadro.

Na primeira passagem corrigida Radeon/Legacy/720p sem VSync: 109–329 chamadas de desenho, 424–644 objetos renderizados, até 28.866 primitivas; física amostrada 1,16–3,97 ms. Allocator ~53,7 MB e render allocations ~24 MB não são RSS nem VRAM total. Três passagens passaram os critérios numéricos de cauda; [dados e limitações](performance.md#avenida-do-vale--corredor-visual-de-600-m).

Esses números descrevem a base atual e a margem para a próxima experiência, não autorizam multiplicar por quilômetros. Ainda medir custo incremental de células ativas, texturas/props mais variados, HLOD, sombras Medium e tráfego. Um hitch de primeira exibição das placas foi eliminado por rasterização offline; guardar esse caso como regra de medição, sem impor proibição genérica de texto 3D.

## Experimento de residência de células

A variante da avenida usa três arquivos: 297/261/295 colisores (incluindo um piso por célula), materiais/primitivas externos compartilhados e horizonte sempre residente. Um job solicitado/pronto de cada vez; no máximo uma ativação ou liberação de nós por quadro. O streamer registra duração síncrona de solicitar, instanciar, anexar e liberar, além da latência até pronto. Limite de três residentes é configuração da fixture, não um budget universal.

Gate de travessia: nenhum bloqueio de segurança por perna conduzida, apoio contínuo e limite residente respeitado, além dos percentis/cauda de frame time. Entrada fria e virada por reset são fases separadas declaradas no relatório, sem apagar seus eventos. `streaming_rendered.gd` grava estados/eventos e RSS Linux em `user://streaming.json`, com custo das leituras anotado; os CSV/JSON de quadros permanecem completos. Três ciclos ajudam a investigar retenção; contagem de células e memória estática não comprovam RAM total ou 8 GB.

Antes de escalar: verificar no profiler a ativação da célula mais cara e testar conteúdo adicional. Um timer não interrompe uma instanciação longa; se ela estourar a cauda, subdividir o artefato ou mudar representação. A prova agora preserva vista distante com proxies por célula; HLOD por distrito com residência limitada ainda é necessário antes de escalar.

## Custo estrutural do HLOD desta prova

Três proxies residentes: 1.324 triângulos no total, uma superfície opaca sem textura mais um lote de cards de árvore por célula; sombras e colisões desativadas. Artefato textual de cerca de 126 KiB, sem referências a cenas detalhadas. Bytes do arquivo não representam RAM/VRAM. Na vista fixa com vizinho residente distante, 306 → 219 draw calls e 26.290 → 21.617 primitivas; no spawn são quatro chamadas adicionais para preservar duas células descarregadas. Esses números são contadores das vistas comparáveis, não aprovação de FPS. Medições de condução e limites em [performance.md](performance.md).

`--no-hlod` isola o desenho: recursos dos proxies continuam residentes nas duas condições. Não usar esse A/B para prometer redução de RSS ou ausência de overhead. Próxima escala exige budget próprio de proxies por distrito, em vez de carregar todos os proxies do mundo.
