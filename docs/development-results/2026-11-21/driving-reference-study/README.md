# Câmera, condução e gráficos em movimento

O estudo combina vídeos e imagens oficiais dos três títulos com material técnico da Kunos e da Criterion. A prova prática usa o Gol em duas versões do Wave, com o mesmo roteiro automatizado de aceleração, frenagem e entrada na Alameda.

[Comparação em movimento, avenida → Alameda](avenida-alameda.mp4) · [Largada](largada.jpg) · [Pneus durante a derrapagem](derrapagem.jpg)

## O que as referências mostram

| Jogo | Câmera e condução | Apresentação em movimento |
| --- | --- | --- |
| Assetto Corsa (2014) | A Kunos descreve pneus, telemetria e perfis de assistência. A relação entre entrada, transferência de peso e saída da curva é central para aprender a pista. [Kunos](https://assettocorsa.gg/assetto-corsa/) | Nos primeiros segundos do trailer de 2016, o grão do asfalto, o desgaste das zebras e o contraste entre piso e vegetação dão escala ao carro. As tomadas de replay ajudam a observar os materiais e a suspensão. [Trailers e imagens oficiais](https://store.steampowered.com/app/244210/Assetto_Corsa/) |
| Need for Speed: Most Wanted (2012) | A descrição da demo pela Criterion liga minimapa, alternativas de percurso e objetivos cronometrados. A aproximação de cada cruzamento pede uma decisão que o jogador consiga executar em velocidade. [Criterion](https://blog.playstation.com/2012/11/13/5-tips-to-make-the-most-of-the-need-for-speed-most-wanted-demo-out-today-on-psn/) | Por volta de 45 s no trailer da loja, luz quente no horizonte, superfícies, reflexos e o rastro junto às rodas descrevem o que acontece com o carro. A montagem promocional serve como referência de direção de arte. [Trailer oficial](https://store.steampowered.com/app/1262560/Need_for_Speed_Most_Wanted/) |
| Burnout Paradise Remastered | No início de *The Race is On*, tomadas com HUD mostram o carro na região inferior, enquanto a saída da curva continua legível. O manual explica o papel de atalhos, desafios nas ruas e recordes. [Trailer](https://store.steampowered.com/app/1238080/Burnout_Paradise_Remastered/) · [Manual](https://eaassets-a.akamaihd.net/eahelp/manuals/bpr-manuals_ps4_ukanz.pdf) | A alternância entre paredes próximas, viadutos e vistas abertas torna a passagem pelos objetos perceptível. A equipe cita 60 FPS e alcance de desenho como partes da apresentação da versão para Xbox One X. [Equipe de Burnout no Xbox Wire](https://news.xbox.com/en-us/2018/03/15/inside-xbox-one-x-enhanced-burnout-paradise-remastered/) |

Na apresentação de Matthew Harris, o acompanhamento e a área de interesse da câmera têm funções diferentes. O exemplo combina um acompanhamento amortecido e uma direção de olhar extrapolada. A posição do carro no quadro comunica a manobra e o jogador ainda precisa enxergar onde pretende chegar. O limite de antecipação e o tempo de resposta desta versão vêm dos testes no Wave. [Vehicle Feel Masterclass, Criterion, GDC 2018](https://media.gdcvault.com/gdc2018/presentations/Harris_Matthew_VehicleFeelMasterclass.pdf)

## Decisões aplicadas no Wave

- A câmera segue a componente horizontal da trajetória, usa a velocidade de guinada para antecipar a curva e inclina a mira gradualmente conforme a rampa. Um deslocamento longitudinal acompanha a aceleração medida. O amortecimento vertical separa pequenos ressaltos do movimento do quadro. Olhar manual, visão traseira e capô continuam disponíveis.
- O Gol inclina a carroceria a partir da aceleração medida, incluindo o mergulho sob frenagem. Os contatos das quatro rodas combinam os níveis de aderência e de resistência de asfalto, calçada, acostamento e gramado. Em velocidade, pequenos comandos analógicos de direção ficam mais graduais. A aceleração progressiva de 0,4 mantém a calibração anterior.
- As marcas de borracha seguem os contatos das rodas traseiras. A emissão de fumaça reage ao deslizamento e ao bloqueio pelo freio de mão. No gramado e no acostamento há poeira. O albedo do asfalto tem agregado em escala de rua, e a cor das encostas continua a variar com a distância e o ciclo solar. O brilho de altas luzes pode ser ativado no pós-processamento. [Proveniência e prompt do asfalto criado com ImageGen](../../../../assets/textures/figueiras/asfalto-alameda.provenance.json)
- O Sprint da Alameda usa a própria rua para uma sequência de aceleração, freada e mudanças de direção. Os portões aparecem em ordem, a rota fica realçada no minimapa e o melhor tempo fica salvo localmente.

## Diferenças que aparecem na comparação

A Vila ainda tem frentes muito uniformes e áreas vazias no campo periférico. A densidade de tráfego, as reações dos outros veículos e a consistência dos materiais em todo o bairro pesam na diferença observada em relação às referências. O ensaio de condução mede trajetória, antecipação, superfície e tempo. A avaliação com pessoas conduzindo continua em aberto.

## Medições no Wave

Na tomada comparativa, as duas versões percorrem o mesmo trecho com apoio em todos os 405 quadros medidos. O vídeo apresenta uma amostra a cada dois quadros da reprodução controlada. O teste separado do sprint passou pelos cinco portões em **19,641 s**, com **0,95 m** de margem mínima do centro do Gol à borda da pista e até **8,5°** de antecipação angular na conversão. O teste confirmou o registro do recorde e a preparação de uma nova tentativa pela tecla **T**.

Em uma passagem diagnóstica de 10 s a cerca de 38 km/h, a Radeon R7 M260 passou de 27,6 para 26,9 FPS no Equilibrado a 1280 × 720. O P95 de tempo de quadro passou de 41,7 para 43,9 ms. As duas janelas ficaram fora de foco. A medição em condições de jogo e a estabilidade sustentada de quadros seguem em aberto.

Passaram **22 verificações** com renderização e **18** no pacote final do Sprint da Alameda. A regressão da Vila passou 68 verificações. Os testes de câmera e controle, dirigibilidade e circuito também passaram. O executável Linux abriu a Vila revisada e o build Windows foi exportado com o mesmo PCK.

## Segunda rodada na Vila

Os seguintes princípios orientaram as mudanças a partir das diferenças observadas na primeira rodada.

- **Burnout Paradise.** Richard Bunn descreve o equilíbrio entre densidade, velocidade e tipo de veículo, além do cuidado com as zonas de conflito. A Vila recebeu seis trajetórias direcionais agrupadas em três circuitos, vinte carros e quatro semáforos com fases alternadas. A aproximação leva em conta a distância de frenagem, o veículo à frente e a convergência de duas trajetórias. O contato do Gol com o tráfego usa a colisão física e produz som, vibração e um deslocamento curto na câmera. [Relato de Richard Bunn](https://richardbunn.com/burnout-paradise)
- **Need for Speed: Most Wanted (2012).** O manual associa exploração, percursos alternativos e objetivos com critérios diferentes. A Vila passou de uma para cinco provas. O radar soma as leituras de três portões, o Contorno premia a chegada próxima de 57 segundos e a serra exige mudanças de ritmo, da subida à descida. A Travessia usa um atalho por dois galpões. O mapa mostra curvas de nível, pontos de partida, percurso e recorde. [Manual da Criterion e da EA](https://eaassets-a.akamaihd.net/eahelp/manuals/need-for-speed-most-wanted-manuals_Sony%20Playstation%203.pdf)
- **Assetto Corsa e Assetto Corsa EVO.** A cabine aproxima a vista do assento e mantém a pista legível nas curvas. O modelo do Gol ganhou volante móvel, velocímetro, limpador automático e retrovisor em tempo real no perfil Equilibrado ou com detalhe de materiais. A Kunos distingue fumaça, poeira, água e impactos. No Wave, a chuva reduz a aderência do asfalto em 21%, altera materiais e luz, cria spray nos pneus e separa os recordes. [Assetto Corsa, Kunos](https://assettocorsa.gg/assetto-corsa/) · [Efeitos de superfície no Assetto Corsa EVO 0.7](https://assettocorsa.gg/assetto-corsa-evo-early-access-0-7-now-available/)

As dimensões são da Vila. As ruas locais têm 7,6 m e a coletora tem 12 m. A avenida tem quatro faixas de 3,7 m, separador de 1,9 m e estacionamento de 2,35 m por lado. No trajeto das Oficinas, uma passagem pavimentada de 9,3 m cruza uma quadra em declive com entradas abertas, paralelepípedo nos pátios e vista para a cidade. Na avenida, as fachadas dos Correios e da Galeria do Relógio quebram a repetição das coberturas. O relógio acompanha o ciclo da Vila.

[Vídeo em movimento](nova-vila/percurso.mp4) · [Avenida anterior](nova-vila/antes-avenida.jpg) · [Avenida atual](nova-vila/avenida.jpg) · [Cabine na chuva](nova-vila/cabine-chuva.jpg) · [Oficinas](nova-vila/oficinas.jpg) · [Chuva à noite](nova-vila/avenida-chuva.jpg) · [Mapa de provas](nova-vila/mapa.jpg)

Na pista, o teste manteve os vinte carros circulando por 95 segundos sem sobreposição das carrocerias e observou a parada e retomada nos cruzamentos. Um teste de impacto confirmou que um carro do tráfego impede a passagem do Gol. A Subida do Mirante terminou em **43,210 s** com os seis portões, margem mínima de **1,64 m** em relação à borda do asfalto e apoio ao longo do trajeto. O teste de radares passou por três pontos a velocidade controlada. Para comparar o traçado e a física da pista, os testes de percurso isolam o tráfego e repetem os comandos de volante e pedais.

Passaram **68 verificações da Vila** no projeto e **53 verificações de condução, mapa, tráfego, câmera e chuva** no PCK exportado. O Linux iniciou nativamente e o executável Windows iniciou no Wine 10. Os dois usam o mesmo pacote de recursos. As capturas foram feitas no perfil Equilibrado antes do agrupamento dos carros. A montagem de 8,25 s usa reprodução a passo fixo e mostra a avenida, a cabine na chuva e o acesso das Oficinas.

As carrocerias, rodas e lanternas do tráfego foram agrupadas para reduzir o custo de desenho. Os carros usam sombras de contato, e o retrovisor da cabine é criado quando necessário. No diagnóstico em janela focada no perfil Equilibrado com VSync desligado, a Radeon R7 M260 registrou 8,6 FPS no pacote anterior, 4,4 FPS na primeira versão desta rodada e 6,1 FPS após agrupar os carros. Com VSync ligado, as duas versões ficaram em torno de 1 FPS nesse ambiente de teste. Os números indicam que o custo visual continua alto para esse equipamento e que a sincronização de vídeo afeta bastante o diagnóstico.
