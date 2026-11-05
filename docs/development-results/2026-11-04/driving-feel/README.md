# Dirigibilidade, derrapagem e sensação de velocidade — 2026-11-04

A revisão trabalha o carro compartilhado pela cidade e pelos mapas arcade. A intenção é oferecer uma derrapagem deliberada que o jogador consiga iniciar, sustentar e encerrar, enquanto curvas normais continuam firmes. A aceleração gradual escolhida anteriormente (escala 0,4), o limite de 220 km/h, os freios, a ré e o contato com o relevo são preservados. O modelo experimental de pneus do rally não recebe a assistência de drift.

## Estudo e decisões

O código anterior já possuía limite de força lateral, amortecimento de rotação, frenagem limitada pela aderência, quatro amostras de apoio e recuperação de escorregamento. Porém, um toque curto no freio de mão não abria uma manobra sustentada: a recuperação forte da aderência voltava assim que o botão era solto. O áudio tinha apenas motor/ambiente/música, e a câmera abria pouco o campo de visão nas velocidades comuns da cidade.

A [Vehicle Feel Masterclass, de Matthew Harris/Criterion, GDC 2018](https://gdcvault.com/play/1025295/) aborda a combinação entre simulação, assistências e câmera. O [texto da equipe de NFS Heat](https://www.ea.com/games/battlefield/news/under-the-hood-the-handling-model) descreve entradas deliberadas de derrapagem, dosagem pelo acelerador e o equilíbrio com curvas de aderência. [Steve Lycett, da Sumo Sheffield](https://www.gamedeveloper.com/design/getting-under-the-hood-of-racing-games), relaciona leitura de velocidade à câmera e ao áudio. São referências de projeto; os números desta implementação vêm das nossas próprias fixtures, e não de uma reprodução da física desses jogos.

Minha aplicação dessas referências é manter a condução comum previsível e concentrar a assistência na manobra que o jogador pediu pelo freio de mão. A câmera acompanha parte da direção real do movimento, sem esconder o ângulo da carroceria. A informação sonora responde ao estado do veículo, para ajudar a perceber aderência e velocidade.

## O que muda

- **Entrada:** acima de aproximadamente 30 km/h, virar e tocar o freio de mão inicia a assistência. Virar/acelerar normalmente nunca a arma. Estacionamento, ré e baixa velocidade ficam fora desse estado.
- **Sustentação:** soltar o freio de mão e manter direção/acelerador permite carregar o escorregamento. O acelerador dosa o ângulo; aliviar, centralizar, contravirar ou usar o freio normal recupera a aderência. Segurar o freio de mão continua levando à parada.
- **Limites:** o controlador aproxima um ângulo limitado, respeita o orçamento de força lateral e não injeta velocidade. O movimento permanece sujeito ao contato e às colisões. Há dissipação durante a derrapagem, menor que na recuperação comum, e o carro continua perdendo velocidade na manobra.
- **Direção:** contravirar cruza o centro mais rapidamente. O limite de esterço por velocidade e a resposta gradual das curvas normais continuam ativos.
- **Câmera:** altura base de 2,8 m, pequena redução adicional em alta velocidade, antecipação amortecida de até 1,8 m e FOV entre 70° e 84°. Durante drift, até 45% da orientação automática considera a direção do movimento. Olhar manual e visão traseira mantêm prioridade; a visão do capô tem alvo de aumento de até 4,9°. Não há tremor aleatório nem rolagem adicionada ao horizonte.
- **Áudio:** pneus soam conforme o ângulo de escorregamento em superfícies identificadas como asfalto e silenciam sem contato ou em outros tipos identificados. O vento cresce com a velocidade. O motor usa cinco faixas e histerese de redução, evitando repetidas quedas artificiais de rotação na última marcha. Os novos sons originais são sintetizados offline; a qualidade sonora ainda requer escuta jogada. Todos respeitam o volume Motor e a pausa.
- **Descoberta:** o painel opcional de controles da cidade explica a entrada, sustentação e saída da derrapagem, tanto no teclado quanto no controle.

As mudanças não acrescentam partículas, render targets, raycasts ou geometria. São um pequeno controlador de assistência e duas camadas de áudio em loop. A geração salva da cidade com relevo permanece a mesma; não foi necessário gerar os quarteirões novamente. A classificação de piso usa os metadados existentes: colisores sem identificação conservam o padrão de asfalto do controlador anterior. A cidade ainda tem colisores sem classificação própria, portanto esse fallback também vale para o áudio; esta revisão não faz reconhecimento por material visual.

[Gráfico comparativo de ângulo e velocidade](maneuver-comparison.svg). O gráfico mostra amostras da fixture; não é uma captura do jogo.

## Comparação controlada

Fixture plana, entrada a 79,2 km/h, direção a 70%, toque de freio de mão de 0,2 s, depois acelerador a 70%. Mesma cena, parâmetros e sequência de comandos antes/depois. Os números abaixo são tomados a 2 s do começo da manobra; o ângulo é o módulo da diferença entre orientação e movimento.

| Medida | Antes | Depois |
| --- | ---: | ---: |
| Ângulo da manobra deliberada | 1,24° | 23,70° |
| Velocidade nessa manobra | 85,24 km/h | 70,42 km/h |
| Curva comum acelerada, sem freio de mão | 1,14° / 92,55 km/h | 1,14° / 92,55 km/h |
| FOV automático a 100 km/h, estabilizado | 72,73° | 79,57° |

Os FOVs da tabela são os alvos estabilizados calculados pelas curvas dos dois scripts; a nova fixture também verifica a progressão real da câmera. As demais medidas vêm dos percursos físicos registrados.

A derrapagem passa a ser uma escolha com custo de velocidade. A curva comum permanece eficiente. A comparação não mede diversão ou equivalência com Most Wanted: essas dependem de avaliação jogada. [Comandos da fixture](validation/comparison-fixture.gd.txt), [telemetria anterior](validation/before-maneuvers.json), [telemetria atual](validation/after-maneuvers.json), [log anterior](validation/baseline-probe.log) e [log atual](validation/current-probe.log). As versões anteriores dos três scripts estão preservadas na pasta de validação.

## Verificações específicas

A nova suíte executa **31 verificações** de comportamento real: curvas comuns, manobras simétricas, velocidade/apoio, contravolante, modulação do acelerador, saída por freio, parada, baixa velocidade/ré, reset, orientação da câmera, limites de FOV, camadas sonoras, última marcha, histerese e pausa. Foi executada em **30, 60 e 120 Hz** de física. Nas manobras de referência, os ângulos ficaram em 23,68–23,70° e a velocidade em 70,42–70,58 km/h. Esses Hz são configurações da física, não medições de FPS.

A suíte de handling passa **37 verificações**; o caso antigo que exigia encerrar toda derrapagem mesmo mantendo direção/acelerador foi atualizado para verificar sustentação limitada e recuperação ao aliviar. Os casos de frenagem, superfície de baixa aderência, ré, degraus, subida e perfil de simulação continuam presentes.

A prova de motor confirmou **0–100 km/h em 8,00 s** e **0–220 km/h sob potência em 35,48 s**, mantendo a progressão anterior. [Alta velocidade](validation/high-speed.log).

[30 Hz](validation/feel-30hz.log) · [60 Hz](validation/feel-60hz.log) · [120 Hz](validation/feel-120hz.log) · [handling](validation/handling.log).

Uma prova adicional de colisão frontal parte a aproximadamente 220 km/h e deixa a antecipação da câmera estabilizar antes do impacto. O braço permaneceu com pelo menos 7,28 m e a câmera a mais de 7,11 m da face do muro: a antecipação não a prendeu contra a colisão. [Fixture](validation/camera-wall-fixture.gd.txt) · [resultado](validation/camera-wall.log).

## Avaliação jogada

Abrir o build e escolher **Dirigir na cidade piloto**. Em um cruzamento amplo, entrar a 40–80 km/h, virar e tocar **Espaço / X do PlayStation / A do Xbox**. Soltar o botão e dosar o acelerador; comparar acelerador parcial com cheio. Para recuperar, aliviar ou virar para o lado contrário. Comparar também a mesma curva sem freio de mão, a encosta nos dois sentidos, capô, câmera livre e frenagem antes dos cruzamentos. O menu de controles traz a explicação dentro do jogo.

O trabalho foi feito sem janela gráfica. Os testes validam respostas e regressões; a sensação subjetiva, a escuta dos sons e a leitura da câmera nas ruas precisam de avaliação humana. Nenhum FPS ou aprovação visual é inferido dos testes headless.

## Reproduzir

```sh
godot --headless --path . --fixed-fps 60 --script res://tests/driving_feel_smoke.gd
godot --headless --path . --fixed-fps 30 --script res://tests/driving_feel_smoke.gd -- --physics-hz=30
godot --headless --path . --fixed-fps 120 --script res://tests/driving_feel_smoke.gd -- --physics-hz=120
godot --headless --path . --fixed-fps 60 --script res://tests/handling_smoke.gd
python3 scripts/tools/build_audio.py --vehicle-feedback-only
GODOT_BIN=/caminho/para/godot bash scripts/tools/check_project.sh
GODOT_BIN=/caminho/para/godot bash scripts/tools/export_builds.sh
GODOT_BIN=/caminho/para/godot bash scripts/tools/check_exported_access.sh
```

## Validação final

Passaram **1040 verificações Godot**, cobrindo **43 suítes principais**, persistência e montagem offline, além de **23 testes Python**. A execução foi concluída em quatro segmentos. Dois coordenadores foram interrompidos com código 143; o teste de cidade que continuou independentemente concluiu suas 43 verificações. Outra retomada corrigiu o carregamento de dependências `user://` de uma geração em outra pasta temporária, e a comparação completa de geometria/colisão passou novamente. Os casos incompletos/falhos e repetições não entram na contagem final. A fixture também passa a encerrar claramente quando a cena de referência não carrega.

O pacote passou **655 verificações**, cobrindo **23 suítes** e a guarda que exige recursos exportados. A suíte da cidade exportada passou 41 verificações; os seis percursos mantiveram apoio e pavimento em todas as amostras. As novas suítes de direção, handling, dirigibilidade e áudio estão incluídas no runner do pacote.

Os builds Linux e Windows foram atualizados com PCKs idênticos: **201.400.300 bytes**, SHA-256 `0a2d81207220043f70b246d6afdab5edfe50625bab58a4085004ec3b61319bef`. O pacote cresce 41.280 bytes (aproximadamente 40 KiB) em relação ao build com relevo anterior. O executável Linux iniciou e encerrou o menu em headless, com código zero. A execução nativa no Windows, a sensação jogada, a escuta dos sons e o FPS renderizado permanecem pendentes.

O primeiro ensaio detectou que a curva de FOV abria tarde demais perto de 40 km/h. A abertura foi antecipada e o teste original de direção passou, mantendo a exigência de retorno visual nessa velocidade. [Primeiro ensaio](validation/source-attempt-1.log) · [tentativa com dependências temporárias fora do diretório](validation/source-dependency-attempt.log).

[Origem: segmento 1](validation/source-part-1.log) · [segmento 2](validation/source-part-2.log) · [segmento 3: cidade](validation/source-part-3.log) · [segmento 4](validation/source-part-4.log) · [pacote exportado](validation/exported-access.log) · [exportação](validation/export-builds.log) · [menu Linux](validation/native-linux-menu.log) · [hashes dos arquivos](validation/artifact-hashes.json) · [registro completo](validation/record.json).
