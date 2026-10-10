# Avaliação após execuções interrompidas — 2026-10-10

## Resolução na retomada

A entrega foi sincronizada: 36 malhas de calçadas distantes ainda estavam embutidas com conteúdo antigo nos setores. Foram substituídas pelos recursos externos da geração atual. A comparação completa entre cidade salva e regenerada passou, incluindo os índices de LOD; o teste agora encerra cedo quando encontra divergência e permite retomar uma geração já concluída.

Passaram **857 verificações Godot no projeto, 14 testes Python e 401 verificações no PCK**, além de três verificações adicionais de geometria. Linux e Windows foram reexportados com pacotes idênticos, SHA-256 `c197ac71e440757ea4fab959175da4b39f9f7078a3e50448748d6372acce590a`. O inventário final registra 47.644 nós, 20.752 formas de colisão, 118.034.903 bytes em 5.105 arquivos e 180.719 triângulos no piso distante.

A fixture de benchmark foi corrigida para preservar as curvas de ligação entre os trechos. As tentativas intermediárias foram mantidas separadas da comparação final.

As medições renderizadas têm somente escopo de diagnóstico, conforme solicitado pelo usuário. Validação controlada de desempenho, execução nativa Windows, requisito de 8 GB e avaliação humana continuam etapas próprias. [Relatório atualizado e evidências](pilot-consolidation/README.md).

## Registro da avaliação inicial

A revisão da cidade piloto está presente no diretório de trabalho, mas sua entrega ficou incompleta. O código, os recursos gerados, os executáveis exportados e o relatório de consolidação representam etapas diferentes da revisão. Esta avaliação preserva as alterações existentes e não modifica a implementação.

## Pendências confirmadas na avaliação inicial

1. **Exportações anteriores à última otimização.** Os PCKs Linux e Windows têm SHA-256 idêntico (`6292725d7dbf6ea46c77b21356cf34e42395a39c53e57943238a9c8620da0600`). O teste atual `pilot_optimization_smoke.gd` executado sobre o PCK Linux aprova 15 das 17 verificações, mas falha na presença dos LODs das superfícies e do piso distante. O mesmo teste sobre o projeto atual aprova as 17 verificações. É necessário exportar novamente e validar os novos pacotes.
2. **Inventário e relatório desatualizados.** O inventário publicado descreve 47.512 nós e 96.811.129 bytes. A inspeção atual encontra 47.644 nós, 20.752 formas de colisão e 119.865.229 bytes em 5.105 arquivos da cidade. Entre os 4.576 arquivos do inventário publicado, 1.552 mudaram de tamanho; nenhum está ausente. A cidade atual inclui 132 malhas `FloorFar`, com 181.410 triângulos, inexistentes no inventário publicado. Atualizar as medidas e evidências após fixar a versão a entregar.
3. **Relatório de desempenho incompleto.** A seção de desempenho renderizado ainda contém o marcador literal `BENCHMARK_RESULTS`. Não há resultados de benchmark da consolidação junto ao relatório. Os runners e testes Python da análise estão presentes, mas testes headless e redução de nós não demonstram FPS. O plano exige uma janela combinada de uso exclusivo para a medição controlada.
4. **Revisão sem commit.** O último commit é `782ab5b`, anterior à consolidação. Na abertura da avaliação havia 84 entradas rastreadas alteradas/removidas e 5.142 arquivos não rastreados, principalmente recursos gerados da cidade. Os novos scripts, shaders, texturas e recursos precisam acompanhar o commit da revisão. Também há caches Python não rastreados.

## Evidências da avaliação inicial

- Godot 4.7.2 importa o projeto; `git diff --check` passa.
- Os 14 testes Python do runner passam.
- O runner geral concluiu 473 verificações Godot sem falhas, abrangendo condução, terreno, calçadas, acessos, handling, carro, câmera, bairro, circuito, rally, áudio, menu e mapa. Somando as suítes específicas de otimização, passeio e dia/noite executadas separadamente, foram 565 verificações Godot aprovadas nesta avaliação.
- Otimização no projeto atual: 17 verificações, zero falhas.
- Mapa completo no projeto atual: 13 verificações, zero falhas.
- Passeio praça → oficina no projeto atual: 21 verificações, zero falhas, incluindo condução real, estacionamento, pausa, reset e prevenção de chegada por teleporte.
- Ciclo de dia/noite no projeto atual: 54 verificações, zero falhas.
- Otimização no PCK existente: 17 verificações, duas falhas.
- Inventário atual obtido carregando e instanciando a cidade salva, sem regenerar os recursos de produção.

**A suíte geral não foi concluída nesta avaliação.** Sua execução foi encerrada deliberadamente após a regeneração temporária da cidade permanecer por mais de cinco minutos na etapa das calçadas, ainda com atividade de CPU. Isso não demonstra travamento nem falha do gerador. A comparação completa entre gerador e cidade salva, assim como as suítes seguintes do runner, precisa ser retomada. As 565 verificações acima incluem somente suítes efetivamente concluídas; não contam o teste de regeneração parcial.

Logs adicionais desta sessão estão em `/tmp/wave-project-audit-2026-10-10.log`, `/tmp/wave-optimization-audit-2026-10-10.log`, `/tmp/wave-package-audit-2026-10-10.log` e `/tmp/wave-inventory-audit-2026-10-10.log`; o inventário completo está em `/tmp/wave-pilot-inventory-audit-2026-10-10.json`.

Os logs históricos contêm falhas intermediárias, mas as suítes correspondentes têm novas execuções aprovadas. Isso sustenta as contagens históricas da versão anterior; não valida automaticamente as alterações posteriores de LOD e piso distante.

## Sequência proposta na avaliação inicial

Concluir a validação do estado atual, exportar Linux e Windows, validar os novos PCKs e atualizar inventário/relatório/capturas da mesma versão. Medir a rota renderizada nas condições previstas no plano e substituir o marcador por resultados verificáveis ou registrar explicitamente a pendência. Depois, consolidar código e recursos em commit. Avaliação humana da condução e da arte, execução nativa Windows e requisito de 8 GB continuam pendências próprias.
