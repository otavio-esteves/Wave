# Arquitetura do protótipo

## Cenas e responsabilidades

| Arquivo | Responsabilidade |
| --- | --- |
| `scenes/test_track.tscn` | Pista, piso, obstáculos, rampa, barreiras, carro, câmera e HUD |
| `scenes/city/drive_neighborhood.tscn` | Cena inicial: mapa do bairro, ambiente, sol, carro, câmera e HUD |
| `scenes/city/neighborhood_map.tscn` | Geometria e colisões estáticas do bairro |
| `scenes/cars/player_car.tscn` | Colisor, Hatch 1000 e pivôs de rodas animadas |
| `assets/models/hatch_1000/` | Malhas estáticas de carroceria e roda, com materiais |
| `scripts/tools/build_hatch_car.gd` | Modelagem e gravação offline do hatch |
| `scenes/race/drive_race.tscn` / `race_map.tscn` | Mundo de corrida e geometria estática do circuito |
| `scripts/race/circuit_layout.gd` | Traçado fechado e medidas, compartilhados pelo gerador e pelos testes |
| `scripts/race/race_timing.gd` | Checkpoints ordenados, validade e tempos da sessão |
| `scripts/tools/build_race_track.gd` | Geração offline do circuito |
| `scenes/terrain/practice_area.tscn` | Subida contínua, descida, calçada e piso inclinado na pista técnica |
| `tests/terrain_smoke.gd` / `race_smoke.gd` | Contato com terreno, calçadas e volta completa |
| `scenes/cars/chase_camera.tscn` | Pivô, braço de colisão e câmera, compartilhados entre mapas |
| `scenes/ui/prototype_hud.tscn` | Velocímetro, instruções e menu de pausa |
| `scenes/ui/main_menu.tscn` / `scripts/ui/main_menu.gd` | Entrada do jogo, início da direção e opções |
| `scripts/input_setup.gd` | Ações para teclado e controle, registradas sem duplicatas |
| `scripts/driving_world.gd` | Inicialização dos inputs, nome do mundo e destino da troca de cenas |
| `scripts/city/neighborhood_builder.gd` | Layout, peças de edifícios, props, materiais e lotes de instâncias |
| `scripts/city/baked_multimesh.gd` | Transformações persistidas dos lotes e restauração durante o carregamento |
| `scripts/city/neighborhood_validation.gd` | Verificação dos dados visuais e sua correspondência com piso e edifícios |
| `scripts/tools/build_neighborhood.gd` | Geração e gravação da cena estática do mapa |
| `scripts/player_car.gd` | Motor simplificado, freios, direção, aderência, colisões e reset |
| `scripts/chase_camera.gd` | Posição, atraso angular, FOV, visão traseira e reset da câmera |
| `scripts/prototype_hud.gd` | Telemetria e pausa, incluindo navegação por botões |
| `scripts/audio/wave_settings.gd` | Autoload com buses de áudio, volumes e persistência |
| `scripts/audio/driving_audio.gd` | Players de motor/ambiente/música por mundo e resposta à condução |
| `scripts/audio/audio_options.gd` | Menu de volume com sliders e navegação por foco |
| `scripts/ui/graphics_options.gd` | Tela cheia, resolução, VSync, sombras e modo econômico |
| `scripts/tools/performance_capture.gd` | Captura renderizada em CSV e resumo JSON, acionada por F4 |
| `scripts/tools/build_audio.py` | Síntese offline dos três WAVs originais |
| `tests/driving_smoke.gd` | Verificação de comportamentos com inputs simulados na cena real |
| `tests/neighborhood_smoke.gd` | Percursos nas ruas, acessos, colisões, reset e troca de mundos |
| `tests/audio_smoke.gd` | Loops, resposta do motor, pausa, opções e persistência após reiniciar |
| `tests/menu_smoke.gd` | Menus, preferências gráficas, modo econômico e transições |
| `tests/rendered_route.gd` | Rota automatizada com janela real, screenshots e medição |
| `scripts/tools/check_project.sh` | Execução das suítes em diretórios temporários |
| `export_presets.cfg` / `scripts/tools/export_builds.sh` | Exportação Linux e Windows x86_64 |

Os inputs são registrados em `_enter_tree()` do mundo, antes da inicialização dos filhos. O controlador roda em passos de física; a câmera atualiza depois do carro e o braço de colisão depois da câmera. O HUD continua recebendo input durante a pausa, enquanto a física do carro fica parada. A troca de mapas desfaz a pausa antes de substituir a cena.

## Bairro

O gerador define o bairro em coordenadas fixas e combina caixas, prismas, cilindros e esferas de poucos polígonos. Os modelos e materiais são compartilhados; as peças repetidas são agrupadas em `MultiMeshInstance3D`. Colisões simples cobrem o piso, as calçadas, os edifícios e os props que bloqueiam o carro. Os acessos ao posto têm intervalos sem meio-fio.

O comando de geração salva uma `PackedScene`. Cada lote usa `baked_multimesh.gd` para persistir suas transformações em uma propriedade exportada, independentemente do servidor gráfico. Isso permite gerar o arquivo sem interface sem perder a geometria. Durante o carregamento, o recurso restaura as instâncias e calcula seus limites de visibilidade uma vez; não há processamento por frame nesses recursos.

Depois de salvar, o gerador recarrega a cena e valida transformações, limites de visibilidade e correspondência das malhas com as colisões de piso e edifícios. O teste do bairro também verifica um ciclo de gravação e recarregamento para detectar regressões.

A comparação usa transformações acumuladas até a raiz do mapa, incluindo os nós pais. Os testes detectam o deslocamento do grupo de colisores e aceitam uma transformação comum aplicada ao mapa inteiro.

O jogo carrega essa cena sem executar o gerador, e o mapa não tem scripts por objeto. A cena principal define céu, ambiente e luz solar. As luminárias emissivas produzem aparência iluminada, mas não iluminam fisicamente a rua.

Os lotes agora são separados por células de 84 m e por geometria/material/sombras, com limites próprios de visibilidade. As ruas longas são divididas em trechos. O mapa é carregado inteiro; não foi necessário adicionar streaming. A expansão foi medida com renderização real.

## Veículo

O Hatch 1000 usa duas malhas estáticas: carroceria e roda compartilhada. Caixas de roda são recortes da geometria; acabamentos são agrupados por material. A cena mantém os caminhos dos pivôs. O colisor mede 1,6 × 0,7 × 3,65 m, entre-eixos de 2,26 m e rodas com raio de 0,31 m.

Quatro raios verticais amostram o apoio das rodas, excluindo o próprio carro e rejeitando superfícies muito íngremes. O plano ajustado aos contatos determina a inclinação suavizada de carroceria e colisor; na ausência de quatro contatos, usa-se a normal do piso detectada pela Godot. O movimento longitudinal/lateral é projetado no plano de apoio. A gravidade afeta a velocidade longitudinal no terreno; resistência ao rolamento e freios se opõem a ela. O freio de mão mantém o carro parado na ladeira. Após o ajuste ao piso, a componente vertical tangente é reconstruída a partir da resposta horizontal das colisões, evitando perda artificial de velocidade em descidas. No voo, o momento é preservado e a gravidade age verticalmente. Os pivôs das rodas acompanham os contatos dentro do curso visual de suspensão.

Meios-fios são atravessados quando o movimento encontra uma parede baixa, há espaço para elevar o carro em até 20 cm e existe piso transitável após o deslocamento. A altura do apoio encontrado determina a elevação efetiva, em vez de elevar sempre pelo limite. A checagem mantém barreiras altas e edifícios sólidos.

`CharacterBody3D` mantém uma velocidade longitudinal e preserva parte do movimento lateral ao virar. A aderência reduz esse movimento lateral a cada passo; o freio de mão diminui a aderência. O esterçamento usa uma distância entre eixos e limita o ângulo das rodas em alta velocidade.

A intensidade do pedal multiplica a aceleração, enquanto os limites de velocidade permanecem fixos. Aliviar o acelerador não seleciona uma velocidade alvo inferior; ao soltar completamente, entra a resistência ao rolamento e ao ar.

Após `move_and_slide()`, o controlador lê a velocidade resultante da colisão. Assim, bater não restaura a velocidade anterior. Ao resetar, ele limpa o movimento e emite `car_reset`, que reposiciona a câmera imediatamente.

O modelo é cinemático: a inclinação do colisor e a trajetória seguem o piso, enquanto a suspensão das rodas e o balanço adicional da carroceria são visuais. Ainda não simula molas físicas, capotamento, transferência real de peso ou resposta de um veículo rígido. Reavaliar essas limitações conforme o teste jogado, sem tratar o protótipo como um simulador.

## Circuito e cronometragem

O gerador amostra um circuito Catmull–Rom fechado, produz faixas de asfalto e escape e instancia zebras, trilhos, boxes e arquibancada. A rota e a extensão são metadados serializados na cena. O piso físico é plano e contínuo; a pista técnica preserva as rampas.

`RaceTiming` processa depois do carro. Cada checkpoint usa o cruzamento entre a posição anterior e a atual, verificando sentido, largura e altura. São necessárias as 16 portas em ordem para concluir uma volta; afastar-se do asfalto invalida a tentativa. Deslocamentos impossíveis para um passo de física cancelam a tentativa. A linha inicia uma nova volta; reset cancela a atual, preservando melhor tempo e contagem da sessão. O cronômetro pausa com o mundo. O teste dirige uma volta completa usando inputs comuns; não teleporta entre checkpoints.

## Câmera

O pivô acompanha a posição do carro e suaviza a direção. Um `SpringArm3D` com forma esférica reduz a distância diante de obstáculos e exclui o colisor do carro. Olhar para trás troca a direção do braço imediatamente, evitando um movimento que atravessaria o carro. Referência: [documentação oficial de SpringArm3D](https://docs.godotengine.org/en/stable/classes/class_springarm3d.html).

## Validação

### Áudio

`WaveSettings` é um autoload pequeno que mantém os buses Master, Motor, Ambiente e Música. O `ConfigFile` em `user://wave-settings.cfg` guarda volumes lineares entre 0 e 1; valores inválidos usam o padrão, e zero ativa mute. Alterações são aplicadas imediatamente e gravadas após 0,5 segundo, ao fechar opções ou ao sair.

Cada `DrivingWorld` cria um `DrivingAudio` depois dos filhos estarem prontos. Ele instancia três players 2D com streams em loop; o motor responde à velocidade e ao pedal, simulando três faixas de marcha. A câmera próxima justifica o motor sem atenuação espacial neste protótipo. Os players continuam processando durante a pausa para suspender/retomar seus streams, e são encerrados ao trocar de mundo. A síntese ocorre offline, sem custo por amostra durante o jogo.

### Gráficos e menu

O menu inicial abre opções de áudio e gráficos antes da direção. O HUD usa o mesmo painel gráfico na pausa e permite voltar ao menu sem deixar física pausada ou áudio do mapa anterior ativo. As preferências gráficas são validadas e persistidas na seção `graphics` do mesmo ConfigFile. `DrivingWorld` aplica as sombras ao entrar e ao alterar a preferência.

Os controles do painel são sincronizados ao abrir ou aplicar o modo econômico. A resolução corresponde ao tamanho da janela; tela cheia usa o monitor. Na Intel HD Graphics 4400, preferências gráficas ausentes usam 854×480 sem sombras. Preferências salvas continuam prevalecendo.

O registrador de desempenho processa apenas durante a condução, guarda intervalos de quadros e amostras de FPS/draw calls e salva ao encerrar, trocar de mapa ou alterar qualidade. Ele recusa o renderer sem interface. Testes de comportamento não usam seus números como FPS gráfico.

### Testes

Os testes usam a cena do jogo e a física da Godot, com inputs de teclado e gamepad simulados. Passam por aceleração, resistência, frenagem/ré, direção, derrapagem e recuperação, colisões, rampa, câmera e pausa. A simulação de eventos de gamepad verifica o mapeamento, mas não substitui um teste com um controle conectado.

No ambiente restrito, os diretórios de usuário da Godot são redirecionados para `/tmp` por variáveis XDG. O editor pode registrar erros de socket de depuração por restrições do ambiente; a execução do jogo e os testes de comportamento não dependem desses sockets. Nesta sessão foi possível acessar a janela com execução autorizada fora do sandbox: menu, geometria e rota foram verificados com renderização real. Timbre, mixagem e sensação de direção continuam precisando de avaliação jogada.
