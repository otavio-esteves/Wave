# Correções ponto a ponto — 2026-10-10

Continuação em 2026-10-11: [diagnóstico nativo Intel, simplificação dos prédios distantes e correção do céu](../../../performance-results/2026-10-11/pilot-intel-profile/README.md). Os números e hashes abaixo descrevem a revisão anterior; consulte o relatório novo para os builds atualizados.

Esta revisão responde à análise do projeto e mantém a cidade de 200 quarteirões. O usuário autorizou somente diagnóstico gráfico, pois continuará usando a máquina. FPS e memória observados nesta sessão não certificam os gates de uso exclusivo, 8 GB ou Windows nativo.

| Ponto | Implementação |
| --- | --- |
| Desempenho | Cache de luzes, superfícies e materiais; materiais compartilhados são atualizados uma vez por recurso. LOD de folhagem acompanha o preset. HUD atualiza a cada 100 ms e distâncias da atividade usam comprimentos acumulados. |
| Residência física | Prédios, árvores e outros sólidos entram no espaço físico perto do carro. Raio de entrada de 320 m e retenção de 448 m; verificação a cada 250 ms com deslocamento mínimo de 16 m. Reset restaura a vizinhança imediatamente. Terreno, ruas e guias continuam ativos em toda a cidade. As formas e a geometria permanecem carregadas: esta redução de broad phase não é streaming de RAM. |
| Telemetria | Leituras de sensores executadas em processo separado, com orçamento de 100 ms por amostra e timeout de 150 ms por leitura, além de 250 ms de tolerância para iniciar o leitor. Sensores sem resposta são registrados e retirados das próximas tentativas. O encerramento do jogo não depende do driver. |
| Carregamento | Menu solicita cenas em background, mostra progresso/preparação, bloqueia solicitações duplicadas e apresenta erros recuperáveis. A instanciação continua na thread principal, como exige a API usada. Os três WAVs compartilhados são pré-carregados na thread principal para evitar referências de decodificação vazadas no ensaio de carregamento em background. |
| Gerador e publicação | Código separado em superfícies, cenário e arquitetura, coordenados pelo gerador. Dependências são gravadas em uma geração nova; publicação verifica dependências, carrega a cena e troca a entrada por rename no mesmo diretório. Gerações anteriores permanecem intactas. Exportações excluem os diretórios legados de geometria/setores; o plugin de exportação inclui somente a geração publicada, mesmo quando outras gerações são preservadas para recuperação. |
| Acabamento e atividade | Seis variações sutis por imóvel via cores de instância, sem multiplicar materiais/lotes. Praça e oficina recebem identificação; a praça ganha marcação de vagas. O passeio oferece instruções de curva e mantém estacionamento real, pausa, reset e cancelamento. Não houve expansão do mapa. |

## Validação

As 40 etapas de validação Godot do código-fonte passaram, com 884 verificações, além de 15 testes Python. A execução foi retomada por suite após corrigir as falhas intermediárias. Os testes novos cobrem publicação interrompida/dependência ausente, nomes únicos para materiais no mesmo setor, troca de colisões entre distritos e reset, piso distante, progresso de carregamento, erros e solicitações duplicadas. Os testes existentes conferem materiais, controles, apoio, condução, streaming, relevo e montagem offline. [Logs de validação](validation/).

A comparação completa das duas gerações identificou somente um nome automático (`@MeshInstance3D@...`), causado por superfícies de materiais diferentes com o mesmo nome. O gerador agora acrescenta o material quando há colisão de nomes. A produção foi regenerada; para reaproveitar o artefato anterior, o [ensaio de comparação](validation/regeneration_replay.gd) normaliza exclusivamente esse nome antes de comparar todos os campos geométricos. A suite da cidade passou em 43 verificações, incluindo seis percursos de ida/volta e os acessos à praça/oficina.

O ensaio exportado de menu/condução passou em 17 verificações sem avisos de vazamento. O shader compartilhado do corredor também é pré-carregado na thread principal; luzes ainda não anexadas ao mundo são liberadas ao fechar a cena imediatamente. O teste headless aguarda tempo real para o áudio terminar, pois `--fixed-fps` acelera os timers simulados. Linux abriu/encerrou normalmente; os dois pacotes incluem somente a geração publicada `1791684494-830368047`, excluindo a geração anterior preservada e os diretórios legados. Windows nativo permanece sem execução.

A ativação de células carregadas em background agora aguarda um frame após o resultado ficar pronto. Isso eliminou o erro de recurso-base não reconhecido que surgiu no ensaio exportado de acessos. O teste de streaming verifica esse intervalo; os runners reprovam erros inesperados do motor, além das assertions, mantendo a exceção específica do teste de arquivo ausente. A mensagem do motor corresponde ao caso de tipo-base não reconhecido no [código de RendererSceneCull](https://github.com/godotengine/godot/blob/master/servers/rendering/renderer_scene_cull.cpp); a necessidade do intervalo foi estabelecida pelo ensaio local de 100 verificações antes/depois, não por uma garantia geral da API.

Os builds Linux e Windows estão atualizados após essa correção. A validação exportada passou em 418 verificações de acesso, além das 17 de menu/condução, sem erros inesperados do motor. Ambos os PCKs têm SHA-256 `bf2cb8c3e6a0a0cc0bf1bfdcc4410d49da8e81883795be6891efdf536bfaa8a7`. O diagnóstico gráfico foi concluído em 11 de outubro; suas limitações permanecem abaixo. As contagens de suites e suas execuções finais constam no [manifesto](validation/manifest.json).

## Diagnóstico e revisão visual

Quatro passagens de 14 trechos terminaram com apoio no piso acima de 99%, nos pacotes anterior e atual. A execução atual registrou **17,41 FPS na Intel** e **66,75 FPS na Radeon**, com pior P99 por trecho de **141,40 ms / 54,77 ms**, respectivamente. O gate completo de estabilidade não passou. A passagem anterior registrou 18,48 / 39,76 FPS; a concorrência, a diferença de foco e o intervalo de várias horas na comparação Intel impedem atribuir o resultado somente às correções. Pico de RSS próximo de 1,5 GB nas quatro passagens, sem redução material observada. [Relatório, métricas e dados brutos](diagnostic/README.md).

A [galeria antes/depois](visual/index.html) reúne cinco posições por preset: saída, praça, oficina, noite e mapa. As vagas e a identificação da oficina aparecem na câmera real; a variação de fachadas continua sutil, sem alterar o mapa. A cena noturna no modo Econômico permanece escura e requer avaliação humana de condução. A fixture congela a atividade para a captura e atualiza explicitamente o progresso/readout, evitando exibir a distância inicial ainda não calculada.

Os ensaios renderizados registram dois avisos GLES3 de textura ao encerrar, de 21.844 bytes cada, também presentes no pacote anterior. Seis ensaios mínimos (viewport sem cenário, quatro modos de processamento do céu e shader real do céu) não reproduziram os avisos. A causa na cena completa **não foi isolada**; isso permanece registrado, sem atribuição conclusiva ao motor nem alegação de resolução. [Fixture e logs isolados](validation/sky-exit/).

As correções funcionais e os builds desta revisão estão concluídos. A estabilidade de renderização, os avisos de textura na saída, streaming real de recursos, alvo de 8 GB e Windows nativo permanecem pendentes; o diagnóstico realizado não fecha esses critérios de produto.

## Limites

A arquitetura da cidade permanece totalmente residente em memória. A decisão sobre streaming de recursos deve usar RSS, memória estática, custo de carregamento e a cauda de frame times. Ativar apenas física próxima reduz trabalho e residência no espaço físico; não libera malhas/texturas nem certifica 8 GB.

A comparação renderizada usa a fixture `pilot-three-districts-v3`, 14 trechos a 50 km/h, relógio às 16h30, aquecimento de dez segundos, Intel/Econômico em 854×480 e Radeon/Equilibrado em 1280×720. Os processos concorrentes, foco, energia e sensores indisponíveis permanecem registrados. Não se atribuem mudanças de FPS exclusivamente ao projeto em uma máquina compartilhada.
