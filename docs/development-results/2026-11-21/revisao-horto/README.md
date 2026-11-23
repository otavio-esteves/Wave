# Vila das Figueiras — revisão do Horto

A Estrada do Horto liga as duas ruas residenciais no oeste da Vila. São 342 m de pista de mão dupla com 8,6 m de largura, curvas em desnível e um pátio acessível pelos dois lados. A altura vai de 42,85 m no acesso inferior a 61,45 m no ponto mais alto. O pátio de paralelepípedos dá acesso visual à Casa das Sementes e permite estacionar ou retornar à pista. A Volta do Horto é a sexta prova do mapa.

| Via | Largura de pista |
| --- | ---: |
| Ruas locais | 7,6 m |
| Rua das Jabuticabeiras | 7,8 m |
| Estrada do Horto | 8,6 m |
| Alameda da Estação | 9,4 m |
| Coletora | 12,0 m |
| Avenida, com separador e estacionamento | 21,4 m |

A caixa de colisão do Gol mede 1,60 m de largura. Uma faixa da avenida comporta 2,31 larguras do carro, e cada sentido do Horto tem aproximadamente 2,69 larguras antes do alargamento das bocas. A avenida tem quatro faixas de 3,7 m, separador de 1,9 m, bolsões de 2,35 m de cada lado e calçadas de 4,25 m. Na encosta, o acostamento, o muro e a abertura do pátio dão referências distintas da distância lateral. O perfil do Horto e os encontros com as ruas foram verificados nas próprias formas de colisão. [Manual de travessias urbanas do DNIT](https://www.gov.br/dnit/pt-br/assuntos/planejamento-e-pesquisa/ipr/coletanea-de-manuais/vigentes/ipr_740_manual_projetos_geometricos_travessias_urbanas.pdf)

## Referências e aplicação

- **Assetto Corsa.** A Kunos mostra como abas, depressões e inclinações do piso entram na simulação e como suspensão, pneus e áudio tornam o resultado perceptível. Verifiquei a integração do terreno da Vila com contatos reais das quatro rodas. O Gol mantém o modelo arcade e ganhou cinco relações ligadas à rotação da roda, trocas com interrupção de torque e resposta diferente quando os pneus dianteiros e traseiros passam por superfícies diferentes. Os amortecedores da carroceria respondem a ondulação, frenagem e alteração de apoio. [Kunos Simulazioni](https://assettocorsa.gg/assetto-corsa/) · [Entrevista técnica com a Kunos](https://www.unrealengine.com/developer-interviews/assetto-corsa-competizione-leans-into-realism-to-create-the-ultimate-racing-sim)
- **Need for Speed: Most Wanted (2012).** Craig Sullivan descreve o trabalho da Criterion com superfícies e espaços arquitetônicos de Boston e com ruas que sugerem a próxima trajetória. O Horto usa uma subida com muros, um pátio em curva com fachada própria e uma descida mais aberta. A alameda e a avenida usam grupos de fachadas com escala distinta. O estudo de vitrines da Playground também orientou o deslocamento aparente dos interiores do comércio conforme o ângulo de visão. [Craig Sullivan, Criterion](https://www.theguardian.com/technology/gamesblog/2012/oct/17/need-for-speed-most-wanted-preview) · [Gareth Harwood, Playground Games](https://www.gamedeveloper.com/design/game-tech-deep-dive-a-window-into-playground-games-latest-shader-development)
- **Burnout Paradise.** O relato de Jack Griffin liga a malha contínua ao orçamento de desenho em movimento. A masterclass de Matthew Harris também descreve amortecimento e antecipação independentes da câmera. A câmera do Gol antecipa a direção e lê a inclinação da pista adiante. Ela recolhe perto de obstáculos e volta à distância anterior gradualmente. O ajuste do campo de visão é horizontal. A vegetação ganhou silhuetas distantes agrupadas por área, e a geometria estática e as sombras têm orçamentos específicos por perfil. [Jack Griffin, Criterion](https://www.youtube.com/watch?v=jYpbXhl-4h0) · [Vehicle Feel Masterclass, GDC 2018](https://media.gdcvault.com/gdc2018/presentations/Harris_Matthew_VehicleFeelMasterclass.pdf)

Os três jogos foram estudados por meio de material de seus desenvolvedores, capturas oficiais e apresentações técnicas. A validação dirigível foi feita no Wave com entradas automatizadas e registradas.

## Gráficos, carro e controles

As casas da encosta têm pavimentos recuados, volumes e telhados distintos, janelas em profundidade e terraços. No Horto, o terreno tem cortes de rocha, arrimos e acostamentos acompanhando a inclinação. Três imagens originais entraram no cenário como rebocos, azulejos da Casa das Sementes e paralelepípedos do pátio. O ciclo de luz também muda as gradações das serras. Os pés das árvores acompanham o terreno da malha exportada. [Rebocos](../../../../assets/textures/figueiras/rebocos-da-vila.provenance.json) · [Azulejos](../../../../assets/textures/figueiras/azulejos-do-horto.provenance.json) · [Pavimento](../../../../assets/textures/figueiras/pedra-do-horto.provenance.json)

A cabine tem dois mostradores no painel e retrovisor que renderiza rua, fachadas e tráfego com profundidade de visão limitada. Na chuva, gotas no vidro mudam na área varrida pelo limpador. A visão externa indica marcha, movimento do motor e superfície no HUD. Use **V** para alternar câmera, **M** para abrir o mapa e selecionar a Volta do Horto e **G** para alternar a chuva.

## Percurso e capturas

[Vídeo do percurso](percurso.mp4) · [Avenida anterior](avenida-anterior.jpg) · [Avenida revisada](avenida.jpg) · [Encosta](encosta.jpg) · [Pátio](horto.jpg) · [Casa das Sementes](sementes.jpg) · [Cabine na chuva](cabine-chuva.jpg) · [Mapa das seis provas](atlas.jpg)

O vídeo de 23,8 s mostra a avenida, a encosta, o pátio e a cabine na chuva. As imagens vêm do renderizador Compatibility com o perfil Equilibrado. A gravação usa um quadro a cada três passos de física a 60 Hz. A comparação da avenida repete a posição de largada e o horário nas duas versões.

## Validação de condução

O ensaio do Horto completou a prova em **33,499 s**, com **1,83 m** de margem mínima entre o centro do Gol e a borda do asfalto. O teste independente percorreu a via nos dois sentidos, com margens de **2,15 m** e **1,63 m**. Em todos os percursos, as rodas mantiveram apoio. O ensaio do pátio dirigiu sobre os paralelepípedos entre as duas aberturas. O teste da rua residencial também repetiu a arrancada a partir do repouso depois do ajuste de torque em primeira.

O teste de câmera colocou um colisor atrás do Gol para medir o recolhimento e o retorno gradual. Na pista, os testes observaram a antecipação da inclinação, a queda real de RPM na troca de marcha e a diferença de aderência entre os eixos quando parte do carro passa da pista à calçada.

A cena detalha 221 edificações e 758 árvores de rua e jardim. Os quatro conjuntos da Vila passaram no PCK final, com 70 verificações de acesso, relevo e circulação, 18 de condução, 35 de tráfego, mapa e clima e 12 da revisão do Horto. Também passaram 20 verificações de câmera e controle, 31 de dirigibilidade, 37 dos dois modelos de condução, 12 de reflexos, 18 de áudio e 59 do ciclo de luz. O executável Linux iniciou nativamente e o Windows iniciou no Wine 10.

## Otimização

A vegetação próxima mantém suas malhas em setores de 42 m. As árvores mais distantes usam representações agrupadas com silhuetas projetadas a partir do atlas. Os objetos arquitetônicos opacos compartilham material e malha por setor. A sombra de contato do Gol continua seguindo os triângulos da pista e atualiza um buffer sempre que precisa desenhar um novo quadro. O perfil Equilibrado limita a sombra direcional a um mapa com alcance de 72 m. O retrovisor renderiza uma seleção de objetos algumas vezes por segundo.

As duas versões exportadas percorrem os trechos com o mesmo roteiro de direção e pedais comandado a cada passo de física. A cena roda no i7-4510U com Godot 4.7.2 Compatibility, Mesa e X11. O relógio da cidade fica em 16h15. As tomadas têm janela em foco e VSync desligado. No Econômico, a janela tem 854 × 480 com viewport de 569 × 320. No Equilibrado, ambos têm 1280 × 720. O P95 indica o tempo que 95% dos quadros levaram ou ficaram abaixo. O ensaio usa tempo real e inclui o tráfego. [Rotina de medição](../../../../tests/figueiras_benchmark.gd)

| Trecho e configuração | FPS médio anterior → revisão | P95 anterior → revisão | Triângulos por quadro anterior → revisão |
| --- | ---: | ---: | ---: |
| Avenida, Intel HD 4400 Econômico | 23,9 → 34,8 | 109,2 → 77,3 ms | 598 mil → 355 mil |
| Avenida, Radeon R7 M260 Equilibrado | 26,9 → 32,5 | 42,6 → 35,7 ms | 1,05 milhão → 549 mil |
| Mirante, Intel HD 4400 Econômico | 22,6 → 23,3 | 99,2 → 76,4 ms | 324 mil → 178 mil |
| Mirante, Radeon R7 M260 Equilibrado | 34,6 → 36,7 | 38,3 → 38,5 ms | 385 mil → 229 mil |

No Mirante, a queda de geometria trouxe ganho pequeno na taxa média da Intel. O P95 melhorou na Intel e ficou praticamente igual na Radeon. A cena ainda tem variações de tempo de quadro, e os trechos medidos deixam a meta de 30 FPS sustentados em aberto.

Em uma repetição de 30 s e cerca de 340 m na avenida, a Radeon passou de **28,0 para 33,3 FPS**, com P95 de **41,8 para 34,9 ms**. A Intel passou de **24,4 para 27,4 FPS**, com P95 de **104,4 para 79,6 ms**.

Na cabine com chuva, a Radeon no Equilibrado passou de **20,0 para 25,9 FPS**, com P95 de **62,0 para 43,2 ms**. O P99 variou de **124,8 para 157,2 ms**, sinal de que os engasgos mais raros ainda precisam de atenção. A Estrada do Horto, disponível na revisão, marcou **40,0 FPS** na Radeon e **35,1 FPS** na Intel nos mesmos perfis. Em Qualidade a 1920 × 1080, a Radeon marcou **22,7 FPS** no Horto.

Em 10 s na avenida com VSync ligado, o pacote revisado marcou **30,5 FPS** na Radeon e **31,4 FPS** na Intel. O P95 ficou em **42,3 ms** e **92,0 ms**, respectivamente. [Dados das 19 passagens](medicoes.json)

O vídeo registra os controles no jogo com tempo de simulação fixo. A avaliação subjetiva do peso, da direção e da leitura do relevo permanece em aberto com jogadores.
