# Plano de desenvolvimento — Wave

Reorientação de 2026-10-08: concentrar física, jogabilidade e estética em uma cidade piloto antes de construir as cidades definitivas. Em 2026-10-10, a nova expansão passa da etapa de 72 quarteirões para **200 quarteirões em três bairros**, com **quatro vezes a área anterior**, mantendo o ciclo de dia e noite. O [plano anterior](docs/plans/2026-10-08-pre-pilot-plan.md) e seus resultados ficam preservados como histórico.

## Objetivo atual

Entregar um lugar coeso que dê vontade de dirigir: ruas conectadas, curvas com personalidade, relevo perceptível, cruzamentos, trajetos alternativos e destinos reconhecíveis. A cidade piloto é o laboratório comum das próximas decisões. Uma mudança de carro, câmera, pavimento ou fachada deve ser avaliada no mesmo percurso, com condições comparáveis.

A cidade atual possui 200 quarteirões, 430 trechos de rua e terreno de 3.072 × 2.464 m. Jardins do Vale concentra residências e colinas; Vila Aurora reúne casas e comércio de bairro; Centro Horizonte combina torres, avenidas e parques. A expansão inclui minimapa, identificação do bairro e janelas noturnas nos arranha-céus. A cena principal está em [drive_pilot_city.tscn](scenes/city/drive_pilot_city.tscn), acessível pela primeira opção do menu. [Layout](scripts/city/pilot_city_layout.gd) e [gerador](scripts/city/pilot_city_builder.gd) definem ruas, terreno, lotes e colisões offline.

## Revisão atual por etapas

1. Resolver esbarramentos nas calçadas: transições suaves, malha sem frestas nas curvas e testes de frente/ré/diagonal em ruas com relevo.
2. Melhorar o veículo: formas, pintura, vidros, faróis, rodas e acabamento, preservando dimensões físicas e resposta do controlador.
3. Consolidar o bairro de classe alta: casas, prédios, praça, vegetação, pavimento e entorno contínuo.
4. Avaliar o bairro ampliado e medir a mesma rota antes/depois nos perfis obrigatórios em uma janela combinada de uso exclusivo. A ambição atual de “500%” orienta o salto visual; não é uma métrica objetiva de qualidade.

O primeiro incremento dessas etapas está implementado: guias chanfradas, nove sobrados, cinco prédios, praça/jardins e revisão do Hatch 1000. [Resultados e comparações](docs/art-results/2026-10-08/jardins-do-vale/README.md) registram a passagem funcional e as medições curtas. A segunda revisão substitui as árvores inteiras em billboard por troncos/galhos e copas em volume, acrescenta entradas/endereços e uma cabine visível no hatch. [Comparações desta etapa](docs/art-results/2026-10-08/jardins-realismo/README.md). A terceira etapa arredonda a carroceria/vidros/retrovisores, revisa rodas e materiais e introduz asfalto/gramado originais com acabamento de fachadas. [Capturas, otimização e validação](docs/art-results/2026-10-08/jardins-mw2012/README.md). O acabamento próximo e o desempenho sustentado na Intel continuam pendentes; a média de FPS não encerra esse critério.

A [quarta revisão, em 2026-10-09](docs/art-results/2026-10-09/neighborhood-refresh/README.md), acrescenta 30 casas às frentes externas das ruas existentes, totalizando 45 imóveis. Ruas passam de 8–10 m para 11,5–14 m; o recorte conserva seis quarteirões e os dezessete trechos conectados. Há 229 árvores, 21 carros estacionados, jardins compartilhados, variação de telhados/alturas e horizonte preenchido. O carro recebe nova revisão de óticas, rodas/pneus, para-choques, pintura, vidros e placas, com luzes de freio/ré funcionais. O céu original com nuvens é usado também nos reflexos. Capturas em Equilibrado/Econômico são inspeções estáticas; a janela combinada de benchmark e a avaliação jogada continuam como próximos gates antes da expansão.

A revisão seguinte amplia a cidade para 18 quarteirões, triplica a área física, une as calçadas e acrescenta gramíneas e relevo mais variado. Os 115 imóveis usam lotes sem sobreposição e fundações/muros ajustados ao terreno. O Gol ganha 6 cm de altura na carroceria e faróis funcionais em todos os mapas, com L/L1. O usuário confirmou a melhora visual e o funcionamento do controle antes desta expansão. [Capturas desta etapa](docs/art-results/2026-10-09/pilot-expansion/README.md) e [validação](docs/development-results/2026-10-09/pilot-expansion/README.md): 739 verificações Godot + 10 Python no projeto, 316 no pacote. A retomada isola o controle conectado dos inputs da fixture da serra; os comandos do jogo permanecem intactos.

A etapa anterior ampliou o recorte para 1.536 × 1.232 m, com 72 quarteirões, seis praças e variação de densidade/fachadas/vegetação entre zonas. O dia completo dura 24 minutos reais, com relógio no HUD e avanço de três horas por F6/R1. A cena gerada é salva como `.scn` comprimido. [Resultados desta etapa](docs/development-results/2026-10-09/pilot-day-night/README.md).

## Sequência de trabalho

### 1. Consolidar os três bairros como base de condução

Conferir o traçado em movimento: contorno da cidade, volta pelo centro e subida/descida da encosta nos dois sentidos. Conferir curvas, largura, cruzamentos, guias, entrada da praça e pátio da oficina no bairro ampliado. O carro deve encontrar apoio contínuo, poder frear e manobrar e retornar à mesma sessão sem trocar de mapa.

Os testes automatizados verificam conectividade, geometria reproduzível, colisões e condução por comandos reais. A avaliação jogada verifica leitura, escala e prazer. Se um trecho exigir correção, alterar primeiro o problema observado; não criar outro mapa para contorná-lo.

### 2. Definir física e câmera nesse lugar

Usar o controlador arcade existente como ponto de partida. Avaliar baixa velocidade, ré, frenagem, subida, descida, curvas e freio de mão. Escolher uma rota curta repetível e comparar ajustes nela. Registrar sensação humana e defeitos reproduzíveis; alterar física somente com um motivo concreto. Verificar teclado e gamepad, câmera externa e capô.

Velocidade de teste automatizada não é certificação de handling. Cruzamentos urbanos precisam de frenagem e curvas legíveis; o limite do carro não determina a velocidade adequada para toda rua.

A [primeira revisão de 2026-10-09](docs/development-results/2026-10-09/arcade-handling/README.md) corrige a rotação solicitada além da aderência disponível e acrescenta dissipação de escorregamento e resposta gradual. O feedback jogado aprovou a melhora na condução, mas pediu aceleração aproximadamente 60% menor e **Most Wanted 2012 como referência atual de condução**. A [revisão seguinte](docs/development-results/2026-10-09/mw2012-acceleration/README.md) reduz o ganho de velocidade sob acelerador para 40%: 0–100 em 8,0 s, preservando o limite alcançável de 220 km/h e a capacidade de subir. Avaliar a progressão de velocidade na rota atual antes de considerar a sensação aprovada.

### 3. Estabelecer a estética em um quarteirão da própria cidade

Escolher um trecho que reúna rua, calçada, fachada, vegetação e relevo. Trabalhar proporção, paleta, pavimento, iluminação, horizonte e detalhes brasileiros com assets originais ou licença verificável. Comparar imagens e condução no mesmo trecho em Econômico e Equilibrado. O kit atual é provisório; validar o acabamento em um trecho representativo antes de refiná-lo no bairro inteiro.

A orientação visual mais recente do usuário passa a ser Most Wanted 2012, especialmente realismo do carro, materiais, iluminação e acabamento urbano. A referência anterior de 2005 permanece apenas no histórico documental. Não usar assets extraídos. [Referências de design](docs/design-references.md) permanecem como orientação.

### 4. Avaliar a expansão solicitada

A expansão atual quadruplica a área da etapa de 72 quarteirões e acrescenta dois bairros com arquiteturas distintas. Avaliar a travessia entre os bairros, a leitura do minimapa, as avenidas do centro e a subida/descida residencial. O ciclo contínuo de dia e noite preserva sol, lua, nuvens, estrelas e luzes locais, com janelas seletivas nas torres. A medição de custo continua pendente para uma janela combinada; capturas estáticas não aprovam desempenho.

Integrar atividades pequenas ao traçado quando direção e leitura estiverem boas: percurso entre praça e oficina, checkpoints ou entrega simples. Reaproveitar o HUD e os sistemas existentes conforme necessário. A expansão é conteúdo conectado, sem reiniciar uma coleção de cenas independentes.

### 5. Consolidar custo e critérios antes das cidades definitivas

Medir rotas renderizadas e sessão longa na cidade piloto. Corrigir os custos demonstrados pelas medições; adotar partição/streaming existente somente quando a residência ou o carregamento justificar. A primeira versão compacta carrega inteira. Capturas estáticas e testes headless não comprovam FPS.

A cidade piloto estará consolidada quando traçado, condução e direção visual tiverem avaliação humana, acessos forem confiáveis e os perfis obrigatórios forem medidos. Então construir as cidades definitivas usando o kit, a física, a câmera e os limites de custo estabelecidos aqui. Escala e ligação regional serão decididas nesse momento.

## Restrições preservadas

Godot 4.7.2, GDScript tipado e renderer Compatibility. Geração offline: editar, gerar, validar e salvar; nenhuma geração pesada durante a partida. Preservar controles, áudio, configurações persistidas e sistemas úteis. Os mapas anteriores permanecem no menu como laboratórios de regressão, incluindo circuito, rally, corredor, streaming, viagem e serra. O desenvolvimento de conteúdo se concentra na cidade piloto.

O perfil de pneus experimental do rally não redefine a física do projeto. Streaming/HLOD existentes podem ser reaproveitados quando necessários. Não reescrever o controlador nem criar outro gerenciador sem evidência de necessidade.

## Hardware e validação

Meta: Dell Inspiron 5547/Haswell com **8 GB de RAM**. Econômico (`economy`), inicialmente 854×480, sem sombras/MSAA/efeitos caros: HD 4400 com pelo menos 30 FPS sustentados. Equilibrado (`medium`), inicialmente 1280×720, sombras/MSAA 2×: R7 M260 com pelo menos 30 FPS sustentados. Qualidade (`high`) atende hardware moderno. Preferências antigas, preset Legacy e backend permanecem compatíveis.

A máquina disponível tem 16 GB e é compartilhada; não certifica o requisito de 8 GB. Benchmarks novos exigem condições de uso exclusivo combinadas. Registrar GPU, renderer, resolução, presets, rota e frame times, com três passagens e sessão longa. [Performance](docs/performance.md) e [orçamento](docs/performance-budget.md) detalham a medição. Windows nativo continua pendente. O DualShock 4 conectado foi reconhecido e seu funcionamento foi confirmado pelo usuário em 2026-10-09.

Executar o runner de projeto após alterações compartilhadas e conferir o pacote exportado antes de distribuir. Evidência da cidade deve distinguir testes funcionais, capturas visuais, medição de desempenho e avaliação humana. Nenhuma aprovação de uma dessas frentes substitui as demais.
