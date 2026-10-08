# Auditoria e conexão entre regiões — 2026-10-07

## Verificações

- `checks-before.log`: primeira execução interrompida no circuito; parcial, não aprovada.
- `checks-baseline.log`: runner existente completo, **322 verificações + seis testes Python**, zero falhas. Novos arquivos/acesso opcional foram acrescentados durante essa execução; não é baseline com árvore imutável.
- `intercity-initial.log`: erro de inferência do tipo de resultado de raycast na fixture; corrigido com `Dictionary` explícito.
- `intercity-fixed.log`: prova headless, **14 verificações**, zero falhas. Conferência final ampliada inclui menu/retorno no `checks-final.log`.
- `checks-final.log`: runner consolidado, **338 verificações + seis testes Python**, zero falhas; três mapas anteriores regenerados equivalentes. Erros auxiliares de socket do editor headless no sandbox não reprovaram importação ou suites e permanecem no log.
- `build.log`: geração offline bem-sucedida, sem alterar células/maps antigos.

`preexisting.patch` preserva mudanças rastreadas anteriores; o plano antigo completo fica em `docs/plans/2026-10-06-plan.md`. `source-context.json` registra commit-base, plataforma/RAM e hashes dos recursos/código (inclui arquivos novos, não representa árvore commitada). `measured-intercity-smoke.gd.txt` preserva a fixture medida; a versão final acrescenta checks de acesso/retorno pelo menu, sem alterar estrada, loader ou direção. Nenhum commit foi criado.

## Primeira medição renderizada da viagem

Inspiron 5547, i7-4510U, **16 GB instalados**, Linux/Mesa 25.0.7, Godot 4.7.2/Compatibility/OpenGL. Intel HD 4400: Econômico/**854×480**; Radeon R7 M260: Equilibrado/**1280×720**, sombras/MSAA 2×. Log e JSON confirmam GPU e resolução. O campo `viewport_size` registra retângulo lógico da UI sob stretch; `window_size` é o tamanho nativo conferido. Não são ensaios equivalentes entre GPUs/presets nem comparação de otimização com a avenida antiga.

Uma sessão por GPU, **uma ida e uma volta**, 10 s de aquecimento, preferências/caches XDG novos, VSync desligado explicitamente, sem limite FPS ou queries do viewport. Sem teste/export/segunda Godot concorrente. Sem série térmica/controle de carga externa; não atribuir causalidade dos picos. `DRI_PRIME=0` produziu aviso de valor inválido, mas o log confirmou Intel. Radeon confirmada por `DRI_PRIME=1`. Os dois ensaios mantiveram foco em todos os intervalos. Todos os quadros estão preservados.

| GPU / perna | FPS médio | 1% low aprox. | P95 ms | P99 ms | Pior ms | >33,33 / >50 ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| intel / ida | 49.64 | 26.21 | 26.377 | 30.797 | 74.552 | 13 / 2 |
| intel / volta | 49.61 | 21.91 | 26.325 | 29.293 | 286.404 | 9 / 4 |
| amd / ida | 66.05 | 52.33 | 16.556 | 17.586 | 28.440 | 0 / 0 |
| amd / volta | 67.16 | 50.51 | 16.149 | 16.973 | 58.712 | 1 / 1 |

Cada perna dura cerca de 48,7–48,9 s, com alvo de 108 km/h e aproximadamente 1,38 km. Ambas as sessões passaram **11 checks renderizados**, mantendo apoio, zero falhas do loader e zero novos bloqueios de segurança nas pernas dirigidas. Pico de três células residentes entre quatro regiões; identidade do carro/câmera/HUD mantida. Desvio lateral máximo em torno de 1,42 m; fixture segue mesma faixa geométrica na volta, sem tráfego. Virada por heading reset/teleporte nos extremos, não manobra humana.

**Econômico não aprovou estabilidade:** 1% low abaixo de 30 nas duas pernas e pico de 286,4 ms na volta. Equilibrado mostra margem e ida sem hitches nesta sessão, mas a volta teve um quadro >50 ms; não substitui três passagens e sessão longa. **Nenhum perfil foi certificado.** Windows nativo, 8 GB efetivos, hardware moderno, gamepad físico, diversão e avaliação de áudio permanecem pendentes. Não existe A/B de gargalo nesta etapa, portanto nenhum ganho de FPS é reivindicado.

O JSON `intercity.json` inclui eventos de sondagens/teleportes fora das séries: não confundir esses holds explícitos com bloqueio durante viagem. Capturas acabam antes das sondagens, retomam apenas para a perna de retorno e terminam antes das screenshots. CSV amostrado, CSV por quadro e JSON ficam em `intel/` e `amd/`; contagem, duração, pior quadro, média, 1% low, P99 e hitches foram recalculados dos CSV e conferidos contra os JSON em `capture-audit.json`. `intel/region-*.png` são prévias posteriores às capturas.

## Avaliação das prévias

Inspecionadas rural e núcleo do interior em Econômico/480p: estrada curvada legível, massas de horizonte laterais, carro integrado pelo contato barato. Pasto e cercas são repetitivos, casas ainda isoladas no gramado, fachadas reutilizadas e cidade interior sem calçadas/autoria suficiente. Essas limitações estão abertas; não equivale à meta artística MW2005. Nenhum efeito caro ou asset externo foi acrescentado.

## Reprodução

```sh
GODOT_BIN=~/Downloads/Apps/Godot_v4.7.2-stable_linux.x86_64 bash scripts/tools/check_project.sh
XDG_DATA_HOME=/tmp/wave-sol-serra-test godot --headless --path . --fixed-fps 60 --script res://tests/intercity_smoke.gd
DRI_PRIME=0 XDG_DATA_HOME=/tmp/wave-sol-serra-intel-new XDG_CACHE_HOME=/tmp/wave-sol-serra-intel-cache-new godot --path . --rendering-method gl_compatibility --script res://tests/intercity_smoke.gd -- --foreground --no-vsync --previews
DRI_PRIME=1 XDG_DATA_HOME=/tmp/wave-sol-serra-amd-new XDG_CACHE_HOME=/tmp/wave-sol-serra-amd-cache-new godot --path . --rendering-method gl_compatibility --script res://tests/intercity_smoke.gd -- --balanced --foreground --no-vsync
```

Executar uma janela por vez; não rodar testes/export durante captura. Metas futuras no plano W0–W6. Próximas prioridades: isolar hitches de gravação/fronteira/apresentação/térmica; repetir perfis; testar prazer de direção; dar autoria às transições/núcleo; depois apoio irregular e integração do Bairro do Sol.

## Builds e pacote

Linux e Windows reexportados com templates 4.7.2; artefatos/hashes em `builds.json`. `export.log` produziu os pacotes, mas teve erros de gravação auxiliar do editor no sandbox. Repetição `export-isolated.log`, com XDG_CONFIG/CACHE temporários, concluiu sem esses erros. `exported-pack.log`: **13 checks, zero falhas**, usando o PCK Linux com harness Godot fora da raiz do projeto: acesso antigo preservado, menu da viagem, manifesto e apoio real no destino remoto com seus recursos compartilhados. Não é benchmark release nem execução Windows nativa.
