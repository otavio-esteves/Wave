# Prova de três células — Avenida do Vale

Inspiron 5547/i7-4510U/R7 M260, 16 GB, Linux/Mesa 25.0.7, Compatibility/Legacy/1280×720, sem VSync/queries de viewport e sem testes ou export concorrentes.

- `amd-r1..r3.*`: três passagens de ida, alvo 120 km/h. Cada nome contém JSON/CSV, `-frames.csv`, log, `-streaming.json` e `-context.json`.
- `amd-three-cycles.*`: seis pernas conduzidas, três idas e voltas, alvo 220 km/h, virada por reset/heading declarada. Registra memória e liberações repetidas.
- `checks-before.log` / `checks-after.log`: 271 → 304 verificações completas, incluindo regeneração equivalente dos mapas antigos.
- `status.json`: distingue aprovação das travessias curtas da integração completa de M1/M3.

Os CSV por quadro não foram filtrados. Contagem/duração/pior intervalo foram auditados contra os JSON. Os hashes de código/cena/recursos/manifesto/texturas são iguais nas quatro medições. `capture_start/end` no log de streaming permite alinhar eventos à série de quadros.

A primeira célula leva cerca de 4,7–5 s para liberar movimento na entrada fria, antes da captura após aquecimento; esse custo permanece nos eventos. RSS cresceu ~6,8 MB nos 84,5 s com captura rodando: não certifica convergência de memória. Não há HLOD, Windows nativo, memória limitada a 8 GB ou sessão jogada longa aprovados.

[Condições, análise e reprodução](../../../performance.md#prova-de-streaming--três-células-da-avenida).
