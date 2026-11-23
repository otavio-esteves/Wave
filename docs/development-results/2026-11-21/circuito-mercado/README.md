# Vila das Figueiras — Circuito do Mercado

A Rua do Mercado sai da avenida 17 m à frente da posição inicial do Gol, contorna o Mercado das Figueiras e devolve o carro à avenida por um segundo acesso. A pista tem **158,6 m**, **8,8 m de largura** e **6,7 m de variação de altura**. A maior inclinação medida em 4 m é de **13,1%**. A cobertura acompanha **22,2 m** da curva. As duas faixas têm 4,4 m cada, ou 2,75 vezes a largura da caixa de colisão do Gol. Cada acesso foi desenhado para a conversão a partir da faixa externa.

A cobertura tem vigas transversais, apoios fora das faixas, luzes locais e pátios de carga com paralelepípedos. A caixa-d’água ajuda a localizar a quadra, e os arrimos marcam a transição entre a calçada e o terreno. A fachada do Mercado tem um painel de azulejos produzido para o jogo. [Proveniência do painel](../../../../assets/textures/figueiras/painel-do-mercado.provenance.json)

## Estudo e decisões

- **Need for Speed: Most Wanted (2012).** Por volta de 19 s na montagem oficial, a freeway tem várias linhas possíveis entre carros e barreiras. Aos 32 s, as fachadas próximas do beco comunicam a velocidade. Craig Sullivan descreve como a equipe usa espaços reconhecíveis para fazer uma rua conduzir à próxima. A avenida da Vila introduz a escolha de trajeto, a curva contrai o campo visual sob a estrutura do Mercado e a saída recupera a vista do bairro. [Criterion e EA](https://store.steampowered.com/app/1262560/Need_for_Speed_Most_Wanted/) · [Entrevista com Craig Sullivan e Alex Ward](https://www.theguardian.com/technology/gamesblog/2012/oct/17/need-for-speed-most-wanted-preview)
- **Burnout Paradise.** Por volta de 28 s, o trailer enquadra uma passagem coberta com a rua legível na saída. Na tomada de serra aos 12 s, a linha de centro e o guard-rail deixam clara a trajetória quando a encosta oculta parte da curva. O acesso do Mercado tem sinalização antes da virada e mantém a passagem visível pelos dois lados. [Criterion e EA](https://store.steampowered.com/app/1238080/Burnout_Paradise_Remastered/) · [Richard Bunn, desenho da malha e do tráfego](https://richardbunn.com/burnout-paradise)
- **Assetto Corsa.** A tomada de Spa em ângulo baixo, por volta de 7 s, mostra como zebra, caimento e relevo definem a leitura do apoio. A Kunos descreve contatos, suspensão e comportamento dos pneus em pisos diferentes. No Wave, a gravidade da rampa fica fora do orçamento de atrito. A carga medida é redistribuída entre as quatro rodas e afeta a aderência de cada lado. A câmera usa a curva real da rua para antecipar a saída, com influência reduzida durante contravolante e órbita manual. [Trailer da Kunos](https://store.steampowered.com/app/244210/Assetto_Corsa/) · [Contato do pneu no Assetto Corsa EVO](https://support.505games.com/hc/en/assetto-corsa-evo/articles/assetto-corsa-evo-0-6-update-steam-37)

O estudo de proporções usou a relação visual entre carro, faixa e fachada em capturas oficiais. As metragens da Vila vêm da sua malha. Os ensaios de controle e de câmera foram feitos na Vila.

## Chuva e custo por quadro

A intensidade sobre a via varia com a cobertura. O asfalto protegido mantém mais aderência e gera menos spray. O material usa pequenas áreas de acúmulo e controla a intensidade do reflexo do céu. O Gol reage à chuva na pintura, e a faixa de chuva de seis segundos é gerada fora do jogo. [Gerador de áudio](../../../../scripts/tools/build_audio.py)

A sombra de contato reaproveita uma região da malha de colisão. A sombra se move e gira por parâmetros do shader enquanto a região cobre o entorno do Gol. O buffer de vértices só é atualizado quando o carro se aproxima da borda da região. As placas pequenas têm alcance de desenho ligado ao tamanho das letras. O tráfego reutiliza a posição e a direção já calculadas para cada carro durante o passo de física.

## Percurso e capturas

[Da avenida à avenida](percurso.mp4) · [Entrada](avenida.jpg) · [Fachada do Mercado](mural.jpg) · [Descida](descida.jpg) · [Cobertura](galpao.jpg) · [Retorno](retorno.jpg) · [Cabine à noite](galpao-noite.jpg) · [Mapa das sete provas](mapa.jpg)

As imagens saíram do pacote exportado em 1280 × 720 no perfil Equilibrado. A comparação da chuva usa a mesma posição na avenida e o mesmo horário. O vídeo de 31,7 s mostra a travessia em câmera externa e termina com uma passagem em cabine à noite. A gravação sem áudio usa um quadro a cada três passos de física de 60 Hz, com o tráfego desativado para repetir a trajetória. [Chuva no pacote anterior](chuva-anterior.jpg) · [Chuva na revisão](chuva.jpg)

## Validação de condução

No ensaio que começa na avenida, o primeiro traçado de entrada encontrou um poste. A posição da colisão foi medida e a placa passou para fora da faixa de conversão. O novo ensaio percorreu **184,8 m** da avenida à avenida, com **0,92 m** de margem mínima do centro do Gol à borda do asfalto e **zero quadros sem apoio**. Entre a largada e a chegada da prova, o cronômetro marcou **17,556 s**.

Em outro ensaio, o Gol freou com um lado na calçada. A carga equivalente sobre o eixo dianteiro chegou a **67,9%** e a guinada atingiu **0,063 rad/s** em direção ao lado de maior aderência. Os valores são leituras do modelo arcade nesta configuração.

A repetição automatizada da travessia marcou **17,553 s**, com **0,93 m** de margem e apoio em todos os quadros. Foram **147 reconstruções da malha de sombra em 1.540 passos de física**, cerca de uma a cada dez passos.

No PCK final passaram 72 verificações de acesso e relevo, 18 de condução, 35 de tráfego, provas, mapa e chuva e 18 de câmera, Gol e passagem pelo Mercado. Também passaram 156 verificações compartilhadas de entrada, câmera, controle, dirigibilidade, reflexo e áudio. O executável Linux abriu nativamente e o executável Windows abriu no Wine. A sensação ao dirigir ainda precisa de avaliação com jogadores.

## Medição da sombra e da taxa de quadros

Os dois pacotes repetiram o mesmo trecho de 155,3 m do Mirante em 864 posições. Cada versão teve 16 passagens medidas, divididas entre duas inicializações, com ordem anterior → revisado → revisado → anterior. O ensaio mede o tempo da chamada que atualiza a sombra na thread principal, em modo headless. A mediana das médias aparadas por passagem, removendo os 18 tempos mais altos de cada uma, caiu de **702 µs para 174 µs**. O P95 das chamadas, resumido pela mediana dos P95 de cada passagem, caiu de **2,50 ms para 2,02 ms**.

Na comparação com janela, a carga de CPU impediu que os dois pacotes completassem a mesma quantidade de simulação. Em 14 s no Mirante, a Intel HD 4400 no perfil Econômico processou 248 e 264 passos de física, de 840 previstos. Os dados ficam registrados para diagnóstico. O ganho de FPS da cena inteira segue sem validação. [Dados das medições](medicoes.json) · [Rotina de medição com janela](../../../../tests/figueiras_benchmark.gd)
