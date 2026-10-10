# Condução arcade — peso e recuperação de aderência

Referência de sensação solicitada: Most Wanted 2005, com mais peso e menos derrapagens prolongadas. Esta revisão ajusta o controlador arcade compartilhado; a equivalência de sensação depende de avaliação jogada. A referência artística do bairro continua Most Wanted 2012.

## Mudanças

- Rotação gradual da carroceria, com resposta de yaw de 7/s, em vez de alterar a orientação imediatamente junto com as rodas.
- Curvas normais usam 85% do orçamento lateral restante depois de acelerar/frear. Quando já há escorregamento, a rotação solicitada diminui para permitir recuperar aderência.
- Derrapagem dissipa velocidade longitudinal; o freio de mão também freia movimento lateral, inclusive quando o carro está atravessado.
- Freio de mão conserva uma derrapagem deliberada, com aumento de rotação menor que antes (1,6× em vez de 2×).
- Inclinação visual responde à aceleração, frenagem e curva, com amortecimento. Reset limpa os novos estados de rotação e transferência visual de peso.

O carro continua cinemático, com os mesmos limites de velocidade, contatos das rodas, degraus e controle de ré. O perfil experimental de pneus do rally conserva seu comportamento.

## Verificação

A fixture de handling acrescenta sete verificações: curva acelerada durante oito segundos com ângulo de escorregamento abaixo de 18°, manutenção de velocidade/apoio, recuperação sob aceleração, parada do movimento puramente lateral, derrapagem deliberada, recuperação com direção/acelerador mantidos e reset da inércia.

O controlador anterior (`3dfeae9`) foi carregado em uma cópia temporária da fixture atual: 34 verificações passaram e uma falhou, na recuperação após soltar o freio de mão e manter acelerador/direção por dois segundos. O controlador ajustado passou as 35 verificações. A fixture de derrapagem arcade agora parte em linha reta, para medir o escorregamento provocado pelo freio de mão; os casos de derrapagem deliberada e recuperação permanecem distintos.

O runner completo passou **699 verificações funcionais e dez testes Python**, incluindo as seis voltas da cidade (contorno, centro e encosta nos dois sentidos), acessos e travessias de calçada. As seis voltas mantiveram apoio e permanência no pavimento de 100%. [Log completo](project-checks.log) e [resumo por suíte](validation-summary.json).

Os builds Linux/Windows foram atualizados, com PCKs idênticos. O pacote passou **313 verificações**: 260 de acesso, 35 de handling, 17 de menu e uma guarda de recursos exportados. O executável Linux iniciou em headless; Windows nativo não foi executado. [Acessos](exported-access.log), [handling](exported-handling.log), [menu](exported-menu.log), [startup Linux](linux-startup.log) e [hashes](artifact-hashes.json). A comparação do controlador anterior está em [baseline-handling.log](baseline-handling.log); sua falha é esperada e reproduz o problema corrigido.

As fixtures da cidade/guias continuam emitindo o aviso de seis instâncias ObjectDB no encerramento já registrado nas etapas anteriores. O runner também imprime os erros esperados dos casos negativos de manifesto. Testes funcionais não certificam sensação equivalente à referência nem desempenho gráfico; não houve benchmark gráfico novo nesta revisão.

## Avaliação jogada

No build, abrir **Dirigir na cidade piloto**. Comparar curvas do centro, encosta nos dois sentidos, frenagem antes dos cruzamentos e um toque curto no freio de mão. Ao soltar o freio de mão e continuar acelerando, o carro deve recuperar o rumo; segurar o freio de mão deve encerrar o movimento. Conferir também ré e manobras na praça/oficina.
