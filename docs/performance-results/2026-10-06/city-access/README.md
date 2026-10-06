# Acesso ao trecho em construção — 2026-10-06

Os builds locais ainda eram de 2026-10-05, anteriores ao corredor. O menu do código fonte também apresentava streaming como “Avenida do Vale · células”, depois do bairro antigo. Agora **Passear na cidade em construção** é a primeira opção e recebe foco inicial; Enter/gamepad abre o corredor com células. A legenda explicita o limite atual: Avenida do Vale, 600 m e ruas laterais. O bairro antigo e a referência estática continuam no menu.

Os presets de exportação incluem explicitamente `scenes/world/cells/*/manifest.json`, pois o streamer lê esses dados via FileAccess. Linux e Windows foram reexportados; hashes dos executáveis/pacotes e fontes em [source-and-builds.json](source-and-builds.json). Os PCKs têm o mesmo hash. Esta entrega não altera layout, física, materiais ou distâncias de streaming.

Validação: **318 checks antes → 319 depois**, sem falhas. Teste de menu verifica foco, ordem e visibilidade da opção de passeio; o teste de streaming agora entra por evento real de Enter em vez de emitir diretamente o sinal do botão. Logs completos preservados. Restrições de socket/salvamento de configurações do editor no sandbox aparecem nos logs de importação/exportação; exportação das duas plataformas terminou com sucesso.

**Executável release Linux real**, lançado em Compatibility na Radeon com preferências/cache isolados: captura do [menu](release-menu.png), Enter abriu a [cidade](release-city.png), W produziu [condução a 94 km/h](release-drive.png). A automação X11 enviou apenas essas teclas à janela criada pelo próprio teste e encerrou o processo ao concluir. Script da automação arquivado; não é benchmark, nem certificação de gamepad ou Windows nativo.

Além disso, a engine Godot do editor carregou diretamente o PCK exportado em um diretório externo ao repositório, executando `tests/exported_menu_smoke.gd`: **9 checks passaram** para settings binários exportados, manifesto empacotado, menu, foco/visibilidade, Enter, células, condução e retorno. [Log final](exported-pack.log). Uma primeira versão do harness teve duas asserções incorretas (argumentos de engine consumidos e tamanho da janela headless); corrigidas para verificar settings binários/ausência de project.godot e retângulo do viewport. O log inicial está preservado e não representa defeito do pacote.

Fechar qualquer instância antiga e abrir `builds/linux/Wave.x86_64` ou `builds/windows/Wave.exe`. Distribuir a pasta completa da plataforma com o PCK atualizado. O trecho está disponível para passeio; ainda não é uma cidade completa.
