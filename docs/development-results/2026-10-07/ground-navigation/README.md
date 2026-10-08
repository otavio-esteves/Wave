# Passagem por calçadas e subidas — 2026-10-07

Correção do esbarrão relatado ao dirigir sobre calçadas e mudanças de inclinação. A guia da Avenida do Vale tem 28 cm, acima dos 26 cm aceitos pelo controlador. Além disso, a assistência de subida ignorava colisões com faces transitáveis: o canto dianteiro da caixa podia prender numa mudança de inclinação, mesmo com apoio nas rodas.

O limite de degrau passou para 35 cm. Uma colisão com face inclinada agora também pode usar a passagem assistida, desde que haja espaço acima, caminho livre na altura elevada e uma superfície transitável para apoiar o carro dentro do limite. A assistência continua usando varreduras físicas; fachadas, muros e barreiras permanecem obstáculos. Vale para os dois perfis de direção já existentes.

## Evidência

| Verificação | Resultado |
| --- | --- |
| Controlador anterior, 27 checks comuns | 8 falhas |
| Primeira correção, mesmos 27 checks | 0 falhas |
| Fixture final: casos anteriores + guias a 64,8 km/h | 33 checks, 0 falhas |
| Avenida real, entrada/saída nas calçadas dos dois lados | 8 checks, 0 falhas |
| Pacote exportado, navegação no chão | 33 checks, 0 falhas |
| Pacote exportado, calçadas da avenida | 8 checks, 0 falhas |
| Runner completo | 445 checks de comportamento + 10 testes Python, 0 falhas |

A fixture reproduz calçadas adjacentes de 12/20/28/30 cm, passagem a 4,32 km/h, frente/ré/diagonal, perfil de simulação e uma subida/descida contínua de 18 m com malha em segmentos de 4 m. Antes, as guias de 28/30 cm prendiam o carro; depois, todos os percursos chegaram ao fim. Na subida, os ticks abaixo de 0,2 m/s caíram de 35 para 4. Nos dois cruzamentos de guia a 64,8 km/h, as velocidades horizontais mínimas foram 17,73 e 17,83 m/s: não houve parada nem lançamento do corpo.

O teste da avenida dirige com inputs reais, sem abrir acessos ou modificar o mapa. Os endpoints respeitam o espaço entre a guia e as fachadas; o teste não tenta atravessar prédios. Confere contato com o chão, alinhamento e ausência de bloqueios do streaming. As suítes foram adicionadas ao runner normal. A regressão completa também passou direção, inclinação transversal, frenagem em rampas, barreira alta, colisões em alta velocidade, circuito/rally, áudio/menu, streaming, viagem/mirante e regeneração dos mapas. Os erros de recurso ausente no log de streaming são falhas injetadas pelo teste, com recuperação conferida.

Logs e identidades nesta pasta. Builds Linux/Windows reexportados. A verificação dos recursos empacotados usa engine Linux, scripts externos, `project.binary` presente e `project.godot` ausente; execução nativa no Windows e avaliação humana da sensação de direção continuam pendentes. Estes ensaios são funcionais headless, sem amostragem de FPS ou conclusão de desempenho da máquina.

## Reproduzir

```sh
godot --headless --path . --fixed-fps 60 --script res://tests/ground_navigation_smoke.gd
godot --headless --path . --fixed-fps 60 --script res://tests/curb_access_smoke.gd
GODOT_BIN=godot bash scripts/tools/check_project.sh
```

Para conferir o controlador anterior, copie `before-car.gd.txt` para um arquivo `.gd` fora do projeto e passe `-- --car-script=/caminho/before-car.gd`. O snapshot não declara a classe global para evitar duplicação. O log anterior corresponde aos 27 checks comuns; a fixture atual inclui também os dois casos rápidos.
