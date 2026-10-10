# Condução — progressão de velocidade e referência MW 2012

Feedback jogado: a revisão anterior melhorou a condução, mas a aceleração ainda era rápida demais. O pedido atual reduz o ganho de velocidade em aproximadamente 60% e passa a usar **Most Wanted 2012 como referência de condução**, além da referência artística já vigente. A equivalência de sensação continua dependendo de avaliação jogada.

## Ajuste

`PlayerCar.arcade_acceleration_scale = 0.4` aplica a redução ao ganho líquido de velocidade sob acelerador, inclusive na ré. Mantém o balanço entre motor e resistência em alta velocidade, para que 220 km/h continuem alcançáveis. A frenagem e a desaceleração sem acelerador conservam a resposta anterior. Nas subidas, a carga da inclinação é compensada dentro do torque disponível, mantendo a capacidade de subir e reduzindo a retomada.

O controle de rotação gradual, a dissipação de derrapagem e a recuperação de aderência da revisão anterior permanecem. A progressão mais lenta permite usar a mesma condução arcade com aceleração mais dosável. O perfil experimental do rally mantém sua resposta de motor anterior.

## Medições funcionais

Na mesma fixture plana, com comandos reais de acelerador:

| Medida | Resposta anterior | Ajuste atual |
| --- | ---: | ---: |
| Velocidade após 1 s de acelerador | 32,32 km/h | 12,97 km/h |
| 0–100 km/h | 3,20 s | 8,00 s |
| 0–220 km/h sob potência | — | 35,48 s |

O ganho no primeiro segundo ficou em 40,1% do anterior, uma redução de 59,9%. O teste compara a escala 1,0 com 0,4 no mesmo controlador, cenário e input; não compara com dados de um veículo de Most Wanted. O 0–100 anterior está no log preservado da revisão anterior.

A fixture de alta velocidade passa a identificar a rota como `high-speed-v3`: mede o 0–100 na avenida real e injeta 220 km/h para o trecho de cruzeiro, porque a aceleração mais lenta exige uma reta maior. O alcance natural de 220 km/h é testado separadamente em um piso amplo, sem injeção de velocidade. Os dados gráficos de v2 e v3 não são diretamente comparáveis.

O runner completo passou **701 verificações funcionais e dez testes Python**. As seis voltas da cidade mantiveram apoio e permanência no pavimento de 100%, incluindo encosta nos dois sentidos. Os testes de aceleração, aderência, ré, subida, freios e travessias de calçada passaram. [Log completo](project-checks.log) e [resumo por suíte](validation-summary.json).

Os builds Linux/Windows foram atualizados, com PCKs idênticos. O pacote passou **328 verificações**: 260 de acesso, 36 de handling, 14 de alta velocidade, 17 de menu e uma guarda de recursos exportados. O executável Linux iniciou em headless; Windows nativo não foi executado. [Acessos finais](exported-access.log), [handling](exported-handling.log), [alta velocidade](exported-speed.log), [menu](exported-menu.log), [startup Linux](linux-startup.log) e [hashes](artifact-hashes.json).

O primeiro runner de acesso exportado parou na rua lateral leste: o prazo anterior de dez segundos era curto para a partida a meio acelerador, com a redução solicitada. A fixture passa a aguardar até quinze segundos, mantendo o mesmo destino, desvio máximo de 0,5 m e apoio contínuo. A validação retomou essa suíte e as três restantes no mesmo PCK; todas passaram. [Primeiro ensaio preservado](exported-access-attempt-1.log). O corredor estático também espera a chegada ao trecho final, dentro de um prazo, para acomodar a partida mais lenta.

As fixtures da cidade/guias continuam emitindo o aviso de seis instâncias ObjectDB no encerramento. Também foi observado um erro de um RID DummyMultiMesh no encerramento da fixture de acesso aos mapas no pacote, sem falha nas suas cem verificações funcionais. Os logs preservam essas mensagens; esta revisão não certifica ausência de leaks. Não houve benchmark gráfico novo. As medições de aceleração usam física em headless/fixed-fps; não medem FPS gráfico.

## Avaliação jogada

Abrir **Dirigir na cidade piloto**, acelerar da saída até o centro, retomar após um cruzamento e subir a encosta. Comparar também uma curva sob acelerador e um toque curto no freio de mão. O objetivo desta etapa é dar tempo para ler a rua e dosar velocidade, mantendo a condução já melhorada.
