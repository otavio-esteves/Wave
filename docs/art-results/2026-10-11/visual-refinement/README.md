# Gol e cidade: revisão de acabamento — 2026-10-11

Direção solicitada: refinar o veículo e o mundo existente, estabelecer o visual e depois otimizar. O terreno, os 200 quarteirões, a condução e os destinos permanecem na cidade atual. [Comparação interativa](index.html).

## Veículo

A malha do capô atravessava a cabine. A revisão remove esse piso pintado indevido e preserva uma cabine aberta, com bancos arredondados, costuras, forro, instrumentos, ventilação, rádio e porta-luvas. Pintura, borracha, plástico e tecido recebem texturas originais geradas offline em espaço local; o detalhe acompanha o carro. Vidro mais claro, molduras, calhas do teto, friso, maçanetas, marcadores laterais, limpadores e desembaçador acrescentam profundidade. As rodas conservam o desenho de aço, agora com válvula, contrapeso, inscrições e detalhes nos ombros dos pneus. Os limites físicos e a resposta do controlador foram preservados.

As lentes dos faróis recebem nervuras cruzadas e bulbos, com emissão mais discreta; os feixes continuam funcionais. Freio, ré e alternância dos faróis mantêm materiais independentes por veículo. O modelo salva 21.474 triângulos de carroceria/cabine e 6.172 por roda, 46.162 no carro completo.

Equilibrado/Qualidade usam uma captura local de reflexos que exclui o próprio veículo e afeta apenas sua camada visual. Ela acompanha mudanças de rua, reset e horário; Econômico desliga a captura. O modo de atualização e as máscaras seguem a [API de ReflectionProbe da Godot](https://docs.godotengine.org/en/stable/classes/class_reflectionprobe.html). A captura não substitui streaming de recursos.

A comparação com as sombras desabilitadas isolou as listras do capô como auto-sombreamento. Quatro divisões de sombra, bias de 0,12 e normal bias de 3,0 removeram o artefato na vista revisada, preservando a sombra no piso. Essas imagens de diagnóstico não integram a comparação final do produto.

## Cidade

As frentes existentes recebem mais tentativas de implantação de casas, preservando a busca por lotes afastados das ruas e sem sobreposição. O inventário passa de 2.023 para 2.377 imóveis, de 813 para 974 veículos estacionados e de 3.790 para 4.105 árvores. O aumento ocupa a mesma área. Casas menores ganham persianas, floreiras, calhas, chaminés, detalhes de porta, caixas de correio/serviço e arremates de muros. Janelas usam um plano com UV completo para sugerir cortinas e interior; algumas janelas residenciais acendem à noite. Vitrines comerciais usam um interior de exposição próprio, sem cortinas.

Calçadas passam a usar placas de concreto com juntas chanfradas, agregado e variações sutis. Pátios usam blocos intertravados; telhados e fachadas do centro recebem materiais próprios. Guias, piso tátil, tampas de inspeção e drenagem dão escala ao pavimento. Os detalhes visuais acompanham o suporte existente, sem introduzir degraus físicos novos.

Os bancos usam nove ripas, estrutura metálica, braços e fixação no piso. Lixeiras têm ripas e abertura visível. As 18 praças passam de dois para quatro bancos cada, somados aos 427 conjuntos de mobiliário nas ruas; pontos de ônibus ganham identificação e painel de horários. Mesas, cadeiras e toldos enriquecem as frentes comerciais. Copas mais cheias, tons menos escuros e folhagem nos arbustos acompanham o acabamento. O céu recebe paleta menos saturada e uma segunda escala de detalhe nas nuvens.

## Evidência e reprodução

As comparações principais usam Radeon R7 M260, Compatibility, Equilibrado, 1280 × 720, às 16h30. Meio-dia e noite usam o mesmo relógio, congelado para a captura. Névoa e faixas de visibilidade permanecem nas condições jogáveis. A câmera continua vendo a camada visual do carro. Os enquadramentos do carro repetem o mesmo deslocamento relativo; a acomodação física inicial gera uma variação de até um centímetro nas posições da câmera, registrada nos arquivos de contexto. A terceira residência é um exemplo atual; as duas primeiras mantêm exatamente o enquadramento do registro anterior.

```sh
godot --headless --path . --script res://scripts/tools/build_neighborhood_materials.gd
godot --headless --path . --script res://scripts/tools/build_hatch_car.gd
godot --headless --path . --script res://scripts/tools/build_pilot_city.gd
godot --path . --script res://scripts/tools/build_refinement_previews.gd -- --output=/tmp/wave-visual-review
```

O gerador salva os recursos offline numa geração nova. As imagens e os resultados finais da validação são registrados junto desta revisão. A otimização gráfica e a avaliação humana da condução/arte são as próximas frentes; capturas estáticas e testes funcionais não aprovam desempenho ou realismo final.

## Validação desta revisão

O projeto passou 880 verificações Godot nas 39 suítes, nas verificações de persistência e na montagem offline, além de 19 testes Python. A versão final do volume de reflexos passou mais 12 verificações específicas. A cidade foi regenerada em armazenamento isolado e comparada integralmente: terreno, ruas, UVs, instâncias e colisões coincidem com a geração de produção.

O encadeador inicial foi interrompido enquanto a suíte da cidade continuava rodando. Os 43 checks dessa suíte concluíram sem falhas; a sequência foi retomada com `check_project.sh --from=pilot_optimization`. Os logs preservam as três partes, sem apresentar a execução como uma única sequência ininterrupta. Os dois erros de recurso ausente na suíte de streaming são a entrada negativa deliberada já filtrada pelo runner.

Linux e Windows foram reexportados depois da correção final do asfalto. O executável Linux abriu em Compatibility na Radeon R7 M260 e encerrou sem diagnósticos de erro. O fluxo de menu, carregamento, condução e retorno do pacote passou 17 verificações adicionais. [Captura do Gol usando o PCK](validation/exported-preview/car-front.png) e [câmera jogável do PCK](validation/exported-preview/driving.png) foram produzidas com o harness do editor carregando exclusivamente os recursos exportados. A execução nativa de Windows permanece sem avaliação nesta revisão.

As 16 suítes do pacote Linux concluíram 450 verificações, incluindo a guarda que confirma o uso exclusivo dos recursos exportados. Percursos entre bairros, centro e subida, entradas da praça e oficina, travessia de calçadas, iluminação, câmera e reflexos passaram sem falhas. Os PCKs de Linux e Windows são idênticos, com 182.428.124 bytes e SHA-256 `ef37cab14cbb91812129fa06b601cf933b38f1601013024e83e90834610b6ed9`. [Registro completo, inventário e hashes dos executáveis](validation/record.json); os logs ficam na mesma pasta.
