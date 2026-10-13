# Composição dos bairros — 2026-10-12

A orientação desta etapa é reforçar a identidade brasileira, a aparência e o preenchimento completo dos três bairros existentes. A otimização vem depois da revisão visual, conforme solicitado pelo usuário. O traçado mantém 200 quarteirões, os mesmos controles, a física arcade e os destinos praça/oficina.

[Galeria interativa antes/depois](index.html).

## Composição

As frentes e laterais recebem uma cadência em metros, com recuos menores e proteção dos cruzamentos. As ruas do perímetro também recebem mais moradias. Jardins do Vale combina as nove formas de sobrados com prédios residenciais pontuais; Vila Aurora intercala casas, comércio e apartamentos; Centro Horizonte amplia o conjunto de torres e os térreos comerciais. Os quarteirões estreitos usam torres residenciais mais esbeltas, com 13 a 22 andares; lojas menores completam frentes onde uma torre não cabe. Esses quarteirões aproveitam os parques públicos existentes, sem reservar o mesmo jardim central largo dos bairros residenciais. A conferência da implantação exige pelo menos oito construções em cada quarteirão comum, preservando praça, parques e oficina. As tentativas de implantação continuam rejeitando sobreposição de lotes e proximidade indevida das ruas.

O comércio acrescenta vitrines, toldos listrados e oito letreiros fictícios. Portões deslizantes recolhidos deixam os acessos abertos; fachadas posteriores, muros, caixas-d’água, antenas, varais e vasos sugerem moradias ocupadas. Apartamentos recebem ar-condicionado e plantas nas varandas. Postes de concreto, cruzetas, fios com flecha, placas de rua e pequenos murais reforçam a escala do bairro.

Arborização em intervalos regulares é interrompida pelos acessos. Os espaços residuais dos quarteirões recebem grupos de árvores, arbustos e flores. As copas das seis formas existentes ganham mais conjuntos de folhas; arbustos deixam de usar esferas verdes sólidas. Bancos detalhados também passam a ocupar os jardins internos. As 18 praças recebem quadras e playgrounds em lotes seguros, além dos caminhos, bancos e jardins existentes. A quadra e os balanços são cenário; não acrescentam uma atividade jogável.

## Materiais, iluminação e continuidade

Gramado original com palha e variação de crescimento substitui a superfície excessivamente uniforme. As fachadas de vidro recebem textura original de caixilhos, persianas e ocupação. Ambas são geradas offline em 512², com normal e escala em metros. A luz ambiente diurna passa de 0,42 para 0,49; a intensidade solar máxima passa de 1,12 para 1,05. O alcance de sombra autoral passa de 90 para 120 m. À noite, a luz ambiente e a lua passam de 0,13 para 0,19; os postes usam alcance de 23 m e energia 2,2, antes 17 m e 1,6, conservando o grupo de oito luzes locais.

Casas e fachadas agora permanecem visíveis até 650 m; troncos e folhas, até 850 m. Isso corrige a aparência de campos vazios criada pelo desaparecimento dos volumes a aproximadamente 240 m. Torres conservam o alcance de 1.800 m e o sistema existente do Econômico. A grama próxima mantém seu alcance anterior. O aumento de conteúdo e de visibilidade ainda precisa da próxima etapa de otimização.

## Inventário final

| Elemento | Antes | Depois |
| --- | ---: | ---: |
| Imóveis | 2.377 | 3.319 |
| Arranha-céus | 211 | 449 |
| Árvores volumétricas | 4.105 | 9.942 |
| Tufos de grama | 47.678 | 88.883 |
| Veículos estacionados | 974 | 1.399 |

A revisão contém 730 bancos detalhados, 1.163 frentes comerciais, 1.891 árvores de rua, 136 postes de infraestrutura, 18 quadras e 18 playgrounds. Os 3.728 grupos de plantio residual integram o total de árvores. Os imóveis internos se distribuem em 893 nos Jardins, 1.515 na Vila e 575 no Centro; as moradias do perímetro completam o total.

## Evidência

Os pares usam vistas fixas nas ruas dos três bairros, na encosta, no perímetro, na praça e sobre um quarteirão. Incluem a câmera jogável, meio-dia e noite. As capturas usam Radeon R7 M260, Compatibility, Equilibrado, 1280 × 720. A revisão anterior é carregada de sua geração preservada e usa os valores anteriores de iluminação e sombra. O relógio e as nuvens ficam congelados; os carros não aparecem nos enquadramentos de arquitetura. A captura inicial usa o carro e a câmera reais do jogo.

[Contexto anterior](before/context.json) e [contexto atual](after/context.json) registram GPU, preset, tamanho, posições, alvos, horários e inventário. Estas imagens não aprovam sensação humana ou desempenho. Não foi executado benchmark nesta etapa.

## Validação

O projeto passou **926 verificações Godot**, cobrindo 40 suítes, persistência e montagem offline, além dos **19 testes Python**. A primeira sequência concluiu até `city_map`; a regeneração de `pilot_city` foi interrompida intencionalmente para corrigir os quarteirões estreitos. A retomada começou em `pilot_city`, usando uma regeneração completa independente. A comparação conferiu integralmente terreno, ruas, UVs, instâncias, LODs e colisões. Os logs preservam as duas partes; não representam uma sequência única ininterrupta. Os dois diagnósticos de recurso ausente da suíte de streaming são casos negativos deliberados, filtrados pelo runner.

O teste específico da composição passou nove verificações, incluindo mínimo de oito construções em cada quarteirão comum, 18 quadras/playgrounds, preservação das folhas texturizadas, fios, vidro, gramado e janelas ocupadas. O teste de física contabilizou **34.170 sólidos residentes**, com ativação por proximidade. O orçamento anterior de 30 mil formas deixou de ser um critério de aprovação desta etapa de arte, conforme a prioridade solicitada: o teste correspondente verifica a cobertura integral dos sólidos pelo sistema de proximidade e imprime o custo como diagnóstico. Conectividade, sobreposição, apoio, ruas, calçadas, praça/oficina, controles e persistência continuam verificados.

Os executáveis Linux/Windows foram reexportados com a distribuição final. O pacote passou 17 suítes com **458 verificações**, mais 17 do menu/carregamento/acessos e uma guarda que confirma o uso exclusivo dos recursos exportados: **476 verificações ao todo, sem diagnósticos inesperados**. Os PCKs são idênticos, com 210.435.576 bytes e SHA-256 `9f05b3ee89d584900b7fb928daf51196f2fe758bceb087d5a45558b608c0bcbd`.

A [captura da câmera jogável usando exclusivamente o PCK](validation/exported-preview/driving.png) também foi gerada em Equilibrado na Radeon. O harness da engine do editor verifica os recursos exportados; não é uma medição do executável release. O executável Linux abriu o menu em Compatibility na Radeon e fechou normalmente por `WM_DELETE_WINDOW`, com saída zero e sem erros. A primeira tentativa de encerramento automático atingiu seu limite de tempo; a repetição registrou a abertura e o fechamento normais. Windows foi exportado, mas não foi executado nativamente.

[Registro completo e hashes](validation/record.json) · [primeira parte do runner](validation/source-before-centre-fix.log) · [retomada e resultado final](validation/source.log) · [verificações exportadas](validation/exported-access.log) · [menu exportado](validation/exported-menu.log) · [abertura/fechamento Linux](validation/native-menu.log).

## Reproduzir

```sh
godot --headless --path . --script res://scripts/tools/build_neighborhood_materials.gd -- --only=turf
godot --headless --path . --script res://scripts/tools/build_neighborhood_materials.gd -- --only=curtain_wall
godot --headless --path . --script res://scripts/tools/build_pilot_city.gd
godot --path . --script res://scripts/tools/build_composition_previews.gd -- --output=/tmp/wave-composition
GODOT_BIN=/caminho/para/godot bash scripts/tools/check_project.sh
GODOT_BIN=/caminho/para/godot bash scripts/tools/export_builds.sh
GODOT_BIN=/caminho/para/godot bash scripts/tools/check_exported_access.sh
```

O runner também aceita `WAVE_REGENERATED_PILOT=/caminho/para/copia-independente.scn`, quando a regeneração isolada já estiver concluída; a comparação de toda a geometria continua obrigatória. As vistas anteriores vêm da geração preservada `1791745458-651417125`, com `--city=res://scenes/city/pilot/pilot_city_generations/1791745458-651417125/city.scn --baseline-grade`. O enquadramento noturno atualizado tem seu [contexto próprio](validation/night-before-context.json), mantendo câmera e horário iguais no par.
