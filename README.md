# Wave

Protótipo de um jogo de direção livre com atmosfera de fim de tarde. O projeto usa Godot 4.7.2, GDScript e o renderer Compatibility.

## Abrir

Abra `project.godot` no editor Godot, pressione **F5** e selecione **Dirigir** no menu inicial para passear pelo **Bairro do Sol**. Também é possível iniciar pela raiz do projeto:

```sh
godot --path .
```

Se o executável tiver outro nome, substitua `godot` pelo caminho correspondente. Para verificar importação e scripts sem interface:

```sh
godot --headless --path . --editor --quit
```

Neste notebook, o executável está em `~/Downloads/Apps/Godot_v4.7.2-stable_linux.x86_64`. Ele pode permanecer fora do repositório.

## Controles do protótipo

| Ação | Teclado | Gamepad |
| --- | --- | --- |
| Acelerar | W ou ↑ | Gatilho direito |
| Frear / ré | S ou ↓ | Gatilho esquerdo |
| Virar | A/D ou ←/→ | Analógico esquerdo |
| Freio de mão | Espaço | Botão A |
| Olhar para trás | C | Botão Y |
| Reiniciar carro | R | Botão B |
| Pausar | Esc | Start |
| Mostrar / ocultar FPS | F3 | — |
| Iniciar / salvar medição de desempenho | F4 | — |

Segure o freio para parar; mantendo-o pressionado, o carro entra em ré após uma pequena pausa. Os gatilhos controlam a intensidade da aceleração, preservando o limite de velocidade. O freio de mão permite uma derrapagem em curvas. No menu de pausa é possível continuar, reiniciar o carro, trocar de mapa, ajustar áudio/gráficos, voltar ao menu inicial ou sair.

## Protótipo atual

- Carro reutilizável com rodas visíveis, esterçamento suave e ângulo reduzido em alta velocidade.
- Aceleração, resistência ao rolamento, frenagem, ré e aderência lateral com recuperação após derrapagem.
- Câmera com atraso nas curvas, FOV discreto conforme a velocidade, visão traseira e proteção contra paredes.
- Pista em circuito, obstáculos, rampa e barreiras, com velocímetro e indicação de ré.
- Bairro com seis ruas conectadas, cruzamentos, calçadas, casas, comércio, praça, posto e estacionamento diante da oficina.
- Céu de fim de tarde, sol baixo, sombras longas e materiais compartilhados. O cenário é estático, sem trânsito ou pedestres nesta etapa.

O veículo usa física arcade com `CharacterBody3D`. A suspensão física e o modelo vintage definitivo ainda fazem parte das próximas etapas.

## Áudio

O motor acompanha aceleração e velocidade, com três faixas de marcha simuladas. Vento, pássaros e uma música instrumental original acompanham o passeio. Os áudios são provisórios, sintetizados para Wave sem samples externos.

Use **Esc → Áudio** para ajustar volume geral, motor, ambiente e música. Zero silencia a categoria. As preferências são salvas em `user://wave-settings.cfg` e permanecem ao trocar de mapa ou reabrir o jogo. A pausa suspende os sons; retome a direção para ouvir o ajuste. Sliders aceitam mouse e teclas direcionais.

## Gráficos

Use **Gráficos** no menu inicial ou na pausa para alterar tela cheia, resolução da janela, VSync e sombras. As preferências compartilham `user://wave-settings.cfg` com o áudio e permanecem após reiniciar. Em tela cheia, a resolução é a do monitor.

**Aplicar modo econômico** seleciona uma janela de 854×480 sem sombras. Esse perfil também é o padrão inicial da Intel HD Graphics 4400 quando não há preferências gráficas salvas. Outras GPUs começam em 1280×720 com sombras; preferências existentes têm prioridade.

F4 inicia e encerra uma captura de até 180 segundos, salvando CSV e resumo JSON em `user://performance`. O resumo registra GPU, renderer, tamanho real da janela e opções usadas. A pausa suspende a captura; alterar gráficos ou sair do mapa encerra e salva a amostra. Medições gráficas são recusadas no modo sem interface.

## Verificação

Execute todas as verificações com diretórios temporários, preservando suas preferências de jogo:

```sh
GODOT_BIN=~/Downloads/Apps/Godot_v4.7.2-stable_linux.x86_64 bash scripts/tools/check_project.sh
```

O teste abaixo executa 31 verificações com controles simulados na cena real, incluindo acelerador parcial, colisões, rampa, câmera e pausa:

```sh
godot --headless --path . --fixed-fps 60 --script res://tests/driving_smoke.gd
```

O teste do bairro acrescenta 22 verificações de percurso pelas seis ruas, acesso ao estacionamento, colisões, reset, troca de cenas, transformações dos pais e preservação da geometria ao salvar e recarregar o mapa:

```sh
godot --headless --path . --fixed-fps 60 --script res://tests/neighborhood_smoke.gd
```

O áudio acrescenta 18 verificações de reprodução, loops, resposta do motor, pausa, menu e volumes, mais duas em um novo processo para conferir persistência. Use um diretório separado para preservar suas preferências de jogo:

```sh
XDG_DATA_HOME=/tmp/wave-audio-check godot --headless --path . --fixed-fps 60 --script res://tests/audio_smoke.gd
XDG_DATA_HOME=/tmp/wave-audio-check godot --headless --path . --script res://tests/audio_smoke.gd -- --verify-persistence
```

Esses testes verificam dados e comportamento; o timbre e a mixagem precisam de avaliação ouvindo no desktop.

Menu e gráficos acrescentam 19 verificações de navegação, foco, transições, modo econômico, aplicação das sombras e validação de valores, mais uma de persistência em outro processo:

```sh
XDG_DATA_HOME=/tmp/wave-menu-check godot --headless --path . --fixed-fps 60 --script res://tests/menu_smoke.gd
XDG_DATA_HOME=/tmp/wave-menu-check godot --headless --path . --script res://tests/menu_smoke.gd -- --verify-persistence
```

Total: **93 verificações**. Para medir a rota com controles automatizados e janela real, consulte [desempenho](docs/performance.md).

Para o teste jogado, faça duas voltas no circuito, experimente freio e ré na reta, use o freio de mão em uma curva, atravesse a rampa e confira a pausa. O resultado esperado é dirigir sem travamentos, recuperar aderência ao soltar o freio de mão e voltar à pista com R. Esses testes não substituem a avaliação da sensação de direção ou uma medição de FPS com renderização.

No bairro, explore o circuito externo, atravesse a avenida central e entre no posto pelos acessos sem calçada. Use F3 para conferir FPS; a [rota de desempenho](docs/performance.md) permite comparar versões.

## Editar o bairro

A cena principal é `scenes/city/drive_neighborhood.tscn`. Ela combina mapa, iluminação, carro, câmera e HUD. A geometria do mapa é gerada antes da execução e salva como uma cena estática; não há geração por frame durante o jogo.

Edite `scripts/city/neighborhood_builder.gd` e regenere o mapa com:

```sh
godot --headless --path . --script res://scripts/tools/build_neighborhood.gd
```

O comando substitui `scenes/city/neighborhood_map.tscn`, portanto altere a geometria no gerador. Depois de salvar, ele recarrega o arquivo e verifica os dados de renderização e sua correspondência com o piso e os edifícios. Ajustes de iluminação e posição inicial ficam na cena principal.

## Estado

Base versionada e correções do acelerador analógico e da validação das colisões registradas em commits. Menu inicial, opções persistentes de áudio/gráficos e registro de desempenho implementados. Medições com renderização real e rota automatizada registradas em [desempenho](docs/performance.md). Timbre, mixagem, sensação de direção com gamepad físico, carro vintage definitivo e avaliação nativa no Windows continuam pendentes. Consulte o [plano](development-plan.md) e a [arquitetura](docs/architecture.md).

## Builds Linux e Windows

Presets versionados em `export_presets.cfg`. Com templates Godot 4.7.2 instalados no editor, exporte ambos com:

```sh
GODOT_BIN=~/Downloads/Apps/Godot_v4.7.2-stable_linux.x86_64 bash scripts/tools/export_builds.sh
```

O script também aceita os templates locais em `tools/godot/export_templates/4.7.2.stable`, extraídos nesta máquina do pacote oficial. Essa pasta é ignorada pelo Git; em outro checkout, instale os templates pelo editor. Os builds ficam em `builds/linux` e `builds/windows`, também ignorados pelo Git.

Execute `builds/linux/Wave.x86_64` no Linux ou `builds/windows/Wave.exe` no Windows. Distribua a pasta completa de cada plataforma, incluindo `Wave.pck`. A inicialização foi verificada no Linux e pelo Wine; Wine não substitui uma avaliação nativa no Windows.
