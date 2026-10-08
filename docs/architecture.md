> Atualização de 2026-10-07: plano W0–W6 e Econômico/480p obrigatório substituem as prioridades históricas M0–M9/Legacy abaixo. A prova Caminho da Serra reutiliza streamer/HLOD/kit; quatro regiões, até três células residentes, sem novo autoload. Detalhes em [auditoria atual](reorientation-2026-10-07.md).

# Arquitetura e revisão — 2026-10-05

## Decisão

Evoluir o protótipo existente, sem reiniciar. Engine: Godot 4.7.2, GDScript tipado; Compatibility é a base visual. O novo norte é arcade brasileiro com qualidade percebida de racers de 2005–2010. O modelo por eixo do rally continua um experimento isolado e testado. O [plano vigente](../development-plan.md) substitui o roadmap de simulação/Forward+.

## Diagnóstico do código real

| Sistema | Evidência e decisão | Próxima mudança necessária |
| --- | --- | --- |
| Carro | `player_car.gd`: CharacterBody3D, aderência, ré, degraus, quatro raios por tick, subpassos; suites driving/terrain/handling/high_speed | Preservar. Ajustar sensação somente após jogar; não migrar para corpo rígido |
| Pneus do rally | `vehicle/tire_dynamics.gd`, ativado só em `drive_rally.tscn`; suíte rally compara integração/forças | Preservar isolado; não tornar pré-requisito do mundo |
| Câmera | SpringArm, exclusão do carro, FOV, capô e reset; testes reais de colisão | Preservar; avaliar gamepad e velocidade em execução |
| Bairro offline | `NeighborhoodBuilder` combina props/materiais/lotes, `build_neighborhood.gd` salva/recarrega/valida | Preservar mecanismo, substituir a grade repetitiva por layouts com autoria na produção do slice |
| Persistência visual | `BakedMultiMesh` salva transforms e AABB, incluindo margem de billboard; testes roundtrip | Preservar; obrigatório em futuras células geradas headless |
| Setores | Bairro: lotes por 84 m e limites de visibilidade; rally: terreno 64 m, grama 48 m, estrada em chunks | Culling reduz desenho, mas não libera recursos ou colisões. Introduzir células de arquivo próprias |
| Colisões | Bairro/circuito concentram formas em um corpo global; rally tem corpos por tile/chunk | Particionar por célula no pipeline novo; não refazer física agora |
| Geradores acoplados | Circuito/rally agora usam `OfflineSceneBuilder`, independente do layout do bairro | Extração entregue; preservar comparação de artefatos antes de evoluir o kit |
| Materiais | Bairro usa cores de primitivas; circuito/rally já têm texturas, normals, mipmaps/compressão | Reaproveitar pipeline. UVs/atlases no kit novo, triplanar apenas com retorno visual medido |
| Vegetação | Rally tem mais de 2.000 árvores, representação próxima/distante pareada, bounds testados | Aproveitar técnicas; densidade/copa/flora regional precisam de outro orçamento para o slice |
| Cronometragem | Circuito com grade espacial, gates direcionais; rally com portas e verificação de teleporte | Preservar para provas futuras, sem escrever framework de corrida agora |
| Áudio/configurações | Buses, loops offline, persistência, foco/pausa/transições, suites audio/menu | Preservar; som atual é provisório e não cobre pneus/impacto |
| Benchmark | Captura monotônica e rotas com controle real, dados históricos de HD 4400 e R7 M260 | Expandido nesta revisão; falta ainda atribuição de gameplay e streaming |
| Mundo | `DrivingWorld` cria áudio/captura; mapas são substituídos via troca de cena | Novo mundo contínuo mantém player/câmera/sessão e substitui só células; transições antigas ficam nos laboratórios |

**Superdimensionado para a nova meta:** floresta densa como padrão artístico, prioridade de 900p/Forward+, SSIL/volumetria e backlog de pneus/suspensão de simulador. Não apagamos assets/testes; retiramos essa direção do caminho crítico. A evidência histórica mostra o perfil máximo do rally perto de 10 FPS na R7 M260. Otimizações úteis (UV único, recorte alfa, LOD, raios reutilizados e relógio real) permanecem.

**Limitações reais para escalar:** carregamento monolítico, colisores globais, ausência de manifesto de células/rotas de tráfego e HLOD urbano. Não é necessário renomear arquivos e quebrar todos os NodePaths para resolver esses limites.

## Fronteiras e organização

```text
scenes/city, race, rally, terrain  laboratórios estáticos existentes
scenes/corridor, scripts/corridor  trecho visual autoral gerado offline
scripts/player_car.gd             condução/contato; API preservada
scripts/vehicle                   modelo experimental de pneus
scripts/city                      OfflineSceneBuilder, layout do bairro e validação
scripts/tools                     geração, exportação, captura e estatísticas
scripts/audio, ui                 sessão de áudio e opções/menu
scripts/world                     manifesto, partição offline e streamer da prova
scenes/world/cells                 três células do corredor sem player/HUD/sol próprios
```

Não introduzir autoload para cada sistema. `WaveSettings` continua responsável por preferências/buses. `DrivingWorld` continua compatível com os testes existentes. `WorldStreamer` na prova é filho do mundo persistente, recebe alvo/manifesto e é dono dos nós/recursos que descarrega. Decisões de streaming em [world-streaming.md](world-streaming.md).

O compilador offline de células recebe layout/seed/overrides, usa biblioteca compartilhada de props/materiais e emite cena + manifesto + relatório. Valida bounds, colisões, IDs, vizinhança, corredores e determinismo. Hero areas são entradas autorais desse pipeline. Não executar `NeighborhoodBuilder` durante o jogo.

## Primeira implementação: baseline gráfico mensurável

`WaveSettings.GRAPHICS_PRESETS` centraliza Legacy/Medium/High e o fallback econômico; aplicar preset encerra a captura anterior, aplica todos os valores de uma vez e preserva VSync. Presets não alteram backend. O padrão sem preferências é Legacy 720p em todas as GPUs; preferências anteriores mantêm seus valores. Campo novo `post_effects` tem default seguro desligado. SSAO/glow do rally deixam de ser consequência de ligar sombras. SSIL/volumetria continuam cosméticos explicitamente escolhidos, condicionados a Forward+. O launcher de qualidade também volta a Compatibility.

A interface mantém navegação por foco e usa rolagem para opções caberem em 480p/720p. `get_graphics_preset()` identifica o perfil pelas opções; escolhas diferentes ficam `custom`. Tela cheia tem tamanho real registrado, sem pressupor que seja 720p.

`PerformanceCapture` mantém F4/pausa/encerramento e arquivos antigos intactos. Schema 2 acrescenta snapshot de configuração, CPU/driver, identidade de rota, P99, 1% low, mínimos, contagens de quadros lentos, monitores amostrados e CSV cronológico por quadro. `FrameStatistics` calcula percentis sem ordenar/destruir a série original. Valores indisponíveis de memória/render time são null. Timestamp queries de viewport são opt-in para diagnóstico separado, após a execução na HD 4400 revelar stalls de ~1 s e tempo GPU inválido; captura normal não ativa essa instrumentação. Testes exercitam cauda lenta, serialização e preferências legadas.

## Segunda implementação: montagem offline compartilhada

`offline_scene_builder.gd` recebe `begin(nome, colisores)` e publica `add_box`, `add_instance`, `add_part`, `add_tree`, `add_collision`, `add_label` e `finish()`. Os registries tipados `materials`/`meshes` aceitam o kit existente; batch size, overrides por material e centralização vertical continuam configuráveis. Mantém a implementação de BakedMultiMesh, posições, paleta, formas compartilhadas e limites de visibilidade. `finish()` esvazia a fila de lotes e atribui owners, permitindo finalização repetida sem duplicação; cada `begin` inicia registries/colisores próprios. O chamador continua dono de liberar a raiz anterior.

O bairro estende a montagem e mantém seu layout. Circuito/rally usam a montagem diretamente: não acessam mais campos/métodos privados do gerador de bairro. A biblioteca não produz um bairro implicitamente nem é executada em runtime. Os geradores aceitam `--output=user://arquivo.tscn` para validação isolada, mantendo seus destinos normais quando omitido. O runner regenera os três mapas em dados temporários e compara cenas atuais/geradas (hierarquia, transforms, malhas, colisões, materiais básicos e visibilidade), além de testar isolamento entre duas células e finalização idempotente. Ainda não é streaming nem manifesto de células. Não foi alterado nenhum mapa de produção.

## Preservação de contratos

Input registrado antes dos filhos; carro roda na física, câmera depois dele e SpringArm depois da câmera. Reset limpa momento e sinaliza câmera/áudio. Pausa suspende física/cronometragem/coleta; HUD e opções continuam recebendo input. Troca de mapa desfaz pausa e libera áudio/captura do anterior. Não modificar esses contratos sem teste de integração.

O apoio é cinemático: carro/colisor acompanham piso, rodas e balanço são visuais. Não é suspensão física completa. Os testes de direção percorrem cenas reais por inputs; as rotas não substituem avaliação humana de prazer, mixagem e arte.

## Agora e depois

Agora: revisar arte/HLOD e calibrar custo no corredor de 720p. Durante M1: iterar a prova de três células já entregue, medindo cada gargalo que aparecer. Depois: integrar kit/streaming, expandir uma cidade, rodovia e segunda cidade. Tráfego/progressão entram sobre limites medidos. Mapa gigante, simulação avançada, polícia e multiplayer não justificam refactor antecipado.

## Corredor de referência: Avenida do Vale

`CorridorBuilder` estende a montagem offline, mas possui layout próprio: 600 m de avenida de 12 m, laterais em −160/−360 m e duas hero areas. Seed 5547 varia decoração/medidas, não a conectividade da via. `build_corridor.gd` salva a cena; nenhuma geração roda durante a condução. O runner compara a cena salva com duas gerações independentes e dirige avenida, lateral, acesso da oficina, reset e retorno ao menu.

Materiais compartilham texturas do circuito e dois PNGs originais fixos: atlas de quatro fachadas e árvore recortada. UVs métricos no chão; poucos materiais com atlas, sem normals/triplanar/GI moderna no kit novo. Lotes por 84 m mantêm bounds serializados; cards têm margem de rotação. Fachadas/corpos/placas têm distâncias de cull próprias. É descarte de detalhe, ainda não troca LOD/HLOD nem descarregamento de arquivos.

O Legacy usa manchas opacas de oclusão em vertex colors sob as massas e uma pequena sombra radial transparente sob o carro. `CorridorWorld` atualiza essa sombra depois da física/câmera (prioridade 11). É cosmética e assume piso plano, limitada a esta cena; não altera suspensão/consultas do carro. Medium pode acrescentar sombras dinâmicas do preset existente.

Placas estáticas são PNGs opacos gerados por `build_corridor_signs.py` com fonte bitmap própria, compartilhando o caminho de materiais das fachadas. A primeira versão com `Label3D` apresentou um hitch reproduzível ao entrar em alcance; dados rejeitados e substituição estão preservados em performance-results. Não remover `Label3D` dos mapas antigos por extrapolação desse diagnóstico.

A versão estática do corredor usa corpo de colisão global e cena monolítica como referência preservada. A variante descrita abaixo divide esse conteúdo em três células sem duplicar carro, áudio, sol ou HUD. O menu dá acesso direto e usa rolagem para preservar navegação nas resoluções menores.

## Prova seguinte: residência de três células

`drive_streamed_corridor.tscn` mantém o mundo/carro/câmera/HUD e substitui só o mapa por horizonte persistente + `WorldStreamer`. A variante estática permanece no menu para comparar composição/custo. A partição offline preserva props/colisores e recorta superfícies nas duas fronteiras; materiais/primitivas são recursos externos comuns. Testes comparam a geometria gerada às cenas salvas e ao mapa original.

Estados e política ficam em [world-streaming.md](world-streaming.md). A prova não muda o controlador do carro: usa gate externo de apoio, prioridade de física anterior à condução e API explícita de teleporte no mundo. Erro ou atraso segura movimento e registra o problema; uma viagem que dependa desse fallback não passa o gate normal. Telemetria separa espera de recurso, instanciação, anexação e CPU de liberação, com eventos alinháveis aos intervalos reais de quadro.

Este é o primeiro contrato operacional de células, não uma conversão dos mapas antigos nem aprovação de streaming para duas cidades. A hipótese de piso plano e limite de três células permanecem explícitos. A variante acrescenta `WorldHLOD`: proxies offline por célula, sempre residentes nesta prova, e troca visual com histerese; não é HLOD com residência para duas cidades. O detalhe pode ficar invisível conservando colisões residentes. Contrato, testes e limites em [world-streaming.md](world-streaming.md).
