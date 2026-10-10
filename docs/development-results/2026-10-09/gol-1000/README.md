# Validação — Gol 1000 quadrado

Revisão visual de 9 de outubro de 2026. [Imagens e referência](../../../art-results/2026-10-09/gol-1000/README.md).

Godot 4.7.2 Compatibility. Capturas renderizadas na Radeon R7 M260, preset Equilibrado 1280 × 720, com dados de usuário isolados. Não foram feitas medições de desempenho.

| Verificação | Resultado |
| --- | --- |
| Normais, luzes de freio/ré e isolamento entre carros (`car_visual.log`) | 7 / 7 |
| Condução, câmeras, pausa e relevo (`driving.log`) | 33 / 33 |
| Aderência, frenagem e perfis de condução (`handling.log`) | 36 / 36 |
| Bairro, regeneração e percursos com comandos reais (`pilot_city.log`) | 34 / 34 |
| Luzes e normais no pacote exportado (`exported-car-visual.log`) | 7 / 7 |
| Menu renderizado, passeio e recursos no pacote (`exported-menu.log`) | 17 / 17 |

Total: 110 verificações no projeto e 24 no pacote exportado, sem falhas. Os processos concluíram com código 0. O teste do bairro mantém o aviso já observado de seis instâncias ObjectDB no encerramento; não houve falha funcional.

Linux e Windows foram exportados com `scripts/tools/export_builds.sh`. O executável nativo Linux iniciou sem erro (`native-linux.log`); o executável Windows não foi executado neste ambiente. Os PCK das duas plataformas têm o mesmo SHA-256, registrado junto com executáveis, cena e meshes em [artifact-hashes.json](artifact-hashes.json).

A inspeção externa [package-model.log](package-model.log) confirma `project.binary`, `GOL 1000`, corpo de 15.166 triângulos e roda de 4.592 triângulos dentro do pacote final. Os testes externos usam o motor completo com `--main-pack builds/linux/Wave.pck` e fixtures em `/tmp`, sem carregar recursos do projeto-fonte. As versões das fixtures de menu/captura e inspeção estão arquivadas nesta pasta. [Captura do passeio no pacote](../../../art-results/2026-10-09/gol-1000/package-driving.png).

A alteração mantém colisão, distância dos eixos, raio dos pneus e controlador. A aparência é uma aproximação estilizada do exemplar de 1993; não é uma réplica baseada em medidas industriais. Os testes completos da etapa anterior seguem em `../neighborhood-refresh/`; esta etapa repete as verificações relacionadas ao modelo, à condução e à integração dos builds.
