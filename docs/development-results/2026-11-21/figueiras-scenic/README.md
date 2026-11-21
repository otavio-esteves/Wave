# Vila das Figueiras · encosta e parque

[Estradas, azulejo e travessia](estradas.jpg) · [Lago de dia e ao entardecer](parque.jpg) · [Avenida e café antes e depois](comparacao.jpg)

A Vila ganhou duas estradas que completam voltas a partir dos nove quarteirões. Siga a avenida para leste para chegar ao Contorno das Águas ou suba até os cruzamentos dos extremos norte para entrar na Estrada do Mirante. O minimapa mostra as duas ligações e o lago.

| Via | Extensão | Largura típica do asfalto | Maior inclinação média em 4 m |
| --- | ---: | ---: | ---: |
| Estrada do Mirante | 581,7 m | 10,8 m | 14,0% |
| Contorno das Águas | 341,2 m | 11,4 m | 10,6% |

Os eixos dirigíveis vão de aproximadamente 19 a 73,5 m de altitude. A crista acrescenta cerca de 16,5 m ao ponto mais alto da malha anterior. A Estrada do Mirante contorna a encosta por curvas mais fechadas, enquanto o Contorno das Águas abre a trajetória no parque. As transições unem as larguras das quatro entradas à malha existente. Curvas têm inclinação transversal de até 5,2%. Os recuos acrescentam até 6,2 m de asfalto para estacionar. As dimensões da Vila usam a escala do Gol e a largura de Monza como referências físicas. As ligações por mais de uma rota seguem a lógica de exploração de Most Wanted e Burnout Paradise. [Proporções e referências](../../../design-references.md#proporções-e-desenho-urbano-da-vila-das-figueiras)

O painel cerâmico do Mirante do Ipê fica num muro de pedra junto ao recuo coberto. O lago ganhou margem recortada com pedras e vegetação, passeio, quiosque e píer. A água combina ondas e brilho solar guiados pelo relógio da Vila. Um som de ondas em três dimensões se ouve próximo à margem e segue o volume de Ambiente. A avenida tem travessia de 19,2 m junto à praça, piso tátil, linhas de retenção e balizadores. Telhados de quatro águas variam o perfil das casas e as marquises do café e da farmácia dão profundidade às fachadas. A cena foi gerada com 224 edificações e 479 árvores nas ruas, jardins e encostas. [Textura do painel](../../../../assets/textures/figueiras/azulejo-mirante.png) · [Proveniência e prompt ImageGen](../../../../assets/textures/figueiras/azulejo-mirante.provenance.json)

A geração aumenta a resolução do solo perto das curvas e da margem. Piso, pintura, colisão e sombra de contato do Gol acompanham os mesmos triângulos. Placas, defensas, balizadores e postes acompanham o eixo da estrada. As capturas foram feitas no Equilibrado às 16h30 e, na segunda vista do lago, às 17h33. Na comparação, o pacote anterior está à esquerda.

## Verificação

Cada perfil passou 49 verificações da Vila e 33 verificações da sequência de renderização. O Gol percorreu as duas estradas nos dois sentidos com acelerador, freio e direção. Terminou os quatro percursos entre 48 e 51 km/h, a pelo menos 1,81 m da borda do asfalto, medidos a partir do centro do carro. A condução também entrou nos dois recuos, freou, acionou o freio de mão, saiu e voltou à faixa. O teste registrou zero quadros sem apoio nas seis passagens.

O PCK exportado passou as 49 verificações. Linux e Windows usam o mesmo PCK, conferido byte a byte. A abertura do executável foi verificada no Linux.

O ensaio de desempenho usou os pacotes exportados no mesmo Dell Inspiron 5547, em Compatibility, com a janela em foco, VSync desativado e horário fixo às 16h30. Cada passagem teve cinco segundos de aquecimento e dez de condução com alvo de 38 km/h. A amostra da avenida cobre cerca de 92 m a partir da largada. As novas vias foram amostradas a partir do início da subida e da curva antes do parque.

| Trecho | Econômico · Intel HD 4400 · 854 × 480 | Equilibrado · Radeon R7 M260 · 1280 × 720 |
| --- | ---: | ---: |
| Avenida, pacote anterior | 13,1 FPS · P95 de 87,8 ms | 29,2 FPS · P95 de 35,7 ms |
| Avenida, expansão | 12,2 FPS · P95 de 92,9 ms | 28,6 FPS · P95 de 35,9 ms |
| Estrada do Mirante, expansão | 15,4 FPS · P95 de 72,4 ms | 36,1 FPS · P95 de 28,9 ms |
| Contorno das Águas, expansão | 23,6 FPS · P95 de 50,2 ms | 37,8 FPS · P95 de 28,6 ms |

A avenida passou de 723 para 852 chamadas de desenho por quadro no Econômico e de 1.116 para 1.252 no Equilibrado. O P95 é o percentil 95 dos tempos de quadro. São passagens curtas em trechos específicos. A meta de 30 FPS sustentados permanece aberta, principalmente no Econômico.
