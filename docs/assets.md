# Registro de assets

| Asset | Origem | Autor | Licença | Data | Modificações |
| --- | --- | --- | --- | --- | --- |
| Cupê vintage Maré 68 (modelo anterior) | `assets/models/mare_68/` | Projeto Wave | Original; licença do projeto a definir | 2026-10-04 | Carroceria original, teto marfim, vidros inclinados, caixas de roda recortadas, cromados, faróis circulares, lanternas, retrovisores e rodas com calotas |
| Hatch 1000 | `assets/models/hatch_1000/` e `scenes/cars/player_car.tscn` | Projeto Wave | Geometria original; licença do projeto a definir | 2026-10-04 | Aparência inspirada no Gol 1000 quadrado; sem marca ou logotipo; branco, duas portas, faróis retangulares, plásticos pretos e rodas de aço |
| Autódromo do Sol | `scripts/tools/build_race_track.gd` e `scripts/race/circuit_layout.gd` | Projeto Wave | Licença do projeto a definir | 2026-10-04 | Circuito, boxes, arquibancada, zebras, marcas e áreas de escape originais |
| Casas, comércio e oficina | `scripts/city/neighborhood_builder.gd` | Projeto Wave | Licença do projeto a definir | 2026-10-04 | Geometria gerada e salva na cena do mapa |
| Árvores, postes, bancos e placas | `scripts/city/neighborhood_builder.gd` | Projeto Wave | Licença do projeto a definir | 2026-10-04 | Primitivas e materiais compartilhados |
| Ruas e calçadas | `scripts/city/neighborhood_builder.gd` | Projeto Wave | Licença do projeto a definir | 2026-10-04 | Cruzamentos, faixas e acessos ao estacionamento |
| Céu e iluminação | `scenes/city/drive_neighborhood.tscn` | Projeto Wave | Licença do projeto a definir | 2026-10-04 | Configuração do céu procedural e ambiente da Godot |
| Motor provisório | `assets/audio/wave-engine.wav` | Projeto Wave | Original; licença do projeto a definir | 2026-10-04 | Síntese harmônica, loop de 1 segundo; pitch ajustado durante a condução |
| Vento e pássaros | `assets/audio/wave-evening.wav` | Projeto Wave | Original; licença do projeto a definir | 2026-10-04 | Ruído filtrado e chirps sintetizados; loop de 20 segundos |
| Música “Wave Sunset” | `assets/audio/wave-sunset.wav` | Projeto Wave | Composição original; licença do projeto a definir | 2026-10-04 | Arpejos, baixo e melodia sintetizados; loop de 32 segundos |

Nenhum modelo, textura ou áudio externo foi baixado nesta etapa. O projeto utiliza geometria original e fontes padrão fornecidas pela Godot. Os três arquivos de áudio são criações locais sem gravações, samples ou composições de terceiros. A licença de distribuição do projeto, incluindo esses assets, permanece a definir.

O Maré 68 é um desenho original de cupê compacto inspirado na linguagem geral dos anos 60, sem marca ou logotipo de fabricante. Suas malhas são construídas offline por `scripts/tools/build_vintage_car.gd` e salvas em `body.tres` e `wheel.tres`. São 1.572 triângulos na carroceria e 944 em cada roda, totalizando 5.348. A carroceria tem cinco superfícies de material; as quatro rodas compartilham uma malha de três superfícies. As peças são agrupadas nas malhas, sem scripts por detalhe e sem geração durante o jogo.

O modelo ativo é o **Hatch 1000**, inspirado na aparência do Gol 1000 quadrado. A referência visual são as fotografias do [ensaio da Quatro Rodas](https://quatrorodas.abril.com.br/carros-classicos/classicos-o-popular-vw-gol-1000/); nenhuma fotografia, textura ou malha desse ensaio foi incluída no jogo. A geometria foi criada localmente, sem emblemas de fabricante: 1.512 triângulos de carroceria e 944 por roda, total de 5.288. As rodas e materiais são compartilhados. O Maré 68 foi preservado como modelo anterior.

Regenerar o hatch com `godot --headless --path . --script res://scripts/tools/build_hatch_car.gd`. O gerador anterior permanece em `build_vintage_car.gd`. Gerar uma prévia de quatro ângulos do carro ativo com janela usando `godot --path . --script res://scripts/tools/build_car_preview.gd`; imagens em `builds/previews/hatch-1000.png`. A avaliação visual pelo usuário está pendente.

O circuito atual tem traçado original de 3.241 m amostrado em 649 pontos, asfalto e áreas de escape em malhas compartilhadas e props em lotes por setor. Regenerar com `godot --headless --path . --script res://scripts/tools/build_race_track.gd`. As cenas são carregadas prontas durante o jogo.

Para regenerar os áudios, execute `python3 scripts/tools/build_audio.py`. O script usa apenas a biblioteca padrão do Python e uma semente fixa para o ambiente. Os WAVs são mono, PCM de 16 bits, 22.050 Hz, totalizando aproximadamente 2,3 MB. Os recursos importados devem permanecer em PCM para preservar os loops completos.

### Materiais e cenário do Circuito do Sol

Onze PNGs originais em `assets/textures/race/`, produzidos por `scripts/tools/build_race_textures.py` com semente fixa e apenas a biblioteca padrão de Python: asfalto, concreto, tijolos, grama e chapa metálica, cada um com mapa normal, além de folhagem com transparência recortada. Não há imagens, marcas, modelos ou texturas extraídos de Need for Speed. Most Wanted 2005 é a referência visual solicitada pelo usuário, não uma fonte de assets.

`scripts/race/race_materials.gd` configura os materiais compartilhados; os props usam projeção em coordenadas do mundo para preservar a escala da textura. A pista usa UVs métricos, evitando o custo de três projeções por pixel. Árvores usam três planos cruzados com recorte de alfa, tronco e colisão; oficinas e galpões incluem janelas, portas, calhas, coberturas e ventilação. Geometria e materiais continuam gerados offline e salvos na cena, com lotes por setor.

Esta revisão entrega uma primeira base de materiais e ambiente mais realistas. A modelagem do carro, variedade das fachadas, vegetação e composição do cenário ainda precisam evoluir para alcançar a referência visual.
