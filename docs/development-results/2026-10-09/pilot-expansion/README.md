# Cidade piloto ampliada — 9 de outubro de 2026

A expansão foi solicitada pelo usuário após confirmar a melhoria perceptível e o funcionamento do DualShock 4. O bairro passa de 6 para 18 quarteirões, com três vezes a área física, calçadas contínuas, grama, relevo mais variado e implantação das casas revisada. O Gol ganha 6 cm de altura na carroceria e faróis funcionais na cena comum de todos os mapas. [Capturas e comparação](../../../art-results/2026-10-09/pilot-expansion/README.md).

## Geometria e conteúdo

| Medida | Resultado |
| --- | --- |
| Terreno físico | 768 × 616 m; 473.088 m²; exatamente 3 × 157.696 m² |
| Rede viária | 28 cruzamentos, 45 trechos, 18 quarteirões conectados |
| Largura das ruas | 11,5–14 m |
| Calçadas | Faixa contínua de 3 m, seguindo o relevo, com transições nos acessos |
| Imóveis | 115; lotes sem sobreposição, incluindo reserva para parques/oficina |
| Árvores / carros estacionados | 402 / 56 |
| Gramíneas | 5.341 tufos, afastados das calçadas e lotes |
| Frentes reservadas como área verde | 2, onde uma construção segura não coube |
| Carro | Carroceria +6 cm; rodas e controle físico preservados |
| Faróis | Dois SpotLight3D, 24 m, sem sombras; ligados por padrão; L / L1 |

Os lotes são ajustados em duas direções e avaliados com margem para muros, varandas e passeios. Fundações consideram amostras sob toda a casa; muros, jardineiras e vegetação seguem o terreno. A nova malha de calçadas une segmentos e cruzamentos por um campo de distância, preservando as transições suaves. Tudo é salvo offline; não há geração pesada durante a partida. [Metadados](city-metadata.json) e [geração final](generation.log).

O primeiro ensaio de implantação recusou lotes sem espaço suficiente ([log](first-layout-generation.log)). A correção refinou as dimensões de reserva, buscou posições laterais e converteu as duas frentes restantes em áreas verdes; construções sobrepostas não são forçadas no mapa.

## Validação

- **739 verificações Godot e 10 testes Python aprovados no projeto**, com retomada após isolar os inputs da fixture da serra. [Log consolidado](source-checks.log).
- **316 verificações aprovadas no pacote exportado**: acesso/guard 266, carro 13, câmera/gamepad 20 e menu 17. [Acessos](package-access.log) · [Luzes](package-car_visual.log) · [Câmera/controle](package-camera_input.log) · [Menu](package-exported_menu.log).
- **Linux nativo iniciou e encerrou com código 0**. [Log](native-linux.log). Captura renderizada do pacote confirmou o mapa ampliado.
- As seis voltas completas usam 100% de pavimento e pelo menos 99,987% de apoio; desvio máximo de 1,68 m. As 18 travessias das calçadas não têm frames no ar nem travamentos; maior mudança de altura entre frames: 2,53 cm. Em 36 km/h, a menor retenção de velocidade foi 99,72%.
- Os resultados das seis voltas foram idênticos no projeto e no pacote neste ensaio Linux. [Projeto](source-pilot-city-results.json) · [Pacote](package-pilot-city-results.json) · [Guias do pacote](package-pilot-curb-results.json) · [Resumo](validation-summary.json).

A primeira execução geral parou em duas verificações de acostamento da serra: o controle conectado interferia com os comandos simulados. [Tentativa original](source-first-attempt.log). A fixture passou a limpar os eventos de teclado/gamepad dos comandos usados pelo piloto automatizado, mantendo os mesmos inputs simulados e limites de trajetória/apoio. O teste repetiu as 26 verificações sem falhas e recuperou os resultados anteriores de 0,39/0,46 m de desvio nos acostamentos. [Repetição isolada](elevation-isolated-input.log). Foram executadas as suítes restantes e a regeneração dos três mapas antigos; [log da retomada](source-remaining-checks.log). A correção está apenas nas fixtures da serra/mirante; não muda os controles do jogo.

Os avisos de células ausentes/inválidas no log geral são falhas deliberadamente injetadas pelos testes de streaming/serra, com rejeição segura verificada. A fixture externa de menu ainda registra seis instâncias ObjectDB no encerramento, aviso já observado na etapa anterior; as 17 verificações funcionais passaram.

Os testes de cidade verificam conectividade, área, regeneração reproduzível, lotes sem sobreposição, apoio de todas as ruas e pistas livres. As três voltas percorrem o contorno, centro e encosta nos dois sentidos por inputs reais. Praça e oficina são acessadas na ida e na volta. As 18 travessias das guias cobrem frente, ré, diagonal e velocidade urbana em quatro trechos de vale/encosta.

As verificações do carro cobrem lentes/feixes ligados por padrão, alternância única ao segurar o comando, isolamento dos materiais, estado preservado no reset e independência das luzes de freio/ré. Câmera, controle analógico, pausa, cancelamento/reset e menu seguem verificados. A aceleração reduzida continua em 0–100 km/h de 8,00 s nos ensaios funcionais.

## Builds e reprodução

Os builds foram exportados para [Linux](../../../../builds/linux/Wave.x86_64) e [Windows](../../../../builds/windows/Wave.exe). Distribuir a pasta inteira de cada plataforma, incluindo o `Wave.pck`. Menu inicial: **Dirigir na cidade piloto**. Os recursos dos dois pacotes têm SHA-256 idêntico: `24c2d35743461a578f1128333faa39eb3014ebec0821a2ec877022dc309588fe`. [Hashes dos quatro arquivos](build-sha256.txt) · [Log de exportação](export.log).

```sh
GODOT_BIN=~/Downloads/Apps/Godot_v4.7.2-stable_linux.x86_64 bash scripts/tools/check_project.sh
GODOT_BIN=~/Downloads/Apps/Godot_v4.7.2-stable_linux.x86_64 bash scripts/tools/check_exported_access.sh
DRI_PRIME=1 XDG_DATA_HOME=/tmp/wave-expanded-review ~/Downloads/Apps/Godot_v4.7.2-stable_linux.x86_64 --path . --script scripts/tools/build_pilot_city_previews.gd -- --medium --output=res://builds/previews/pilot-expanded
```

A captura do pacote usa uma [fixture externa](package-preview-fixture.gd), carregada com `--main-pack` a partir de um diretório temporário, sem acesso aos recursos do projeto pelo `res://`. [Log com 18 quarteirões/115 imóveis/473.088 m²](package-preview.log).

## Limites

Capturas estáticas e testes headless são validação visual/funcional, não benchmark. Não foi feita medição de FPS na máquina compartilhada; desempenho sustentado e requisito de 8 GB continuam pendentes para a janela combinada. Windows nativo não foi executado. O funcionamento físico do DualShock 4 foi confirmado pelo usuário antes desta etapa; os novos ensaios de comandos são automatizados. As capturas escurecidas de faróis são somente inspeção, sem adicionar ciclo dia/noite ao jogo. A próxima etapa gráfica ainda não foi executada.
