# Plano de desenvolvimento — Wave

## Visão

O nome oficial do jogo e do projeto é **Wave**.

Um jogo 3D de direção livre: um carro antigo, uma cidade pequena e tranquila, música leve e luz de fim de tarde. O primeiro objetivo é sentir prazer ao dirigir por cinco minutos numa pista cinza. Só depois construiremos o bairro.

## Decisões técnicas iniciais

- **Engine:** Godot 4.7.2 estável, GDScript tipado. Manter o projeto compatível com Godot 4.x sempre que possível.
- **Renderer:** Compatibility, adequado ao notebook de referência com GPU Intel Haswell. Começar em 1280 × 720 e medir antes de aumentar a qualidade.
- **Veículo provisório:** `CharacterBody3D` com física arcade controlada. Isso permite ajustar a sensação de direção rapidamente. Reavaliar `RigidBody3D` ou `VehicleBody3D` somente se testes de condução mostrarem uma limitação concreta.
- **Estrutura:** cenas e scripts pequenos, poucos autoloads. Introduzir managers, recursos de dados e streaming quando surgir o primeiro uso real.
- **Plataformas:** Linux primeiro; Windows em cada marco jogável. Gamepad entra junto do protótipo de direção.
- **Assets:** geometria e materiais provisórios criados no projeto. Registrar autor, origem e licença antes de importar assets externos; só usar música original ou devidamente licenciada.
- **Versionamento:** Git com commits pequenos. `main` basta no início; criar branches quando houver trabalho paralelo ou uma mudança de risco.

## Critérios técnicos

- O projeto abre e roda sem erros na versão escolhida da Godot.
- Referência de desempenho: 30 FPS estáveis no notebook, com meta de 45–60 FPS quando possível. Registrar resolução, renderer, hardware e rota de teste ao medir.
- As cenas são jogadas após mudanças de condução, câmera ou arte. Validação estática sozinha não confirma a sensação do jogo.
- Preferir medições reais a limites arbitrários de triângulos ou a otimizações antecipadas.

## Marcos

### M0 — Fundação

Criar projeto Godot, `.gitignore`, documentação curta, ações de input, cena inicial e pista de testes simples. Executar em modo editor e jogo. Fazer primeiro commit.

**Pronto quando:** o projeto abre, inicia e fecha sem erro, com chão, iluminação e câmera visíveis.

### M1 — Direção divertida

Implementar carro provisório, aceleração, freio, ré, direção, resistência, reset e câmera de perseguição. Adicionar suporte básico a teclado e gamepad. Ajustar parâmetros jogando numa pista com curvas e obstáculos. Depois acrescentar aderência lateral, derrapagem controlável e freio de mão.

**Pronto quando:** cinco minutos de condução numa pista cinza são agradáveis, previsíveis e sem falhas frequentes de colisão ou câmera.

### M2 — Primeira experiência do jogo

Criar 3–5 ruas, cruzamentos, estacionamento, edifícios simples, árvores e postes. Adicionar carro vintage, iluminação de 18h, áudio ambiente, motor e música com licença registrada. Incluir menu simples e opções de áudio e gráficos.

**Pronto quando:** o jogador consegue passear pelo bairro por dez minutos, com identidade visual clara e desempenho dentro da meta.

### M3 — Cidade expansível

Medir desempenho. Introduzir setores carregados por proximidade apenas quando o mapa exigir. Usar LOD e ocultação de objetos distantes conforme os gargalos observados. Testar builds Linux e Windows.

**Pronto quando:** adicionar um setor não provoca queda sustentada abaixo da meta de FPS.

### M4 — Mundo vivo

Adicionar trânsito por rotas simples, semáforos, poucos pedestres e pontos de interesse. Controlar densidade e desativar agentes distantes.

### M5 — Jogo completo

Adicionar garagem, outros carros, corrida ponto a ponto, provas adicionais, progressão e save versionado. Criar conteúdo somente sobre uma base de direção e mundo já estável.

## MVP

O primeiro lançamento jogável inclui um carro, um bairro pequeno, direção completa, câmera, iluminação de fim de tarde, motor/ambiente/música, opções básicas de áudio e gráficos, teclado e gamepad, builds Linux e Windows. Não inclui polícia, história, multiplayer, tuning profundo, cidade enorme ou clima dinâmico.

**Concluído quando:** é possível iniciar, selecionar “Dirigir”, circular por todo o bairro, alterar opções, sair e reabrir sem erro; áudio e controles funcionam nas duas plataformas; FPS é medido e permanece estável na máquina de referência.

## Sequência de execução imediata

1. **Sprint 0:** criar e validar M0.
2. **Sprint 1:** carro provisório com aceleração, freio, ré, direção e reset.
3. **Sprint 2:** câmera de perseguição e primeiro ajuste jogado de condução.
4. **Sprint 3:** aderência, freio de mão, obstáculos e segunda rodada de ajustes.
5. **Sprint 4:** primeiro quarteirão e atmosfera visual.
6. **Sprint 5:** motor, ambiente, música original e opções persistentes de volume.
7. **Sprint 6:** menu inicial e opções gráficas básicas; medir FPS no desktop.

Cada sprint termina com execução do jogo, correção dos problemas observados e commit. O escopo da próxima sprint pode mudar conforme o teste jogado.

## Estado em 2026-10-04

### Revisão após avaliação do usuário

O usuário autorizou substituir o carro por um hatch equivalente em aparência ao Gol 1000 e seguir com os demais pontos. Entregue para avaliação:

1. **Carro:** Hatch 1000 branco, duas portas, faróis retangulares, para-choques pretos e rodas de aço. Malhas originais geradas offline; Maré 68 preservado como modelo anterior. Aparência ainda depende da avaliação do usuário.
2. **Física:** orientação de carroceria e colisor pelo contato das quatro rodas, movimento ao longo do piso, suspensão visual limitada, momento de saída de rampas preservado e horizonte estável da câmera. Testes cobrem subida, ré em descida, inclinação lateral e pouso.
3. **Calçadas:** travessia de meios-fios baixos com checagem de espaço e apoio, preservando colisão de paredes e edifícios. Travessia de 12 cm validada; limite de elevação configurável de 20 cm.
4. **Mapa maior:** ruas em 504 × 504 m, piso total de 536 × 536 m e 14 vias conectadas. Lotes divididos por setores de 84 m, com percurso de 460 m validado nas vias externas.
5. **Pista completa:** Autódromo do Sol, fechado, com 1.219 m, curvas variadas, sequência em S, linha de chegada, boxes, arquibancada, zebras e áreas de escape. Cronômetro, última/melhor volta e 16 checkpoints ordenados. Pista técnica preservada.

**Validação desta revisão:** 124 verificações sem falhas. Volta real automatizada completa no autódromo, em modo sem interface e com renderização. Na Intel, modo econômico: bairro 39,8 FPS médios; autódromo 48,1 FPS. Dados e oscilações registrados em `docs/performance.md`. Builds Linux/Windows atualizados.

**Próxima avaliação:** aparência do hatch, sensação de direção em curvas, transição de rampas e calçadas, uma volta cronometrada e passeios nas vias externas. Ajustar conforme a resposta do usuário antes de acrescentar trânsito ou progressão. Capotamento e transferência física de peso continuam fora desta implementação arcade.

- Plano revisto para priorizar um protótipo jogável e explicitar decisões técnicas.
- Projeto, pista de testes, carro e câmera provisórios criados. As referências da cena passaram por checagem estática.
- O executável Godot 4.7.2 foi encontrado em `~/Downloads/Apps`. O usuário testou o protótipo de direção no desktop e autorizou avançar para o bairro.
- **Sprint 1:** controle básico implementado, com esterçamento progressivo, freio antes da ré, limite de velocidade, colisões e reset. O carro agora é uma cena reutilizável com rodas provisórias.
- **Sprint 2:** câmera com suavização angular, FOV por velocidade, olhar para trás, proteção contra paredes e reposicionamento imediato após reset implementada.
- Parte da **Sprint 3** já disponível: aderência lateral, freio de mão com perda de aderência, circuito, obstáculos e rampa. Incluído HUD de velocidade e menu de pausa.
- Os testes na cena real passaram em **28 verificações**, cobrindo motor, direção, controle analógico simulado, derrapagem, colisões, rampa, câmera, reset e pausa. O jogo também iniciou sem erros no teste sem interface. Esses resultados não comprovam FPS com renderização nem a sensação de direção.
- **Sprint 4:** criado o Bairro do Sol, com seis ruas conectadas, cruzamentos, calçadas, casas, comércio, praça, árvores, postes, posto e estacionamento. É a nova cena inicial; o menu de pausa permite visitar a pista e retornar.
- Primeira atmosfera de fim de tarde: céu alaranjado, sol baixo, sombras longas e neblina discreta. Há uma única luz dinâmica principal; as luminárias e janelas usam materiais emissivos.
- O mapa é uma cena estática produzida por um gerador versionável. A geometria repetida usa 24 lotes MultiMesh. F3 permite conferir FPS e draw calls no desktop, com rota descrita em `docs/performance.md`.
- Corrigido o mapa invisível relatado no desktop: a geração sem interface perdia as transformações das malhas. Elas agora são persistidas em propriedades do recurso e restauradas no carregamento. O gerador verifica a geometria após recarregar o arquivo salvo.
- Os **20 testes do bairro** passaram, verificando percursos, acesso ao estacionamento, colisões, transições entre cenas e preservação dos dados de renderização ao salvar e recarregar. Somados aos testes de direção, são **48 verificações sem falhas**. O usuário confirmou que o mapa corrigido ficou visível no desktop.
- **Sprint 5:** motor com pitch e volume acompanhando a condução, ambiente com vento/pássaros e música instrumental original. Arquivos gerados offline com síntese determinística; origem registrada em `docs/assets.md`. Áudio provisório para avaliação jogada.
- Menu de pausa com opções separadas de volume geral, motor, ambiente e música. Preferências persistidas em `user://wave-settings.cfg`; pausa suspende todos os sons e troca de mundo encerra os players anteriores.
- Os **20 testes de áudio**, incluindo duas verificações após reiniciar o processo, passaram. Total atual: **68 verificações sem falhas**. A reprodução ouvida e a mixagem ainda precisam ser avaliadas no desktop; testes sem interface não confirmam qualidade sonora.
- Primeiro commit criado (`5831afe`), seguido das correções do acelerador analógico e das transformações de colisões (`e00bc9c`). O acesso a `.git` foi autorizado fora do sandbox.
- Acelerador parcial agora controla torque, mantendo os limites de velocidade. A validação visual/física do bairro inclui os nós pais dos colisores e das malhas.
- **Sprint 6:** menu inicial com Dirigir, Áudio, Gráficos e Sair; opções persistentes de tela cheia, resolução da janela, VSync e sombras. A pausa permite configurar gráficos e voltar ao menu inicial. Acrescentado modo econômico de 854×480 sem sombras, usado por padrão na Intel HD Graphics 4400 sem preferências gráficas salvas.
- Total de **93 verificações automatizadas**: 31 de direção, 22 do bairro, 20 de áudio e 20 de menus/gráficos, incluindo persistência em novos processos. Runner em `scripts/tools/check_project.sh` preserva as preferências de jogo usando diretórios temporários.
- Medições com renderização real na AMD dedicada e na Intel integrada; resultados e condições registrados em `docs/performance.md`. F4 salva CSV e resumo JSON para novas comparações. Menu, janela, geometria e rota também foram inspecionados com renderização real.
- Presets e script de exportação Linux/Windows criados; templates oficiais locais em `tools/`, sem inclusão no Git. Builds Linux e Windows gerados. Inicialização verificada no Linux e por Wine, com checagem adicional do fluxo do pacote exportado no runtime Godot. A validação nativa no Windows segue pendente.
- **Maré 68:** cupê original integrado ao bairro e à pista, substituindo o bloco provisório. Carroceria terracota, teto marfim, caixas de roda recortadas, vidros inclinados, cromados, lanternas e calotas. Malhas geradas offline, com 5.348 triângulos no carro completo. Os 93 checks existentes passaram; controlador e colisor preservados para esta avaliação visual. Builds Linux/Windows atualizados, com fluxo do pacote exportado verificado. Na Intel em modo econômico, a rota completa registrou 34,1 FPS médios e mínimo amostrado de 30; resultados em `docs/performance.md`.
- Revisão seguinte: o usuário pediu o hatch inspirado no Gol 1000 e autorizou avançar em física, calçadas, mapa maior e circuito; implementação e testes descritos acima. Próximo passo: avaliação jogada desses cinco pontos. Timbre/mixagem, gamepad físico e experiência jogada de dez minutos também aguardam avaliação. M2 permanece em andamento. A licença de distribuição do projeto continua a definir.

## Refinamento de condução após “continua”

- Gravidade longitudinal nas subidas e descidas: coasting perde velocidade ao subir, ganha ao descer e o carro pode recuar numa ladeira ao soltar os freios. Freio de mão segura o veículo parado.
- Corrigida a perda artificial de velocidade nas descidas após o ajuste ao piso; a resposta horizontal de paredes continua sendo preservada.
- Calçadas elevam o carro pela altura do apoio encontrado, com limite de 20 cm. Travessia em ré e na diagonal verificada.
- Velocímetro mede a velocidade ao longo do piso inclinado.
- Área de exercícios identificada na pista técnica: subida com topo e descida contínuos, calçada e piso inclinado acessível pela borda baixa. A rampa original e o circuito continuam disponíveis.
- 134 verificações passaram: 33 de direção, 21 de terreno, 26 do bairro, 14 de corrida, 20 de áudio e 20 de menus/gráficos. Execução renderizada conferida e builds Linux/Windows atualizados. As medições de FPS anteriores não foram refeitas nesta revisão; a sensação de direção segue para avaliação do usuário.

## Testes a 220 km/h e mapa com cinco vezes a área

- Velocidade máxima padrão de 220 km/h. Resistência ao ar reajustada para uma desaceleração progressiva ao soltar o acelerador.
- Área quintuplicada usando √5 em cada dimensão: ruas de 1.127 × 1.127 m e piso de 1.199 × 1.199 m. São 30 ruas conectadas; avenidas externas de 24 m de largura com retas de mais de 1 km. Centro, praça e posto preservados.
- Direção limitada pela aceleração lateral e suavizada conforme a velocidade; recuperação de aderência limitada pela força dos pneus. Freio de mão conserva derrapagem.
- Simulação de contato e colisão dividida conforme a velocidade, com deslocamento total preservado. Verificados 220 km/h reais, frenagem e colisão com uma barreira fina.
- 146 verificações: 33 de direção, 21 de terreno, 12 de alta velocidade, 26 do bairro, 14 de corrida, 20 de áudio e 20 de menus/gráficos. Builds Linux/Windows atualizados após aprovação dos testes.
- A interpretação aplicada para “quintuplicar” é cinco vezes a área, não cinco vezes cada dimensão. Aparência e sensação de condução seguem para avaliação jogada.

- Conferência renderizada a 220 km/h concluída. Na Intel, 854×480 sem sombras: 33.9 FPS médios no exercício de aceleração/coast/frenagem; dados completos em `docs/performance.md`.

## Circuito dedicado e primeira etapa de realismo

- Aceleração reduzida em 20%, de 12 para 9,6 m/s² de torque inicial; limite de 220 km/h preservado. Teste físico mede 0–100 em aproximadamente 3,28 s. O ajuste respeita o pedido relativo do usuário; não simula o desempenho de fábrica de um Gol 1000.
- Circuito substituído por uma volta de 3.241 m em mapa de 1.200 × 1.060 m. Reta principal de aproximadamente 700 m, curvas variadas, setor industrial, trecho arborizado, boxes, grid, arquibancada coberta, guardrails e 16 checkpoints. Bairro e pista técnica continuam disponíveis.
- Amostragem uniforme por distância corrige lacunas em segmentos curtos vizinhos de retas longas, incluindo o fechamento do circuito. Volta completa conduzida pelos controles reais, sem teletransportar entre checkpoints.
- Primeira evolução gráfica rumo à referência Most Wanted 2005: materiais originais com textura e normal maps, asfalto desgastado, alvenaria, concreto, metal, fachadas com detalhes, árvores com folhagem recortada, silos, relevo de fundo e iluminação diurna quente. Ainda não há equivalência visual com a referência.
- Opção persistente de MSAA 2× para suavizar contornos; modo econômico mantém a opção desligada junto das sombras. Materiais novos aplicados ao circuito nesta etapa.
- 149 verificações passaram em execuções das suítes de direção, terreno, alta velocidade, bairro, corrida, áudio e menus. Algumas execuções do runner também apresentaram falhas intermitentes em asserts antigos de câmera/percurso do bairro; esses asserts passaram nas execuções separadas. A origem dessa intermitência não foi confirmada e continua anotada para acompanhamento. Próximas etapas visuais anotadas: refinar a carroceria/vidros/faróis, variar fachadas e terrenos, melhorar árvores e objetos de rua, adicionar detalhe localizado e composição de cenário sem perder o desempenho da máquina de referência.

- Consulta espacial do cronômetro por setores de 64 m, preservando a distância exata fora da pista e eliminando varreduras completas durante a condução normal. Comprimento do circuito calculado uma vez para o HUD. Teste compara a consulta com a geometria integral.

- Volta renderizada concluída na Intel: 15 verificações passaram, afastamento máximo de 4,17 m. Captura adicional de 60 s em 854×480, sem sombras ou MSAA, registrou 51,9 FPS médios, mínimo amostrado de 26; detalhes e dados brutos em `docs/performance.md`. O perfil econômico reaplica o tamanho da janela mesmo se as preferências já coincidem.

- Builds Linux/Windows exportados e fluxo das quatro cenas conferido nos pacotes, com velocidade máxima, aceleração e materiais do circuito validados. Executável Linux iniciado; Windows iniciado via Wine. Na revisão final, pavimento dos boxes ampliado para conectar os acessos e projeção da textura desse trecho corrigida. A medição de FPS anterior a esse pequeno ajuste foi preservada, sem nova comparação de desempenho.


## Primeira etapa rumo a Assetto Corsa Rally

O usuário definiu Assetto Corsa Rally como referência e escolheu priorizar gráficos mesmo exigindo GPU melhor. A meta foi registrada como evolução em etapas, sem declarar equivalência com um simulador comercial.

- [x] Rally da Serra: 1.516 m de percurso aberto, relevo com colisão real, asfalto/cascalho/grama, floresta, pedras, marcas de bordo e 13 controles de cronometragem.
- [x] Novo perfil de pneus na etapa: tração dianteira, círculo combinado de forças, transferência longitudinal de carga, inércia de guinada, freio de mão no eixo traseiro e aderência por terreno. Controlador anterior preservado nos outros mapas para comparação.
- [x] Câmera de capô por V / botão X; instruções textuais de curva, poeira no cascalho e melhor tempo da sessão.
- [x] Vegetação detalhada original, tufos de grama, cascalho/pedra com normal maps, oclusão ambiente, exposição e perfil de 900p; launcher Forward+ com luz indireta e névoa volumétrica.
- [x] Runner anterior: 149 verificações passaram na mesma execução. Rally ampliado: 31 verificações passaram, incluindo o percurso inteiro, tentativa válida, estabilidade entre passos, câmera e qualidade. Total: 180 checks de comportamento.
- [ ] Usuário avaliar o novo perfil na etapa; depois decidir sua aplicação no bairro e no circuito.
- [ ] Suspensão por molas/amortecedores e corpo rígido, transferência lateral por roda, pneus calibrados, transmissão e diferencial; atualmente ainda há apoio cinemático.
- [ ] Refinar carroceria, reflexos, interior, faróis e áudio/RPM; o hatch atual permanece a base visual.
- [ ] Vegetação 3D próxima, variedade de árvores, superfícies naturais sem repetição, relevo mais detalhado, céu/clima e composição do cenário.
- [ ] Notas de navegador e áudio de pneu/superfície; danos, capotamento e periféricos de simulação.

As medidas de desempenho desta etapa são independentes das rotas históricas. Forward+ de 900p exige GPU superior à R7 M260 disponível; não houve validação em GPU moderna ou Windows nativo.

- Conferência final: runner completo com 180 verificações sem falhas; trecho renderizado com inputs e apoio estável após corrigir espera da ré na subida. Perfil Forward+ de 900p mediu 7,52 FPS na R7 M260, com limites registrados em `docs/performance.md`.
- Builds finais Linux/Windows atualizados e iniciadores de qualidade incluídos. As cinco cenas e os assets do rally foram conferidos no pacote Linux; inicialização do executável Linux e do Windows via Wine sem falhas. Windows nativo permanece pendente.
