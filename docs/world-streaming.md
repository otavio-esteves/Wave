# Contrato de mundo contínuo

**Estado:** prova implementada com três células da Avenida do Vale. O menu mantém o corredor estático e oferece **Passear na cidade em construção** como variante experimental. Os mapas antigos continuam monolíticos; HLOD simples por célula foi acrescentado; bairro integrado e mundo entre cidades ainda são futuros. Este documento distingue o contrato exercitado da arquitetura a expandir.

## Dados offline

Manifesto versionado com regiões, célula/ID estável, caminho de `PackedScene` em string (não preload de todas as cenas), origem em metros, AABB, vizinhos, entradas viárias, seed/versão de gerador, representação distante e custo medido. Exemplo lógico: CidadeA/Bairro01, Highway/Segment01, Highway/Posto, CidadeB/Industrial. Uma região contém várias células; a prova usa fronteiras em −200/−400 m: trecho central de 200 m, células das extremidades com piso de entrada/saída. Os lotes internos continuam em 84 m. Essa divisão é um experimento, não tamanho universal.

Cada cena contém geometria agrupada, colisões locais, marcadores de rota/atividades e LOD. Carro, câmera, HUD, céu/sol e sessão pertencem ao mundo persistente. Materiais/meshes comuns são recursos externos para compartilhamento; liberar uma célula não deve manter referência acidental ao mapa inteiro. Uma casa/prop que cruza limites tem um dono definido. Conexões de piso devem se encaixar sem lacunas, duplicação de colisão ou seams aparentes.

## Estados e responsabilidades

| Estado | Responsabilidade |
| --- | --- |
| Descarregada | Só metadados/representação distante elegível |
| Solicitada | I/O por `ResourceLoader.load_threaded_request`; fila de prioridade por proximidade/corredor |
| Pronta | Recurso concluído; não fazer `load_threaded_get` enquanto carrega |
| Ativa | Cena anexada à árvore, colisão necessária disponível, visual dentro de LOD |
| Retida | Fora da região ativa mas no anel de histerese; custo/memória contabilizados |
| Falha | Erro reportado e política segura; sem retry ilimitado a cada frame |

O streamer consulta metadados com grade espacial quando o manifesto crescer. Na prova pequena, uma lista limitada é suficiente. Usa distância aos **limites da célula**, não só ao centro. Prioriza célula atual, vizinhos com entrada conectada e corredor à frente. Distância de preload deriva de velocidade × pior latência medida + margem de frenagem/segurança. Reset ou teleporte invalida prioridades antigas; o alvo novo não pode entrar sem apoio.

I/O assíncrono não garante quadro barato: instanciar, restaurar MultiMesh, anexar colisões, compilar shaders e fazer upload de texturas são custos separados. Um job por vez ou fila pequena, com tempo medido de cada fase; no primeiro protótipo, uma célula ativada por frame e limites de conteúdo suficientemente pequenos. Budget de milissegundos não consegue interromper `instantiate()` no meio; se exceder, subdividir a célula/artefato, não apenas aumentar o timer.

Carregar e descarregar com raios distintos. Congelar transições durante pausa. Distant/HLOD não ativa gameplay ou colisões detalhadas. Remover nós e referências de recursos/caches ao descarregar; observar RAM/RSS convergindo após viagens repetidas. Não supor que `queue_free` libere GPU no mesmo quadro. Oclusão/frustum/cull de MultiMesh continua independente de residência de célula.

## Carga atrasada e segurança

No caminho normal, preload antecipado deve ocultar o I/O. Em atraso/falha, manter piso de segurança retido e impedir avanço para uma entrada sem apoio, com desaceleração/transição controlada e diagnóstico. O fallback de falha não deve mascarar uma rota que falhou o gate: registrar atraso/tempo parado e reprovar travadas repetidas. Não inserir loading explícito na viagem normal nem deixar o carro cair enquanto arquivos chegam.

## Prova e testes obrigatórios

1. Três células serializadas, atravessadas de ida/volta com colisões e determinismo do layout.
2. Reset na célula original, salto para destino não residente e reversão na fronteira sem ciclo de load/unload.
3. Injetar I/O lento, recurso inválido, request obsoleto e erro de ativação; nenhum piso ausente ou retry frenético.
4. Contar cenas/recursos residentes, respeitar conjunto ativo/retido máximo configurado, repetir viagens e conferir convergência.
5. Capturar frame time e tempos de solicitar/concluir/instanciar/anexar/liberar em janela real; correr a 120 e 220 km/h onde a geometria permitir.
6. Testar pausa/troca de mundo/destruição com jobs pendentes; limpar referências sem callbacks para nós liberados.

Apenas após essa prova converter um bairro. Não recortar automaticamente a cidade existente se colisões globais, placa/landmark ou piso transpassarem fronteiras sem regras explícitas.

## Implementação da prova

- `CorridorCellsBuilder` parte do layout original, atribui dono por centro a props/colisores/landmarks e separa os lotes existentes. Recorta triângulos de piso, via, remendos, fios e oclusão com interpolação de UV/normal/cor; não duplica a avenida inteira em cada arquivo. Objetos que atravessam fronteiras têm um único dono e permanecem completos.
- `build_corridor_cells.gd` escreve `scenes/world/cells/vale/{manifest.json,cell-0..2.tscn,horizon.tscn,shared/}`. Materiais e primitivas compartilhados são `.tres` externos. A regeneração isolada aceita `-- --output=user://cells-regenerated`; não altera o corredor estático ou os mapas anteriores.
- `WorldStreamer` lê só metadados; solicita um arquivo por vez, mantém no máximo um job solicitado/pronto, consulta status e só obtém a cena após `LOADED`. Em `FAILED` (terminal), consome o resultado nulo para liberar o job; nunca chama `get` durante `IN_PROGRESS`. Cena pronta obsoleta é descartada. Não mantém `PackedScene` depois de instanciar.
- Uma ativação **ou** liberação de nós por quadro de processo. Residentes limitados a três nesta fixture; um inicial parado, até três no centro e dois no extremo oposto. Preload de 210 m aos limites, com até 65 m adicionais conforme velocidade; retenção de 330 m evita oscilações. Não são distâncias calibradas para o mundo final.
- Corpo/floor local em cada célula. O contrato inicial exige `Colliders/Floor` box contínuo, alinhado e plano em y=0, consistente com os limites do manifesto. A ativação valida esse apoio e aguarda dois ticks físicos antes de liberar movimento. Não declarar uma célula segura apenas porque o arquivo abriu.
- Player/câmera/HUD/áudio/sol persistem. O guard roda antes do carro e verifica os quatro cantos da footprint no próximo passo. Atraso/falha congela temporariamente a condução sobre apoio retido ou no destino de teleporte. É fallback diagnóstico abrupto, não a desaceleração final; suas ocorrências ficam explícitas e reprovam a viagem normal.
- Pausa congela seleção/ativação/descarregamento; o worker pode concluir I/O. Reset e `teleport_to` recolocam prioridades, mantêm posição até apoio pronto e preservam reset/câmera do carro. Ao destruir o mundo, um nó temporário na raiz consome resultados pendentes sem referências/callbacks para o streamer liberado; Godot não oferece cancelamento do job. Esse nó some ao terminar.

`snapshot()` registra estados, residentes/pico, liberações, falhas, bloqueios e os últimos 1.024 eventos por fase com posição, frame, tick e relógio monotônico. Marcadores `capture_start/end` permitem alinhar eventos aos CSV por quadro. `request` mede CPU da solicitação; `request_to_ready` inclui espera de polling; `instantiate` e `attach` medem CPU síncrona. `release_cpu` mede a liberação dos nós/recursos na thread principal, não a conclusão do driver GPU. Upload/compilação aparecem também nos intervalos de quadro, sem atribuição exclusiva GPU.

`corridor_cells_smoke.gd` confere preservação/regeneração/recorte; `streaming_smoke.gd` dirige ida/volta a 220 km/h, sonda seams, reverte, reseta e injeta atraso/erro/obsolescência/pausa/destruição. `streaming_rendered.gd` mede janela real: rota de ida a 120 km/h; flags `--speed-220 --round-trip --three-cycles` exercitam três viagens completas. O diagnóstico aceita `--cycles=1..6` e `--no-capture`: doze pernas com e sem buffers de frame time, registrando RSS, recursos, nós/órfãos, allocator, render allocations e contagens da captura nos endpoints. Sem captura não há série nem aprovação de FPS. `--startup-only` mede somente entrada/aquecimento, com intervalos monotônicos desde antes da troca de cena até o primeiro apoio; não representa o tempo completo de iniciar o processo nem tempo exclusivo GPU. Retorno usa uma virada por reset/heading no mesmo ponto, declarada no relatório; cada perna é conduzida por inputs comuns. Sem screenshots na captura.

## HLOD do corredor

`CorridorHLODBuilder` gera `distant.tscn` na mesma etapa offline das células. Cada grupo usa uma única superfície opaca com vertex colors derivados das cores/texturas do material original, mesclando piso/vias e silhuetas reais de corpos/telhados/galpões. Um MultiMesh de árvores reaproveita os cards e a textura já existentes, sem sombras. Não acrescenta vegetação 3D, fachadas/placas detalhadas, transparência de fade ou colisões. Os três grupos somam 1.324 triângulos e até seis lotes visuais; não referenciam nenhum `PackedScene` de célula detalhada.

`WorldHLOD` atua depois da mutação de streaming no quadro. Distância do jogador aos limites da célula: entra em detalhe a 180 m, sai acima de 200 m; na faixa mantém a escolha anterior. São valores experimentais, não budget universal. Sem nó residente, mostra proxy mesmo longe; com detalhe, esconde proxy. `visible` da raiz detalhada controla apenas desenho: corpo/apoio físico continua sob o guard do streamer. Uma célula pode estar residente com colisão ativa e renderização simplificada. A histerese de residência e a histerese visual têm responsabilidades diferentes.

A prova mantém **três proxies pequenos residentes**. Isso resolve a perda de silhueta desta avenida, mas não permite deixar proxies de duas cidades inteiras carregados. Próxima escala deve usar anel/manifesto de representação distante e HLOD por distrito; conservar horizonte separado. Por enquanto, não há LOD individual com três versões de cada casa nem qualidade final aprovada. A troca é opaca; verificar variação de cor/piso e popping em execução real antes de ampliar.

`snapshot()` registra representações, proxies visíveis, transições e os últimos 256 eventos com frame/clock/posição para cruzar com os CSV. `hlod_smoke.gd` testa serialização/determinismo, isolamento das cenas completas, limite de lotes, alternância/histerese, apoio real quando o detalhe está oculto e destruição. `--no-hlod` em `streaming_rendered.gd` restaura desenho de todos os residentes e esconde proxies para A/B; **os recursos dos proxies permanecem carregados nos dois casos**, isolando o desenho, não o consumo de memória do artefato.

O runner `hlod` produz vistas fixas comparáveis e contadores de desenho; não mede FPS. Readback/PNG fica fora de toda captura. Runner `streaming` mede condução com HLOD ligado por padrão e guarda a configuração no JSON. Resultados em [performance.md](performance.md).

## Limites desta entrega

Não há HLOD por distrito com streaming próprio, filas para dezenas de regiões, terreno irregular, tráfego ou streaming de áudio. A validação de apoio é específica ao corredor plano. O limite de residentes precisa ser compatível com a área de preload/retenção: esta prova foi calibrada para três células, não certifica configurações menores ou manifestos maiores. Distâncias e entrada fria ainda devem ser calibradas em cenário maior. Massas de prédios, telhados, piso e árvores agora persistem na representação distante ao descarregar o dono. Props pequenos, placas, postes/fios e oclusão local são descartados longe. HLOD/impostores por distrito com residência limitada serão necessários antes de escalar; horizonte e os três grupos desta prova continuam residentes.

Testes de contagem não comprovam RAM sob 8 GB. Viagens repetidas, RSS e monitores de memória ajudam a investigar convergência, sem certificar sessões longas/térmica ou Windows. Evidência de pacing e condições em [performance.md](performance.md).

O manifesto da Avenida do Vale registra também `generator_version` (atualmente 2), separado da versão 1 do contrato do manifesto. A revisão das hero areas é produzida no gerador e propagada às cenas estática e particionadas; não exige geração em runtime ou mudança no loader.

## Preparação de renderização na primeira entrada

O material opaco distante usa a variante padrão de cores de vértice em Compatibility: a conversão sRGB adicional era inativa nesse renderer, mas criava outro shader. `WorldHLOD` liga a conversão nos renderers lineares. O gerador e o artefato mantêm exatamente as mesmas cores/geometria; o loader e o guard permanecem iguais. Três pares de entrada/cache mostram redução fria média de 14,17%, ainda com 4,83–4,97 s até apoio pronto. [Medição](performance-results/2026-10-06/startup-material/README.md).

O observador registra chamada da troca, anexação, apoio e intervalos `frame_pre_draw`/`frame_post_draw`; não mede tempo exclusivo GPU. A fixture renderizada aceita `--reference-hlod-srgb` para restaurar a variante anterior antes do primeiro desenho e registrar o valor usado, sem opção no menu do produto.
