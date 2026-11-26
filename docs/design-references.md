# Referências de design — primeira leitura documental, 2026-10-07

**Estudo da Baixada do Arroio, 2026-11-22.** A comparação entre *Need for Speed*, *Midnight Club: Los Angeles*, *Assetto Corsa* e *Forza* orientou a Rota Livre, a leitura das transições de piso e o desenho dos marcos do novo bairro. [Fontes, aplicação e capturas](development-results/2026-11-22/baixada-do-arroio/README.md#referências-de-jogabilidade-e-direção-de-arte)

**Atualização de direção visual — 2026-10-08:** o usuário passou a solicitar Most Wanted **2012** como referência de realismo, principalmente para o carro e o bairro piloto. Essa é a meta artística atual; o estudo de 2005 abaixo fica como histórico de condução/composição. Não houve comparação jogada nem medição de equivalência visual com 2012.

**Atualização de condução — 2026-10-09:** Most Wanted **2012** também passa a orientar a sensação de dirigir. O feedback no Wave confirmou a melhora em peso/aderência e pediu aceleração cerca de 60% menor. A [revisão de progressão de velocidade](development-results/2026-10-09/mw2012-acceleration/README.md) implementa esse ajuste no controlador arcade; as constantes são decisões do Wave, sem atribuição à física interna do jogo de referência.

Esta etapa traduz a orientação do projeto em decisões verificáveis. Não houve sessão comparativa jogada dos títulos de referência, nem engenharia reversa de seus renderers/física. As receitas para Godot abaixo são propostas para Wave; não descrevem código interno dos jogos.

| Referência | Princípio adotado | Experimento no Wave |
| --- | --- | --- |
| Most Wanted **2005**, EA Black Box | Curvas legíveis, velocidade perceptível, frenagem/derrapagem acessíveis e atmosfera de fim de tarde | Manter controlador, testar três velocidades, ajustar câmera/FOV e ritmo de objetos; avaliar diversão antes de migração física |
| Test Drive Unlimited **2006** | Prazer da viagem e continuidade entre paisagens/destinos | Caminho da Serra mantém um carro e uma sessão entre quatro usos do território; próxima prova inclui alternativa e destino reconhecível |
| San Andreas **2004** | Identidade por região, horizonte e escala com detalhe seletivo | Massas distantes/HLOD e kit compartilhado; medir CPU/GPU/residência, sem tentar copiar a tecnologia original |
| Midnight Club 3 / Underground 2 | Escolhas de rota, atalhos e serviços/progressão automotivos | Laterais e refúgios antes de garagem; não introduzir tuning/progressão nesta prova de streaming |
| Burnout Paradise | Atividades integradas à exploração | Futura atividade ponto a ponto sobre rede viária/checkpoints existentes; não construir outro sistema de mapas |
| 171 | Ambiente urbano brasileiro observado | Uso e proporções de comércio, calçadas, muros, portões, fios e vegetação; nenhuma mecânica de ação/crime entra no escopo |

O [manual da EA de Most Wanted Black Edition (2005), preservado em reprodução](https://www.videogamemanual.com/PS2/Need%20for%20Speed-%20Most%20Wanted%20%28Black%20Edition%29%20%28USA%29.pdf) identifica o título de referência. Páginas modernas da EA com “Most Wanted” frequentemente descrevem a versão de **2012**; não usar requisitos ou comportamento daquela versão para justificar decisões sobre 2005. Atmosfera e sensação descritas aqui são intenção artística do projeto e precisam de comparação humana, não foram medidas a partir do manual.

O [manual oficial de Burnout Paradise Remastered](https://eaassets-a.akamaihd.net/eahelp/manuals/burnout-paradise-remastered-manual_switch_en-gb.pdf), nas seções Freeburn e Events, descreve descoberta de atalhos, início de eventos em cruzamentos e provas ponto a ponto sem rota fixa. A proposta de integrar atividades às ruas do Wave deriva desses princípios; não prevê takedowns, dano ou boost nesta etapa. [Material de suporte da Rockstar para Midnight Club 3](https://support.rockstargames.com/articles/50ixFXwl1jsgSGRhUfgdSG/game-tips-for-midnight-club-3-dub-edition) e [apresentação oficial de 171 na comunidade Steam](https://steamcommunity.com/app/1269370?l=brazilian) são referências documentais adicionais. Não foram baixados assets desses títulos.

## Proporções e desenho urbano da Vila das Figueiras

A leitura de material oficial orientou o papel de cada rua e a relação entre o carro, o bairro e o terreno. As dimensões abaixo foram escolhidas para o Wave, tendo a caixa de colisão do Gol como escala de jogo e guias urbanos como referência em metros.

| Jogo | Decisão aplicada à Vila |
| --- | --- |
| GTA V | Enquadrar a rua com fachadas, calçadas úteis e volumes de fundo. Usar os morros como referência visual. [Rockstar Games](https://www.rockstargames.com/newswire/article/o349k552544449/grand-theft-auto-v-official-announcement.html) |
| Need for Speed: Most Wanted (2012) | Tornar a avenida comercial legível em movimento, com faixas de rodagem, estacionamento e travessias distintos. Ligar o corredor comercial a um contorno mais rápido, com duas entradas no bairro. [Electronic Arts](https://news.ea.com/press-releases/press-releases-details/2012/Criterion-Games-Reinvents-Best-Selling-Need-for-Speed-Most-Wanted/default.aspx) |
| Burnout Paradise | Dar folga para escolher trajetórias nos cruzamentos e criar circuitos conectados. Uma volta alterna a malha de bairro, curvas de encosta e a vista da crista. [Galeria da Electronic Arts](https://www.ea.com/en-gb/games/burnout/burnout-paradise-remastered) · [Retrospectiva de Jack Griffin, da Criterion](https://www.youtube.com/watch?v=jYpbXhl-4h0) |
| Midnight Club: Los Angeles | Dar ritmos diferentes à avenida e às ruas locais. Recuos, vagas, postes e fachadas dão uma escala que se percebe pela câmera traseira. [Rockstar Games](https://www.rockstargames.com/games/MidnightClubLA) |
| Forza Horizon 5 | Usar a alternância entre trechos confinados e vistas abertas sobre encostas, inspirada na descrição oficial de Guanajuato. [Playground Games](https://forza.net/news/exploring-forza-horizon-5-biomes-and-seasons) |
| Assetto Corsa | Usar a relação entre carro e piso escaneado como referência física. Monza, reproduzida no jogo, tem de 10 a 12 m na ficha oficial do autódromo. A coletora e as três estradas usam essa ordem de grandeza. [Kunos Simulazioni](https://assettocorsa.gg/assetto-corsa/) · [Autodromo Nazionale Monza](https://www.monzanet.it/en/circuit/) |

| Elemento | Dimensão no Wave |
| --- | ---: |
| Gol, caixa de colisão | 1,60 × 3,65 m |
| Rua residencial | 7,60 m, dois sentidos de 3,80 m |
| Rua coletora | 12,00 m, dois sentidos e bordas demarcadas |
| Avenida comercial | 21,40 m, quatro faixas de 3,70 m, duas faixas de estacionamento de 2,35 m e separador de 1,90 m |
| Rua das Jabuticabeiras | 7,80 m no corpo da rua, com as bocas alargadas |
| Alameda da Estação | 9,40 m no corpo da rua, com as bocas alargadas |
| Estrada do Horto | 8,60 m de pista, 342 m de extensão e pátio com acesso pelos dois lados |
| Rua do Mercado | 8,80 m de pista, 158,6 m de extensão, duas bocas na avenida e 22,2 m sob cobertura |
| Estrada do Mirante | 10,80 m de asfalto e 582 m de extensão |
| Contorno das Águas | 11,40 m de asfalto e 341 m de extensão |
| Estrada do Vale | 10,60 m de asfalto e 579 m de extensão |
| Galeria da Pedra | 48 m de extensão e 12,70 m de largura interna entre as paredes |
| Recuos das estradas | Até 6,20 m adicionais de largura, com entrada e saída progressivas |
| Calçadas | 2,50 m nas ruas locais e 4,25 m na avenida |
| Meio-fio | Até 14,5 cm, transição chanfrada de 0,40 m e rebaixamento nos cruzamentos |
| Raios das esquinas | 3,60 m em ruas locais, 5,80 m na coletora e 7,00–10,50 m nas esquinas da avenida |

O guia da NACTO toma 10 pés, cerca de 3,05 m, como largura apropriada para uma faixa urbana. Na Vila, uma faixa local corresponde a 2,38 larguras da caixa de colisão do Gol, e uma faixa da avenida a 2,31. O manual de Burnout descreve a descoberta de atalhos e a liberdade para escolher percursos. A descrição de Fairhaven pela EA reforça a ideia de uma malha que convida à exploração. A Vila traduz essas referências com duas ligações curvas entre ruas da malha original e com esquinas mais abertas no eixo comercial. As dimensões da tabela foram projetadas para o Wave. [NACTO](https://nacto.org/publication/urban-street-design-guide/street-design-elements/lane-width/) · [Fairhaven, EA](https://ir.ea.com/press-releases/press-release-details/2012/Need-for-Speed-Most-Wanted-Demo-Available-Today--Now-Players-Can-Experience-the-Most-Critically-Acclaimed-Open-World-Racing-Game-of-2012/default.aspx) · [Manual de Burnout Paradise Remastered](https://eaassets-a.akamaihd.net/eahelp/manuals/burnout-paradise-remastered-manual_switch_en-gb.pdf)

Os bolsões de estacionamento ficam separados das faixas de rodagem. Faixas de pedestre, drenagem e mobiliário deixam visível a borda da via. Os encaixes curvos ampliam a área de manobra antes da faixa de pedestres. Na avenida, o aclive e a descida usam um perfil próprio, unido às encostas por curvas verticais suaves. O mobiliário e as árvores ficam na faixa de serviço da calçada. [Prefeitura de São Paulo](https://prefeitura.sp.gov.br/web/subprefeituras/w/calcadas/37447)

## Acabamento da Rua das Jabuticabeiras

- Em **Most Wanted (2012)**, a rua continua legível em movimento porque marcações, remendos, sarjetas e bases das fachadas têm escalas distintas. As capturas oficiais também mostram toldos e cornijas projetando sombras próprias. Na Jabuticabeiras, a faixa de rodagem recebe remendos e desgaste em várias escalas. A padaria, a oficina e alguns sobrados ganham volumes que ajudam a reconhecer cada trecho. [Capturas de Criterion Games e Electronic Arts](https://store.steampowered.com/app/1262560/Need_for_Speed_Most_Wanted/)
- Em **Forza Horizon 5**, a arquitetura de Guanajuato usa a encosta para alternar ruas fechadas com vistas em profundidade. Muros baixos, vegetação e fachadas formam planos sucessivos. Na Jabuticabeiras, o Largo do Ipê abre uma vista da serra na subida e o viveiro marca o retorno inferior. O basalto, os rebocos, o ferro pintado e as sacadas seguem a linguagem de um bairro brasileiro. [Playground Games sobre Guanajuato](https://forza.net/news/exploring-forza-horizon-5-biomes-and-seasons) · [Guia de luz e enquadramento da Turn 10](https://forza.net/news/forza-photo-guide)

## Tradução técnica para Compatibility

A [documentação oficial de carregamento em background](https://docs.godotengine.org/en/stable/tutorials/io/background_loading.html) diferencia solicitar/consultar estado/obter recurso; obter antes de concluir pode bloquear. O loader existente já respeita essa sequência e é reaproveitado. Instanciação/anexação/upload continuam custos a medir, sem promessa de assíncrono completo.

[MultiMesh](https://docs.godotengine.org/en/stable/classes/class_multimesh.html) agrupa desenho e exige bounds que representem as instâncias. No Wave, lotes espaciais e `BakedMultiMesh` preservam os transforms/AABBs salvos, incluindo cards orientados à câmera. Quantidade reduzida de lotes não comprova ganho de FPS por si só. Os [intervalos de visibilidade/HLOD](https://docs.godotengine.org/en/stable/tutorials/3d/visibility_ranges.html) permitem simplificação; aqui o sistema existente separa visibilidade de residência/colisão e usa histerese.

Próxima avaliação de referência: dirigir os títulos disponíveis legalmente em percursos comparáveis, registrar respostas de câmera, curvas e ritmo urbano/rural; documentar observações qualitativas separadas de medidas do Wave. Esse estudo permanece aberto. Não atribuir resultados visuais ou desempenho ao algoritmo de um jogo sem fonte/evidência.

### Gol 1000 quadrado (1993)

A carroceria do Gol 1000 de 1993 foi refeita a partir das vistas dianteira, lateral e traseira de um exemplar branco. A revisão usou como referência o capô inclinado, a coluna central pintada, o vidro traseiro trapezoidal, as lanternas com duas fileiras que retornam pelos cantos, o nicho da placa e as rodas de aço com seis respiros. [Exemplar branco de 1993 na Garage84](https://garage84.com.br/comprar/vw-volkswagen/gol-1000-1993/31) · [Histórico da Volkswagen](https://www.vwnews.com.br/news/305)

A geometria do carro foi modelada no projeto e é gerada offline. A padaria usa [uma textura original gerada para a Vila](../assets/textures/figueiras/bakery-interior.provenance.json), com recortes para os dois vidros e luz ligada ao ciclo da cidade.
