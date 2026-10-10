# Diagnóstico renderizado da consolidação

Quatro passagens completas da fixture v3, com 14 trechos cada. Os arquivos de percurso e performance mantêm a estrutura `data/godot/app_userdata/Wave`; logs, exit code e telemetria ficam na raiz de cada passagem. Os snapshots de scripts usam a extensão `.gd.txt`; seus hashes correspondem aos arquivos usados no ensaio.

Recalcular o resumo a partir dos dados arquivados, na raiz do projeto:

```bash
python3 scripts/tools/analyze_pilot_benchmark.py docs/development-results/2026-10-10/pilot-consolidation/benchmark
```

`context.json` registra os hashes dos PCKs e das fixtures, commits e escopo de diagnóstico. `source.patch.gz` preserva o diff completo de fontes rastreadas antes do commit de consolidação. As tentativas com a fixture v2 e a sessão extra interrompida ficam em subdiretórios separados e não entram no resumo final.

A máquina era compartilhada; a passagem Intel anterior mudou de bateria para tomada. O critério controlado continua pendente e os critérios numéricos de pacing não passaram em todos os trechos. Consulte o relatório principal para as tabelas e os limites.
