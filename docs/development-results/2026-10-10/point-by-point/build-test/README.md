# Build provisório para teste local

Este registro é histórico. O build foi substituído pela revisão validada descrita no [relatório principal](../README.md), que também resolve os avisos registrados abaixo.

Linux e Windows exportados em 2026-10-10 com as correções atuais e a cidade publicada (geração 11). Este build atende ao pedido de teste local; a divergência geométrica da regeneração permanece pendente.

Execute `builds/linux/Wave.x86_64` ou `builds/windows/Wave.exe`. Mantenha o arquivo `Wave.pck` junto ao executável. Cada pacote contém somente a geração publicada, sem os diretórios legados de geometria/setores.

O executável Linux abriu e encerrou normalmente em modo headless. Com o pacote Linux, passaram 8 verificações de física, 5 de carregamento e 17 de menu/acessos/condução. O teste de menu registrou aviso de 7 instâncias ObjectDB vazadas no encerramento; investigação pendente. Os logs desta pasta preservam os resultados. Não houve validação gráfica nesta etapa nem execução nativa do Windows.

Os dois PCKs têm SHA-256 `eac036a5e09f52f8f8d5a4886e81297ecfa50a60b4930756868d16166402d183`.
