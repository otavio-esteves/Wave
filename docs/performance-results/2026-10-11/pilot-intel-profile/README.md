# Diagnóstico Intel e detalhe dos prédios distantes — 2026-10-11

O perfil Econômico agora conserva o volume, os recuos, as coberturas, antenas, cores e janelas iluminadas dos prédios distantes em lotes simplificados. A fachada completa volta perto do carro. A comparação nativa repetida mediu cerca de 21 FPS contra 13 FPS na vista 113, e 25–26 contra 22 FPS na vista 119. A meta de 30 FPS continua pendente.

## Condições e evidência

Intel HD Graphics 4400, Mesa 25.0.7, Linux, 16 GB instalados, Compatibility, 854 × 480, preset Econômico, sem VSync ou limite de FPS. O executável do diagnóstico veio do template de exportação release (`debug_build=false`). A seleção foi explícita: `DRI_PRIME=pci-0000_00_02_0`, e o adaptador registrado confirmou Intel. A tentativa anterior sem seletor iniciou na Radeon e foi interrompida; não integra estes números.

A máquina continuou disponível para o usuário. As capturas estáticas ficaram sem foco, e todos os quadros foram mantidos. Os ensaios não certificam uso exclusivo, pacing durante condução, 8 GB ou Windows nativo. Não foram habilitadas consultas de timestamp da GPU. O monitor de processo não equivale a tempo puro de CPU: pode incluir esperas de renderização.

O primeiro ensaio alternou oito ablações com controles completos. Desabilitar o 3D passou de aproximadamente 12 para 113 FPS; reduzir a distância das geometrias passou de 12 para 23 FPS. Desligar scripts/física não apresentou ganho consistente. As demais ablações tiveram ganhos pequenos ou resultados piores, com deriva dos controles de até 37%; servem para localizar o trabalho de desenho como prioridade, não para atribuir seu custo exclusivamente à GPU. [Análise e contexto](ablation/analysis.json), [quadros, amostras e imagens brutas](ablation/raw-evidence.tar.gz).

O segundo ensaio fez três comparações de oito segundos por vista, com dois segundos de aquecimento e controles antes/depois. O controle usa a representação simplificada; `authored-detail` reativa todas as fachadas originais. A deriva entre controles ficou entre 0,1% e 1,8%.

| Vista | Fachada completa | Representação distante | Chamadas de desenho, completas → simplificadas |
| --- | --- | --- | --- |
| 113 — bairro olhando para o centro | 13,2–13,3 FPS | 20,8–20,9 FPS | aproximadamente 930 → 340 |
| 119 — centro | 21,6–22,4 FPS | 25,4–26,0 FPS | aproximadamente 364 → 255 |

[Análise das seis comparações](tower-lod/analysis.json), [contexto e hashes dos artefatos experimentais](tower-lod/context.json), [evidência bruta](tower-lod/raw-evidence.tar.gz). Esses pacotes experimentais antecedem a correção de encerramento do céu; os hashes dos builds finais ficam em [validation/manifest.json](validation/manifest.json).

[Vista com representação distante](01-view113-baseline.png) · [mesma vista com fachada completa](02-view113-authored-detail.png).

## Implementação

`pilot_city_visual_lod.gd` agrupa as partes estruturais por material equivalente e setor de 512 m. Os detalhes entram a 340 m e permanecem até 420 m. A seleção roda a cada 250 ms, após deslocamento mínimo de 16 m; reset e troca de preset atualizam imediatamente. Somente os setores com mudança de composição reenviam seus buffers. Médio/Alto restauram a fachada original. Malhas e colisões permanecem residentes e a física não usa esses proxies.

As verificações novas cobrem posição, cores, cobertura, antenas, luzes, histerese, reset, retorno de preset e compartilhamento de materiais equivalentes. O teste isolado passou 12 verificações; o teste da cidade completa passou 21, incluindo dois critérios novos sobre a redução de instâncias e a restauração do detalhe. Os quatro testes Python da análise verificam ponderação dos controles, deriva, preservação de quadros sem foco e rejeição de GPU/debug/contexto inválidos.

## Encerramento do céu

O ensaio mínimo original com um céu não reproduzia os avisos. Ao manter um céu original e criar uma cópia, reapareceram exatamente dois avisos de 21.844 bytes. A cópia superficial apenas do ambiente foi limpa; copiar/criar um segundo céu reproduziu os avisos mesmo compartilhando a textura importada. A sonda com céu original de 128 pixels e céu ativo de 64 mudou os avisos para 87.380 bytes: os buffers remanescentes correspondiam ao céu original. Liberá-lo explicitamente na sonda eliminou os avisos. [Fixtures e logs](validation/sky-probes/).

A cena da cidade agora guarda o material autoral, e o ciclo cria seu único céu em runtime, mantendo tamanho de radiância e modo de processamento. O ambiente e os uniforms pertencem à instância; shader e textura de nuvens são compartilhados. O teste funcional passou 57 verificações, incluindo isolamento dos uniforms e preservação dos parâmetros autorais. A execução renderizada desse teste também passou 57 e encerrou limpa. O build release de diagnóstico com o código final da cidade encerrou após 180 frames na Intel e na Radeon, sem avisos de textura. [Intel](validation/sky-exit-intel.log), [Radeon](validation/sky-exit-radeon.log).

A fixture de condução foi adaptada de `SceneTree` para um `Node` incluído em um projeto de diagnóstico separado, pois o template release desabilita overrides externos de caminho/script. Sua validação nativa headless, com passo fixo de 60 Hz, completou as 14 pernas com apoio no chão em todas as amostras: [resultados](validation/native-headless-routes.json), [fixture e configuração](validation/native-fixture/). Isso valida condução e transições de proximidade, sem medir FPS.

O pacote final passou as 15 suites exportadas, com 435 verificações, mais 17 de menu/acessos: **452 verificações, sem diagnósticos inesperados**. Os 19 testes Python passaram. O executável normal Linux abriu e encerrou pelo menu sem erros; Windows foi exportado e recebeu o mesmo PCK, mas não foi executado nativamente. [Manifesto](validation/manifest.json), [suites exportadas](validation/exported-access.log), [menu](validation/exported-menu.log), [abertura nativa](validation/native-menu.log).

## Percurso renderizado final

Foram executadas três passagens nativas na ordem final → anterior → final. Todas completaram as 14 pernas entre os três bairros, com apoio no chão em todas as amostras. As duas passagens novas encerraram sem avisos de textura; a anterior reproduziu os dois avisos de 21.844 bytes.

| Passagem | FPS agregado | P99 | 1% low | Quadros sem foco | RSS máximo observado |
| --- | --- | --- | --- | --- | --- |
| Final, primeira | 13,30 | 141,89 ms | 5,93 FPS | 959 / 3.179 | 1.457 MiB |
| Anterior | 13,43 | 142,48 ms | 5,14 FPS | 195 / 2.976 | 1.453 MiB |
| Final, repetição | 22,07 | 119,79 ms | 7,24 FPS | 4.509 / 5.281 | 1.456 MiB |

Todos os quadros foram mantidos. A variação entre controles finais e a mudança de foco são grandes; o ensaio não sustenta atribuir ganho ou regressão à alteração na rota inteira. O ganho nas vistas estáticas do centro continua restrito às condições e aos controles daquele ensaio. **O pacing do percurso não passou.** [Resumo agregado](native-driving/aggregate.json), [auditoria por perna](native-driving/summary.json), [evidência bruta](native-driving/raw-evidence.tar.gz), [vista final](native-driving/final-view.png).

A comparação monta o pacote anterior sobre o namespace de recursos antes de carregar o mundo, preservando a fixture e o executável release. O resultado anterior confirma `visual_lod_present=false`; o final confirma `true`, ambos com `debug_build=false`. A passagem anterior e a repetição final usam exatamente o mesmo executável/fixture. A primeira passagem final antecede apenas a inclusão desse seletor de pacote e dos marcadores no JSON. [Fixture da comparação](validation/native-overlay-fixture/), [contexto e hashes](native-driving/context.json).

## Reproduzir o perfil estático

```bash
GODOT_BIN=/caminho/para/godot bash scripts/tools/build_pilot_profile.sh /tmp/wave-profile
DRI_PRIME=pci-0000_00_02_0 /tmp/wave-profile/WaveProfile.x86_64 -- \
  --expected-gpu=intel --preset=economy --views=113,119 \
  --cases=authored-detail,authored-detail,authored-detail \
  --seconds=8 --warmup=2 --output=/tmp/wave-profile-results
python3 scripts/tools/analyze_pilot_profile.py /tmp/wave-profile-results/summary.json
```

Use o endereço PCI da GPU da máquina. O argumento `--expected-gpu` rejeita adaptador inesperado antes de carregar a cidade. O projeto fonte não troca sua cena principal: o script monta um projeto de diagnóstico separado. Sem `--cases`, executa as oito ablações; `no-floor-far` permite investigar o custo do piso distante, mas esse corte gera lacunas e não é uma alteração do produto.

As próximas verificações de produto continuam sendo condução e revisão visual humanas, pacing controlado, Windows nativo e memória em 8 GB. A cidade continua completamente carregada em RAM; este LOD reduz desenho e não é streaming de recursos.
