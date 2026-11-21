# Revisão urbana da Vila das Figueiras

[Avenida, subida e praça de dia e de noite](comparacao.jpg) · [Coletora e vitrines](coletora-vitrine.jpg)

As comparações usam a câmera do jogo no Equilibrado, às 16h30 e às 21h na vista noturna. A versão anterior está à esquerda. O traçado preserva os nove quarteirões da Vila e distribui as larguras conforme o uso da rua. A ficha de Monza serve de referência física para a coletora, e o material de Most Wanted e Burnout orienta a leitura da avenida e a folga nos cruzamentos. [Referências e medidas](../../../design-references.md#proporções-e-desenho-urbano-da-vila-das-figueiras)

| Medida | Antes | Revisão |
| --- | ---: | ---: |
| Rua residencial, de guia a guia | 7,20 m | 8,40 m |
| Rua coletora, de guia a guia | 8,40 m | 11,20 m |
| Avenida, com estacionamento | 12,40 m | 19,20 m |
| Faixas de rodagem na avenida | 2 | 4 |
| Desnível medido entre os cruzamentos externos | 33,67 m | 38,03 m |
| Maior inclinação média em 6 m no mesmo recorte | 15,80% | 15,31% |
| Edificações | 218 | 224 |

Na curva mais aberta, entre a coletora e a avenida, o raio do meio-fio é de 8,5 m. O greide da avenida sobe no acesso leste e desce até o vale. A amostragem a cada 6 m mostrou cerca de 9,6% como maior inclinação nesse eixo. A faixa de asfalto, a guia e a calçada são recortadas nos próprios triângulos do terreno. A colisão e as pinturas no piso usam esses mesmos planos.

Os cruzamentos receberam travessias, setas, pisos táteis e sinalização. A praça ganhou pérgola, jardineiras em patamares e uma fonte maior. No comércio, letreiros, toldos e coberturas variam entre os lotes. O café, o mercado, a oficina e a farmácia usam um atlas de interiores original gerado com a ferramenta integrada ImageGen. As vitrines aproveitam a mesma textura com recortes por loja e acendem com o relógio. [Atlas e prompt integral](../../../../assets/textures/figueiras/lojas-interiores.provenance.json)

## Verificação

O teste da Vila passou 38 verificações em cada perfil e repetiu 38 no pacote exportado. Ele percorre a avenida, sobe e desce a encosta e faz o giro da coletora para a avenida com o controlador normal do Gol. O giro terminou a 43,1 km/h, com apoio contínuo e margem mínima de 2,82 m entre o centro do carro e a borda do asfalto. O teste também confere chão, ciclo de luz e retorno dos Laboratórios. A abertura do executável Linux foi validada. Os builds Linux e Windows contêm o mesmo PCK.

As peças opacas sem textura foram reunidas por setor com as cores originais por instância. Marcas pequenas de pavimento e sombras de contato usam o centro de seu setor para o limite de visibilidade. O Econômico usa iluminação por vértice na folhagem e aplica o detalhe distante mais cedo.

O ensaio renderizado comparou os dois pacotes em Compatibility no Dell Inspiron 5547. Depois de cinco segundos de aquecimento, cada passagem usou dez segundos de condução pela avenida, com a janela em foco, o relógio às 16h30, VSync desativado e alvo de 38 km/h. A distância percorrida variou de 92 a 100 m conforme o greide.

| Perfil | FPS médios antes → revisão | P95, ms antes → revisão | Chamadas de desenho por quadro antes → revisão |
| --- | ---: | ---: | ---: |
| Econômico, Intel HD 4400, 854 × 480 | 17,1 → 22,6 | 95,0 → 101,4 | 784 → 717 |
| Equilibrado, Radeon R7 M260, 1280 × 720 | 29,1 → 29,2 | 36,3 → 35,7 | 1.245 → 1.116 |

São diagnósticos de um trecho curto em cada perfil. O Econômico ganhou em FPS médios e teve um P95 maior. A meta de 30 FPS sustentados segue aberta.
