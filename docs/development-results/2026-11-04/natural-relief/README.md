# Relevo natural da cidade piloto — 2026-11-04

A revisão dá mais presença às subidas e descidas dos 200 quarteirões existentes. Jardins do Vale recebe duas colinas amplas conectadas por uma crista; Vila Aurora acompanha suas encostas e um vale mais baixo; Centro Horizonte conserva um patamar mais suave. A geometria é construída offline, com as mesmas ruas curvas e a mesma malha de terreno de oito metros.

[Comparação das alturas e do perfil da avenida](terrain-comparison.svg). O diagrama usa dados reais do layout; não é uma captura renderizada do jogo. A escala representa altura relativa ao ponto mais baixo do terreno de cada versão, sem confundir a mudança de cota de base com o aumento do relevo.

## Perfil das ruas

| Medida | Antes | Depois |
| --- | ---: | ---: |
| Desnível entre ruas mais baixas e mais altas | 20,7 m | 52,4 m |
| Inclinação longitudinal máxima | 4,5% | 8,4% |
| Inclinação transversal máxima | 4,5% | 8,3% |
| Cota mínima/máxima das ruas | 2,4–23,1 m | 14,1–66,5 m |

As curvas verticais são largas e progressivas. O Centro varia aproximadamente 3,5 m nas ruas amostradas; as colinas ficam concentradas nos bairros residenciais. O traçado horizontal, os 430 trechos e a área de 3.072 × 2.464 m são preservados. O terreno continua com **236.544 triângulos**; não há subdivisão adicional para obter o relevo.

## Integração e custo

`pilot_terrain.gd` concentra a altura analítica, a amostragem da grade e a interpolação na mesma diagonal usada pela malha salva. Um cache compacto de amostras é preenchido sob demanda: ele evita repetir as funções de altura para as mesmas células, sem gerar a cidade durante a partida. Consultas fora do mapa continuam o mesmo campo de relevo para o cenário distante.

O gerador recalcula terreno, ruas, calçadas, guias, acessos, fundações, muros, vegetação e colisões. As fundações permanecem niveladas, enquanto muros e pavimentos acompanham o solo. Bancos em locais inclinados recebem um pequeno embasamento nivelado; sua colisão original é ajustada para cobrir esse apoio, preservando uma única forma por banco. Carro, câmera, controles e parâmetros de condução permanecem os existentes. O gerador passa à versão 14 e registra `terrain_revision=2026-11-04-natural-relief`.

Os recursos compartilhados, os LODs, os buffers compactos e a compactação nativa dos sólidos da revisão de otimização continuam ativos. O cache de alturas limita suas tabelas a aproximadamente 1 MiB. Preservar a contagem de triângulos não certifica FPS: mudanças de visibilidade e sombras nas colinas ainda precisam de medição renderizada.

## Verificação específica

Os 15 testes de relevo verificam desnível, limites de inclinação, curvas verticais, variedade de subidas/descidas, suavidade do Centro, orçamento de triângulos, continuidade nas células e bordas e correspondência com os vértices reais. Uma bancada de colisão criada a partir do terreno executa quatro percursos nos dois sentidos das encostas, com apoio em todas as amostras, além de estacionamento com freio de mão. A base e a colisão dos bancos são verificadas em uma encosta real do layout.

Essa bancada isola o terreno; a condução nos bairros completos e as transições de calçadas são verificadas separadamente após a geração da cidade. O trabalho mantém o modo headless: nenhuma janela do jogo é aberta, e a avaliação visual jogada permanece necessária.

[Dados anteriores](validation/before-terrain.json) · [dados atuais](validation/after-terrain.json) · [testes específicos](validation/relief-smoke.log).

## Reproduzir

```sh
godot --headless --path . --script res://scripts/tools/profile_pilot_terrain.gd -- --output=/tmp/wave-terrain.json
godot --headless --path . --fixed-fps 60 --script res://tests/pilot_relief_smoke.gd
godot --headless --path . --script res://scripts/tools/build_pilot_city.gd
GODOT_BIN=/caminho/para/godot bash scripts/tools/check_project.sh
GODOT_BIN=/caminho/para/godot bash scripts/tools/export_builds.sh
GODOT_BIN=/caminho/para/godot bash scripts/tools/check_exported_access.sh
```

A comparação pode ser recriada com `scripts/tools/plot_pilot_terrain.py ANTES.json DEPOIS.json SAIDA.svg`, usando Matplotlib e NumPy apenas para o diagrama. Essas bibliotecas não são dependências do jogo.

## Cidade salva e pacote

A cidade de produção foi regenerada e os builds Linux e Windows foram atualizados. A suíte da cidade comparou a geometria, os UVs, as posições e todas as colisões com uma segunda geração isolada, sem diferenças. Seus 43 testes passaram, incluindo seis percursos fechados de ida/volta e os acessos à praça e à oficina. Os testes de calçadas incluem agora a encosta mais íngreme nos dois sentidos e passaram nas 72 verificações.

O pacote exportado passou **536 verificações em 19 suítes**, incluindo a guarda de integridade do pacote. Os trajetos mantiveram apoio e pavimento em todas as amostras. O executável Linux também abriu e encerrou o menu em headless, sem diagnósticos inesperados. Os dois arquivos `Wave.pck` têm 201.359.020 bytes e SHA-256 `cce26078b591e4d43bc40624bfa90f16f68a2e697fc99e454a1387989afacee9`.

[Regeneração de produção](validation/city-build.log) · [validação do pacote](validation/exported-access.log) · [exportação](validation/export-builds.log) · [menu Linux headless](validation/native-headless-menu.log). A execução nativa no Windows, a leitura visual em movimento e a medição de FPS permanecem pendentes.

A execução completa do projeto passou **1008 verificações Godot em 42 suítes principais**, além de **23 testes Python**, persistência e montagem offline. Não houve falhas nem diagnósticos inesperados. [Log completo](validation/source.log) · [regeneração e percursos da cidade](validation/pilot-city.log) · [dados dos percursos](validation/pilot-city-results.json) · [registro de integridade](validation/record.json).
