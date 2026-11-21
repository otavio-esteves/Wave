# Vila das Figueiras · vale, cidade e galeria

[Avenida e lago antes e depois](comparacao.jpg) · [Galeria e encosta](galeria.jpg) · [Vale, arroio, viveiro e cinema](vale.jpg)

A Estrada do Vale liga os extremos da rua sul. São **578,5 m** em dois sentidos, com 10,6 m de asfalto antes dos recuos. Ela desce até o Arroio do Vale, atravessa o aterro sobre a drenagem e volta a subir junto ao Viveiro do Vale. O pomar, o galpão e o caminho de pedra ficam ao lado do recuo. Junto com a Estrada do Mirante e o Contorno das Águas, são **1.501,5 m** de estradas conectadas à malha urbana. As três vias usam a largura de Monza como referência física e oferecem voltas com ritmos diferentes, seguindo a lógica de exploração de Most Wanted e Burnout Paradise. [Referências e dimensões](../../../design-references.md#proporções-e-desenho-urbano-da-vila-das-figueiras)

O eixo da Estrada do Vale vai de 18,1 a 38,1 m. A maior inclinação média em 4 m é de 11,7%, com raio de curva mínimo de cerca de 32 m medido em uma janela de 12 m. Da parte mais baixa do vale ao alto da Estrada do Mirante, o desnível dirigível é de **55,4 m**. O terreno é subdividido junto às estradas e ao arroio e forma um patamar no acesso ao viveiro. A pintura e a colisão acompanham os mesmos triângulos do asfalto.

A **Galeria da Pedra** cobre 48 m da Estrada do Mirante, entre cortes de rocha. A abóbada tem colisão própria. Oito pares de luminárias marcam a curva. As luzes iluminam a pista por proximidade, com limite de uma luz dinâmica no Econômico. O arroio tem corrente animada, pedras nas margens e som sintético localizado no canal Ambiente. No lago, as ondulações variam ao longo da superfície e os grupos de juncos interrompem a linha da margem. A névoa se aproxima na transição de luz para marcar a profundidade das encostas. [Material de gnaisse](../../../../assets/textures/figueiras/gnaisse-vale.png) · [Proveniência e prompt ImageGen](../../../../assets/textures/figueiras/gnaisse-vale.provenance.json)

O **Cine Figueiras** abre a sequência comercial da avenida com marquise, cartazes, pilastras e platibanda escalonada. As fachadas vizinhas ganharam janelas em três vãos, peitoris de pedra e varandas. As cores de reboco compartilham material e geometria por setor. Faixas brancas e amarelas agrupam a pintura no mesmo lote de malha, e o acostamento aproveita a malha e o material do asfalto. O alcance das vidraças segue o perfil gráfico. Árvores de fundo têm tronco e copa com silhuetas diferentes das árvores próximas. O minimapa indica o vale, o arroio, a galeria e os três recuos.

## Verificação

O teste de condução começa nas ruas do bairro e termina de volta à malha urbana. Ele usa aceleração, direção e freio em todos os trechos, com uma parada em cada recuo. Raios conferem piso, teto e pelo menos 4 m de altura livre nas faixas da galeria. As capturas foram feitas no Equilibrado, com a versão anterior à esquerda na comparação. A galeria aparece às 16h30 e às 20h, o lago às 16h30 e o arroio às 14h.

O pacote final passou **61 verificações** e a sequência de renderização passou **47 verificações**. Nos seis percursos e nas três manobras de estacionamento, o Gol manteve apoio em todos os quadros. O teste também confirmou o patamar e os degraus do viveiro. O executável Linux abriu a Vila e os builds Linux e Windows têm PCKs idênticos.

## Desempenho

Cada passagem usou cinco segundos de aquecimento e dez de condução com janela em foco, VSync desativado e alvo de 38 km/h. O ensaio comparou o pacote anterior com a revisão de renderização. O ajuste do patamar do viveiro veio depois desse ensaio.

| Trecho | Econômico · Intel HD 4400 · 854 × 480 | Equilibrado · Radeon R7 M260 · 1280 × 720 |
| --- | ---: | ---: |
| Avenida, pacote anterior | 10,5 FPS · P95 de 106,5 ms · 852 chamadas de desenho | 28,6 FPS · P95 de 35,9 ms · 1.253 chamadas de desenho |
| Avenida, revisão | 10,6 FPS · P95 de 112,2 ms · 770 chamadas de desenho | 27,8 FPS · P95 de 37,2 ms · 1.185 chamadas de desenho |
| Estrada do Mirante, atravessando a galeria | 14,2 FPS · P95 de 66,2 ms | 35,5 FPS · P95 de 38,2 ms |

O P95 é o percentil 95 dos tempos de quadro. A avenida passou a emitir aproximadamente 10% e 5% menos chamadas de desenho, respectivamente. A meta de 30 FPS sustentados continua aberta nos dois perfis.
