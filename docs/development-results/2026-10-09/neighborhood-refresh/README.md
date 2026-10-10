# Bairro e veículo — validação de 2026-10-09

A entrega preenche as frentes externas dos seis quarteirões, alarga as ruas e revisa o Hatch 1000, céu, superfícies e entorno. [Comparações e decisões de arte](../../../art-results/2026-10-09/neighborhood-refresh/README.md) e [comparação interativa](../../../art-results/2026-10-09/neighborhood-refresh/compare.html).

## Projeto

O [runner completo](source-checks.log) registra **710 verificações funcionais, zero falhas**, além de **10 testes Python** (seis de pacing e quatro de intercity). O log termina com `All Wave checks passed`. Inclui direção, terreno, navegação, calçadas, aceleração/aderência, alta velocidade, luzes do carro, menus, cidade piloto, rally, circuito, streaming, HLOD, viagens, paradas, elevação e montagem offline.

A cidade passa **34 checks**; seus seis percursos fechados chegam ao destino, com apoio em 100% das amostras e permanência no pavimento entre 99,35% e 100%. Praça/oficina são acessíveis nos dois sentidos. As **56 verificações de calçadas** usam agora a largura real de cada rua para testar frente, ré/diagonal, relevo e retenção de velocidade. A fixture nova de luzes verifica acionamento dos pedais, ré, reset, normais do modelo e independência de material entre carros: **7 checks**.

Os [dados das rotas](source-pilot-city-results.json) e [travessias das guias](source-pilot-curb-results.json) ficam preservados. A última correção visual remove as calçadas sobrepostas ao asfalto nos cruzamentos e recorta a pintura pelos planos pavimentados. As colisões finais conservam as mesmas faixas verificadas pelo runner. A [regeneração final](geometry.log) passa mais **3 checks**, incluindo igualdade das malhas, transforms, UVs e colisões salvos com o resultado do gerador.

A primeira iteração está em [first-iteration-pilot-city.log](first-iteration-pilot-city.log): 32 checks e três falhas, antes das correções. Nomes automáticos das rodas estacionadas impediam comparação determinística; calçadas sobrepostas perto dos cruzamentos também alteravam a classificação do pavimento. Rodas recebem nomes fixos e as sobreposições foram removidas. O [retorno pela encosta](hill-return.log) foi conferido separadamente antes do runner completo, com 24 checks sem falha. Esses ensaios intermediários não entram no total final.

## Pacote exportado

O [runner de acessos do PCK final](exported-access.log) passa **263 checks**: guarda de pacote 1, rally 40, transições de chão 100, cidade anterior 15, paradas 19, cidade piloto 32 e calçadas 56. As fixtures ficam fora do projeto e usam somente os recursos do pacote exportado. O runner final termina com status 0.

Mais **7 checks de óticas/reset/normais** passam no [carro do PCK](exported-car-visual.log), e **17 checks** passam no [menu com renderização real](exported-menu-rendered.log), incluindo Enter para abrir o bairro, condução, retorno ao menu, streaming e carregamento da célula remota. Total do pacote final: **287 checks sem falha**. [Dados da cidade](exported-pilot-city-results.json) e [guias](exported-pilot-curb-results.json).

O primeiro pacote, anterior ao último acabamento do pavimento, também passou seus 263 checks; [log](first-package-access.log) e [hashes](first-package-hashes.json) ficam como ensaio intermediário. Ele não substitui os testes do pacote final acima.

Os [hashes finais](artifact-hashes.json) registram executáveis, PCKs e launchers. Os pacotes Linux/Windows são idênticos. Os [exports](exports.log) produziram `builds/linux/Wave.x86_64` e `builds/windows/Wave.exe`; distribuir a pasta de cada plataforma com seu PCK. Não houve execução nativa no Windows.

O [executável Linux](native-linux-startup.log) inicia em headless e termina normalmente. Para as fixtures externas, foi usado o binário completo do Godot 4.7.2 com `--main-pack` e diretório isolado. O template release rejeita `--path`; as duas tentativas iniciais ficaram em `native-override-*-attempt.log`, não são falhas do jogo. A fixture de [menu com captura](exported-menu-capture-fixture.gd) adiciona apenas preset Equilibrado e uma imagem após a condução da cidade, em preferências temporárias. A [imagem do PCK](../../../art-results/2026-10-09/neighborhood-refresh/package-driving.png) mostra a câmera/HUD reais após comandos de aceleração.

## Condições e limites

Godot 4.7.2, Compatibility. Capturas de inspeção renderizadas na Radeon R7 M260, Equilibrado 1280×720 e Econômico 854×480, com preferências isoladas e restauradas pelo gerador. As vistas de inspeção desligam neblina/culling; somente a vista de condução mantém as condições de jogo. Não são benchmarks. A quantidade de geometria/objetos cresceu; a janela combinada de medição, 30 FPS sustentados/8 GB e a avaliação jogada continuam pendentes.

As fixtures de streaming incluem erros/avisos deliberados para exercitar falhas de carregamento e validação de suporte; os checks passam. O aviso de seis objetos ObjectDB no encerramento das fixtures de cidade/calçada já aparecia nas revisões anteriores. Nenhuma alegação de ausência de leaks é feita. O console da ferramenta registrou término 143 para wrappers de duas execuções longas depois de seus logs já conterem todos os checks e o marcador final de sucesso; os resultados e os registros foram preservados, junto aos status das execuções curtas.

O céu é um asset LDR original gerado com imagegen integrado. [Arquivo, prompt e origem](../../../../assets/textures/neighborhood/afternoon-sky-v1.provenance.json). Não há comparação jogada ou equivalência técnica certificada com Most Wanted 2012.

[Resumo estruturado dos resultados](validation-summary.json).
