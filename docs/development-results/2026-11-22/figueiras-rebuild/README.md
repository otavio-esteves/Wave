# Reconstrução da Vila das Figueiras

O Wave agora abre numa Vila com três novas ligações e uma copa que passa por cinco áreas. A Galeria da Praça atravessa o conjunto cívico sob a biblioteca e o arquivo. O Pátio da Estação passa pela plataforma coberta e contorna os galpões de carga. A Estrada do Passo sobe do Horto até a crista e liga ao Mirante. São cerca de **613 m adicionais de ruas dirigíveis**. O Mercado, a Praça e a travessia do arroio foram redesenhados no mesmo mapa.

## Desenho dos percursos

| Lugar | Decisão de desenho | O que muda ao dirigir |
| --- | --- | --- |
| Galeria da Praça | Dois arcos de alvenaria, passeio sob a cobertura, acesso pela avenida e saída na rua do meio | Travessia de 106,5 m. A saída sobe e conduz a outra parte da malha urbana. |
| Pátio da Estação | Plataforma no alinhamento da rua, estação em volumes escalonados conforme a cota, galpão com telhado em dentes de serra | Ligação de 116,1 m. A esquerda se fecha depois da cobertura e exige reduzir antes de entrar no pátio. |
| Mercado | Entrada por três arcos, bancas visíveis e núcleo de carga atrás do edifício | A descida e as curvas em sequência passam da rua aberta à cobertura. |
| Passo | Estrada curvada em torno da encosta, contenções no corte, recuo de parada na crista | Ligação de 390,7 m, variação de cota em torno de 29 m, inclinação transversal de até 5,2% e grampo com raio de aproximadamente 10 m. |
| Vale | Ponte com estrutura, guarda-corpos, encontros e canal contínuo sob a pista | 28 m de ponte. O leito e a pista têm colisões independentes em altura, com separação de 5,8 m no centro. |

Em *Forza Horizon 5*, Guanajuato dá orientação através dos encontros entre percursos, marcos vistos de longe e diferenças de cota. Na Vila, a crista do Passo revela a ligação ao Mirante e os galpões orientam a transição para o bairro baixo. Os cortes e o escoamento do Arroio seguem referências de implantação rodoviária. A Estação e o Mercado usam tipologias brasileiras de plataformas, galpões e mercados cobertos. [Seth Brown sobre Guanajuato](https://seth_brown.artstation.com/projects/eaGB3P?album_id=4439222) · [DNIT, implantação básica](https://www.gov.br/dnit/pt-br/assuntos/planejamento-e-pesquisa/ipr/coletanea-de-manuais/vigentes/742_manual_de_implantacao_basica_com_incorporacao_da_errata_1.pdf) · [FHWA, relevo, curva e distância de visibilidade](https://highways.dot.gov/safety/speed-management/speed-concepts-informational-guide/chapter-4-engineering-and-technical) · [IPHAN, estações e complexos ferroviários](https://www.gov.br/iphan/pt-br/assuntos/noticias/iphan-preserva-estacoes-e-complexos-que-guardam-a-memoria-dos-trilhos-no-brasil) · [Mercado Velho de Diamantina](https://www.diamantina.mg.gov.br/portal/turismo/0/9/726/mercado-velho--centro-cultural-david-ribeiro)

## Gol e câmeras

Cada roda calcula carga, curso da suspensão, escorregamento e aderência disponível para acelerar, frear e esterçar. Em cristas, a carga se desfaz antes de voltar na descida. Em piso dividido, a frenagem pode puxar para o lado que tem atrito maior. As camadas sonoras de asfalto, pedra e terra são misturadas de acordo com o contato das rodas.

O enquadramento em perseguição acompanha a trajetória com amortecimento e reduz o braço em obstruções, compensando parte da mudança com campo de visão. Na cabine, a inclinação e o olhar usam movimento do carro e leitura adiante da estrada. O retrovisor passa a atualizar com menor frequência quando o carro está parado ou o quadro está abaixo de 27 FPS. A calibragem é própria do Wave. Ela parte do trabalho de Matthew Harris sobre resposta e legibilidade em *Burnout* e *Need for Speed*, de medições de transientes de pneus e de modelos de transferência de carga. [GDC, Matthew Harris](https://www.gdcvault.com/play/1025383/Vehicle-Feel-Masterclass-Balancing-Arcade) · [Alcázar Vargas et al., transientes de pneus](https://doi.org/10.3390/s22176380) · [TU Chalmers, dinâmica de pneus e veículo](https://publications.lib.chalmers.se/records/fulltext/179864/179864.pdf)

## Provas e Copa

O mapa de atividades reúne dez provas. Marque a largada para receber orientação pelas ruas da Vila. A Copa percorre Alameda, Galeria, Estação, Passo e Mercado, registra a etapa atual entre sessões e mantém troféus separados por piso seco e molhado. Cada etapa pode render até três pontos. Uma colisão forte ou uma saída prolongada de pista exige repetir a etapa antes de avançar. Depois de completar uma prova separada, o mapa permite repetir da largada.

O melhor percurso válido registra posição e orientação a 15 Hz e reaparece como fantasma em tentativas no mesmo piso. As passagens cronometradas guardam parciais. O mapa exibe o recorde limpo e a meta de ouro. Alguns trechos adiantam a indicação de uma curva, crista ou cobertura conforme a velocidade de aproximação. Os Rivals de *Forza Motorsport 7* informaram o uso de fantasmas e de voltas limpas. As chamadas simplificadas de *EA Sports WRC* informaram as indicações em português. [Forza, Rivals e placares](https://support.forza.net/hc/en-us/articles/360005424113-FM7-Rivals-and-Leaderboards) · [EA, chamadas do navegador](https://www.ea.com/able/resources/ea-sports-wrc?isLocalized=true)

## Terreno e custo de renderização

A cena processa as sombras de contato estáticas fora do jogo. O resultado é uma textura com canais independentes para copas e volumes opacos, lida pelos materiais do chão. A sombra do Gol segue projetada no terreno durante a condução. O mapa tem níveis de detalhe indexados que reaproveitam os vértices originais por trecho e deixam o suporte físico na resolução do bake. A projeção do carro, câmera e rotas sobre curvas reutiliza segmentos pré-calculados. No teste de 125 mil projeções, os pontos retornados foram idênticos e o tempo caiu de 44,17 s para 33,56 s nesta máquina compartilhada. [Godot, níveis de detalhe por malha](https://docs.godotengine.org/en/stable/classes/class_importermesh.html)

O mapa de entrega contém 218 edificações e 765 árvores. Os 164 trechos simplificados têm 310.066 triângulos no nível de detalhe máximo e 65.816 quando todos usam o nível mais distante. A textura de contato substitui 46 malhas transparentes e 33.371 triângulos. Em cinco posições fixas da Avenida, o mesmo mapa e a mesma câmera renderizaram em média **18,9% menos triângulos por quadro** com a otimização ligada. A economia por posição variou de 17,6% a 20,8%. A comparação usa Intel HD 4400, perfil Econômico, câmera de perseguição e tráfego desligado para isolar o terreno. A contagem é do quadro inteiro.


Na repetição mais estável do percurso da Avenida, a **Intel HD 4400** passou de **13,3 para 14,2 FPS** em média no Econômico. O número de triângulos renderizados por quadro caiu de **359 mil para 305 mil**. A janela de 854 × 480 apresentou um viewport de 569 × 320 no X11. Cada versão teve duas passagens de 14 segundos, com 817 a 842 passos físicos frente aos 840 esperados. A meta de 30 FPS sustentados na Intel continua em aberto.

Na repetição da **Radeon R7 M260**, com viewport de 1280 × 720 e perfil Equilibrado, a Avenida foi de **34,2 para 33,4 FPS**. A cabine com chuva foi de **23,5 para 24,2 FPS**. A geometria média na Avenida caiu de 539 mil para 490 mil triângulos por quadro. As rodadas anteriores, feitas com carga concorrente maior, estão registradas nas medições. [Medições e condições de cada passagem](medicoes.json) · [Script de medição em movimento](../../../../tests/figueiras_benchmark.gd)

## Voltas verificadas

| Trecho | Seco | Chuva | Verificação |
| --- | ---: | ---: | --- |
| Alameda | 19,846 s | — | Prova completa e 0,97 m de margem mínima em asfalto |
| Galeria da Praça | 7,306 s | 8,297 s | Quatro balizas e fantasmas salvos nos dois pisos |
| Pátio da Estação | 10,150 s | 11,416 s | Ouro nos dois pisos, margem de 1,25 m e quatro pneus em contato durante a passagem cronometrada |
| Estrada do Passo | 31,467 s | 35,438 s | Ouro nos dois pisos e margem de 1,87 m e 1,95 m, respectivamente |

Uma Copa seca completa no pacote exportado somou **14 de 15 pontos**. O teste preparou o Gol antes da largada de cada etapa e percorreu todas as balizas com aceleração, freio e esterço. As cinco passagens salvaram fantasmas e o troféu foi recarregado do arquivo de progresso.

No próprio mapa de entrega, o Gol entrou no Passo pelo Horto, cruzou as quatro balizas e saiu pelo Mirante. A margem mínima chegou a 1,99 m, com 29,64 m de diferença de cota e apoio ao longo do percurso. A ponte conservou 5,8 m entre os dois níveis e as juntas do tabuleiro variaram até 1,56 cm da altura projetada. O teste de frenagem a 57,6 km/h mediu 13,11 m no seco e 16,29 m no molhado.

## Comparação visual

- Praça e Mercado. [Praça anterior](praca-anterior.jpg) · [Praça reconstruída](praca-entrega.jpg) · [Mercado anterior](mercado-anterior.jpg) · [Mercado reconstruído](mercado-entrega.jpg)
- Novas ligações cobertas. [Avenida antes da Galeria](galeria-anterior.jpg) · [Galeria da Praça](galeria-entrega.jpg) · [Acesso anterior da Estação](estacao-anterior.jpg) · [Pátio da Estação](estacao-entrega.jpg)
- Encosta e arroio. [Crista do Passo](passo-crista.jpg) · [Travessia anterior](vale-anterior.jpg) · [Ponte do Arroio](vale-entrega.jpg)
- Condução com entradas de volante, acelerador e freio registradas no jogo. [Galeria e Passo em movimento](galeria-e-passo.mp4)
- Câmera interna sob chuva no mesmo ponto da Avenida. [Cabine anterior](cabine-anterior.jpg) · [Cabine na entrega](cabine-entrega.jpg)
- Mapa aberto com a Travessia do Passo selecionada. [Mapa de atividades](mapa-de-atividades.jpg)
- Fantasma local carregado de uma volta anterior e renderizado na Galeria. [Replay durante a prova](fantasma-galeria.jpg)

## Validação do pacote

O pacote exportado passou em **193 verificações de Figueiras**. Foram 82 de mapa e travessias, 18 de condução, 43 de circulação e atividades, 26 de qualidade e 24 de Copa e fantasmas. O Linux carregou o build em uma janela nativa. O executável Windows carregou o mesmo pacote de recursos via Wine. Os arquivos `Wave.pck` são idênticos, com o SHA-256 nas medições.

As suítes de regressão em código-fonte, da preparação do piloto aos laboratórios, também passaram. O teste de comparação da cidade-piloto reutilizou a regeneração isolada anterior e comparou a cena salva com as mesmas verificações de geometria, colocação e colisão.
