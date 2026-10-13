# Correções da auditoria — 2026-10-12

As três correções tratam a perda de otimização ao personalizar o Econômico e duas falsas aprovações possíveis no analisador de benchmark. O traçado, a composição e os assets da cidade permanecem os da revisão visual atual.

## Preferência geométrica independente

`city_lod` controla a simplificação dos prédios distantes e a seleção dos LODs das superfícies. O Econômico a ativa; Equilibrado, Qualidade e Legacy mantêm a geometria autoral. A opção **Simplificar prédios distantes** permite ajustar essa escolha sem acoplar resolução, sombras, MSAA ou materiais. Ela é salva com as demais preferências e é aplicada tanto ao abrir a cidade quanto durante a sessão e ao restaurar o diagnóstico.

Preferências antigas que correspondem ao Econômico são migradas; Legacy mantém seu comportamento anterior. O identificador de preset continua sendo `custom` quando o jogador altera a resolução, mas isso já não remove a otimização geométrica.

O teste usa o código real do mundo com uma cidade pequena: confere prédios próximos/distantes, LOD do chão, mudanças de resolução e outras opções, persistência, restauração do detalhe e todos os presets. A suíte de desempenho verifica a migração; o menu verifica o controle e a persistência entre processos.

## Evidência obrigatória do benchmark

Uma pasta de sessão longa exige `long_session=true` e pelo menos 600 segundos, independentemente do que o arquivo declara. Cada captura precisa de índices inteiros válidos de volta e trecho. O conjunto deve cobrir exatamente todos os resultados da condução, uma vez cada; duplicações não compensam trechos ausentes. Voltas repetidas válidas continuam aceitas.

As regressões incluem sessão longa declarada como curta, flags inválidas, duplicação, índices negativos, fora de faixa, ausentes ou de tipo incorreto, além de um percurso válido com duas voltas. Os demais critérios de GPU, resolução, renderer, foco e frame times continuam obrigatórios.

## Próxima etapa de otimização

As correções tornam a escolha gráfica estável e a medição mais confiável. O ganho de FPS desta revisão ainda não foi medido. O diagnóstico Intel de 2026-10-11 apontou custo de desenho como prioridade; a composição de 2026-10-12 aumentou conteúdo e distância visível, portanto a medição precisa usar essa cidade atual.

1. Medir o mesmo percurso em Intel/Econômico e Radeon/Equilibrado, incluindo noite e sessão longa; preservar frame times, chamadas de desenho e RAM.
2. Localizar o custo por categoria: fachadas, vegetação, chão, materiais, sombras e reflexos. Comparar cada intervenção no mesmo enquadramento e rota.
3. Priorizar LOD/HLOD de casas e árvores, agrupamento espacial e por material, redução de chamadas de desenho e custo dos materiais conforme a evidência. Preservar silhuetas e continuidade dos bairros.
4. Medir separadamente carregamento, atualização dos proxies e ativação de colisões. Investigar residência/streaming se RAM ou carregamento justificarem.
5. Repetir a rota e a sessão longa após as mudanças, além da avaliação visual jogada. Validar 8 GB e Windows nativo para fechar os requisitos de produto.

Não há nova aprovação de desempenho nesta etapa.

## Validação

O projeto passou **939 verificações Godot e 23 testes Python únicos**. O pacote passou **467 verificações**, incluindo sua guarda de recursos, em 17 suítes. Não houve diagnósticos inesperados. Os dois erros de recurso ausente da suíte de streaming são casos negativos deliberados, filtrados pelo runner.

A execução foi dividida: o primeiro runner concluiu até `city_map`; a regeneração completa e a comparação integral passaram antes da interrupção intencional, para separar o custo da geração do limite de 1.200 segundos da suíte de condução. `pilot_city` reutilizou esse artefato completo no mesmo diretório de dados isolado, refez a comparação integral e passou as 43 verificações. O runner retomou em `neighborhood_composition` e concluiu as demais suítes e a montagem offline. Os testes Python foram repetidos na retomada; o total acima conta apenas os 23 testes únicos. O log parcial da regeneração não acrescenta verificações duplicadas ao total.

[Primeira parte](validation/source-before-resume.log) · [regeneração isolada](validation/regeneration.log) · [cidade e comparação completas](validation/source-pilot.log) · [retomada e montagem offline](validation/source-resume.log) · [pacote exportado](validation/exported-access.log).

Linux e Windows foram reexportados com PCKs idênticos. O executável Linux abriu e encerrou o menu em modo headless com saída zero; isso verifica a inicialização release, sem medir FPS. Windows nativo, 8 GB e desempenho sustentado continuam pendentes.

[Exportação](validation/export-builds.log) · [inicialização Linux](validation/native-headless-menu.log) · [contagens, contexto e hashes](validation/record.json).
