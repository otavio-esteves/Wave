# Wave

Protótipo de um jogo de direção livre com atmosfera de fim de tarde. O projeto usa Godot 4.7.2, GDScript e o renderer Compatibility.

## Abrir

Abra `project.godot` no editor Godot e pressione **F5** para passear pelo **Bairro do Sol**. Também é possível iniciar pela raiz do projeto:

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

Segure o freio para parar; mantendo-o pressionado, o carro entra em ré após uma pequena pausa. O freio de mão permite uma derrapagem em curvas. No menu de pausa é possível continuar, reiniciar o carro, trocar entre bairro e pista de testes ou sair.

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

## Verificação

O teste abaixo executa 28 verificações com controles simulados na cena real, incluindo colisões, rampa, câmera e pausa:

```sh
godot --headless --path . --fixed-fps 60 --script res://tests/driving_smoke.gd
```

O teste do bairro acrescenta 20 verificações de percurso pelas seis ruas, acesso ao estacionamento, colisões, reset, troca de cenas e preservação da geometria ao salvar e recarregar o mapa:

```sh
godot --headless --path . --fixed-fps 60 --script res://tests/neighborhood_smoke.gd
```

O áudio acrescenta 18 verificações de reprodução, loops, resposta do motor, pausa, menu e volumes, mais duas em um novo processo para conferir persistência. Use um diretório separado para preservar suas preferências de jogo:

```sh
XDG_DATA_HOME=/tmp/wave-audio-check godot --headless --path . --fixed-fps 60 --script res://tests/audio_smoke.gd
XDG_DATA_HOME=/tmp/wave-audio-check godot --headless --path . --script res://tests/audio_smoke.gd -- --verify-persistence
```

Esses testes verificam dados e comportamento; o timbre e a mixagem precisam de avaliação ouvindo no desktop.

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

O usuário testou a direção e confirmou a correção do mapa invisível no desktop. Implementados motor, ambiente, música original e opções persistentes de volume. Esta etapa passou nas **68 verificações** e na execução sem interface na Godot 4.7.2. Timbre e mixagem, medição de FPS, opções gráficas, modelo vintage definitivo e builds exportadas seguem no plano. O primeiro commit depende de acesso de escrita a `.git`. Consulte o [plano](development-plan.md) e a [arquitetura](docs/architecture.md).
