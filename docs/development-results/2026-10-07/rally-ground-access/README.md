# Acesso ao chão e às pistas em todos os mapas — 2026-10-07

A correção anterior de calçadas/subidas não abrangia a entrada lateral da grama na pista do Rally da Serra. O teste antigo do rally dirigia pelo eixo viário. A nova fixture reproduziu bloqueio em 10 das 20 entradas amostradas, usando o controlador após a primeira correção, o colisor anterior e a geometria original da pista. Das dez saídas executadas após entradas válidas, uma também prendeu.

## Correção

A malha da pista tinha 14 cm de altura sobre o terreno até sua borda externa. O contato com essa borda aberta podia atingir o carro por baixo, bloqueando a elevação usada para atravessar um degrau. Os dois acostamentos de 1 m agora descem dos 14 cm até o terreno, enquanto a faixa central conserva a altura. Malha visível e colisão usam os mesmos vértices. O mapa salvo foi regenerado a partir do gerador atualizado.

O colisor compartilhado do carro passou de uma caixa a um casco convexo de 12 pontos. Conserva largura, comprimento e altura totais (1,60 × 3,65 × 0,70 m), com o fundo plano entre os eixos e as extremidades inferiores elevadas em 27 cm. Assim, a frente/traseira além do apoio das rodas têm folga ao mudar de inclinação. O contorno também resolveu o esbarrão residual ao sair do cascalho para o terreno. Motor, aderência e assistência de degrau mantêm os ajustes da revisão anterior.

## Verificação

| Ensaio | Resultado |
| --- | --- |
| Entradas no rally antes, mesmas 20 posições | 10 passagens / 10 bloqueios |
| Entradas e saídas no rally após a correção | 40 checks, 0 falhas (auditoria de 2026-10-08) |
| Transições nos outros sete mapas após a correção | 100 checks, 0 falhas (auditoria de 2026-10-08) |
| Runner completo | 585 checks de comportamento + 10 testes Python, 0 falhas (auditoria de 2026-10-08) |
| Rally no pacote exportado | Aguardando pacote |
| Outros sete mapas no pacote exportado | Aguardando pacote |

O rally é conduzido com inputs de aceleração/freio/direção a aproximadamente 3 m/s, em dez seções representativas, nos dois lados do asfalto e cascalho, de grama para pista e de pista para grama. A chegada exige apoio físico e a identificação correta do piso nas rodas. Os pontos usam acostamentos livres: postes, troncos e pedras com colisão continuam obstáculos; a fixture não tenta atravessá-los.

A outra suíte verifica ida/volta em rampas e guias da pista de testes, calçadas do Bairro do Sol, avenida estática e avenida com streaming, regiões urbana/rural/rodoviária/vila do Caminho da Serra, acostamentos do circuito e bordas da pista de relevo. Exige chegar sem desvio excessivo, contato físico durante o percurso e ausência de bloqueios do streaming. São pontos representativos de **todos os oito mapas jogáveis**, não uma inspeção de cada metro quadrado. Ambas as suítes entraram no runner normal.

O log completo da auditoria de 2026-10-08 está em `audit-check-project-2026-10-08.log`. Os pacotes Linux/Windows existentes têm SHA-256 idêntico (`208b2dad5b43d66ba4b51a1e1e2de5c10a16a8f23047d9d3a0218163d3f3af49`); uma sondagem com engine Linux e script externo confirmou `project.binary` presente, `project.godot` ausente e o colisor `ConvexPolygonShape3D` no pacote. Os testes de condução dos recursos empacotados desta revisão continuam pendentes, conforme a tabela. Windows nativo e avaliação humana da sensação de condução permanecem pendentes. Ensaios funcionais headless, sem benchmark ou conclusão de FPS.

## Reproduzir

```sh
godot --headless --path . --fixed-fps 60 --script res://tests/rally_access_smoke.gd
godot --headless --path . --fixed-fps 60 --script res://tests/map_ground_access_smoke.gd
GODOT_BIN=godot bash scripts/tools/check_project.sh
```

Para repetir a comparação anterior, copie `before-builder.gd.txt` para um `.gd` fora do projeto, execute-o com `-- --output=/tmp/rally-before.tscn` e rode a fixture com `-- --rally-map=/tmp/rally-before.tscn --box-collider`. O diagnóstico substitui apenas o mapa e o colisor nessa execução. A regeneração de produção continua usando o gerador atualizado; o runner confere sua equivalência com o mapa salvo.
