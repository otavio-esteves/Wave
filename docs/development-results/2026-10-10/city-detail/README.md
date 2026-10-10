# Cidade preenchida e mapa completo

A área e o traçado existentes são preservados: 7.569.408 m², 200 quarteirões e 430 ruas. [Metadados](city-metadata.json) · [Galeria](../../../art-results/2026-10-10/city-detail/index.html) · [Comparação](../../../art-results/2026-10-10/city-detail/compare.html).

Imóveis passam de 927 para 2.023, árvores de 2.714 para 3.790 e carros estacionados de 320 para 813. Há 211 arranha-céus, 48.971 tufos de grama, seis formas de árvores e 427 conjuntos de mobiliário, incluindo bancos, lixeiras e alguns abrigos de ônibus. Mais frentes de rua e casas laterais usam o mesmo sistema de lotes afastados. Jardins internos reservados, canteiros floridos, duas elevações suaves e tons de asfalto/calçadas por região enriquecem a cidade. Pergolados recebem vigas e quatro apoios. A busca de colisão entre lotes consulta um índice espacial de 64 m.

O mapa completo abre com M/Share ou pelo menu de pausa. Consulta pausa o carro, ciclo e nuvens; fechamento restaura o estado anterior de pausa e o mouse da câmera. Arrastar/direcional move a vista, roda/+/−/L2/R2 controla zoom, clique/X coloca marcador, R3 centraliza no carro. Botões localizam carro, praça e oficina; Esc/Círculo volta sem resetar o carro. O marcador usa linha direta, sem cálculo de rota.

## Armazenamento e integração

Malhas de terreno, ruas, calçadas, marcações, acessos, numeração e sombras de contato ficam em recursos externos comprimidos. A geometria estática é salva em cenas por setores de 512 m. O carregamento permanece integral, sem novo streaming. Colisões de objetos são divididas em corpos estáticos de 128 m; terreno, ruas e calçadas preservam o corpo e os nomes de apoio originais. Transformações e formas físicas são preservadas. Iluminação noturna, perfis gráficos, inspeção de árvores e testes percorrem a hierarquia de setores.

Uma captura inicial encontrou setores salvos sem referência da cena principal. O salvamento passou a definir explicitamente o caminho dos recursos antes de instanciá-los. A inspeção seguinte identificou um falso negativo na fixture: `find_child("Terrain")` encontrava primeiro a colisão homônima. A comparação agora busca explicitamente `MeshInstance3D`. Logs iniciais ficam preservados. Uma fixture de alternância de M também precisou separar liberação/pressão em frames distintos para não modificar o mesmo evento ainda na fila.

## Validação

A cobertura consolidada reúne **812 verificações Godot e dez testes Python**, incluindo os laboratórios anteriores. [Resumo auditável](validation-summary.json) · [Log do runner](project-checks.log) · [Percursos da cidade](source-city-results.json) · [Calçadas no fonte](source-curb-results.json).

A cidade passou **43 checks**: grafo conectado, geração reproduzível, malhas salvas, separação de lotes, apoio e desobstrução de todas as ruas, seis circuitos nos bairros/centro/colinas e acessos da praça/oficina. Os seis circuitos mantiveram apoio e asfalto em todos os quadros, com desvio máximo de 1,076 m. O relevo entre extremos das ruas é 20,661 m; as novas colinas modificam a distribuição local. As 18 travessias de calçada passaram 56 checks, sem travamentos ou quadros sem apoio, com incremento máximo de altura de 0,024921 m. [Resultado do pacote](package-curb-results.json) é numericamente idêntico ao fonte.

O runner inicial leu a cena durante seu salvamento e a fixture de câmera registrou erros de carga apesar de declarar seus 20 checks aprovados. A fixture agora exige a presença real do carro e da cidade; foi repetida após a geração, com **20 checks e saída 0**. O mapa final também foi repetido: **13 checks e saída 0**, incluindo R3, M/Share, Esc/Círculo, zoom, marcador, pausa do carro/relógio e retorno ao menu. Esses resultados substituem a cobertura inicial sem contar checks em duplicidade. O log do runner termina com todos os 34 resumos e `All Wave checks passed`; a sessão de orquestração reportou 143 ao ser recolhida, registrado no JSON.

No pacote real, fora do projeto e com fixtures externas, passaram **193 checks**: cidade/layout 20, mapa 13, dia/noite 54, calçadas 56, menu/mapas anteriores 17, carro 13 e câmera/gamepad 20. A conferência final de layout e o lote das demais suítes encerraram com saída 0. Após um último ajuste para redesenhar o mapa a cada frame durante movimento/zoom, os 13 checks do mapa foram repetidos no fonte e no PCK final; as outras 180 verificações cobrem os mesmos recursos e código não alterado, conferidos no pacote anterior a esse ajuste de interface. A captura do pacote usa `--main-pack`, exige `project.binary` e ausência de `project.godot`, entra pela opção real do menu e registra carro e mapa em Equilibrado/R7 M260. O executável Linux nativo iniciou e encerrou corretamente em headless. O template release não executou a fixture externa pela tentativa com `--script`; a captura foi refeita no Godot com o PCK exportado.

A cena principal tem cerca de 1,9 MiB; as malhas e setores ficam em arquivos separados, todos abaixo de 40 MiB. [Inventário e tamanhos](resource-sizes.json). A separação preserva os recursos e a geometria conferidos pela regeneração.

## Builds e limites

Linux e Windows compartilham o PCK de SHA-256 `94f06f252dd677a4670b892f1066d3c65005ec159e6e625db9db3f7efc46bbeb`. [Hashes completos](build-sha256.txt). Os builds atualizados ficam em `builds/linux` e `builds/windows`, fora do Git. Distribuir a pasta completa de cada plataforma. Windows nativo, aprovação jogada e FPS sustentados permanecem pendentes; capturas e testes headless não certificam essas frentes. A máquina disponível tem 16 GB e não certifica o requisito de 8 GB. Os avisos conhecidos de duas texturas GLES ao encerrar capturas permanecem registrados nos logs.
