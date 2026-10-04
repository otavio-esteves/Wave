# Arquitetura do protótipo

## Cenas e responsabilidades

| Arquivo | Responsabilidade |
| --- | --- |
| `scenes/test_track.tscn` | Pista, piso, obstáculos, rampa, barreiras, carro, câmera e HUD |
| `scenes/city/drive_neighborhood.tscn` | Cena inicial: mapa do bairro, ambiente, sol, carro, câmera e HUD |
| `scenes/city/neighborhood_map.tscn` | Geometria e colisões estáticas do bairro |
| `scenes/cars/player_car.tscn` | Colisor e geometria provisória do carro, com pivôs de rodas |
| `scenes/cars/chase_camera.tscn` | Pivô, braço de colisão e câmera, compartilhados entre mapas |
| `scenes/ui/prototype_hud.tscn` | Velocímetro, instruções e menu de pausa |
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
| `scripts/tools/build_audio.py` | Síntese offline dos três WAVs originais |
| `tests/driving_smoke.gd` | Verificação de comportamentos com inputs simulados na cena real |
| `tests/neighborhood_smoke.gd` | Percursos nas ruas, acessos, colisões, reset e troca de mundos |
| `tests/audio_smoke.gd` | Loops, resposta do motor, pausa, opções e persistência após reiniciar |

Os inputs são registrados em `_enter_tree()` do mundo, antes da inicialização dos filhos. O controlador roda em passos de física; a câmera atualiza depois do carro e o braço de colisão depois da câmera. O HUD continua recebendo input durante a pausa, enquanto a física do carro fica parada. A troca de mapas desfaz a pausa antes de substituir a cena.

## Bairro

O gerador define o bairro em coordenadas fixas e combina caixas, prismas, cilindros e esferas de poucos polígonos. Os modelos e materiais são compartilhados; as peças repetidas são agrupadas em `MultiMeshInstance3D`. Colisões simples cobrem o piso, as calçadas, os edifícios e os props que bloqueiam o carro. Os acessos ao posto têm intervalos sem meio-fio.

O comando de geração salva uma `PackedScene`. Cada lote usa `baked_multimesh.gd` para persistir suas transformações em uma propriedade exportada, independentemente do servidor gráfico. Isso permite gerar o arquivo sem interface sem perder a geometria. Durante o carregamento, o recurso restaura as instâncias e calcula seus limites de visibilidade uma vez; não há processamento por frame nesses recursos.

Depois de salvar, o gerador recarrega a cena e valida transformações, limites de visibilidade e correspondência das malhas com as colisões de piso e edifícios. O teste do bairro também verifica um ciclo de gravação e recarregamento para detectar regressões.

O jogo carrega essa cena sem executar o gerador, e o mapa não tem scripts por objeto. A cena principal define céu, ambiente e luz solar. As luminárias emissivas produzem aparência iluminada, mas não iluminam fisicamente a rua.

Os lotes atuais cobrem o bairro inteiro, que é pequeno. Antes de expandir o mundo, dividir esses lotes por setores para melhorar o descarte de geometria fora da visão. Medir o desempenho renderizado antes de introduzir streaming ou LOD.

## Veículo

`CharacterBody3D` mantém uma velocidade longitudinal e preserva parte do movimento lateral ao virar. A aderência reduz esse movimento lateral a cada passo; o freio de mão diminui a aderência. O esterçamento usa uma distância entre eixos e limita o ângulo das rodas em alta velocidade.

Após `move_and_slide()`, o controlador lê a velocidade resultante da colisão. Assim, bater não restaura a velocidade anterior. Ao resetar, ele limpa o movimento e emite `car_reset`, que reposiciona a câmera imediatamente.

O modelo é cinemático: a inclinação visual da carroceria e o movimento das rodas são cosméticos. Ainda não simula suspensão, capotamento, transferência real de peso ou resposta de um veículo rígido. Reavaliar essas limitações conforme o teste jogado, sem tratar o protótipo como um simulador.

## Câmera

O pivô acompanha a posição do carro e suaviza a direção. Um `SpringArm3D` com forma esférica reduz a distância diante de obstáculos e exclui o colisor do carro. Olhar para trás troca a direção do braço imediatamente, evitando um movimento que atravessaria o carro. Referência: [documentação oficial de SpringArm3D](https://docs.godotengine.org/en/stable/classes/class_springarm3d.html).

## Validação

### Áudio

`WaveSettings` é um autoload pequeno que mantém os buses Master, Motor, Ambiente e Música. O `ConfigFile` em `user://wave-settings.cfg` guarda volumes lineares entre 0 e 1; valores inválidos usam o padrão, e zero ativa mute. Alterações são aplicadas imediatamente e gravadas após 0,5 segundo, ao fechar opções ou ao sair.

Cada `DrivingWorld` cria um `DrivingAudio` depois dos filhos estarem prontos. Ele instancia três players 2D com streams em loop; o motor responde à velocidade e ao pedal, simulando três faixas de marcha. A câmera próxima justifica o motor sem atenuação espacial neste protótipo. Os players continuam processando durante a pausa para suspender/retomar seus streams, e são encerrados ao trocar de mundo. A síntese ocorre offline, sem custo por amostra durante o jogo.

### Testes

Os testes usam a cena do jogo e a física da Godot, com inputs de teclado e gamepad simulados. Passam por aceleração, resistência, frenagem/ré, direção, derrapagem e recuperação, colisões, rampa, câmera e pausa. A simulação de eventos de gamepad verifica o mapeamento, mas não substitui um teste com um controle conectado.

No ambiente restrito, os diretórios de usuário da Godot são redirecionados para `/tmp` por variáveis XDG. O editor pode registrar erros de socket de depuração por restrições do ambiente; a execução do jogo e os testes de comportamento não dependem desses sockets. A janela do desktop não está acessível ao agente, portanto a confirmação visual e a medição de FPS são feitas no desktop do usuário.
