# Avenida do Vale — dados de revisão

600 m, seed 5547, rota `avenue-do-vale-v1`, alvo de 120 km/h. AMD R7 M260, i7-4510U, Inspiron 5547 com 16 GB, Linux/Mesa, Compatibility/Legacy/720p sem VSync.

- `amd-r1..r3.json/csv` e `-frames.csv`: três passagens após trocar placas estáticas por atlas offline. Sem screenshots durante a captura, sem frames filtrados.
- `context-r1..r3.json`: código/cena/hardware/argumentos; `asset-snapshot.json`: texturas, imports, shaders e geradores Python correspondentes.
- `rejected-first-use-signs/`: três séries anteriores completas, com hitch de 283–304 ms na primeira exibição da placa da oficina; código/cena anteriores preservados como `.txt`.
- `previews/`: quatro vistas finais, produzidas separadamente da medição, em resolução nativa de 1280×720. Poses/opções em `context.json`.
- `checks-before.log` / `checks-after.log`: bateria completa antes/depois desta etapa.

[Interpretação e reprodução](../../../performance.md#avenida-do-vale--corredor-visual-de-600-m). `status.json` distingue pacing da rota curta de aprovação completa de M1. A qualidade artística ainda não atingiu a referência; este mapa estático não implementa streaming.
