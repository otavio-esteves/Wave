# Wave

A Vila das Figueiras usa física Jolt, sombras agrupadas e resolução 3D adaptativa nos perfis Econômico e Equilibrado. O Gol reage à direção e ao ponto das batidas. Seu motor muda de timbre sob carga e ao soltar o acelerador, e impactos, raspadas e meio-fios têm retorno sonoro próprio. [Estudo, medições e validação](docs/performance.md#otimização-colisões-e-áudio-na-vila-das-figueiras)

A revisão de tempo de quadro da Vila das Figueiras reduz o custo das sombras, das texturas e das consultas de piso. No Dell de referência, a Avenida em Equilibrado passou de 34,9 para 42,7 FPS na Radeon. Na Intel, o P95 da Avenida ficou em 78,5 ms no pacote final. [Estudo, medições e capturas](docs/performance-results/2026-11-22/tempo-de-quadro-figueiras/README.md)

A otimização da Vila das Figueiras prepara as colisões e as rotas do tráfego no mapa gerado, consolida instâncias estáticas e preserva o acabamento dos pavimentos. [Estudo, medições e capturas antes e depois](docs/performance-results/2026-11-22/otimizacao-figueiras/README.md)

A **Baixada do Arroio** amplia a Vila das Figueiras com **1,55 km de vias**, dois novos tabuleiros sobre o arroio e 27,9% a mais de terreno físico. A descida da avenida, a Fiação, a travessa coberta e os sobrados da subida têm materiais e silhuetas próprios. **M / Share** abre as provas **Avenida da Baixada** e **Rota Livre do Arroio**. Na rota livre, a ordem dos três checkpoints fica a cargo do jogador. [Estudo de referências, capturas e validação](docs/development-results/2026-11-22/baixada-do-arroio/README.md)

A revisão da Vila das Figueiras trabalha a leitura da cidade à altura do Gol. Comércio e estação receberam fachadas e estruturas próprias, o Passo ganhou cortes de basalto e vegetação de encosta, e o horizonte passou a ter cristas em várias profundidades. A câmera interpola o movimento e antecipa curvas e rampas. O Gol divide aderência por roda entre frear e virar, enquanto o tráfego calcula a parada pelo para-choque. [Estudo, comparação, condução e desempenho](docs/development-results/2026-11-22/figueiras-conducao-e-serra/README.md)

A Galeria da Praça, o Pátio da Estação e a Estrada do Passo acrescentam cerca de **613 m** de ligações dirigíveis à Vila. O Mercado, a Praça e a ponte sobre o arroio foram redesenhados. O Gol usa carga, suspensão e aderência por roda. A Copa da Vila passa por cinco áreas e guarda o recorde limpo, os parciais e o fantasma no mesmo piso. [Reconstrução da Vila, referências e medições](docs/development-results/2026-11-22/figueiras-rebuild/README.md)

O Wave abre direto na **Vila das Figueiras**, o primeiro bairro da cidade definitiva. A avenida de **21,4 m** tem quatro faixas, bolsões de estacionamento e um refúgio na travessia da Praça da Figueira. A Rua das Jabuticabeiras e a Alameda da Estação cortam dois dos nove quarteirões. A Estrada do Mirante passa por uma galeria na rocha, o Contorno das Águas acompanha o lago e a Estrada do Vale passa pelo arroio e pelo viveiro. [Comparações e validação](docs/development-results/2026-11-21/figueiras-urban/README.md) · [Proporções e referências](docs/design-references.md#proporções-e-desenho-urbano-da-vila-das-figueiras)

A **Estrada do Horto** acrescenta **342 m** de pista de mão dupla e quase **19 m** de desnível entre o acesso inferior e o ponto mais alto. Ela liga as ruas do lado oeste e dá acesso ao pátio da Casa das Sementes. Casas com terraços, cortes de rocha, arrimos, materiais e vegetação de encosta acompanham o percurso. [Revisão do Horto, estudo e medições](docs/development-results/2026-11-21/revisao-horto/README.md)

A **Rua do Mercado** liga dois acessos da avenida por um percurso de **158,6 m**. Ela passa por uma descida, pelo pátio de carga coberto e pela subida de retorno. A cobertura interfere na aderência e no spray em dia de chuva. [Circuito do Mercado e estudo de condução](docs/development-results/2026-11-21/circuito-mercado/README.md)

**M / Share** abre o mapa de relevo com doze provas e a Copa da Vila. Escolha uma prova e marque a largada para ver o caminho no minimapa local. **T / direcional superior** arma ou cancela a prova selecionada. **G / direcional direito** alterna a chuva, que muda a aderência nos pneus e tem recordes próprios. **V / Quadrado** percorre cinco câmeras, incluindo a cabine do Gol com instrumentos funcionais. Vinte e quatro carros circulam pela malha da Vila e da Baixada. O atalho das Oficinas liga as duas ruas do alto da Vila.

2026-11-19: [revisão gráfica, otimização e correções da auditoria](docs/development-results/2026-11-19/overhaul/README.md). Novo acabamento de pavimentos e janelas, céu e iluminação revistos, vegetação distante leve, agrupamento de pequenos objetos e carregamento de instâncias preparado offline. [Comparação visual](docs/development-results/2026-11-19/overhaul/index.html). A cidade mantém os 200 quarteirões e suas colisões. Para avaliar as novas distâncias de detalhe, selecione novamente **Econômico** ou **Equilibrado**; configurações salvas são preservadas.

2026-11-04: [revisão de dirigibilidade e sensação de velocidade](docs/development-results/2026-11-04/driving-feel/README.md): toque de freio de mão inicia drift deliberado, acelerador dosa o ângulo e contravolante recupera aderência. Câmera antecipa a trajetória, com FOV progressivo, e pneus/vento dão retorno sonoro. A aceleração gradual anterior é preservada. Avaliação jogada de sensação/câmera/áudio permanece pendente.

A [revisão de relevo natural](docs/development-results/2026-11-04/natural-relief/README.md) reforça as subidas e descidas da cidade existente: cerca de **52 m de desnível nas ruas**, colinas conectadas nos Jardins, vale e ondulações na Vila e Centro mais suave. A inclinação máxima medida é de **8,4%**, preservando a malha do terreno e o traçado dos 200 quarteirões. Ruas, calçadas, acessos, fundações, vegetação e colisões foram gerados novamente; bancos nas encostas recebem apoio nivelado. [Diagrama antes/depois](docs/development-results/2026-11-04/natural-relief/terrain-comparison.svg). O diagrama é um diagnóstico de alturas; a avaliação visual jogada continua pendente.

A revisão de [otimização de 2026-11-04](docs/performance-results/2026-11-04/surgical-optimization/README.md) compartilha malhas e materiais entre setores, acrescenta os LODs ausentes dos arbustos e estende a simplificação distante a casas e comércio no Econômico. Buffers compactos, consulta espacial do detalhe e preparação das colisões antes da entrada no mundo tratam carregamento e custo de atualização. As 34.170 formas de sólidos permanecem, com menos nós na sessão. Instalações novas começam no Econômico; preferências existentes são preservadas. Passaram 977 verificações Godot e 23 testes Python no projeto, mais 505 verificações no pacote. Linux/Windows foram reexportados. A etapa usa testes e diagnóstico headless, sem abrir a janela do jogo; desempenho gráfico e aparência em movimento ainda precisam de avaliação renderizada.

Jogo de direção arcade em evolução, com atmosfera brasileira, ciclo de dia e noite e otimização para o Dell Inspiron 5547. **Need for Speed: Most Wanted (2012)** é a referência de qualidade percebida, densidade, composição e velocidade. A Vila das Figueiras tem traçado e composição próprios.

Godot **4.7.2**, GDScript tipado e renderer principal **Compatibility**. A cidade piloto de 200 quarteirões, com Jardins do Vale, Vila Aurora e Centro Horizonte, permanece disponível para referência e regressão.

A revisão gráfica das Figueiras acrescenta um céu panorâmico, asfalto com desgaste, fachadas com marcas de umidade, vitrines com interiores e uma fonte animada. O Gol 1000 de 1993 ganhou carroceria refeita, com os vidros laterais separados pela coluna pintada, tampa traseira, para-choques, grade e lanternas redesenhados.

A revisão do Gol refina os vincos da chapa, os arcos de roda, os conjuntos ópticos e os para-choques. A cabine tem bancos de tecido com frisos, volante, espelhos e cintos modelados. Pintura e vidros refletem o panorama conforme o ângulo e a hora do dia, nos dois perfis gráficos. A [referência de época](docs/design-references.md#gol-1000-quadrado-1993) orienta o acabamento do modelo branco.

## Abrir e dirigir

Execute [Wave no Linux](builds/linux/Wave.x86_64) ou `builds/windows/Wave.exe`. O Gol começa na avenida da Vila das Figueiras, com o minimapa visível e os controles ativos. Abra a pausa com **Esc / Options** para reiniciar o carro, ajustar áudio e gráficos, acessar **Laboratórios** ou sair. Nos laboratórios, use **Voltar à Vila das Figueiras** para retornar.

No editor, abra `project.godot` e pressione F5. Pelo terminal:

```sh
godot --path .
```

Nesta máquina, o executável está em `~/Downloads/Apps/Godot_v4.7.2-stable_linux.x86_64`; substitua `godot` pelo caminho correspondente se necessário.

| Ação | Teclado / mouse | DualShock 4 | Gamepad padrão |
| --- | --- | --- | --- |
| Acelerar | W / ↑ | R2 | Gatilho direito |
| Frear / ré | S / ↓ | L2 | Gatilho esquerdo |
| Virar | A/D / ←/→ | Analógico esquerdo | Analógico esquerdo |
| Girar câmera | Mover mouse | Analógico direito | Analógico direito |
| Centralizar câmera suavemente | Parar de mover o mouse | R3 | Clique do analógico direito |
| Freio de mão | Espaço | X / cruz | A |
| Ligar / desligar faróis | L | L1 | Ombro esquerdo |
| Mapa da Vila ou da cidade piloto | M | Share | View / Back |
| Armar / cancelar a prova selecionada ou o passeio da cidade piloto | T | Direcional superior | Direcional superior |
| Mostrar / ocultar ajuda | H | Direcional esquerdo | Direcional esquerdo |
| Avançar horário em 3 horas (Figueiras e cidade piloto) | F6 | R1 | Ombro direito |
| Olhar para trás | C | Triângulo | Y |
| Trocar câmera | V | Quadrado | X |
| Chuva na Vila das Figueiras | G | Direcional direito | Direcional direito |
| Reiniciar | R | Círculo | B |
| Pausar | Esc | Options | Start |
| Confirmar / voltar nos menus | Enter / Esc | X / Círculo | A / B |
| Diagnósticos / captura | F3 / F4 | — | — |

Mouse e analógico direito permitem olhar ao redor nas câmeras externas e na cabine. Após **1,2 segundo sem movimento**, a câmera volta suavemente ao acompanhamento automático; R3 inicia o retorno imediatamente. Há limite vertical para evitar colocar a câmera sob o carro. Olhar atrás permanece uma troca direta. O cursor é capturado ao dirigir e liberado ao pausar, voltar ao menu ou perder o foco da janela.

Frear continuamente para engatar ré após parar. Pedais aceitam intensidade analógica, com zona morta de 3%; direção usa 12% e câmera 18% para reduzir drift dos analógicos. Na pausa: áudio, gráficos, reset, mapas e menu. Preferências em `user://wave-settings.cfg` são mantidas ao reiniciar. O HUD reconhece conexão/desconexão do controle e atualiza as instruções. [Validação de câmera e DualShock](docs/development-results/2026-10-09/camera-gamepad/README.md).

## Cidade piloto

A [revisão de composição de 2026-10-12](docs/art-results/2026-10-12/neighborhood-composition/README.md) prioriza identidade brasileira, aparência mais real e preenchimento dos bairros existentes. Fachadas mais próximas e contínuas, comércio, arborização de rua, jardins internos, mobiliário, quadras e playgrounds ocupam o mesmo traçado de 200 quarteirões. A cidade passa a reunir **3.319 imóveis, 449 arranha-céus, 9.942 árvores, 88.883 tufos de grama, 1.399 carros estacionados e 730 bancos detalhados**. Caixas-d’água, antenas, portões, varais, postes/fios e placas dão escala doméstica às ruas. Gramado, arbustos, copas e fachadas de vidro recebem novo acabamento; casas e árvores permanecem visíveis por mais distância. [Comparação interativa antes/depois](docs/art-results/2026-10-12/neighborhood-composition/index.html). Avalie em **Equilibrado**. A revisão passou 926 verificações Godot e 19 testes Python no projeto, mais 476 verificações no pacote; Linux/Windows foram reexportados. Conforme a direção atual, a otimização é a etapa seguinte.

A [revisão de acabamento visual de 2026-10-11](docs/art-results/2026-10-11/visual-refinement/README.md) concentra o trabalho no Gol e na cidade existente. Cabine aberta, painel, tecidos, borrachas, óticas, detalhes de rodas e reflexos locais refinam o veículo; a correção de sombras remove as listras no capô. Casas recebem janelas com interior sugerido, soleiras, persianas, floreiras, calhas e detalhes de entrada. Bancos de ripas, lixeiras, piso tátil, guias e pavimentos mais definidos acrescentam escala às ruas. O mapa permanece com 200 quarteirões; a prioridade passa a ser consolidar o visual antes da próxima etapa de otimização. Use **Equilibrado** para avaliar os materiais, as sombras e os reflexos locais.

A [continuação de 2026-10-11](docs/performance-results/2026-10-11/pilot-intel-profile/README.md) reduz o desenho de prédios distantes no Econômico e elimina os avisos de textura no encerramento criando apenas o céu usado pelo jogo. A comparação nativa na Intel passou de cerca de 13 para 21 FPS numa vista estática do centro. Os builds passaram 452 verificações exportadas; a meta de 30 FPS e o pacing do percurso continuam pendentes.

A [revisão ponto a ponto](docs/development-results/2026-10-10/point-by-point/README.md) acrescenta carregamento com progresso, geração transacional, física de sólidos por proximidade e variação de fachadas por cores de instância. Praça e oficina têm identificação; o passeio informa as próximas curvas. O código do gerador está separado em superfícies, cenário e arquitetura. A geometria continua residente em RAM; somente sólidos próximos ocupam o espaço físico. A medição gráfica desta revisão tem escopo de diagnóstico, conforme autorizado pelo usuário.

A [consolidação da cidade piloto](docs/development-results/2026-10-10/pilot-consolidation/README.md) divide o piso em malhas locais, reduz o custo de numeração, carros estacionados e colisões, separa detalhe de materiais do MSAA e simplifica o HUD. **T / direcional superior** inicia ou cancela o passeio opcional praça → oficina; estacione por dois segundos em cada destino. A rota aparece nos mapas. **H / direcional esquerdo** abre a ajuda completa. A retomada validou 857 verificações Godot no projeto, 14 testes Python e 401 verificações no PCK. A comparação renderizada desta revisão tem escopo de diagnóstico; a validação controlada continua pendente.

A cidade piloto reúne **430 trechos de rua e 200 quarteirões** em **7.569.408 m²**. O terreno tem quatro vezes a área da etapa anterior, preservada no [registro de 72 quarteirões](docs/development-results/2026-10-09/pilot-day-night/README.md). **Jardins do Vale** combina sobrados, jardins e ruas curvas em colinas. **Vila Aurora** reúne casas menores, prédios residenciais, padarias, mercados e cafés. **Centro Horizonte** usa uma malha mais reta e densa, avenidas largas, um conjunto de parques e torres com fachadas de vidro, tijolo ou pedra, recuos e coroamentos variados. A arquitetura é procedural original, inspirada na composição de Manhattan. As avenidas principais chegam a 24 metros. Um minimapa acompanha o carro e mostra os parques, enquanto o HUD identifica o bairro. As torres permanecem visíveis à distância e algumas janelas acendem à noite. A revisão de 2026-10-10 registrava **2.023 imóveis, 211 arranha-céus, 3.790 árvores em seis formas, 813 carros estacionados e 48.971 tufos de grama**; o inventário vigente está na revisão de composição acima. A revisão preenche as laterais dos quarteirões, reserva jardins internos e acrescenta **427 conjuntos de bancos/lixeiras**, alguns com abrigos de ônibus. Canteiros floridos, duas colinas adicionais, asfalto com tons por bairro e calçadas com variação de placas enriquecem a cidade existente. **M / Share** abre o mapa completo; arrastar/direcional move a vista, roda/L2/R2 controla zoom, clique/X coloca um marcador e Esc/Círculo retorna. O jogo e o relógio pausam durante a consulta. [Galeria atual](docs/art-results/2026-10-10/city-detail/index.html). Gramíneas, flores, bosques e caminhos preenchem os espaços livres. A [galeria dos três bairros](docs/art-results/2026-10-10/three-districts/index.html) mostra as novas vistas e a condução no pacote. Calçadas de três metros acompanham as curvas e se unem ao redor dos cruzamentos, com rebaixamentos nas entradas. Gramíneas ocupam os espaços livres; bases e muros acompanham o terreno, e os lotes são afastados para evitar sobreposição de casas. As entradas têm pavimento, portões, caixas de correio e numeração. Guias chanfradas e transições nas entradas suavizam a passagem do carro. O carro foi remodelado como um Gol 1000 quadrado de 1993: pintura branca, teto e tampa traseira corrigidos, grade larga com emblema, faróis retangulares, retrovisores pretos e rodas de aço. A carroceria está 6 cm mais alta, preservando o apoio das rodas e a condução. Faróis com feixes reais e lentes luminosas funcionam em todos os mapas; L ou L1 alterna o estado. Mantém verniz, vidros transmissivos, cabine modelada, lentes e pneus detalhados. A [comparação do Gol 1000](docs/art-results/2026-10-09/gol-1000/README.md) registra o resultado. Asfalto com grãos e desgaste, pedra com juntas, madeira e reboco acrescentam detalhe às superfícies. É uma cena gerada offline, salva em setores e recursos binários comprimidos, com o mesmo carro, câmera e HUD durante todo o passeio. Praça e oficina têm acessos pavimentados. O [plano atualizado](development-plan.md) concentra os próximos passos nesse lugar; a [revisão de árvores e realismo](docs/art-results/2026-10-08/jardins-realismo/README.md) reúne as novas comparações e medições. A [etapa com carroceria curva e materiais](docs/art-results/2026-10-08/jardins-mw2012/README.md) segue a direção visual de Most Wanted 2012. A [revisão das calçadas](docs/art-results/2026-10-08/jardins-do-vale/README.md) registra a etapa anterior. A [primeira versão](docs/development-results/2026-10-08/pilot-city/README.md) permanece como registro histórico.

O horário avança automaticamente: **24 minutos reais por dia completo**, começando às 16h30. Sol e lua percorrem o céu; a transição muda a luz ambiente, a névoa, os reflexos e as cores das nuvens. As estrelas aparecem à noite. Postes e janelas acendem gradualmente, com até oito luzes locais próximas ao carro. Pausar congela o relógio e as nuvens; F6/R1 avança três horas. O ciclo está integrado à cidade piloto; os laboratórios conservam seus ambientes anteriores. [Validação da expansão e do ciclo](docs/development-results/2026-10-09/pilot-day-night/README.md).

A [revisão de densidade de 2026-10-09](docs/art-results/2026-10-09/neighborhood-refresh/README.md) amplia as ruas para **11,5–14 m** e completa as frentes externas: **45 imóveis, 229 árvores volumétricas e 21 carros estacionados**, com telhados/alturas variados, jardins, conjuntos de árvores e massas distantes. O Hatch recebe para-choques arredondados, rodas abertas com discos/pinças, acabamento dos pneus/vidros, placas legíveis e lanternas de freio/ré funcionais. Céu original com nuvens alimenta os reflexos. [Comparação interativa antes/depois](docs/art-results/2026-10-09/neighborhood-refresh/compare.html). Equilibrado mostra sombras, mapas normais e reflexão local; Econômico conserva os modelos, texturas e céu. A densidade acrescentada ainda requer medição de desempenho na janela combinada.

## Laboratórios anteriores

No menu, **Viajar pelo Caminho da Serra** abre uma prova contínua: trecho urbano reutilizado da Avenida do Vale → 400 m rural → 400 m de rodovia com curvas suaves → 400 m de núcleo provisório do interior. Mesmo carro, câmera, céu e sessão; quatro células no manifesto e até três residentes. Aproximadamente 1,38 km entre os endpoints do teste. Não são duas cidades completas: piso plano, casas/árvores reaproveitadas e arte provisória. Bairro do Sol inteiro, relevo de serra, tráfego e atividades novos ainda não estão integrados.

A Vila da Serra recebeu [uma primeira revisão de autoria](docs/art-results/2026-10-07/vila-da-serra/README.md): calçadas, lotes variados, cruzamento e praça com abrigo/bancos. Quem chega encontra a praça à esquerda, depois do cruzamento; a entrada e a rua lateral são dirigíveis. Builds locais Linux/Windows atualizados; aprovação artística e custo gráfico desta revisão continuam pendentes.

O percurso também recebeu [placas e paradas mais legíveis](docs/art-results/2026-10-07/transicoes/README.md): parada rural à esquerda, refúgio rodoviário à direita com acesso pavimentado, cobertura e vagas, e orientação até a vila/praça e na volta ao Bairro do Sol. Árvores agrupadas substituem as filas regulares no campo/rodovia. Builds atualizados e acessos testados; avaliação humana em movimento continua pendente.

A [revisão de orientação de 2026-10-08](docs/art-results/2026-10-08/orientacao-das-paradas/README.md) acrescenta setas e avisos de entrada nos dois sentidos para a parada rural, o refúgio e a praça. Os painéis ficaram maiores; na volta, o aviso do Bairro do Sol foi afastado para deixar o refúgio visível. Builds Linux/Windows atualizados e acessos validados no pacote exportado; legibilidade em movimento continua pendente.

A [revisão com a câmera real durante a viagem](docs/art-results/2026-10-08/acessos-em-movimento/README.md) acrescenta limites e setas pintados nas três entradas e faz os pisos rural/rodoviário acompanharem a curva. As comparações usam condução por inputs com alvo de 80 km/h; entradas/saídas foram conferidas separadamente no projeto e no pacote exportado. Builds atualizados; avaliação humana de leitura, frenagem e manobra permanece pendente.

A [revisão das frentes das paradas](docs/art-results/2026-10-08/frentes-das-paradas/README.md) organiza a parada rural e o refúgio com balizadores laterais, limites pintados e quatro vagas em cada pátio; o refúgio também ganha piso distinto junto ao abrigo. Uma nova fixture freia a partir de 80 km/h, entra, para e volta à faixa na parada rural, no refúgio e na praça, nos dois sentidos: 19 checks, também aprovados no PCK. Builds Linux/Windows atualizados; avaliação humana de leitura e manobra continua pendente.

**Experimentar relevo da serra**, no menu, abre uma pista separada de 800 m: subida/descida de 18 m, quatro células e até três residentes. O loader reutiliza o ciclo existente e verifica colisão real sob o carro. [Prévias, testes e limites](docs/development-results/2026-10-07/elevation/README.md). É uma prova de apoio em altura com visual simples; a serra ainda não está integrada à viagem. O teste de ida/volta usa aproximadamente 65 km/h; avaliação humana e alta velocidade nesse relevo continuam pendentes.

A pista agora tem [curvas, acostamentos e balizadores](docs/development-results/2026-10-07/elevation-curves/README.md), além de asfalto com textura reaproveitada. A condução automatizada a 65 km/h e pelos dois acostamentos passa; a fixture de 108 km/h conserva apoio, mas sai da faixa e ainda não está aprovada. Builds locais atualizadas; avaliação humana continua pendente.

O laboratório recebeu também [paisagem e Mirante da Serra](docs/development-results/2026-10-07/serra-landscape/README.md): morros no horizonte, vegetação em grupos, chão texturizado e uma parada perto da crista. Na ida, procure a placa e entre à direita na área ampla ao lado do abrigo. Entrada/saída são dirigíveis; a pista continua separada do Caminho da Serra.

Ao abrir a pista, o HUD inicia o [Passeio ao Mirante](docs/development-results/2026-10-07/lookout-trip/README.md): siga a estrada, entre à direita e pare nas vagas marcadas por dois segundos. Segure Espaço para manter o freio de mão. A chegada aparece no HUD; R repete o passeio. Você pode continuar explorando depois de chegar. O progresso vale para a sessão atual.

A cena está em [drive_intercity.tscn](scenes/world/drive_intercity.tscn). Os builds locais Linux/Windows foram atualizados e o pacote passou 13 checks de acesso/apoio, incluindo a célula remota do interior; Windows nativo permanece pendente. Também é possível abrir com F5 ou `godot --path .`. [Auditoria, resultados e limitações](docs/reorientation-2026-10-07.md).

## O que existe hoje

Gol 1000 com geometria própria, controlador arcade em `CharacterBody3D`, limite de 220 km/h, aderência/freio de mão, colisões, contato de quatro rodas, degraus e suspensão visual; câmera com SpringArm/FOV e capô. Bairro do Sol gerado offline com ruas/casas/comércio/posto, Circuito do Sol de 3,24 km com checkpoints, rally de 1,52 km com terreno/LOD/poeira e pista técnica. Motor/pneus/vento/ambiente/música provisórios sintetizados offline, menus, teclado/gamepad e testes automatizados.

A [primeira revisão de condução de 2026-10-09](docs/development-results/2026-10-09/arcade-handling/README.md) acrescenta entrada de curva gradual, recuperação de aderência sob aceleração, dissipação de derrapagem e transferência visual de peso. Após avaliação jogada, a [revisão seguinte](docs/development-results/2026-10-09/mw2012-acceleration/README.md) reduz o ganho de velocidade sob acelerador em cerca de 60%: 0–100 km/h em 8,0 s, antes 3,2 s, mantendo 220 km/h alcançáveis. Most Wanted 2012 passa a ser a referência de condução e arte; a equivalência de sensação permanece sujeita a avaliação jogada.

A **Avenida do Vale** acrescenta 600 m de avenida, duas ruas laterais, casas/sobrados, oficina, mercado, postes/fios, árvores em impostores, asfalto remendado e horizonte de fim de tarde. É gerada offline, com seed 5547, materiais simples e o mesmo carro.

Os mapas anteriores são laboratórios funcionais preservados. O rally possui um perfil experimental de pneus por eixo; ele não define a física do mundo aberto. Há uma prova de streaming com três células da Avenida do Vale, disponível em **Avenida do Vale · streaming**, preservando a versão estática. Ainda não há streaming integrado aos mapas antigos, tráfego, cidades definitivas ou vertical slice artístico aprovado. O bairro ainda carrega inteiro, embora use lotes espaciais para culling. Arte, timbre/mixagem e sensação exigem avaliação jogada.

## Gráficos e meta mínima

**Requisitos de produto:** Inspiron 5547/Haswell e 8 GB; Econômico na HD 4400 com 854×480 inicial e ≥30 FPS sustentados, Equilibrado na R7 M260 com 1280×720 inicial e ≥30 FPS sustentados. Qualidade para hardware moderno. A validação final desses perfis permanece aberta; a máquina medida tem 16 GB, não comprova o limite de 8 GB. Aprovação na Radeon não substitui o requisito econômico.

| Preset | Configuração inicial |
| --- | --- |
| Econômico (`economy`) | 854×480 ajustável, sem sombras/MSAA/efeitos caros |
| Equilibrado (`medium`) | 1280×720 ajustável, sombras e MSAA 2× |
| Qualidade (`high`) | 1920×1080, sombras/MSAA e cosméticos opcionais |
| Legacy (`legacy`, adicional) | 1280×720 sem sombras/MSAA, preservado para benchmarks e preferências anteriores |

Os IDs e preferências existentes permanecem compatíveis; instalações novas começam no Econômico. Cada perfil precisa de rota gráfica própria e validação longa, conforme [performance.md](docs/performance.md).

Econômico e Equilibrado ativam **Simplificar prédios e vegetação distantes**, independentemente da resolução, sombras e materiais. O Equilibrado mantém o detalhe próximo por mais distância. A opção **Detalhes urbanos por mais distância** permite escolher esse alcance separadamente; Qualidade e Legacy preservam a representação completa. Alterar a resolução conserva essas escolhas. Preferências antigas não são substituídas silenciosamente.

Todos os presets funcionam em Compatibility e não trocam backend. Sombras e pós-processamento têm controles separados. HIGH não ativa SSIL/volumetria automaticamente. A opção desses cosméticos do rally só está disponível quando o processo foi iniciado em Forward+; nenhuma parte essencial do novo visual deverá depender dela. Tela cheia usa tamanho do monitor, registrado no benchmark. Preferências antigas de resolução/sombras/MSAA continuam válidas.

F4 registra até 180 s de condução: CSV amostrado, CSV por quadro e JSON com configuração, CPU/GPU, renderer, tamanho real, média, P95/P99, 1% low aproximado, picos e monitores de custo. Tempo CPU/GPU de viewport é opt-in em diagnóstico separado (`--profile-render-time`), pois as queries causaram stalls neste driver Intel. Pausa é excluída; alterar gráficos/trocar de mapa encerra a captura. Headless recusa FPS gráfico. Reprodução e limitações em [performance.md](docs/performance.md).

## Validar

O [preenchimento e mapa completo de 2026-10-10](docs/development-results/2026-10-10/city-detail/README.md) têm cobertura consolidada de **812 verificações Godot e dez testes Python**, com **193 verificações no pacote final**. A regeneração confere malhas, colocações e colisões; os seis circuitos mantêm apoio e asfalto. As [prévias atuais](docs/art-results/2026-10-10/city-detail/index.html) e a [comparação](docs/art-results/2026-10-10/city-detail/compare.html) permitem revisar o preenchimento. Linux e Windows foram atualizados; FPS sustentados e avaliação jogada continuam pendentes.

A [expansão de 2026-10-09](docs/development-results/2026-10-09/pilot-expansion/README.md) passou 739 verificações Godot e 10 testes Python no projeto, com retomada após isolar a entrada do controle físico na fixture da serra, e 316 verificações no pacote exportado. Linux e Windows estão atualizados; o Linux nativo iniciou corretamente. [Comparação do bairro ampliado](docs/art-results/2026-10-09/pilot-expansion/compare.html). Esta etapa valida geometria, acessos e comportamento; desempenho renderizado continua pendente para a janela combinada.

```sh
GODOT_BIN=~/Downloads/Apps/Godot_v4.7.2-stable_linux.x86_64 bash scripts/tools/check_project.sh
```

Os runners de verificação requerem Bash, Python 3, `ripgrep` (`rg`) e `timeout` do GNU coreutils. Além das falhas das assertions, eles reprovam erros inesperados do motor e avisos de objetos vazados; a suite de streaming permite somente os erros de arquivo ausente provocados pelo seu teste de falha de I/O.

A revisão de árvores/realismo passou **202 verificações direcionadas**: cidade 32, travessias de calçada 56, direção 33, navegação 33, menu 29 e captura/configurações gráficas 19. A regeneração confere também as árvores instanciadas e seus LODs. O pacote exportado passou 103 verificações do bairro/guias/menu; o menu passou novamente com renderização real. Ambos os builds foram atualizados. A etapa de carroceria e materiais repetiu 103 verificações no pacote final, com 34,7 FPS na Intel/Econômico e 50,3 na Radeon/Equilibrado em diagnósticos curtos; a Intel ainda apresenta quedas abaixo de 30. [Etapa atual](docs/art-results/2026-10-08/jardins-mw2012/README.md). [Comparações, logs, custo visual e limites](docs/art-results/2026-10-08/jardins-realismo/README.md).

A validação da primeira versão da cidade aprovou **635 verificações de comportamento e dez testes Python**, retomando o runner após atualizar a seleção do mapa na fixture de streaming. O runner também verifica os laboratórios anteriores, áudio, configurações, física e ferramentas de pacing em diretórios temporários. Os testes usam cenas reais e inputs; não substituem benchmark renderizado, gamepad conectado, escuta ou avaliação humana de diversão.

Para executar as seis fixtures sequencialmente e guardar contexto/identidade do código em uma pasta nova:

```sh
DRI_PRIME=0 GODOT_BIN=~/Downloads/Apps/Godot_v4.7.2-stable_linux.x86_64 bash scripts/tools/benchmark_reference.sh /tmp/wave-reference-new all
```

O runner aceita `urban`, `residential`, `vegetation`, `speed`, `corridor` ou `streaming` no lugar de `all`. Rotas individuais com janela, sem `--headless` ou `--fixed-fps`, uma execução por vez:

```sh
DRI_PRIME=0 XDG_DATA_HOME=/tmp/wave-urban godot --path . --rendering-method gl_compatibility --script res://tests/rendered_route.gd -- --legacy
DRI_PRIME=0 XDG_DATA_HOME=/tmp/wave-residential godot --path . --rendering-method gl_compatibility --script res://tests/rendered_route.gd -- --legacy --residential
DRI_PRIME=0 XDG_DATA_HOME=/tmp/wave-vegetation godot --path . --rendering-method gl_compatibility --script res://tests/rally_rendered.gd -- --legacy
DRI_PRIME=0 XDG_DATA_HOME=/tmp/wave-speed godot --path . --rendering-method gl_compatibility --script res://tests/high_speed_smoke.gd -- --legacy
```

`DRI_PRIME` é específico do Linux/Mesa; confirme a GPU no log/JSON. Use pastas distintas e nunca compartilhe preferências pessoais com ensaios. Rodovia/tráfego próprios aguardam conteúdo; a avenida externa e o rally são fixtures identificadas, não provas do mundo futuro.

A passagem por calçadas e mudanças de inclinação recebeu uma [correção no controlador](docs/development-results/2026-10-07/ground-navigation/README.md), com testes de guias em frente/ré/diagonal, em baixa velocidade e a 64,8 km/h, além das calçadas reais da avenida. A revisão seguinte [corrige o acesso ao Rally da Serra e verifica os oito mapas](docs/development-results/2026-10-07/rally-ground-access/README.md), incluindo bordas de asfalto/cascalho, acostamentos, rampas e calçadas.

## Pipeline offline e builds

Editar geradores, gerar → validar → salvar → carregar. O jogo não executa geração procedural pesada. O gerador da cidade piloto salva terreno, ruas, calçadas, lotes e colisões. Comandos:

```sh
godot --headless --path . --script res://scripts/tools/build_figueiras.gd
godot --headless --path . --script res://scripts/tools/build_pilot_city.gd
python3 scripts/tools/build_corridor_signs.py
python3 scripts/tools/build_intercity_signs.py
godot --headless --path . --editor --quit
godot --headless --path . --script res://scripts/tools/build_corridor.gd
godot --headless --path . --script res://scripts/tools/build_corridor_cells.gd
godot --headless --path . --script res://scripts/tools/build_intercity.gd
godot --headless --path . --script res://scripts/tools/build_neighborhood.gd
godot --headless --path . --script res://scripts/tools/build_hatch_car.gd
godot --headless --path . --script res://scripts/tools/build_elevation.gd
python3 scripts/tools/build_race_textures.py
godot --headless --path . --script res://scripts/tools/build_race_track.gd
python3 scripts/tools/build_rally_textures.py
godot --headless --path . --script res://scripts/tools/build_rally_stage.gd
python3 scripts/tools/build_audio.py
```

Bairro, circuito, rally e corredor usam a API compartilhada `OfflineSceneBuilder`, sem depender dos internos do layout do bairro. Os três geradores aceitam `-- --output=user://teste.tscn` para regeneração isolada; o runner usa essa opção e compara geometria, colisões e visibilidade com as cenas preservadas.

Geradores sobrescrevem seus artefatos: autoria deve entrar no layout/parâmetros/overrides, não se perder ao regenerar. O pinheiro produzido por IA é um PNG independente preservado. Origem dos recursos em [assets.md](docs/assets.md). Prévias usam scripts `build_*_previews.gd` com janela e ficam em `builds/previews`.

Exportar Linux/Windows com templates 4.7.2 instalados:

```sh
GODOT_BIN=~/Downloads/Apps/Godot_v4.7.2-stable_linux.x86_64 bash scripts/tools/export_builds.sh
```

O pacote inclui explicitamente os manifestos JSON de `scenes/world/cells/`. Para verificar o menu, o carregamento das células, a condução e o retorno usando os recursos exportados (com a engine do editor como harness, não como benchmark):

```sh
wave_repo="$PWD"
cd /tmp
XDG_DATA_HOME=/tmp/wave-pack-access godot --headless --main-pack "$wave_repo/builds/linux/Wave.pck" --script "$wave_repo/tests/exported_menu_smoke.gd"
```

Para validar entradas/saídas do rally e transições de chão nos outros sete mapas usando apenas os recursos do pacote:

```sh
GODOT_BIN=~/Downloads/Apps/Godot_v4.7.2-stable_linux.x86_64 bash scripts/tools/check_exported_access.sh
```

A [retomada da revisão de acesso](docs/development-results/2026-10-07/rally-ground-access/README.md) passou os 140 checks no PCK. A [revisão das frentes das paradas](docs/art-results/2026-10-08/frentes-das-paradas/README.md) amplia o runner para **174 checks funcionais**, incluindo 15 de acesso às paradas e 19 de aproximação/manobra, mais a guarda que exige recursos exportados. O runner usa fixtures externas e preferências isoladas; aceita outro PCK como primeiro argumento. Windows nativo e sensação de condução ainda exigem avaliação própria.

Templates locais em `tools/godot/export_templates` também são aceitos. Distribuir a pasta completa da plataforma, incluindo `Wave.pck`. Os launchers `Wave-quality` agora iniciam HIGH em Compatibility. Os builds locais Linux/Windows foram reexportados com a revisão das frentes das paradas; o PCK passou 174 verificações funcionais de acesso/manobra e 13 do menu/apoio remoto; Windows nativo continua pendente; a sessão longa documentada abaixo reprovou pacing.

## Plano e decisões

[Plano vigente](development-plan.md) · [Revisão arquitetural](docs/architecture.md) · [Contrato de streaming](docs/world-streaming.md) · [Direção de arte](docs/art-direction.md) · [Orçamento](docs/performance-budget.md) · [Medições](docs/performance.md) · [Histórico arquivado](docs/history.md).

A variante de células preserva silhuetas distantes com HLOD offline e troca visual com histerese. Oficina e mercado receberam uma primeira revisão de placas, acessos, pintura e desgaste com materiais existentes, preservando as colisões. [Comparações e custo medido](docs/performance-results/2026-10-06/hero-areas/README.md). A primeira otimização de entrada reduziu a média fria de 5,70 para 4,89 s na Radeon (**14,17%**), em três pares com fontes idênticas; [evidência](docs/performance-results/2026-10-06/startup-material/README.md). As duas capturas prolongadas novas preservaram apoio, mas tiveram picos; pacing/térmica continuam pendentes. Prioridade atual: continuar autoria localizada do percurso e avaliar a Vila da Serra. O diagnóstico dos picos permanece preliminar por uso concorrente da máquina; retomar medições e otimização numa janela combinada de uso exclusivo. Expansão, trânsito e atividades vêm depois dos gates de qualidade e pacing.

Prévia atual: [Mercado do Vale — Legacy 720p](docs/performance-results/2026-10-06/hero-areas/after-views/corridor-2.png). Fachadas e árvore originais via image_gen: [prompts e origem](assets/textures/corridor/provenance.json).

A prova de células tem [contrato e limites](docs/world-streaming.md), guard de apoio e telemetria de carga/ativação/liberação. O [diagnóstico de entrada/memória](docs/performance-results/2026-10-06/streaming-diagnostics/README.md) compara cache novo/reutilizado e doze travessias com/sem captura: contagens estáveis e RSS desacelerando, sem certificar sessões longas ou 8 GB. Ela usa piso plano; o fallback de atraso segura a condução e não deve ocorrer nas travessias normais.

HLOD da avenida: [comparações visuais, benchmarks e limites](docs/performance-results/2026-10-06/hlod/README.md). O custo adicional da entrada fria recebeu uma primeira redução por compartilhamento de variante de material, mas permanece pendente; continuidade distante e menor desenho durante a rota também foram medidos.

O menu inclui limite persistente de 30/60/120 FPS ou sem limite. A sessão automatizada com foco contínuo completou 44 pernas em dez minutos, mas teve 71 quadros >50 ms e lacunas na rotação dos arquivos de captura; estabilidade longa permanece pendente. [Telemetria, resultados e próximos ajustes](docs/performance-results/2026-10-06/pacing-thermal/README.md).

O [diagnóstico seguinte na Intel](docs/performance-results/2026-10-07/intercity-pacing/README.md) reproduziu o pico de retorno em seis sessões com/sem captura e isolou a troca para detalhe urbano como gatilho: mudar a distância apenas na fixture deslocou a travada 60 m. A correção do custo de desenho e os gates de estabilidade continuam pendentes. Runner reproduzível: `scripts/tools/benchmark_intercity_pacing.sh`.

A reorientação de 2026-10-07 usa marcos W0–W6 e acrescenta a fixture `tests/intercity_smoke.gd` ao runner. Medição gráfica da prova, com pastas de preferências isoladas e sem testes simultâneos:

```sh
DRI_PRIME=0 XDG_DATA_HOME=/tmp/wave-sol-serra-new godot --path . --rendering-method gl_compatibility --script res://tests/intercity_smoke.gd -- --foreground --no-vsync --previews
# Radeon / Equilibrado: DRI_PRIME=1, outra pasta XDG, acrescentar --balanced.
```

`--no-vsync` é condição explícita do ensaio, não mudança global do produto. Prévias e teleporte de sondagem ficam fora das capturas. Próximas prioridades: avaliar o bairro ampliado em movimento e concentrar a próxima etapa em carro, iluminação e acabamento gráfico. Pacing e medição por perfil ficam pendentes para uma janela combinada de uso exclusivo. [Plano vigente](development-plan.md).
