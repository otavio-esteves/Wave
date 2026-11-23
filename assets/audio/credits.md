# Áudio da Vila das Figueiras

**Brisa do Arroio**, **Alameda 92** e **Depois da Chuva** são composições instrumentais originais do Wave. O gerador usa síntese de cordas, teclas, baixo e percussão, com arranjos e melodias escritos no próprio script. Para renderizar os Ogg Vorbis estéreo, execute `python3 scripts/tools/build_radio.py` com a libsndfile instalada.

Os efeitos abaixo usam prévias públicas das gravações CC0. O Wave recorta, equaliza e normaliza as fontes. Os loops do motor alinham a fase de fragmentos curtos à frequência de ignição de cada faixa. As batidas juntam a gravação a ressonâncias produzidas no Wave.

| Gravação | Uso no Wave |
| --- | --- |
| [seth-m, 269771](https://freesound.org/people/seth-m/sounds/269771/) | Marcha lenta. Motor de quatro cilindros gravado num Mini Cooper. |
| [alexftw123, 152661](https://freesound.org/people/alexftw123/sounds/152661/) | Quatro faixas de aceleração, da saída até a rotação alta. |
| [IanGW, 808203](https://freesound.org/people/IanGW/sounds/808203/) | Motor 1,0 a gasolina para a desaceleração e os carros do trânsito. |
| [orlandorizo, 591079](https://freesound.org/people/orlandorizo/sounds/591079/) | Rolamento no asfalto. |
| [pnwheeler, 831720](https://freesound.org/people/pnwheeler/sounds/831720/) | Rolamento no paralelepípedo. |
| [Felix Blume, 685231](https://freesound.org/people/felix.blume/sounds/685231/) | Rodas no cascalho e no acostamento. |
| [RutgerMuller, 104026](https://freesound.org/people/RutgerMuller/sounds/104026/) | Guinchado dos pneus no limite da aderência. |
| [nick121087, 342461](https://freesound.org/people/nick121087/sounds/342461/) | Gotas no para-brisa e textura de água sob os pneus. |
| [dslrguide, 321488](https://freesound.org/people/dslrguide/sounds/321488/) | Textura de raspadas e batidas em piso mineral. |
| [mandymatz, 424031](https://freesound.org/people/mandymatz/sounds/424031/) | Ressonância de carroceria, suspensão e engate. |

Para refazer a edição, salve a prévia MP3 de qualidade alta de cada gravação como `audio-source-ID.mp3` na mesma pasta e execute `python3 scripts/tools/build_recorded_audio.py CAMINHO_DAS_GRAVAÇÕES`. A libsndfile precisa oferecer decodificação de MP3.
