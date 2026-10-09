# Plano de desenvolvimento — Wave

Reorientação de 2026-10-07. O [plano anterior](docs/plans/2026-10-06-plan.md), incluindo as alterações locais encontradas nesta auditoria, e o [histórico](docs/history.md) permanecem disponíveis. Resultados históricos conservam suas condições; não são certificação dos novos objetivos.

Prioridade desta iteração, conforme orientação do usuário: desenvolvimento localizado do cenário; otimização pode voltar depois. A máquina é compartilhada com outros jogos, portanto capturas recentes são diagnóstico preliminar e novos benchmarks exigem janela combinada de uso exclusivo. Os requisitos de hardware continuam abertos. A [primeira autoria da Vila da Serra](docs/art-results/2026-10-07/vila-da-serra/README.md) acrescenta calçadas, lotes e praça ao núcleo existente.

## Produto e decisão de prioridade

Wave é direção livre arcade em um território brasileiro fictício: Cidade A urbana/residencial, partindo do Bairro do Sol; Cidade B menor, no interior e perto de serras; rodovia, estradas secundárias e paisagens ligam ambas sem troca manual de mapa. Fim de tarde, carros fictícios, boa resposta e rotas interessantes sustentam a experiência. Densidade de descobertas e composição valem mais que área total. Extensão definitiva depende de condução e custo medidos.

Toda mudança deve melhorar beleza, diversão, plausibilidade ou eficiência no hardware-alvo. Preservar Godot 4.7.2, GDScript tipado, Compatibility, mapas, controles, testes, configurações e funcionalidades úteis. Não reescrever o projeto nem migrar a física sem defeito demonstrado e protótipo comparativo. Conteúdo original ou com origem/licença verificadas; sem assets extraídos dos jogos de referência.

## Referências transformadas em critérios de autoria

As leituras abaixo são diretrizes de design para Wave, não afirmações sobre algoritmos internos dos jogos. Estudo e fontes em [referências](docs/design-references.md).

| Referência | Aplicação no Wave | Como avaliar |
| --- | --- | --- |
| Most Wanted **2005** | Velocidade comunicada por escala, FOV, câmera, contraste, luz e aderência progressiva | Dirigir a 40/80/120 km/h, frear e corrigir curvas; enquadramentos iguais em Econômico/Equilibrado |
| Test Drive Unlimited **2006** | Viagens contínuas, transições e alternativas entre regiões reconhecíveis | Ida/volta sem trocar mapa; destinos legíveis; percurso prazeroso sem evento obrigatório |
| San Andreas **2004** | Massas/horizontes e identidade regional com detalhe seletivo | Reconhecer região pelo cenário; medir residência e desenho, não só triângulos |
| Midnight Club 3 / Underground 2 | Ruas conectadas, atalhos, garagem e progressão automotiva | Rotas alternativas úteis e cruzamentos claros; garagem depois da base contínua |
| Burnout Paradise | Exploração integrada a atividades opcionais | Reutilizar a rede viária e checkpoints sem interromper passeio |
| 171 | Observação de fachadas, calçadas, portões, comércio, fios e vegetação brasileiros | Comparação artística local; condução continua o foco |

## Hardware e perfis obrigatórios

Dell Inspiron 5547, Intel de quarta geração, **8 GB RAM**. Econômico é requisito de produto; aprovação na Radeon não certifica nem substitui a Intel. Pode-se executar provas pequenas de arquitetura enquanto gates estão abertos; não ampliar cidades ou declarar o slice concluído com base em média alta.

| Perfil de produto | ID persistente atual | Base | Meta a comprovar |
| --- | --- | --- | --- |
| Econômico | `economy` | **854×480**, ajustável; sombras/MSAA/efeitos caros desligados | HD 4400: ≥30 FPS sustentados com identidade visual |
| Equilibrado | `medium` | **1280×720**, ajustável; sombras/MSAA 2× | R7 M260: ≥30 FPS sustentados |
| Qualidade | `high` | 1920×1080 inicial; sombras/materiais/vegetação melhores conforme orçamento | Hardware moderno medido, sem dependência artística de Forward+ |

`legacy`/720p continua como preset adicional e fixture histórica. Preferências existentes e padrão atual de primeira execução permanecem; não selecionar GPU automaticamente nem alterar resolução salva. Presets não trocam renderer. Uma aprovação exige mesma rota/câmera/configuração, três passagens, sessão longa e cauda de frame time aceitável. [Orçamento](docs/performance-budget.md) registra gates e recursos. Windows nativo, 8 GB efetivos, gamepad e diversão humana continuam pendentes.

## Auditoria do estado real

Base aproveitável: CharacterBody3D com quatro consultas de rodas, ré/freios/colisão e perfil experimental por eixo no rally; câmera SpringArm/FOV/capô; geração offline e BakedMultiMesh; materiais/texturas originais; áudio/buses/persistência; bairro, circuito, rally e pista técnica; captura monotônica CSV/JSON e suites automatizadas.

Já existiam três células da Avenida do Vale, loader por thread, preload/histerese, guard de apoio, HLOD e testes de falhas. Portanto W2 não começa pela criação de outro manager. Limitações: apoio restrito a piso plano; guard abrupto em atraso; proxies sempre residentes; seleção linear de poucos registros; ativação indivisível de uma cena por quadro; mapas antigos monolíticos; arte repetitiva, árvores em cards e áudio provisório. Não há tráfego, segunda cidade completa ou diversão humana aprovada. [Auditoria atual](docs/reorientation-2026-10-07.md) compara planejamento e código.

A sessão histórica de 620 s teve 71 quadros >50 ms e lacunas na gravação. Causas térmicas/concorrência/apresentação não foram isoladas. Nenhum ganho de pacing é reivindicado nesta reorientação.

## Arquitetura mínima e primeiro incremento

Mundo persistente contém carro/câmera/HUD/áudio/sol e sessão. `WorldStreamer` filho controla residência das células descritas por manifesto: ID, região, origem, limites, vizinhos e cena. Geração offline é responsável por geometrias/colisões/UVs/junções e recursos compartilhados. `WorldHLOD` controla representação visual, sem desligar colisão residente. Regiões são dados; não autoloads nem mapas separados. Caminhos/faixas/atividades e save versionado entram quando houver consumidor real.

**Caminho da Serra**, prova independente: célula inicial da Avenida do Vale reutilizada sem edição + 400 m rural + 400 m rodovia com curva suave + 400 m de núcleo provisório da Cidade B. Aproximadamente 1,38 km entre os endpoints da fixture, não dimensão definitiva do mundo. Mesmo veículo, piso plano e luz persistente. Vila da Serra é nome provisório. O Bairro do Sol inteiro ainda não está conectado. [Contrato e limites](docs/world-streaming.md).

Essa prova demonstra viagem entre usos do território e residência limitada, não entrega cidades completas ou vertical slice artístico aprovado. O gerador estende o kit do corredor, reutiliza materiais/casas/árvores, emite células/HLOD/manifesto, e não roda durante o jogo. Os mapas anteriores permanecem acessíveis. O novo botão do menu permite testar a viagem sem alterar a fixture histórica de 600 m.

## Marcos e critérios de saída

| Marco | Situação e entrega | Critério de saída |
| --- | --- | --- |
| **W0 — Auditoria/baseline** | Auditoria, plano, runner e baseline gráfico da prova | Logs reproduzíveis; limites e alterações preexistentes identificados; desempenho final não presumido |
| **W1 — Direção/câmera/arte** | Controlador e kit existentes preservados; avaliação/refino pendentes | Teste humano teclado/gamepad, frenagem/derrapagem/superfícies, carro integrado ao piso, identidade brasileira nos três perfis |
| **W2 — Mundo contínuo** | Loader/HLOD existentes; prova de quatro regiões implementada | Ida/volta/reset/atraso/falha/pausa sem piso ausente; memória converge; ativação e representação distantes dentro do orçamento; apoio irregular antes de serra real |
| **W3 — Slice de duas cidades** | Caminho da Serra é esqueleto jogável | Urbanização autoral, rural/rodovia/núcleo distinto, acessos/POIs legíveis, ligação real à Cidade A; avaliação artística e condução aprovadas |
| **W4 — Otimização profunda** | Medição acompanha todos os marcos | Econômico Intel e Equilibrado Radeon passam três rotas + sessão longa; 8 GB/Windows; comparar gargalos antes/depois |
| **W5 — Mundo vivo** | Não iniciado | Tráfego pequeno por faixa/cruzamento, densidade por perfil e simulação distante previsíveis; atividades opcionais por checkpoints |
| **W6 — Expansão/polimento** | Não iniciado | Expandir só regiões aprovadas; veículos/áudio/garagem/save; estabilidade e licenças verificadas para builds distribuíveis |

Nenhum marco artístico ou de desempenho é considerado concluído por headless, uma screenshot ou uma passagem curta. W1 e W4 continuam abertos; a prova funcional não remove esses gates.

## Próxima sequência por prioridade

1. Avaliar jogando o percurso atual: Vila com praça/calçadas/lotes e [orientação/paradas revisadas](docs/art-results/2026-10-07/transicoes/README.md), incluindo placas de ida/volta, acesso ao refúgio e árvores em grupos. A [revisão de 2026-10-08](docs/art-results/2026-10-08/orientacao-das-paradas/README.md) acrescenta setas e avisos das três entradas nos dois sentidos. A [passada com a câmera real](docs/art-results/2026-10-08/acessos-em-movimento/README.md) identifica o piso fraco nas aproximações e acrescenta pintura e pavimento acompanhando a curva, com imagens a 80 km/h e acessos testados no PCK. A [revisão das frentes](docs/art-results/2026-10-08/frentes-das-paradas/README.md) organiza os dois pátios com balizadores, vagas e piso junto ao abrigo; a nova fixture freia de 80 km/h e completa entrada/parada/saída nos três destinos, nos dois sentidos, com 19 checks também aprovados no PCK. Os balizadores foram afastados após interferência detectada na saída. A suíte completa passou com 604 checks de comportamento e 10 testes Python; o runner exportado passou 174 checks funcionais, além da guarda do PCK. Conferir jogando a sequência placa → pintura → entrada, reduzir e manobrar nos dois sentidos; refinar os problemas antes de aumentar a extensão ou efeitos. Desenvolvimento localizado continua prioritário; medições aguardam janela exclusiva.
2. A [correção de passagem por calçadas e subidas](docs/development-results/2026-10-07/ground-navigation/README.md) atende ao esbarrão relatado e tem regressões físicas. A revisão de [acesso ao rally e aos oito mapas](docs/development-results/2026-10-07/rally-ground-access/README.md) acrescenta acostamentos contínuos e folga no colisor do carro. A retomada de 2026-10-08 concluiu a validação automatizada: 585 checks e 10 testes Python no projeto, mais 140 checks nos recursos exportados; logs e runner reproduzível estão no relatório. Avaliar jogando a sensação de passagem e fazer uma sessão humana de direção/câmera/áudio; corrigir curva, frenagem, escala e orientação conforme os problemas encontrados. Refinar hatch, luz, piso e vegetação nos enquadramentos fracos.
3. Retomar otimização numa janela combinada de uso exclusivo: o [diagnóstico Intel preliminar](docs/performance-results/2026-10-07/intercity-pacing/README.md) associou o pico à entrada do detalhe urbano, mas uso concorrente não foi controlado. Confirmar e separar preparação de malhas/MultiMeshes, materiais e driver antes de otimizar. Validar os dois perfis e sessão longa; esses gates continuam abertos.
4. A pista isolada tem curvas/acostamentos e recebeu [paisagem, vegetação e Mirante da Serra](docs/development-results/2026-10-07/serra-landscape/README.md), com acesso testado à parada. Avaliar jogando a composição, legibilidade das placas e direção/câmera. A fixture de 108 km/h conserva apoio, mas ainda reprova trajetória: separar limitações da fixture e da condução antes de aprovar velocidades maiores. Preparar horizonte/HLOD em altura e generalizar o contrato de apoio antes de integrar um pequeno trecho à viagem; o perfil continua específico deste laboratório.
5. HLOD por anel/distrito e orçamento de ativação: só subdividir ou indexar quando profiler/crescimento demonstrarem necessidade; preservar continuidade de curvas/UVs/colisões.
6. Integrar um recorte do Bairro do Sol como Cidade A, acrescentar alternativa secundária e POIs; depois validar 8 GB, Windows nativo e sessões longas antes de expansão.
7. O laboratório já tem [Passeio ao Mirante](docs/development-results/2026-10-07/lookout-trip/README.md), com progresso no HUD e chegada ao estacionar, testado por inputs reais. Avaliar a atividade jogando e desenvolver uma etapa de retorno ou outro destino antes de ampliar. Tráfego mínimo continua pendente; garagem/save/versionamento ficam para depois da viagem estável.

## Validação reproduzível

`GODOT_BIN=... bash scripts/tools/check_project.sh` importa, testa contratos e regenera mapas antigos em dados isolados. A nova suíte `intercity_smoke.gd` compara a geometria salva/regenerada e dirige ida/volta com inputs reais; verifica junções físicas, identidade do player/câmera/HUD, reset e residência. Suites anteriores mantêm falhas/atraso/obsolescência/pausa e destruição do loader.

Com janela real, a mesma fixture aceita `--balanced`, `--foreground`, `--no-vsync` e `--previews`; default Econômico. Captura usa `PerformanceCapture`, CSV/CSV por quadro/JSON existentes. Teleportes de sondagem e screenshots ficam fora das séries de condução. Registrar hardware/driver/resolução efetiva/renderer/seed/versão e código modificado. Não comparar o novo percurso às médias da avenida antiga como ganho de otimização.

Resultados e limitações desta etapa: [evidências de 2026-10-07](docs/performance-results/2026-10-07/reorientation/README.md).
