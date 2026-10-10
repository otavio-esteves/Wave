# Câmera manual e DualShock 4 — 9 de outubro de 2026

Mouse e analógico direito controlam o ângulo da câmera externa ou do capô. Após 1,2 s sem movimento, o ângulo retorna ao acompanhamento automático por interpolação exponencial, independente da taxa de quadros. R3 inicia esse retorno imediatamente. Reset e troca de câmera centralizam o enquadramento. Olhar atrás mantém a troca direta, e o SpringArm continua evitando paredes e excluindo o próprio carro.

O mouse usa `screen_relative` com sensibilidade de 0,003 rad por pixel físico, conforme a [documentação de InputEventMouseMotion](https://docs.godotengine.org/en/stable/classes/class_inputeventmousemotion.html). O cursor é capturado ao dirigir e liberado na pausa, no menu e quando a janela perde o foco. Ao retomar ou recuperar o foco, volta a ser capturado. A inclinação manual é limitada a −0,55…0,24 rad em relação ao ângulo normal do braço.

O sistema identificou um controle Sony USB `054c:09cc`, e o Godot reconheceu **PS4 Controller** com `known: true`. A mesma detecção ocorreu no pacote final: [controller-detection.json](controller-detection.json). O mapeamento existente do motor foi suficiente, sem instalar drivers ou adicionar uma tabela personalizada. A [documentação de controles do Godot](https://docs.godotengine.org/en/stable/tutorials/inputs/controllers_gamepads_joysticks.html) descreve o suporte do backend e o tratamento de zonas mortas.

| Ação | DualShock 4 |
| --- | --- |
| Direção | Analógico esquerdo |
| Acelerar / frear e ré | R2 / L2 |
| Câmera / retorno imediato | Analógico direito / R3 |
| Freio de mão | X |
| Externa / capô | Quadrado |
| Olhar atrás | Triângulo |
| Reset | Círculo |
| Pausa | Options |
| Menus | Direcional ou analógico esquerdo, X para confirmar, Círculo para voltar |

Zonas mortas: 3% para pedais, 12% para direção e 18% para câmera. As ações aceitam qualquer índice de controle. O HUD atualiza as instruções ao conectar ou desconectar o gamepad. Círculo na pausa é consumido até ser solto, evitando que o comando de voltar também reinicie o carro; uma nova pressão ao dirigir volta a funcionar como reset. A aceleração e a aderência da revisão anterior foram preservadas.

| Teste | Verificações aprovadas |
| --- | --- |
| Câmera em headless: matemática e eventos de gamepad | 20 |
| Câmera renderizada: eventos reais do mouse, captura/liberação e gamepad | 24 |
| Condução e colisão da câmera | 33 |
| Menu e gráficos | 29 |
| Persistência após reiniciar | 1 |
| Câmera no pacote renderizado, com guarda de `project.binary` | 25 |
| Menu e passeio no pacote renderizado | 17 |

**149 verificações, zero falhas**, com código de saída 0. O display headless não captura um cursor: nessa modalidade a fixture injeta o deslocamento na matemática do orbit; os testes renderizados passam `InputEventMouseMotion` pelo viewport e verificam o modo real do cursor. Os testes de controle usam eventos sintéticos de um segundo dispositivo. A detecção do DualShock conectado foi real; não foi feita uma sessão manual apertando seus botões. Não houve benchmark de FPS.

A primeira tentativa em headless está arquivada em `first-headless-attempt.log` e expõe essa limitação do display fictício. Os logs `circle-resume-regression-*` registram o conflito de reset na pausa antes da correção; os logs finais `camera_input-headless.log`, `camera-input-rendered.log` e `exported-camera.log` verificam sua resolução. `camera-input-headless.log` registra uma execução anterior da matemática. As fixtures externas de export/captura estão preservadas nesta pasta.

Linux e Windows foram exportados (`export.log`). Os pacotes PCK são idênticos; hashes e tamanhos estão em [artifact-hashes.json](artifact-hashes.json). O executável Linux iniciou sem erro (`native-linux.log`). O executável Windows não foi executado nesta máquina. Os testes externos usam o motor completo com `--main-pack` e fixtures em `/tmp`, carregando os recursos exclusivamente do PCK final.

[Ângulo manual](camera-orbit.png) · [Retorno automático](camera-return.png) · [Menu de pausa](pause.png) · [Passeio no build](pilot-drive.png)
