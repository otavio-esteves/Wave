# Revisão das mudanças pendentes — 2026-10-06

Validação local antes de registrar o corredor, streaming/HLOD, gráficos e instrumentação em Git. Engine Godot 4.7.2, runner headless; não é benchmark gráfico.

A primeira bateria falhou em cinco verificações de streaming. A reprodução isolada mostrou um pedido ainda `THREAD_LOAD_IN_PROGRESS` após apenas 148 ms reais: os 600 frames de espera haviam avançado dez segundos simulados. `--fixed-fps` não respeita o limite de `Engine.max_fps`; a leitura em worker continua usando tempo real. O mesmo problema atingia a espera pelo descarte de pedidos pendentes.

As fixtures `streaming_smoke.gd` e `hlod_smoke.gd` passam a ceder 4.167 µs por frame em headless, mantendo a física a 60 Hz simulados e dando tempo real aos workers. A lógica de streaming do produto não mudou. O teste isolado corrigido passou 28 verificações, sem falhas; os logs anteriores permanecem como evidência.

A bateria completa corrigida passou, incluindo persistência e regeneração dos três mapas antigos: **319 verificações, zero falhas**. Log integral em `checks-final.log`.
