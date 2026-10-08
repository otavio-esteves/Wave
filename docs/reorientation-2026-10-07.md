# Auditoria e primeira conexão entre regiões — 2026-10-07

## Estado encontrado e preservação

Lidos README, plano, performance/assets, arquitetura/streaming/arte/orçamento, geradores do corredor/células/HLOD, loader, mundo/câmera/inputs e testes/ferramentas pertinentes. A base já havia avançado além do prompt: avenida de 600 m, três arquivos de célula, I/O por thread, guard de apoio e proxies HLOD existiam. A proposta de começar outro streamer não era necessária.

O Git tinha mudanças locais em README/plano/performance/streaming, settings/gráficos/captura/benchmark/runner e testes, além das ferramentas/evidências de pacing não rastreadas. Foram preservadas. [Patch das mudanças rastreadas anteriores](performance-results/2026-10-07/reorientation/preexisting.patch). O plano anterior completo, incluindo ajustes locais, foi [arquivado](plans/2026-10-06-plan.md), sem apagar evidências históricas. Nenhum commit/limpeza/reset foi feito.

A primeira execução do runner foi interrompida no teste de circuito; o log parcial não prova execução completa. A execução reiniciada completou o runner existente. Novos arquivos e acesso opcional no menu foram acrescentados enquanto ela rodava; portanto esse log é conferência inicial das suites existentes, não baseline com árvore imutável. Runner final verifica a implementação consolidada. Resultados e condições em [evidências](performance-results/2026-10-07/reorientation/README.md).

## Problemas e decisões

- O plano tratava 480p como fallback e liberava progresso pela Radeon. A nova orientação exige Econômico/480p na Intel como perfil de produto. Plano/política/orçamento/interface foram realinhados sem apagar medições ou mudar preferências salvas.
- Streaming/HLOD funcionais são preservados. O contrato plano e proxies sempre residentes impedem afirmar que cidades/serra já estão resolvidas. Não trocar o controlador ou adicionar managers globais para esse problema.
- Sessão longa anterior reprovou pacing; gravação síncrona, térmica e concorrência têm evidência contextual, sem causa isolada. A nova prova é experimento pequeno separado, não autorização para multiplicar conteúdo.
- Casas de atlas repetidas, cards próximos, grandes pisos planos e horizonte genérico limitam o visual. O núcleo novo ainda usa o mesmo kit; não cumpre distinção artística da segunda cidade. Refinar composição, transições e vegetação antes de efeitos caros.
- Direção e câmera têm cobertura funcional, mas testes por autopiloto não aprovam prazer, gamepad ou mixagem. Física por eixo do rally continua isolada.

## Implementação concreta

`intercity_layout.gd`: coordenadas de autoria do eixo curvo com junções alinhadas. `intercity_builder.gd`: extensão offline do kit do corredor; reutiliza a célula urbana inicial sem edição, emite três células novas de 400 m e materiais/primitivas compartilhados. Manifesto registra regiões e vizinhos; HLOD e horizonte separados conservam massas distantes. As novas células mantêm colisores locais e piso plano compatível com o guard.

`drive_intercity.tscn`: mesmo script de mundo, carro, câmera, HUD, sol/ambiente e loader. Menu acrescenta **Viajar pelo Caminho da Serra**, mantendo a opção histórica como padrão. Até três células residentes, com quatro no mundo; não há geração procedural no jogo. Rural tem casa/refúgio/cercas, rodovia tem curva/acesso de beira de estrada, núcleo do interior tem casas espaçadas e rua transversal. Estrada asfaltada de 12 m; não são terra/cascalho, relevo de serra ou duas cidades finalizadas.

`intercity_smoke.gd`: regeneração isolada, equivalência da geometria/UVs/colisores/transforms, ida/volta por inputs, sondagem das três junções, identidade do player/câmera/HUD, reset e residência. Em janela real usa captura existente por perna; teleporte diagnóstico/virada/screenshots ficam fora da série. Suite integrada ao runner completo.

## Limites e próximos passos

Prova funcional de ligação entre usos do território, aproximadamente 1,38 km de viagem. Cidade A é recorte da avenida, não integração do Bairro do Sol inteiro; Vila da Serra é implantação provisória e plana. Sem tráfego, eventos/garagem novos, save de mundo, HLOD por distrito ou apoio irregular. Não houve avaliação humana de diversão. Dados de 16 GB não validam 8 GB; Windows nativo e hardware moderno continuam abertos.

Prioridade: medir três passagens por perfil e pacing prolongado; corrigir custos comprovados; avaliar direção/câmera/áudio; revisar autoria das transições e núcleo interior; depois contrato de alturas, alternativa viária e conexão com Bairro do Sol. W1/W3/W4 não são considerados concluídos. [Plano W0–W6](../development-plan.md).

A bateria consolidada passou em **338 verificações + seis testes Python**; builds locais Linux/Windows atualizados e pacote Linux validado em **13 checks**, incluindo recursos/colisão do destino remoto. Resultados gráficos são duas pernas por GPU/preset, não três repetições ou certificação longa. Windows nativo continua pendente.
