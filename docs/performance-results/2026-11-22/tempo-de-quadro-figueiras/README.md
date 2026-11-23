# Tempo de quadro na Vila das Figueiras

A revisão usa como referência o pacote da [otimização anterior](../otimizacao-figueiras/README.md). A contagem de chamadas já havia caído, mas os tempos de quadro continuavam altos no Dell Inspiron 5547. Esta rodada mede o custo de sombras, terreno, vegetação e resolução no mapa que abre ao iniciar o jogo.

## Referências e aplicação

- Em **Most Wanted (2012)**, Matt Webster, da Criterion, relacionou a meta de 30 FPS nos consoles ao custo visual do mundo aberto e destacou a latência entre controle e tela. O Wave mede a cauda dos tempos de quadro em movimento, com física de 60 Hz e os 24 carros do trânsito. [Entrevista de Matt Webster](https://www.videogamer.com/news/lifting-the-bonnet-criterion-talks-about-the-engine-powering-nfs-most-wanted-map-size-and-30fps/)
- A Turn 10 descreveu como **Forza Motorsport 3** escolhe níveis de geometria e mips de textura pela contribuição à imagem. No Wave, reduzir a resolução do atlas de sombras direcionais de 4.096 para 2.048 manteve as sombras no Equilibrado e baixou o P95 de 30,5 para 25,1 ms no teste fixo da Avenida. O alcance da sombra é de 72 m. A resolução menor suaviza suas bordas. [Turn 10 na GDC](https://media.gdcvault.com/gdc10/slides/Tector_Chris_StreamingMassiveEnvironments.pdf) · [Sombras direcionais na Godot](https://docs.godotengine.org/en/4.7/tutorials/3d/lights_and_shadows.html#shadow-map-size)
- **Need for Speed Rivals** usou um mapa de densidade para concentrar detalhe geométrico onde ele aparecia. Na Vila, o diagnóstico apontou custo alto do material do terreno. As variantes de grama fixam o tipo de superfície no código do shader, permitindo ao compilador eliminar os caminhos de pintura viária, sarjetas e reflexos de poças. [Apresentação sobre o terreno de Rivals na GDC](https://d29g4g2dyqv443.cloudfront.net/sites/default/files/akamai/gameworks%2Fevents%2Fgdc14%2FGDC_14_From%20Terrain%20to%20Godrays%20-%20Better%20Use%20of%20DirectX11CantlayTatarinov.pdf)
- Os perfis Econômico e Equilibrado geram um cubemap de céu de 32 texels por face, pois já usam luz ambiente por cor. O desenho do panorama na tela continua na resolução do viewport. O perfil Qualidade usa o cubemap de 64 texels para o ambiente e seus reflexos. Seis texturas de pavimento e fachadas usam BC7 com mipmaps nos pacotes desktop. [Cubemap de radiância da Godot](https://docs.godotengine.org/en/4.7/classes/class_sky.html) · [Implementação da compressão no Compatibility](https://github.com/godotengine/godot/blob/4.7-stable/drivers/gles3/storage/texture_storage.cpp)

## Medição em movimento

Dell Inspiron 5547 com i7-4510U e 16 GiB, Linux, Mesa 25.0.7, X11 e Godot 4.7.2/Compatibility. Cada lado alternou três passagens de 12 segundos após cinco segundos de aquecimento. As medições usam o mesmo script, VSync desligado, 24 carros e estado de luz controlado. O foco foi conferido a cada quadro. Na Radeon, janela e viewport de 1.280 × 720. Na Intel, janela de 854 × 480 e viewport efetivo de 569 × 320 nesta sessão.

| GPU, perfil e trecho | FPS médio | P95 | P99 | Quadros acima de 33,3 ms |
| --- | ---: | ---: | ---: | ---: |
| Radeon R7 M260, Equilibrado, Avenida | 34,86 → 42,51 | 36,69 → 33,02 ms | 43,10 → 39,04 ms | 15,7% → 4,5% |
| Radeon R7 M260, Equilibrado, cabine com chuva | 25,14 → 28,32 | 50,35 → 44,37 ms | 111,37 → 79,78 ms | 87,2% → 59,0% |
| Intel HD 4400, Econômico, Avenida | 16,62 → 22,69 | 77,90 → 73,99 ms | 87,90 → 81,65 ms | 94,3% → 61,6% |
| Intel HD 4400, Econômico, Baixada | 26,81 → 29,09 | 72,49 → 70,51 ms | 81,25 → 79,27 ms | 56,3% → 50,7% |

A tabela mostra a mediana de cada métrica nas três passagens da revisão gráfica. O FPS da Intel variou de 16,1 a 30,7 entre as três passagens da referência na Avenida. Desabilitar o pré-passe de profundidade ou forçar a desativação do VSync no driver deixou o P95 acima de 70 ms na rota. A passagem de diagnóstico via Wayland ficou sem foco. O P99 dos quatro trechos segue acima do orçamento de 33,3 ms. [Script de medição](../../../../tests/figueiras_benchmark.gd)

O mesmo ponto de vista da Avenida registrou **127,5 → 111,5 MiB** no contador de texturas da Godot. Os dados das seis texturas de 1.024 × 1.024 com mipmaps passaram de **24,0 para 8,0 MiB**. A Radeon reportou suporte nativo a BPTC no Compatibility. [Contadores do RenderingServer](https://docs.godotengine.org/en/4.7/classes/class_renderingserver.html#enum-renderingserver-renderinginfo)

## Apoio dos pneus

A versão final reaproveita a projeção nas estradas da Baixada, do Horto e do Passo entre a seleção de pavimento, a consulta da borda e a leitura de abrigo da chuva. A comparação consulta o mundo carregado em cada pacote, usando a malha de pontos do terreno e estações ao longo das estradas, em seco e molhado. Os **87.814 resultados** de tipo de piso, aderência, resistência ao rolamento e exposição à água coincidiram.

Em cinco passagens isoladas, a mediana das 87.814 consultas caiu de **4.622 para 3.582 ms** (−22,5%). As 30.860 consultas dentro da Baixada passaram de **2.371 para 1.608 ms** (−32,2%). Os tempos medem a classificação do piso por roda, uma parte do cálculo de física.

## Conferência do pacote distribuído

O PCK distribuído repetiu uma passagem de cada cenário após a revisão das consultas de piso e a correção visual do minimapa. A referência é a mediana das três passagens anteriores às mudanças.

| GPU, perfil e trecho | FPS médio | P95 | P99 |
| --- | ---: | ---: | ---: |
| Radeon R7 M260, Equilibrado, Avenida | 34,86 → 42,68 | 36,69 → 31,66 ms | 43,10 → 39,63 ms |
| Radeon R7 M260, Equilibrado, cabine com chuva | 25,14 → 28,90 | 50,35 → 42,31 ms | 111,37 → 56,66 ms |
| Intel HD 4400, Econômico, Avenida | 16,62 → 16,33 | 77,90 → 78,49 ms | 87,90 → 91,53 ms |
| Intel HD 4400, Econômico, Baixada | 26,81 → 22,16 | 72,49 → 69,30 ms | 81,25 → 75,60 ms |

A Avenida da Radeon teve 3,0% dos quadros acima de 33,3 ms na passagem final, ante 15,7% na referência. Na Intel, as médias da rodada final caíram dentro ou abaixo da faixa da referência. O objetivo de 30 FPS sustentados continua pendente, principalmente na Intel e na cabine com chuva.

## Capturas e exportação

A comparação fixa usou quatro vistas em 1.280 × 720. A diferença ficou em até quatro níveis de 8 bits por canal em 97,9% dos pixels da Avenida, 93,3% dos pixels da Praça, 97,4% dos pixels da Baixada e mais de 99,9% dos pixels no piso molhado. A Praça expõe a diferença de nitidez das sombras. O teste visual flagrou ruas que sumiam com o cache experimental do minimapa. O pacote final corrige o desenho, conferido novamente nas quatro vistas.

[Avenida antes](capturas/avenida-antes.png) · [Avenida depois](capturas/avenida-depois.png) · [Praça depois](capturas/praca-depois.png)

O pacote final passou em 72 verificações de qualidade, Copa e Baixada, além da guarda de uso exclusivo do PCK. Uma rodada anterior com a mesma classificação de piso passou em 231 verificações direcionadas de Figueiras. Linux e Windows receberam PCKs com o mesmo SHA-256. A execução nativa foi verificada no Linux. [Dados brutos e hashes](medicoes.json)
