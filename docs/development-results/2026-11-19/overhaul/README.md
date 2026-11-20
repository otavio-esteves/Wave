# Revisão gráfica e otimização da cidade piloto

Pedido: corrigir os problemas da auditoria e melhorar substancialmente gráficos e otimização, com três agentes coordenados. A referência anterior é o commit `b36005dd0d63b05ee0651f4f3789394240b40448`. A cidade continua com 200 quarteirões; não houve expansão nem remoção de colisões para obter os ganhos.

[Comparação visual com controle deslizante](index.html). As imagens são inspeções estáticas na Intel HD 4400, Compatibility, Equilibrado em 1280×720. O comparador registra as diferenças entre os presets das duas versões. A ambição de “400%” é uma direção artística, sem unidade objetiva de qualidade.

## O que mudou

O pavimento recebeu albedo, normal e escala revistos, com menos contraste miúdo no asfalto e gramado menos saturado. Materiais de pedra, concreto, telhados e vidro têm respostas mais consistentes. O céu ganhou nuvens, transições e leitura solar mais suaves; o tonemapping Linear foi escolhido após comparar Linear, Filmic e ACES na mesma cena. As janelas residenciais usam um interior original com cortinas e sala recuada. Apenas as unidades ocupadas recebem emissão texturizada à noite, ligada ao ciclo existente. O carro conserva suas formas, cabine e controles.

Os materiais são copiados uma vez por mundo e continuam compartilhados entre os objetos. A revisão de acabamento não adiciona passagens, geometrias ou luzes por janela. O ciclo preserva as oito luzes locais existentes, com alcance/intensidade maiores; isso pode aumentar o trabalho noturno e merece medição própria. Parâmetros idênticos do céu deixam de ser reenviados inutilmente quando o relógio está parado.

O custo foi tratado em quatro pontos:

1. Agrupamento exato de lotes compatíveis de endereços e carros estacionados antes da entrada na árvore. Mantém malhas, materiais, cores, transformações, camadas e visibilidade do pai; casos com comportamento próprio ficam separados.
2. Prédios distantes compartilham uma paleta estrutural com cores por instância. Vidros, emissão e materiais desconhecidos conservam sua representação. A média das texturas é preparada offline, sem leitura da GPU durante a partida. Uma comparação de cinco amostras de pixels em Compatibility confirmou erro RGB máximo zero após corrigir a conversão inicial.
3. Vegetação distante usa atlas com duas vistas cruzadas, restaurando os modelos originais perto do carro. A histerese evita alternância na borda. Econômico usa raio de entrada de 200 m; Equilibrado usa 320 m. As colisões continuam independentes da representação visual.
4. `BakedMultiMesh` salva os dados de envio à GPU e os limites espaciais junto às transformações autorais. O carregamento usa uma propriedade atômica versionada; recursos antigos continuam legíveis e caches incompatíveis são reconstruídos. O empacotador usa pequenos blocos vetoriais, com alternativa escalar para builds de precisão diferente e lotes muito grandes.

Depois das primeiras medições, paredes e lajes finas distantes receberam outra representação: as duas faces principais originais permanecem nas mesmas posições, com suas normais, UVs, cores, materiais e limites. As quatro faces laterais subpixel são omitidas. Cada peça elegível passa de 12 para quatro triângulos. A regra vale apenas para caixas opacas da paleta simplificada, com espessura de até 40 cm e razão fino/largo de até 0,2. Vidros, emissão e materiais preservados continuam usando sua representação anterior. O detalhe próximo e o opt-out mantêm a geometria autoral.

Uma fonte que contém peças finas e volumes continua com um único estado de proximidade/histerese. Segmentos direcionam seus dados aos respectivos proxies, e toda alteração reconstrói todas as chaves necessárias. A revisão não remove instâncias. A prova renderizada comparou 36 combinações de eixo, culling e ângulo a 240 m: erro RGB interior e deslocamento dos limites iguais a zero. Esse teste não promete igualdade de todos os pixels da cidade em qualquer posição.

## Decisões apoiadas pelas medições

As ablações abaixo usaram o mesmo executável release, Intel HD 4400, Econômico, vista 150, com controles restaurados entre os casos. A máquina permaneceu compartilhada. Os valores são diagnósticos estáticos curtos; não certificam percurso, 30 FPS ou uso exclusivo.

| Experimento | FPS observado | Decisão |
| --- | ---: | --- |
| Controle da rodada de orçamento | 2,10–2,12 | Referência da rodada |
| Metade do alcance próximo | 2,24 | Padrão preservado; ganho pequeno |
| Oclusão com 4.178 volumes conservadores | 2,12 | Somente diagnóstico; não ativada no jogo |
| Ocultar copas | 2,69 | Teto diagnóstico; vegetação preservada |
| Relógio em movimento / céu incremental | 2,10 / 2,10 | Qualidade do céu preservada |
| Ocultar proxies dos prédios | 5,14 | Identifica o custo distante; nunca aplicado ao jogo |
| Omitir peças distantes mantendo apenas grandes volumes | 3,76 | Rejeitado como padrão por remover conteúdo |
| Duas faces principais, com todas as instâncias | 2,85 | Integrado; aproximadamente 35% sobre controles 2,10–2,11 |

Uma extensão de atlas para flores também foi preparada e testada, preservando byte a byte as 26 células anteriores e seus mips. A aproximação ficou mais densa/brilhante que as pétalas originais; permanece restrita ao profiler. O jogo conserva as flores originais. O atlas não acrescentou dimensão nem uma textura ao caminho normal das árvores.

A comparação final usou executáveis release em sequência, na mesma Intel HD 4400, Econômico, 854×480 e vista 150. A média passou de **3,43 para 7,55 FPS: aproximadamente 2,2×, ou 120% de aumento**. Com o ciclo de horário em movimento, a versão final marcou 7,33 FPS; ao restaurar a condição parada, 7,53 FPS. São janelas estáticas de 20 segundos numa máquina compartilhada, não uma certificação de ganho em qualquer percurso. O resultado ainda fica muito abaixo de 30 FPS. O P99 final foi de aproximadamente 361 ms, indicando travadas ainda relevantes.

Uma repetição sem o monitor externo de hardware marcou 7,69 FPS, com P99 de 361 ms. Portanto, retirar a telemetria não resolveu os picos. A última correção de publicação de recursos alterou somente a resolução de scripts compilados e suas fixtures; o código de renderização permaneceu igual ao desses testes. Dados e contexto estão em [native-comparison.json](native-comparison.json).

Resultados de redução de triplanar não foram promovidos: o controle posterior também acelerou, indicando mudança de condições durante a rodada. Os logs conservam tentativas incompletas, incompatibilidade de fixture/PCK e falhas de integração corrigidas, sem contá-las como aprovações.

## Contagens e custos comprovados

| Medida | Antes | Depois | Escopo |
| --- | ---: | ---: | --- |
| Lotes geométricos dentro de `City` | 34.338 | 30.452 | Agrupamento remove 4.277; selagem acrescenta 391 |
| Nós dentro de `City` | 42.280 | 38.395 | Inclui o contêiner e as 391 malhas de selagem |
| Formas de colisão dos sólidos | 34.170 | 34.170 | Preservadas |
| Lotes estruturais distantes, amostra 150, etapa da paleta | 1.812 | 864 | Etapa anterior à separação das faces; não é contagem final de draw calls |
| Recursos instanciados na migração | 28.850 | 28.850 | 1.375.043 instâncias autorais idênticas |
| Varreduras de limites no carregamento desses recursos | 28.850 | 0 | Verificação headless da migração |

As copas distantes passam de um LOD de 300 triângulos para quatro triângulos por parte. Isso descreve a representação, não uma porcentagem de ganho de FPS. O atlas e o estado do HLOD aumentaram o alocador estático em cerca de 49 MiB no diagnóstico anterior à migração. O formato preparado também aumenta o tamanho dos arquivos; a geração nova tem 151.792.593 bytes. Não houve redução demonstrada de RAM.

A inspeção revelou uma fresta real de aproximadamente 16 cm entre ruas e calçadas na aproximação do cruzamento inicial. Um cache offline de selagem acrescenta somente as faixas entre bordas medidas, em 391 malhas locais; conserva as malhas e colisões autorais. A instalação verifica a geração imutável e os recursos de origem e compartilha o material do asfalto. O remendo tem a classificação `RoadSeam`, separada das ruas físicas. A cunha de grama maior desapareceu nas capturas; resta possível traço de poucos pixels numa junção. As tentativas de rebaixar o piso distante e forçar LOD integral foram descartadas após a investigação.

A migração foi produzida numa entrada isolada. Foram comparados 76.450 snapshots de nós, incluindo malhas completas, transformações, materiais e colisões: zero diferenças. Hash das transformações/cores autorais: `f12cd80ee068938337710883b35bbd6d9fd2a370f3ab4f26000fbb90e54168e9`. Somente após essa comparação a entrada foi promovida atomicamente; as gerações anteriores foram preservadas para retorno e comparação.

No microteste de 4.096 instâncias, cinco pares alternados deram mediana de 43,169 ms no caminho legado e 15,384 ms no preparado. É um teste de CPU de recurso com servidor dummy; não mede FPS. Na migração completa, carregar e instanciar passou de 34,482 s para 21,076 s na mesma execução, mas ordem/cache e carga da máquina não foram controlados. Esses valores não certificam uma razão de velocidade de startup.

## Correções da auditoria

- Publicação verifica a existência física de cada dependência, mesmo que o recurso esteja no cache, e carrega o grafo ignorando o cache. Nos pacotes, resolve `.remap` e confere o destino compilado real, como `.gdc`, com proteção contra ciclos e remapeamentos inválidos. Uma geração incompleta não substitui a entrada funcional. O staging pode usar a família final de gerações para que a promoção não reescreva caminhos já verificados.
- O cancelamento de reset durante uma transição de streaming suprime o botão até sua liberação. Segurar Circle depois de cancelar não dispara um reset inesperado; um novo toque funciona normalmente.
- A análise de pacing exige cobertura temporal completa, considera a união dos intervalos, rejeita sobreposição usada para esconder lacunas, dados não finitos e percursos vazios/incompletos. O gate inclui 1% low de pelo menos 30 FPS. Capturas antigas sem âncoras ainda mostram métricas, mas não aprovam cobertura.
- O carregamento em worker deixou sete referências internas retidas nesta versão da engine. Uma cena mínima reproduziu o problema e confirmou a solução: preparar cinco texturas, a paleta e o shader compartilhados na thread principal antes de pedir o mapa. O menu faz somente esse aquecimento; o atlas e a cidade continuam carregando quando solicitados. O teste completo de carregamento encerrou sem vazamentos.

## Configuração

Selecione **Econômico** ou **Equilibrado** para aplicar as novas escolhas. Ambos simplificam prédios e vegetação distantes; Equilibrado conserva detalhe por mais distância. A opção **Detalhes urbanos por mais distância** é independente de resolução, materiais, sombras e MSAA. Desativar a simplificação restaura as representações originais. Configurações já salvas mantêm suas escolhas; Qualidade e Legacy usam os modelos completos.

## Validação e reprodução

O fechamento de suítes, exports e medições está registrado em [validation.json](validation.json). Logs completos e medições brutas ficam em `builds/overhaul-2026-11-19/`; esse diretório é ignorado pelo Git. As imagens e evidências compactas deste diretório são versionáveis.

A fonte completou as 50 suítes então registradas e as extensões posteriores. O consolidado cobre **52 suítes, 1.268 verificações Godot e 37 testes Python**, incluindo persistência e montagem offline, com zero falhas finais. A regeneração isolada conferiu terreno, ruas, UVs, objetos e colisões; as seis rotas de ida e volta passaram com suporte e pavimento contínuos. O registro preserva a execução completa original e discrimina as extensões e verificações posteriores, sem somar repetições.

O PCK final passou **32 suítes e 862 verificações**, além da confirmação inicial de que os recursos vieram do pacote. O runner encerrou com saída 0, sem falhas. Linux e Windows foram exportados com o mesmo PCK de 236.366.104 bytes; os hashes estão em [exports-sha256.json](exports-sha256.json). O Windows não foi executado nativamente nesta máquina.

A verificação renderizada percorreu 14 trechos com comandos reais, usando a engine do editor como harness e os recursos do PCK final: 14 chegadas, suporte e pavimento de 100% nas amostras, desvio máximo de 1,554 m. O processo temporizado registrou saída 0, enquanto a sessão externa retornou 143 antes de gravar seu fechamento; ambos os estados foram preservados e a origem da divergência não foi estabelecida. Nenhum dos 14 trechos aprovou o gate numérico de pacing. Somente um aprovou a cobertura temporal completa; nos demais, a duração capturada difere da parede além da tolerância do analisador. Esse percurso comprova comportamento funcional e não certifica FPS nativo. Separadamente, o executável release Linux abriu o menu e encerrou automaticamente com saída 0 em todos os níveis, sem avisos ou erros no log. [Evidências de condução e menu](rendered-driving-validation.json).

```bash
export GODOT_BIN="$HOME/Downloads/Apps/Godot_v4.7.2-stable_linux.x86_64"
export TMPDIR="$PWD/builds/overhaul-2026-11-19/tmp"
mkdir -p "$TMPDIR"
WAVE_SUITE_TIMEOUT=3600 bash scripts/tools/check_project.sh
bash scripts/tools/check_exported_access.sh builds/linux/Wave.pck
bash scripts/tools/build_pilot_profile.sh builds/overhaul-2026-11-19/after-native-profile
```

O profiler nativo aceita `--hour=23` e o caso opcional `running-cycle`. Registra o intervalo real do relógio/nuvens e restaura a condição parada entre ablações. As medições renderizadas devem usar executável release com PCK adjacente, `debug_build=false`, resolução e GPU registradas. O editor com PCK serve para testes de recursos, não como evidência de desempenho do executável final.

O contador de primitivos da engine exige cuidado: no caminho GLES3 com LOD, esta revisão não aplica o multiplicador de instâncias usado no caminho sem LOD. Por isso os totais de copas antigas e cards novos não servem para calcular uma porcentagem de trabalho geométrico poupado. FPS e ablações pareadas são tratados separadamente. [Fonte da engine usada](https://github.com/godotengine/godot/blob/ed1daf0bf001b61586d9930840f2f1394092c079/drivers/gles3/rasterizer_scene_gles3.cpp#L1317).

## Arte original e rastreabilidade

O interior foi gerado em modo **built-in image_gen**. [PNG original](../../../../assets/textures/pilot/window-interior-v2.png) e [prompt exato, modo e SHA256](../../../../assets/textures/pilot/window-interior-v2.provenance.json). O material usa a derivação de 512 px com mipmaps, sem acrescentar transparência ou geometria. [Procedência do acabamento](../../../../assets/textures/pilot/finish-provenance.json) e [atlas de vegetação](../../../../assets/textures/pilot/foliage-provenance.json) registram as fontes e a geração.

## Limites

A máquina tem 16 GB e executa outras cargas do usuário. Não foram encerrados processos alheios. Contagens, comparações de pixels e testes headless têm escopo próprio; não aprovam 30 FPS sustentados, funcionamento em 8 GB, Windows nativo ou sensação humana de condução. A aparência das folhas cruzadas em ângulos oblíquos e as transições de detalhe merecem avaliação em movimento. As preferências permitem restaurar a representação completa.
