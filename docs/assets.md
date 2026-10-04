# Registro de assets

| Asset | Origem | Autor | Licença | Data | Modificações |
| --- | --- | --- | --- | --- | --- |
| Carro provisório | `scenes/cars/player_car.tscn` | Projeto Wave | Licença do projeto a definir | 2026-10-04 | Primitivas com rodas e faróis, materiais locais |
| Casas, comércio e oficina | `scripts/city/neighborhood_builder.gd` | Projeto Wave | Licença do projeto a definir | 2026-10-04 | Geometria gerada e salva na cena do mapa |
| Árvores, postes, bancos e placas | `scripts/city/neighborhood_builder.gd` | Projeto Wave | Licença do projeto a definir | 2026-10-04 | Primitivas e materiais compartilhados |
| Ruas e calçadas | `scripts/city/neighborhood_builder.gd` | Projeto Wave | Licença do projeto a definir | 2026-10-04 | Cruzamentos, faixas e acessos ao estacionamento |
| Céu e iluminação | `scenes/city/drive_neighborhood.tscn` | Projeto Wave | Licença do projeto a definir | 2026-10-04 | Configuração do céu procedural e ambiente da Godot |
| Motor provisório | `assets/audio/wave-engine.wav` | Projeto Wave | Original; licença do projeto a definir | 2026-10-04 | Síntese harmônica, loop de 1 segundo; pitch ajustado durante a condução |
| Vento e pássaros | `assets/audio/wave-evening.wav` | Projeto Wave | Original; licença do projeto a definir | 2026-10-04 | Ruído filtrado e chirps sintetizados; loop de 20 segundos |
| Música “Wave Sunset” | `assets/audio/wave-sunset.wav` | Projeto Wave | Composição original; licença do projeto a definir | 2026-10-04 | Arpejos, baixo e melodia sintetizados; loop de 32 segundos |

Nenhum modelo, textura ou áudio externo foi baixado nesta etapa. O projeto utiliza primitivas e fontes padrão fornecidas pela Godot. Os três arquivos de áudio são criações locais sem gravações, samples ou composições de terceiros. A licença de distribuição do projeto, incluindo esses assets, permanece a definir.

Para regenerar os áudios, execute `python3 scripts/tools/build_audio.py`. O script usa apenas a biblioteca padrão do Python e uma semente fixa para o ambiente. Os WAVs são mono, PCM de 16 bits, 22.050 Hz, totalizando aproximadamente 2,3 MB. Os recursos importados devem permanecer em PCM para preservar os loops completos.
