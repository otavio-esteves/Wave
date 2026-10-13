# Registro histórico da pausa e retomada

Continuação: [relatório de 2026-10-11](../../../performance-results/2026-10-11/pilot-intel-profile/README.md), com LOD dos prédios distantes, correção dos avisos de textura, builds atualizados e testes nativos. Os registros abaixo preservam o estado anterior.

Atualização em 11 de outubro: correções funcionais, builds e diagnóstico gráfico concluídos. Estado atual, métricas, galeria e pendências no [relatório final](README.md). As instruções abaixo descrevem a pausa anterior e não são tarefas ainda em execução.

Este documento preserva o estado da pausa. A divergência geométrica e os avisos de vazamento de objetos abaixo foram resolvidos na retomada; a ativação de células em background também passou a aguardar um frame. Consulte o [relatório atualizado](README.md) e os logs de validação para o estado atual.

O usuário pediu um encerramento provisório para preservar tokens. As alterações estão no workspace, sem commit. Depois solicitou um build para teste: **Linux e Windows foram exportados**, com a cidade publicada atual, sem encerrar a pendência da regeneração. Nenhum teste, exportação ou diagnóstico ficou em execução.

Validação do build provisório: executável Linux abriu/encerrou com sucesso; pacote Linux passou 8 verificações de física, 5 de carregamento e 17 de menu/acessos/condução. Ambos os pacotes incluem somente a geração publicada e excluem geometria/setores legados. Os PCKs têm SHA-256 idêntico `eac036a5e09f52f8f8d5a4886e81297ecfa50a60b4930756868d16166402d183`. O teste exportado de menu registrou aviso de 7 instâncias ObjectDB vazadas no encerramento: investigar na continuação. Windows nativo não foi executado. Logs em `build-test/` nesta revisão; log completo da exportação em `/tmp/wave-user-test-export.log`.

## Escopo e autorização

Resolver os seis pontos da análise, sem ampliar a cidade: desempenho, residência, telemetria, carregamento, gerador/publicação e acabamento/atividade. O usuário continuará usando a máquina: medições gráficas são **somente diagnóstico**, sem certificar uso exclusivo, 30 FPS, 8 GB ou Windows nativo. Não pedir novamente reserva da máquina. Não usar subagentes sem solicitação explícita.

## Implementado

- Leitor de sensores em subprocesso, orçamento/timeout e encerramento independente do driver. Teste com FIFO bloqueado passou. Três suites Python: 15 testes passaram.
- Menu com carregamento em background, progresso, erros recuperáveis e bloqueio de cliques duplicados. Áudio compartilhado pré-carregado na thread principal elimina referências vazadas observadas no ensaio.
- Gerador dividido em superfícies, cenário e arquitetura. Publicação usa dependências em diretório imutável, verifica completude e troca atomicamente a entrada. Teste de publicação: 7 verificações passaram.
- Física dos sólidos por proximidade (320 m entrada, 448 m retenção), reset imediato e piso permanente. Teste final isolado: 8 verificações passaram. Geometria continua residente em RAM.
- Cache de luzes/materiais/superfícies, HUD a 100 ms, LOD de folhagem por preset e comprimentos acumulados da atividade.
- Cores por instância, identificação da praça/oficina, vagas e instruções de curva. Última alteração ajustou a distância da curva a partir da posição do carro; teste sintético agora exige direita em 10 m.
- Plugin `addons/city_generation_export` exclui gerações arquivadas da exportação. Ambos os pacotes foram verificados: incluem somente a geração publicada e não incluem diretórios legados. O ensaio com uma geração fictícia adicional ainda não executou.
- Runner exportado passou a incluir `city_loading` e `city_physics`, com timeout por suite.

## Bloqueio encontrado na pausa — resolvido

O runner completo `/tmp/wave-points-full-check.log` falhou em `pilot_city_smoke` após regenerar a cidade. A verificação `_geometry(original) == _geometry(rebuilt)` não passou. Todos os testes anteriores passaram; os posteriores não executaram. Não ignorar essa falha.

Artefato regenerado preservado:

`/tmp/wave-check.BigvMu/pilot_city/godot/app_userdata/Wave/pilot-city-regenerated.scn`

Para carregar suas dependências `user://`, usar `XDG_DATA_HOME=/tmp/wave-check.BigvMu/pilot_city`. A primeira investigação `/tmp/wave-city-difference.gd` comparou apenas cores por instância e contagens de filhos: **zero diferenças nesses campos**, conforme `/tmp/wave-city-difference.log`. Ainda é necessário localizar o primeiro campo divergente na assinatura completa `_geometry` (transformações, malhas, UVs, LODs, colisões etc.). Não assumir que basta regenerar a produção.

Usar o artefato preservado evita repetir aproximadamente oito minutos de geração:

```bash
XDG_DATA_HOME=/tmp/wave-check.BigvMu/pilot_city \
  /home/otavio/Downloads/Apps/Godot_v4.7.2-stable_linux.x86_64 \
  --headless --path /home/otavio/Projects/Wave --fixed-fps 60 \
  --script res://tests/pilot_city_smoke.gd \
  -- --regenerated-scene=user://pilot-city-regenerated.scn
```

Após resolver e aprovar essa suite, continuar o runner a partir de `--from=pilot_optimization`. Verificar o teste atualizado de curva em `pilot_trip`. Os logs anteriores comprovam controles, terreno, acessos, menu, áudio e mapa sem falhas.

## Próximas etapas

1. Resolver a divergência geométrica e concluir as suites restantes, incluindo assembly offline. Resumir resultados e inspecionar erros/vazamentos.
2. Após a correção, atualizar os builds se necessário e concluir a suite ampla de acessos exportados. O build provisório já passou nas verificações descritas acima. Script preparado `/tmp/wave-point-export-and-check.sh` terminou sem exportar porque os testes completos falharam; a exportação posterior foi feita separadamente a pedido do usuário. Para reutilizá-lo, ajustar a condição inicial para os logs finais aprovados. Ele cria uma geração fictícia temporária para testar exclusão, remove-a por trap e executa os checks dos pacotes. Guard em `/tmp/wave-point-package-guard.gd`.
3. Executar diagnóstico sequencial, sem exportações ou suites concorrentes. A baseline Intel já terminou; faltam candidato Intel, baseline Radeon e candidato Radeon. Usar `scripts/tools/hardware_monitor.py`, `tests/pilot_benchmark.gd` e o esquema de `scripts/tools/benchmark_pilot_city.sh --diagnostic`. Preservar contexto/hashes, telemetria e CSVs; gerar `summary.json` com `analyze_pilot_benchmark.py`.
4. Executar `tests/pilot_review.gd` com janela real e inspecionar imagens. A fixture nova ainda não executou. Ela produz spawn, praça, oficina, noite e mapa com câmera real, sem alterar fog/visibilidade. Copiar também `fixture_input.gd` se usar harness externo.
5. Finalizar `README.md` desta revisão com evidência, resultados e limites. Conferir `git diff --check`, arquivos novos e artefatos. Não afirmar certificação nem streaming de RAM. Entregar resumo em português com link para a revisão.

## Artefatos e ferramentas

- Engine: `/home/otavio/Downloads/Apps/Godot_v4.7.2-stable_linux.x86_64`.
- Baseline PCK preservada: `/tmp/wave-before-point-by-point.pck`.
- Diagnóstico: `/tmp/wave-points-diagnostic.IQKr0u/before-intel-1/` (arquivo de localização `/tmp/wave-points-diagnostic-path`). Intel baseline: 14/14 trechos, apoio integral, entrada 31.174 ms, média agregada 18,48 FPS, pior P99 116,635 ms e menor 1% low 5,27 FPS. Máquina compartilhada, sem atribuição causal. Duas mensagens de textura GL no encerramento estavam na baseline.
- Geração publicada: `scenes/city/pilot/pilot_city_generations/1791671200-556800552/`, aproximadamente 115 MB / 4.709 arquivos. Entrada canônica `scenes/city/pilot/pilot_city.scn`, versão 11. Recursos legados permanecem para recuperação e estão excluídos dos presets de exportação.
- Log de geração de produção: `/tmp/wave-point-generation.log`.
- Teste final de física: `/tmp/wave-points-physics-final.log`.
- Log do pipeline interrompido: `/tmp/wave-point-export-check-pipeline.log`.
- Documentação principal e plano já apontam para esta revisão, com ressalva de diagnóstico.

Não há necessidade de reiniciar a análise ou repetir suites já aprovadas, exceto quando uma correção exigir nova verificação.
