# Plano de desenvolvimento — Wave

Reorientação de 2026-10-08: concentrar física, jogabilidade e estética em **uma cidade piloto pequena, com cerca de quinze quarteirões**, antes de construir as cidades definitivas. O [plano anterior](docs/plans/2026-10-08-pre-pilot-plan.md) e seus resultados ficam preservados como histórico.

## Objetivo atual

Entregar um lugar coeso que dê vontade de dirigir: ruas conectadas, curvas com personalidade, relevo perceptível, cruzamentos, trajetos alternativos e destinos reconhecíveis. A cidade piloto é o laboratório comum das próximas decisões. Uma mudança de carro, câmera, pavimento ou fachada deve ser avaliada no mesmo percurso, com condições comparáveis.

O primeiro incremento contém **seis quarteirões conectados**: casas no vale, centro com praça, encosta e oficina. A direção artística solicitada agora é um bairro de classe alta, com sobrados contemporâneos, prédios residenciais, jardins e ruas bem cuidadas. O veículo recebe prioridade de acabamento. Quinze quarteirões continuam sendo a meta após consolidar este bairro. A cena principal está em [drive_pilot_city.tscn](scenes/city/drive_pilot_city.tscn), acessível pela primeira opção do menu. [Layout](scripts/city/pilot_city_layout.gd) e [gerador](scripts/city/pilot_city_builder.gd) definem ruas, terreno, lotes e colisões offline.

## Revisão atual por etapas

1. Resolver esbarramentos nas calçadas: transições suaves, malha sem frestas nas curvas e testes de frente/ré/diagonal em ruas com relevo.
2. Melhorar o veículo: formas, pintura, vidros, faróis, rodas e acabamento, preservando dimensões físicas e resposta do controlador.
3. Consolidar o bairro de classe alta: casas, prédios, praça, vegetação, pavimento e entorno contínuo.
4. Medir a mesma rota antes/depois nos perfis obrigatórios e corrigir custos antes de aumentar a área. A ambição atual de “500%” orienta o salto visual; não é uma métrica objetiva de qualidade.

O primeiro incremento dessas etapas está implementado: guias chanfradas, nove sobrados, cinco prédios, praça/jardins e revisão do Hatch 1000. [Resultados e comparações](docs/art-results/2026-10-08/jardins-do-vale/README.md) registram a passagem funcional e as medições curtas. A segunda revisão substitui as árvores inteiras em billboard por troncos/galhos e copas em volume, acrescenta entradas/endereços e uma cabine visível no hatch. [Comparações desta etapa](docs/art-results/2026-10-08/jardins-realismo/README.md). A terceira etapa arredonda a carroceria/vidros/retrovisores, revisa rodas e materiais e introduz asfalto/gramado originais com acabamento de fachadas. [Capturas, otimização e validação](docs/art-results/2026-10-08/jardins-mw2012/README.md). O acabamento próximo e o desempenho sustentado na Intel continuam pendentes; a média de FPS não encerra esse critério.

## Sequência de trabalho

### 1. Tornar os seis quarteirões uma boa base de condução

Conferir o traçado em movimento: contorno da cidade, volta pelo centro e subida/descida da encosta nos dois sentidos. Corrigir curvas, largura, cruzamentos, guias, entrada da praça e pátio da oficina antes de aumentar a área. O carro deve encontrar apoio contínuo, poder frear e manobrar e retornar à mesma sessão sem trocar de mapa.

Os testes automatizados verificam conectividade, geometria reproduzível, colisões e condução por comandos reais. A avaliação jogada verifica leitura, escala e prazer. Se um trecho exigir correção, alterar primeiro o problema observado; não criar outro mapa para contorná-lo.

### 2. Definir física e câmera nesse lugar

Usar o controlador arcade existente como ponto de partida. Avaliar baixa velocidade, ré, frenagem, subida, descida, curvas e freio de mão. Escolher uma rota curta repetível e comparar ajustes nela. Registrar sensação humana e defeitos reproduzíveis; alterar física somente com um motivo concreto. Verificar teclado e gamepad, câmera externa e capô.

Velocidade de teste automatizada não é certificação de handling. Cruzamentos urbanos precisam de frenagem e curvas legíveis; o limite do carro não determina a velocidade adequada para toda rua.

### 3. Estabelecer a estética em um quarteirão da própria cidade

Escolher um trecho que reúna rua, calçada, fachada, vegetação e relevo. Trabalhar proporção, paleta, pavimento, iluminação, horizonte e detalhes brasileiros com assets originais ou licença verificável. Comparar imagens e condução no mesmo trecho em Econômico e Equilibrado. O kit atual é provisório; evitar espalhar detalhe ainda sem direção visual por quinze quarteirões.

A orientação visual mais recente do usuário passa a ser Most Wanted 2012, especialmente realismo do carro, materiais, iluminação e acabamento urbano. A referência anterior de 2005 permanece apenas no histórico documental. Não usar assets extraídos. [Referências de design](docs/design-references.md) permanecem como orientação.

### 4. Expandir para cerca de quinze quarteirões

Depois de revisar o primeiro bairro, estender a mesma cidade com rotas que acrescentem decisões: outra ligação entre baixa e encosta, curvas distintas, atalhos e destinos. Manter continuidade espacial, escala e identidade. Cada expansão deve preservar a volta de referência e passar pelos mesmos testes de apoio e acesso.

Integrar atividades pequenas ao traçado quando direção e leitura estiverem boas: percurso entre praça e oficina, checkpoints ou entrega simples. Reaproveitar o HUD e os sistemas existentes conforme necessário. A expansão é conteúdo conectado, sem reiniciar uma coleção de cenas independentes.

### 5. Consolidar custo e critérios antes das cidades definitivas

Medir rotas renderizadas e sessão longa na cidade piloto. Corrigir os custos demonstrados pelas medições; adotar partição/streaming existente somente quando a residência ou o carregamento justificar. A primeira versão compacta carrega inteira. Capturas estáticas e testes headless não comprovam FPS.

A cidade piloto estará consolidada quando traçado, condução e direção visual tiverem avaliação humana, acessos forem confiáveis e os perfis obrigatórios forem medidos. Então construir as cidades definitivas usando o kit, a física, a câmera e os limites de custo estabelecidos aqui. Escala e ligação regional serão decididas nesse momento.

## Restrições preservadas

Godot 4.7.2, GDScript tipado e renderer Compatibility. Geração offline: editar, gerar, validar e salvar; nenhuma geração pesada durante a partida. Preservar controles, áudio, configurações persistidas e sistemas úteis. Os mapas anteriores permanecem no menu como laboratórios de regressão, incluindo circuito, rally, corredor, streaming, viagem e serra. O desenvolvimento de conteúdo se concentra na cidade piloto.

O perfil de pneus experimental do rally não redefine a física do projeto. Streaming/HLOD existentes podem ser reaproveitados quando necessários. Não reescrever o controlador nem criar outro gerenciador sem evidência de necessidade.

## Hardware e validação

Meta: Dell Inspiron 5547/Haswell com **8 GB de RAM**. Econômico (`economy`), inicialmente 854×480, sem sombras/MSAA/efeitos caros: HD 4400 com pelo menos 30 FPS sustentados. Equilibrado (`medium`), inicialmente 1280×720, sombras/MSAA 2×: R7 M260 com pelo menos 30 FPS sustentados. Qualidade (`high`) atende hardware moderno. Preferências antigas, preset Legacy e backend permanecem compatíveis.

A máquina disponível tem 16 GB e é compartilhada; não certifica o requisito de 8 GB. Benchmarks novos exigem condições de uso exclusivo combinadas. Registrar GPU, renderer, resolução, presets, rota e frame times, com três passagens e sessão longa. [Performance](docs/performance.md) e [orçamento](docs/performance-budget.md) detalham a medição. Windows nativo e gamepad conectado continuam pendentes.

Executar o runner de projeto após alterações compartilhadas e conferir o pacote exportado antes de distribuir. Evidência da cidade deve distinguir testes funcionais, capturas visuais, medição de desempenho e avaliação humana. Nenhuma aprovação de uma dessas frentes substitui as demais.
