# Vila das Figueiras — condução, cidade e serra

A revisão trabalha na cena principal do Wave, nos nove quarteirões e nas ligações entre o Horto, o Passo, o Mirante e o Vale. O contraste entre comércio, bairros residenciais, estação e encosta passou a depender mais do uso dos espaços, da geometria e dos materiais à altura do carro.

## Estudo de referências

| Referência | O que observar | Tradução para o Wave |
| --- | --- | --- |
| *Need for Speed: Most Wanted* (2012), Criterion | A apresentação oficial de Fairhaven alterna avenidas abertas, atalhos e recintos de escala menor na mesma viagem. A palestra de Matthew Harris distingue arrasto da câmera, antecipação e posição do veículo no quadro. | Antecipação de curvatura e greide combinada à trajetória do Gol, lente horizontal mais contida e pivô estabilizado. A Copa continua integrada às ruas, com trechos cobertos, rampas e provas em piso molhado. [Electronic Arts](https://news.ea.com/press-releases/press-releases-details/2012/Criterion-Games-Reinvents-Best-Selling-Need-for-Speed-Most-Wanted/default.aspx) · [Matthew Harris, GDC, pp. 50–57](https://media.gdcvault.com/gdc2018/presentations/Harris_Matthew_VehicleFeelMasterclass.pdf) |
| *Forza Horizon 5*, Playground Games | A equipe trabalha com referências de campo e define cada bioma por relevo, material e vegetação. Os artistas de Guanajuato mostram componentes de fachada reutilizáveis com composições distintas por edifício. | A Vila tem cinco tipos de frente comercial com portas, caixilhos, bases e recuos próprios. O campo usa cobertura vegetal ligada à drenagem e aos espigões. As curvas da serra conservam o perfil rodoviário sob o talude e as camadas de textura. [Playground Games, biomas](https://news.xbox.com/en-us/2021/07/26/exploring-the-biomes-and-seasons-of-forza-horizon-5/) · [Playground Games, palestra de geração procedural](https://www.youtube.com/watch?v=UjZ5nPwCCOk) · [Simon Hughes, módulos urbanos](https://simonhughes3d.artstation.com/projects/RnEYRD) · [Adam Jarvis, Guanajuato](https://ajarvis.artstation.com/projects/3qleB2) |
| *Forza Motorsport*, Turn 10, e *EA Sports WRC*, Codemasters | O material dos estúdios descreve aderência que varia progressivamente em zebra e superfícies, além de frenagem e carga perceptíveis na direção. | Um único limite por pneu combina forças de frenagem, tração e curva. As rodas dianteiras e traseiras reagem às cargas e ao piso, e o freio de mão descarrega a aderência traseira por escorregamento. A marcha afeta a desaceleração ao soltar o pedal. [Turn 10, pneus](https://forza.net/news/forza-motorsport-drivatars-tire-physics) · [Jon Armstrong, Codemasters](https://blog.playstation.com/2023/10/30/how-ea-sports-wrc-brings-realism-to-rally-driving-on-ps5-out-nov-3/) · [Chalmers, forças combinadas, § 2.2.5](https://research.chalmers.se/publication/526795/file/526795_Fulltext.pdf) |

A composição brasileira usa o ritmo de vãos, portas e alinhamento de fachadas do inventário de São Luiz do Paraitinga. A cobertura da Estação combina pórticos, treliças e plataforma, inspirada na tipologia descrita pelo IEPHA para o conjunto ferroviário de Juiz de Fora. São Paulo serviu como referência para escala de letreiros comerciais. [IPHAN](https://www.gov.br/iphan/pt-br/acesso-a-informacao/participacao-social/conselhos-e-orgaos-colegiados/atas-do-conselho-consultivo-do-patrimonio-cultural/de-2001-ate-2010/66a-reuniao-ordinaria-do-conselho-consultivo-09-12-2010) · [IEPHA](https://www.mg.gov.br/iepha/bem/bem-tombado/juiz-de-fora-conjunto-arquitetonico-das-antigas-estacoes-da-central-do-brasil-e-da-estrada-de-ferro-leopoldina-e-o-acervo-do-nucleo-historico) · [Prefeitura de São Paulo](https://prefeitura.sp.gov.br/web/licenciamento/w/desenvolvimento_urbano/participacao_social/conselhos_e_orgaos_colegiados/cppu/169850)

Nos cortes, a leitura da Serra Geral orientou o uso de patamares, sulcos rasos, escarpa e mata de encosta com araucárias. A silhueta recebeu cristas em profundidades distintas e pequenas drenagens cruzando os contrafortes. No Passo, a rocha agora aparece no próprio terreno, com máscara de declividade, transição para terra e gramínea e blocos de basalto junto ao pé do corte. O material de basalto foi criado no ImageGen integrado. [Plano de manejo do ICMBio](https://www.gov.br/icmbio/pt-br/assuntos/biodiversidade/unidade-de-conservacao/unidades-de-biomas/mata-atlantica/lista-de-ucs/parna-da-serra-geral/arquivos/pm_aparados_versao_para_site_2025abr20_compressed.pdf) · [DAER, Rota do Sol](https://www.daer.rs.gov.br/apa-rota-do-sol) · [Textura e prompt](../../../../assets/textures/figueiras/basalto-do-passo.provenance.json)

## Como a revisão aparece ao dirigir

- **Avenida e transversais.** As frentes comerciais usam marcenaria, alvenaria, vitrines e ondulação da rua para diferenciar lotes. A varanda do café tem piso nivelado. Setas e pintura de retenção coincidem com a geometria de parada do trânsito. Os carros calculam a frenagem até o para-choque e antecipam a parada em piso molhado.
- **Galeria, Mercado e Pátio.** Os três percursos cobertos têm tratamento de entrada e estrutura visível. A Galeria e o Pátio tiveram as duas faixas medidas com raios verticais em quatro estações por percurso. A menor folga observada foi de 5,23 m na Galeria e 5,04 m no Pátio, em amostras discretas.
- **Passo, Mirante e Vale.** As bordas do asfalto passam para drenagem, vegetação baixa e solo. O corte e o aterro acompanham a forma da estrada. A textura usa projeções verticais no Equilibrado e a projeção dominante no Econômico. Chuva reduz contraste e altera os reflexos do carro, do piso e das encostas na mesma hora do dia.
- **Gol.** A pressão de freio responde à intensidade do pedal. O freio de mão atua no eixo traseiro e permite parar numa rampa de 15%. A ré entra após a parada e uma breve espera com o pedal pressionado. A saída de uma curva pede dosar a pressão e o acelerador quando os pneus já estão perto do limite lateral.
- **Câmera.** O enquadramento usa distância e inclinação da pista, direção do carro e folga contra a geometria. A perseguição muda de lente de forma contida. A cabine lê a estrada à frente, com resposta sob aceleração e frenagem. A interpolação do carro e da câmera preenche os intervalos entre passos de física nos quadros renderizados.

## Verificações de condução

Uma Copa seca com aceleração, freio e esterço programados fez **14/15 pontos**, com cinco passagens limpas e cinco fantasmas salvos. Galeria, Estação e Passo ficaram na faixa de ouro nos ensaios seco e molhado. A frenagem de 57,6 km/h consumiu **14,00 m no seco** e **17,31 m no molhado**.


Os tempos abaixo vieram do pacote exportado em provas separadas da Copa, com quatro balizas e sem perda de contato com o piso.

| Trecho | Seco | Chuva |
| --- | ---: | ---: |
| Galeria da Praça | 7,311 s | 8,304 s |
| Pátio da Estação | 8,701 s | 9,830 s |
| Estrada do Passo | 27,195 s | 30,849 s |

O ensaio de câmera fixou 120 amostras por segundo com física a 60 Hz. A Estação, a Galeria e o Passo exibiram 180, 296 e 229 posições de câmera repetidas em 789 amostras de perseguição na versão anterior. A série interpolada eliminou as repetições nos três trechos. O número de consultas de antecipação caiu de 103 para 82 por trecho durante a prova. As amostras usam a mesma malha e o mesmo Gol nas duas versões para isolar a câmera.

O cálculo dos pneus foi medido à parte em processo único, com seis blocos alternados de 100 mil chamadas de cada versão e afinidade de CPU fixa. Foram **31,60 µs por integração** antes e **30,80 µs** depois. O benchmark em janela mede o jogo completo. [Teste dos pneus e pedais](../../../../tests/figueiras_vehicle_response_smoke.gd) · [Teste de tráfego, cabine e chuva](../../../../tests/figueiras_district_smoke.gd)

## Renderização

O inventário das famílias de arquitetura revisadas foi de 249.088 para 212.918 triângulos (−14,5%). Os lotes de telhado caíram de 151 para 72 com coordenadas de textura e tangentes. Nos carros estacionados, a geometria amostra mais perto dos arcos de roda e usa níveis de detalhe conforme a distância. A malha baixa das áreas de campo reúne setores distantes. A pista usa o mesmo relevo físico em todos os perfis. O Econômico usa uma versão do shader com filtragem linear com mipmaps e uma projeção de rocha. A cabine ajusta a distância e o nível de detalhe no retrovisor.


As áreas de campo agrupam 64 setores em 16 lotes distantes. O mesmo princípio reuniu as árvores distantes em 54 lotes, com a mesma geometria de atlas, posição e escala. Em um ensaio isolado desse agrupamento na Intel, as chamadas de desenho por quadro na Avenida foram de 473 para 434, com cerca de 247 mil triângulos nas duas passagens. [Godot, intervalos de visibilidade](https://docs.godotengine.org/en/stable/tutorials/3d/visibility_ranges.html)

| GPU e percurso | Chamadas de desenho por quadro, antes → entrega | Triângulos por quadro, antes → entrega | FPS, antes → entrega | P95 na entrega |
| --- | ---: | ---: | ---: | ---: |
| Intel HD 4400, Avenida, Econômico | 538 → 437 | 291 mil → 249 mil | 13,9 → 14,2 | 126,7 ms |
| Radeon R7 M260, Avenida, Equilibrado | 687 → 567 | 477 mil → 406 mil | 32,5–34,6 → 35,0 | 37,6 ms |
| Radeon R7 M260, cabine com chuva, Equilibrado | 706 → 595 | 488 mil → 420 mil | 23,6–24,2 → 26,0 | 49,8 ms |

O ensaio nativo percorreu cerca de 160 m a 41 km/h, com 14 segundos por passagem, seis de aquecimento e tráfego desligado para repetir a trajetória. A tabela usa a comparação final dos dois pacotes na Intel e duas passagens anteriores e uma da entrega por cenário na Radeon. As medições ocorreram na mesma máquina compartilhada. O viewport efetivo da Intel foi de 569 × 320 em uma janela de 854 × 480. O da Radeon foi de 1280 × 720. Na Intel, a média permaneceu abaixo de 30 FPS. Na dupla final, o P95 subiu de 106,8 para 126,7 ms. Passagens anteriores variaram entre 11,5 e 18,6 FPS no pacote anterior, indicando variação de carga na máquina. [Registros das passagens](medicoes.json) · [Script de benchmark](../../../../tests/figueiras_benchmark.gd)

## Comparação visual

- Passo e Vale com câmeras fixas no mesmo ponto do percurso. [Passo anterior](passo-anterior.jpg) · [Passo revisado](passo.jpg) · [Vale anterior](vale-anterior.jpg) · [Vale revisado](vale.jpg)
- Praça, comércio e percursos cobertos. [Praça anterior](praca-anterior.jpg) · [Praça revisada](praca.jpg) · [Café da Praça](vitrine.jpg) · [Mercado](mercado.jpg) · [Galeria](galeria.jpg) · [Pátio da Estação](estacao.jpg)
- Câmeras do jogo em Equilibrado. [Perseguição na Avenida](avenida.jpg) · [Cabine com chuva](cabine.jpg)
- Trechos gravados com comandos programados na subida e na crista, no seco e na chuva. Nas duas provas completas, o Gol passou pelas quatro balizas, ficou apoiado e registrou ouro. [Passo em movimento](passo-em-movimento.mp4)

## Pacotes de jogo

A versão Linux iniciou em janela no modo Qualidade. O executável Windows iniciou em janela pelo Wine. Os dois pacotes de recursos têm o mesmo SHA-256, registrado nas medições. Os ensaios cronometrados do Gol e da Copa foram repetidos contra o pacote isolado, com entradas programadas.

As seis suítes de Figueiras passaram em **212 verificações** no projeto e no pacote. A regressão completa do pacote também passou nos Laboratórios e na cidade-piloto.

A regressão do código-fonte foi concluída em etapas. A rodada inicial validou as 39 verificações Python e a equivalência geométrica da geração legada isolada. O limite de 20 minutos interrompeu a volta longa da cidade-piloto. A retomada passou nas rotas pendentes. Na suíte de streaming, um diagnóstico de alocação do renderer headless apareceu em uma rodada e a repetição passou com as 33 verificações e sem o diagnóstico.
