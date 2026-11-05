# Otimização cirúrgica sem janela — 2026-11-04

Esta revisão trata custos demonstráveis no código e nos dados da cidade atual, mantendo os 200 quarteirões, os destinos, a condução e a composição próxima. Todo o trabalho e a validação desta etapa usam execução headless; nenhuma janela do jogo foi aberta. Números de CPU e estrutura não certificam FPS, pacing, aparência em movimento, 8 GB ou Windows nativo.

## Recursos e carregamento

Os setores agora referenciam externamente uma coleção compartilhada de malhas e materiais. O pool compara todas as propriedades persistidas, incluindo projeção UV e intensidade dos mapas normais, antes de compartilhar recursos equivalentes. Dimensões de primitivas e materiais diferentes continuam separados. Colisões de caixas equivalentes também compartilham seus recursos. A publicação permanece transacional, com recursos imutáveis por geração e preservação da versão anterior.

`BakedMultiMesh` recebe transformações e cores juntas quando atualizado pelo código, monta o buffer no formato de linhas 3×4 com RGBA e envia o lote de uma vez. Seus arrays de autoria permanecem persistidos; cópias nativas redundantes dos buffers não são salvas. Em headless, o recurso calcula contagens e limites de visibilidade sem enviar dados ao servidor de desenho fictício. O formato segue a [documentação do RenderingServer](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html#class-renderingserver-method-multimesh-set-buffer).

Os sólidos distantes recebem `PROCESS_MODE_DISABLED` antes que a cidade entre na árvore. O modo de remoção do `CollisionObject3D` impede que eles entrem inicialmente no espaço físico. A seleção por proximidade preserva a histerese e restaura colisões antes da condução após reset. Terreno, ruas e calçadas conservam seu suporte físico.

Durante essa preparação, os nós estáticos `CollisionShape3D` dos sólidos são convertidos em [shape owners nativos](https://docs.godotengine.org/en/stable/classes/class_collisionobject3d.html), com as mesmas formas, transformações e estados de habilitação. A cidade salva continua editável e conserva os nós de autoria; a sessão não precisa manter 34.170 nós individuais para essas formas. Colisores com script ou filhos são preservados. A contagem física é conferida contra as formas de autoria antes da conversão, e as superfícies de apoio conservam seus nós e nomes para as consultas do carro.

## Desenho e atualização do detalhe

Os 25.276 arbustos que usavam uma cópia da copa sem LOD recebem os mesmos dois níveis de patches das árvores. Os vértices, índices de detalhe completo, normais, UVs e cores codificados são preservados. O nível distante usa um terço dos triângulos da malha completa, mantendo patches em todos os grupos de galhos. A seleção real de nível depende da projeção do renderer e continua exigindo inspeção visual.

A opção existente de simplificação distante passa a abranger casas e comércio, além das torres. Casas conservam todas as partes próximas; a 240 m entram representações estruturais agrupadas em setores de 256 m, com retenção até 320 m. Paredes, telhados inclinados, portas e painéis de janela são preservados; peças finas são omitidas na representação distante. Torres mantêm os raios de 340/420 m e setores de 512 m. Equilibrado, Qualidade e Legacy restauram a geometria completa. As silhuetas distantes seguem presentes até a névoa, evitando vazios entre bairros; essa aparência ainda precisa ser conferida em movimento.

Os proxies guardam buffers compactos imutáveis por setor. Setores inteiramente distantes compartilham seu próprio buffer, sem uma segunda cópia da cidade distante; somente setores com mistura de grupos próximos e distantes remontam uma seleção. Uma grade espacial consulta grupos próximos e anteriormente ativos, incluindo saídas após teleporte/reset. Mudanças gráficas que conservam a escolha de detalhe não remontam os proxies. A criação dos proxies é adiada até o primeiro uso da simplificação.

## Manutenção e primeira execução

A cidade piloto herda diretamente da base de montagem offline. A paleta e o prédio de atlas compartilhados com o corredor ficam em `city_building_kit.gd`, preservando sua geometria. A extração remove a dependência do gerador inteiro do corredor sem reescrever os demais domínios de arquitetura, superfícies e cenário.

Uma instalação sem arquivo de preferências começa no Econômico. Configurações existentes, incluindo arquivos antigos contendo apenas áudio, preservam os valores e as migrações anteriores. Os demais presets continuam disponíveis.

O inventário de gerações protege a geração ativa, a anterior para retorno, os baselines citados nos documentos e os grafos completos dessas entradas. Três gerações sem referências foram movidas reversivelmente para `/home/otavio/Projects/Wave-artifact-archive/2026-11-04`, com manifesto de restauração: 15.967 arquivos e 368,3 MiB fora da árvore de trabalho. O histórico Git permanece intacto. Isso reduz a árvore atual; o tamanho histórico de `.git` não diminui sem uma reescrita de histórico, que não foi feita.

## Verificação estrutural

A comparação entre a cidade anterior e a candidata conferiu 76.450 snapshots de nós, sem diferenças nos dados de autoria comparados. Os novos índices de LOD dos arbustos são a alteração prevista; sua geometria de detalhe completo participa da comparação. A suíte de recursos verifica compartilhamento após recarregar setores independentes, distinção de UVs e normais, transformações rotacionadas/escaladas, cores e alpha, limites, atualização vazia e compatibilidade das preferências. A suíte de LOD cobre casas, telhados, janelas, mudanças de bairro, presets, histerese, inicialização adiada e reset espacial.

## Diagnóstico final de CPU e memória

Godot 4.7.2, Linux, máquina compartilhada com 16 GB. Cada ponta tem uma captura diagnóstica; isso não é um benchmark controlado. A captura final foi executada depois de encerrar nossos outros processos Godot. O harness começa no Legacy e depois ativa o Econômico: a soma abaixo inclui a preparação inicial do LOD, que agora também cobre as casas e é criada sob demanda.

| Medida | Antes | Depois |
| --- | ---: | ---: |
| Carregamento de recursos | 26,39 s | 10,98 s |
| Instanciação | 14,58 s | 5,01 s |
| Anexação ao mundo | 6,34 s | 2,46 s |
| Soma das fases, incluindo primeira ativação do Econômico | 47,31 s | 21,15 s |
| Memória estática do alocador após ativar o Econômico | 1.130,7 MiB | 1.083,6 MiB |
| Nós da cidade durante a sessão | 76.450 | 42.280 |
| Formas de sólidos, preservadas | 34.170 | 34.170 |

A redução observada do alocador é de aproximadamente 47,1 MiB (4,2%); isso não equivale a RSS ou VRAM. A cidade mantém seus recursos residentes, com 33 malhas de instâncias e 51 materiais únicos nessa captura. Esta etapa reduz duplicação, nós e trabalho de desenho; não introduz streaming de recursos.

A seleção espacial contém 8.626 grupos de detalhe. Nos pontos 150/113/119, consultou respectivamente 437/981/910 candidatos, preservando os grupos próximos e as silhuetas distantes. Um teste sintético de 16 deslocamentos de 16,1 m registrou mediana de 2,10 ms e máximo de 6,58 ms na atualização de seleção, com até 750 candidatos. Esses tempos excluem o envio real à GPU e não são frame times de uma rota dirigida. A primeira ativação do novo LOD custou 2,70 s; os perfis completos dispensam essa construção até a opção ser usada.

[Antes](validation/before-cpu.json) · [harness anterior](validation/before-harness.gd.txt) · [depois](validation/after-cpu.json) · [contexto, contagens e hashes](validation/record.json).

## Validação final e distribuição

O runner completo passou 41 suítes, persistência e montagem offline: **970 verificações Godot**, mais **23 testes Python únicos**. A física foi ampliada durante a revisão; sua execução final de 16 verificações substitui as nove do runner, resultando em **977 verificações Godot únicas nas versões finais**. Recursos (18) e LOD (31) foram repetidos depois das últimas mudanças sem duplicar suas contagens. A física final inclui retorno de pausa sem reativação dos sólidos distantes, compactação idempotente, rotação, formas desabilitadas e preservação de colisores com script.

A regeneração independente completou a comparação integral com a cidade publicada. Os percursos fechados dos três bairros, nos dois sentidos, mantiveram suporte e pavimento em todas as amostras registradas; praça e oficina continuaram acessíveis. A montagem dos mapas anteriores também passou após a extração do kit compartilhado.

O pacote passou 18 suítes e sua guarda de namespace: **504 verificações**. A repetição final da física acrescenta uma verificação à versão anterior, totalizando **505 verificações únicas no pacote**. A guarda confirma carregamento exclusivo dos recursos exportados. Não houve diagnósticos inesperados; os dois erros de recurso ausente do runner de origem são o caso negativo deliberado da suíte de streaming, filtrado pelo próprio runner.

Linux e Windows foram reexportados com PCKs idênticos: **201.446.928 bytes**, SHA-256 `682df296b5fd3474116deea1fad348b67775aa80f0fa008a23906400fe6f2854`. O executável Linux abriu e encerrou o menu headless após cinco frames, com saída zero. O harness do pacote usa a engine do editor; esse teste nativo separado verifica o início do executável release. Windows nativo, aparência renderizada, FPS/pacing sustentados e 8 GB permanecem pendentes.

[Runner de origem](validation/source.log) · [física final](validation/final-city_physics.log) · [LOD final](validation/final-pilot_visual_lod.log) · [recursos finais](validation/final-city_resources.log) · [regeneração](validation/regeneration.log) · [migração](validation/migration-integrity.log) · [pacote](validation/exported-access.log) · [física final do pacote](validation/exported-final-physics.log) · [exportação](validation/export-builds.log) · [menu nativo](validation/native-headless-menu.log) · [retenção](validation/generation-retention.json) · [arquivo reversível](validation/archive-manifest.json).

## Reproduzir sem abrir a janela

```sh
godot --headless --path . --script res://scripts/tools/profile_city_cpu.gd -- --output=/tmp/wave-city-cpu.json
godot --headless --path . --script res://scripts/tools/audit_city_generations.gd -- --output=/tmp/wave-generations.json
GODOT_BIN=/caminho/para/godot bash scripts/tools/check_project.sh
GODOT_BIN=/caminho/para/godot bash scripts/tools/export_builds.sh
GODOT_BIN=/caminho/para/godot bash scripts/tools/check_exported_access.sh
```

O diagnóstico de CPU aceita `--city=/caminho/para/pilot_city.scn` para carregar uma candidata em uma cópia temporária da cena jogável. Ele registra carregamento, instanciação, anexação, memória estática do alocador e contagens da seleção de LOD; lotes logicamente visíveis não equivalem a chamadas efetivas de desenho. A migração offline está disponível em `optimize_pilot_resources.gd`; por padrão grava em `user://`, sem substituir a cidade de produção.
