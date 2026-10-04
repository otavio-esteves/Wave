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

Executar em etapas, com avaliação do usuário entre elas:

1. **Carro definitivo — etapa atual:** substituir o bloco provisório por um cupê vintage original, com carroceria, vidros, acabamentos, faróis, lanternas e rodas detalhados. Integrar nos dois mapas e apresentar para avaliação visual antes de avançar. O modelo proposto se chama **Maré 68**; sua aprovação visual ainda está pendente.
2. **Física de condução:** melhorar substancialmente a resposta do carro ao terreno. A carroceria deve acompanhar a inclinação do piso em rampas, subidas e descidas, com transições suaves, em vez de permanecer perpendicular ao piso inclinado. Avaliar contato das rodas, suspensão, aderência e resposta ao pousar.
3. **Calçadas atravessáveis:** permitir subir e descer os meios-fios dirigindo; eles não devem funcionar como paredes que interrompem a condução. Manter colisões de edifícios e barreiras.
4. **Mapa maior:** ampliar a área de condução e a variedade de percursos para testes mais longos, preservando o desempenho da GPU de referência.
5. **Pista de corrida completa:** construir um circuito fechado com retas, curvas de diferentes raios, largada/chegada, limites legíveis e áreas de escape. Preservar a pista técnica com rampa e obstáculos para regressões.

Nesta etapa, entregar o carro para o usuário jogar e avaliar. Os itens seguintes aguardam essa avaliação; não executá-los todos de uma vez.

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
- Próximo passo: o usuário avalia o carro; depois, seguir a revisão de física, calçadas, mapa maior e pista completa registrada acima. Timbre/mixagem, gamepad físico e experiência jogada de dez minutos também aguardam avaliação. M2 permanece em andamento. A licença de distribuição do projeto continua a definir.
