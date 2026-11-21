# Referências de design — primeira leitura documental, 2026-10-07

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
| Need for Speed: Most Wanted (2012) | Tornar a avenida comercial legível em movimento, com marcas que distinguem a faixa de rodagem, o estacionamento e as travessias. [Electronic Arts](https://news.ea.com/press-releases/press-releases-details/2012/Criterion-Games-Reinvents-Best-Selling-Need-for-Speed-Most-Wanted/default.aspx) |
| Midnight Club: Los Angeles | Dar ritmos diferentes à avenida e às ruas locais. Recuos, vagas, postes e fachadas dão uma escala que se percebe pela câmera traseira. [Rockstar Games](https://www.rockstargames.com/games/MidnightClubLA) |
| Forza Horizon 5 | Usar a alternância entre trechos confinados e vistas abertas sobre encostas, inspirada na descrição oficial de Guanajuato. [Playground Games](https://forza.net/news/exploring-forza-horizon-5-biomes-and-seasons) |
| Assetto Corsa | Usar o carro como régua, preservar a relação em metros e testar o contato no piso que aparece na tela. A Kunos documenta seu uso de escaneamento para reproduzir circuitos. [Kunos Simulazioni](https://store.steampowered.com/app/244210/Assetto_Corsa/) |

| Elemento | Dimensão no Wave |
| --- | ---: |
| Gol, caixa de colisão | 1,60 × 3,65 m |
| Rua residencial | 7,20 m, dois sentidos |
| Rua coletora | 8,40 m, dois sentidos |
| Avenida comercial | 12,40 m, com duas faixas de 3,70 m e duas faixas de estacionamento de 2,50 m |
| Calçadas | 2,25 m nas ruas locais e 3,45 m na avenida |
| Guia | Até 14 cm, com transição chanfrada e rebaixamento perto dos cruzamentos |

O guia da NACTO descreve 10 pés (cerca de 3,05 m) como largura apropriada para faixas urbanas. A Vila usa 3,60 m por sentido nas ruas residenciais e 3,70 m na avenida para dar folga ao controle arcade. O mobiliário e as árvores ficam perto da guia, seguindo a separação entre faixa de serviço e faixa livre documentada pela Prefeitura de São Paulo. [NACTO](https://nacto.org/publication/urban-street-design-guide/street-design-elements/lane-width/) · [Prefeitura de São Paulo](https://prefeitura.sp.gov.br/web/subprefeituras/w/calcadas/37447)

Para a leitura pela câmera traseira, a largura do carro serve como unidade adicional. Cada sentido da rua residencial comporta 2,25 larguras da caixa de colisão do Gol, e a faixa de rodagem da avenida comporta 2,31. Uma análise de desenho de pistas relaciona largura a espaço de correção, raio de curva e posição de câmera. O estudo de Princeton sobre GTA V e o trabalho publicado pelo artista de vias Lee Gregory para Forza Horizon 5 também mostram que os jogos variam a geometria de acordo com o tipo de via. [Análise de traçado para jogos de corrida](https://www.gamedeveloper.com/design/a-rational-approach-to-racing-game-track-design) · [Estudo de Princeton](https://princetonautonomous.github.io/paper.pdf) · [Vias de Forza Horizon 5](https://leegregory.artstation.com/projects/Nx9RKq)

## Tradução técnica para Compatibility

A [documentação oficial de carregamento em background](https://docs.godotengine.org/en/stable/tutorials/io/background_loading.html) diferencia solicitar/consultar estado/obter recurso; obter antes de concluir pode bloquear. O loader existente já respeita essa sequência e é reaproveitado. Instanciação/anexação/upload continuam custos a medir, sem promessa de assíncrono completo.

[MultiMesh](https://docs.godotengine.org/en/stable/classes/class_multimesh.html) agrupa desenho e exige bounds que representem as instâncias. No Wave, lotes espaciais e `BakedMultiMesh` preservam os transforms/AABBs salvos, incluindo cards orientados à câmera. Quantidade reduzida de lotes não comprova ganho de FPS por si só. Os [intervalos de visibilidade/HLOD](https://docs.godotengine.org/en/stable/tutorials/3d/visibility_ranges.html) permitem simplificação; aqui o sistema existente separa visibilidade de residência/colisão e usa histerese.

Próxima avaliação de referência: dirigir os títulos disponíveis legalmente em percursos comparáveis, registrar respostas de câmera, curvas e ritmo urbano/rural; documentar observações qualitativas separadas de medidas do Wave. Esse estudo permanece aberto. Não atribuir resultados visuais ou desempenho ao algoritmo de um jogo sem fonte/evidência.

### Gol 1000 quadrado (1993)

A carroceria do Gol 1000 de 1993 foi refeita a partir das vistas dianteira, lateral e traseira de um exemplar branco. A revisão usou como referência o capô inclinado, a coluna central pintada, o vidro traseiro trapezoidal, as lanternas com duas fileiras que retornam pelos cantos, o nicho da placa e as rodas de aço com seis respiros. [Exemplar branco de 1993 na Garage84](https://garage84.com.br/comprar/vw-volkswagen/gol-1000-1993/31) · [Histórico da Volkswagen](https://www.vwnews.com.br/news/305)

A geometria do carro foi modelada no projeto e é gerada offline. A padaria usa [uma textura original gerada para a Vila](../assets/textures/figueiras/bakery-interior.provenance.json), com recortes para os dois vidros e luz ligada ao ciclo da cidade.
