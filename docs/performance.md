# Desempenho

## Referência

- Godot 4.7.2, renderer Compatibility; 1280 × 720 como referência visual e modo econômico para GPU integrada.
- GPU de referência: Intel Haswell integrada detectada no notebook.
- Meta: manter pelo menos 30 FPS durante a condução, buscando 45–60 FPS quando possível.

## Estado de 2026-10-04

| Dado do Bairro do Sol | Valor |
| --- | --- |
| Lotes MultiMesh | 24 |
| Instâncias de primitivas no mapa | 1.256 |
| Triângulos das primitivas | 21.096 |
| Formas de colisão estáticas | 168 |
| Luzes dinâmicas | 1 direcional |
| FPS com renderização | Medido na AMD R7 M260 e Intel HD Graphics 4400; veja abaixo |

Esses números foram extraídos da cena pela Godot. A contagem de triângulos exclui texto, carro e passes de sombras. A quantidade de lotes não é uma medição de draw calls: fontes, carro e sombras acrescentam trabalho. Os testes sem interface validam comportamento e carregamento; os FPS desse modo não representam o desempenho gráfico.

## Rota para comparar versões

1. Execute o projeto com F5 em 1280 × 720 e aguarde dez segundos.
2. Aperte F3 para mostrar FPS, tempo médio por quadro derivado dos FPS e draw calls.
3. Siga pela via central até o cruzamento diante das casas ao norte.
4. Vire à direita e complete uma volta no circuito externo.
5. Volte à via central e entre no estacionamento do posto.
6. Registre o menor FPS observado, FPS típico, draw calls, renderer, GPU em uso e alterações de qualidade. Faça a mesma rota após mudanças relevantes.

Ao observar quedas, use o profiler da Godot para distinguir custo de renderização e física. O teste deve ser feito sem pausa e com a janela do jogo visível.

## Captura por F4

Após dez segundos de aquecimento, pressione F4, percorra a rota e pressione F4 novamente. O jogo salva um CSV de FPS/draw calls a cada meio segundo e um resumo JSON em `user://performance`. O resumo inclui média de FPS, mediana e percentil 95 dos intervalos de quadros, maior intervalo, GPU, renderer, tamanho real da janela e preferências gráficas. Os intervalos usam o delta da engine, que pode ser suavizado; não são tempos exclusivos da GPU. O percentil 95 descreve os quadros mais lentos da amostra.

A pausa suspende a coleta; mudar gráficos ou trocar de mapa encerra e salva a captura, preservando a configuração registrada. O limite por captura é 180 segundos. O modo sem interface recusa a coleta gráfica.

## Rota automatizada

`tests/rendered_route.gd` abre o menu, inicia o bairro, aguarda dez segundos e dirige pela via central, pelo circuito externo e até o estacionamento do posto. O alvo é 12 m/s nas retas e 6 m/s nas curvas. Salva a captura e screenshots no diretório de usuário e encerra. Todos os cinco pontos devem ser alcançados; o limite de percurso é 90 segundos. É uma medição repetível com controles automatizados, sem avaliação da sensação de dirigir.

```sh
# GPU escolhida normalmente pela Godot (AMD dedicada neste notebook)
XDG_DATA_HOME=/tmp/wave-reference godot --path . --script res://tests/rendered_route.gd

# Intel integrada, perfil econômico
DRI_PRIME=0 XDG_DATA_HOME=/tmp/wave-reference-intel godot --path . --script res://tests/rendered_route.gd -- --economy
```

Argumentos opcionais: `--no-shadows`, `--low-resolution` (960×540), `--economy` (854×480 sem sombras) e `--check-display` (exercita tela cheia e verifica a restauração da resolução antes de medir). Não use `--headless` nem `--fixed-fps` nesta rota. Use pastas distintas para separar os resultados.

## Medições com janela em 2026-10-04

Linux, Mesa 25.0.7, Compatibility e VSync ativado. Cada perfil realizou uma passagem completa pelos cinco pontos, após aquecimento. Dados brutos em [performance-results/2026-10-04](performance-results/2026-10-04). O menor FPS é o menor valor amostrado a cada meio segundo; picos de um único quadro são apresentados separadamente no JSON.

| GPU | Janela real | Sombras | FPS médio | Menor FPS amostrado | P95 de quadro |
| --- | --- | --- | --- | --- | --- |
| AMD R7 M260 | 1280×720 | Sim | 52,0 | 45 | 27,7 ms |
| Intel HD 4400 | 1280×720 | Sim | 12,9 | 11 | 131,9 ms |
| Intel HD 4400 | 1280×683 | Não | 22,0 | 1 | 71,6 ms |
| Intel HD 4400 | 960×540 | Não | 31,8 | 27 | 40,6 ms |
| Intel HD 4400 — econômico | 854×480 | Não | 35,5 | 32 | 36,3 ms |
| Intel HD 4400 — Maré 68, econômico | 854×480 | Não | 34,1 | 30 | 38,5 ms |

A execução de 1280×683 foi solicitada como 1280×720, mas a restauração da janela após tela cheia reduziu sua altura; o valor real está no resumo. Foi acrescentada uma reaplicação da resolução após a restauração assíncrona pelo gerenciador de janelas. Essa amostra também contém um mínimo de 1 FPS, preservado no CSV; não deve ser tratado como comportamento típico.

Sombras e resolução têm impacto concreto na Intel. A configuração com sombras em 720p não atende à meta; 960×540 sem sombras ainda apresenta quedas abaixo de 30 FPS. O modo econômico manteve as amostras de FPS entre 32 e 39 na passagem final, com média de 35,5 FPS, janela confirmada em 854×480 e restauração após tela cheia verificada. Houve quadros isolados mais lentos (máximo de 90,9 ms); a meta não implica ausência de qualquer oscilação. Esse perfil oferece um compromisso mais leve, sem alterar as preferências já salvas. Essas passagens curtas não substituem uma sessão jogada de dez minutos ou garantem FPS em outras máquinas.

As cinco primeiras linhas usam o carro provisório. Com o novo Maré 68 (5.348 triângulos), a passagem completa repetida sem exportações simultâneas registrou 34,1 FPS médios, mínimo amostrado de 30 e máximo de 87,9 ms em um quadro. Dados em `intel-mare68-economy.csv/json`. Uma tentativa anterior durante a etapa de exportação não completou a rota automatizada e não foi usada como referência do percurso completo. O novo carro permanece dentro da meta amostrada nesta execução, com pouca margem na Intel; novas etapas de física e mapa precisam repetir a medição.
