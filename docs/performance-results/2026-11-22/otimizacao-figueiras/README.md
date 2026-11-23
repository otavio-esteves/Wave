# Otimização da Vila das Figueiras — 22 de novembro de 2026

A comparação usa o pacote da Baixada do Arroio como referência. O mapa recompilado conserva a geometria, os materiais, a iluminação, as distâncias dos LODs existentes, os perfis gráficos, o retrovisor e a chuva.

## Estudo e aplicação

- **Renderização da cidade.** O guia da Godot recomenda equilibrar custo por chamada de desenho e granularidade do frustum. Em Compatibility, um `MultiMesh` explícito permite desenhar várias repetições da mesma malha. O Wave consolidou 145 nós instanciados e 27 malhas de pintura viária por setor e material, conservando os atributos dos vértices, a emissão, as máscaras de câmera e as sombras. A arquitetura usa a divisão original, que permite descartar blocos menores fora da câmera. [Otimização 3D na Godot](https://docs.godotengine.org/en/4.7/tutorials/performance/optimizing_3d_performance.html) · [MultiMesh](https://docs.godotengine.org/en/4.7/tutorials/performance/using_multimesh.html)
- **Pavimento.** A profundidade deve poder rejeitar cedo os fragmentos opacos encobertos. O recorte circular das tampas de bueiro ganhou uma variante própria do shader. As outras superfícies usam o acabamento opaco sem o comando de descarte. As equações de desgaste, água, cor e contato continuaram as mesmas. [Guia de otimização de GPU da Godot](https://docs.godotengine.org/en/4.7/tutorials/performance/gpu_optimization.html) · [Capcom RE Engine na GDC](https://gpuopen.com/download/gdc-2019-s4-optimization-techniques-re2-dmc5.pdf)
- **Física e navegação.** O mapa armazena as 2.944 formas de colisão do corpo de sólidos com seus recursos, transformações e estados. O carregamento insere essas formas diretamente em proprietários nativos do corpo. O índice de rotas refina células de 32 m em células de 16 m e conserva todo segmento que ainda pode ser o mais próximo em algum ponto da célula. As curvas de elevação guardam previamente seus coeficientes. [CollisionObject3D](https://docs.godotengine.org/en/stable/classes/class_collisionobject3d.html) · [Otimização de CPU na Godot](https://docs.godotengine.org/en/stable/tutorials/performance/cpu_optimization.html)
- **Trânsito.** O mapa pronto traz oito circuitos do tráfego com amostras de altura e as malhas dos veículos. As luzes reaproveitam o estado já enviado quando ele se repete. A atualização de posição dos veículos continua na física de 60 Hz. O teste na Intel favoreceu as chamadas nativas para o pequeno lote dinâmico. Os lotes estáticos usam buffers preparados offline. [RenderingServer](https://docs.godotengine.org/en/4.7/classes/class_renderingserver.html#class-renderingserver-method-multimesh-set-buffer)
- **Áudio espacial.** As fontes do lago e do arroio participam do encerramento de áudio do Wave. A reprodução termina e libera os WAVs quando o jogo fecha ou troca de cena. Essa correção veio após as medições e mantém o comportamento dos sons durante a condução.

## Evidência de custo

O diagnóstico isolado de projeção usou 98.000 consultas por passagem em 14 estradas, incluindo bordas de células. A mediana de três passagens passou de **2.330 para 1.764 ms**, uma redução de **24,3%**. As projeções e as elevações verificadas coincidiram com o algoritmo anterior.

Na comparação fixa da Avenida, o primeiro agrupamento reduziu de **572 para 443** chamadas na Intel, com **367 mil** triângulos ante **330 mil** na referência. Agrupar apenas instâncias e pintura ficou em **483 chamadas**, com **355 mil** triângulos. Na Radeon, as três versões produziram respectivamente **721**, **585** e **629** chamadas. O P95 da Radeon ficou em **29,3**, **30,6** e **29,8 ms**. O pacote usa o agrupamento de instâncias e pintura, que mantém a seleção original de setores da arquitetura. As rodadas alternaram os mapas dentro do mesmo processo para isolar o desenho.

## Comparação de imagem

As vistas usam a mesma câmera, horário e estado da água para cada par. Avenida, Praça e Baixada têm céu seco. A quarta vista fixa piso molhado e luz de fim de tarde. Os carros de tráfego e as gotas individuais foram retirados dessas vistas fixas para comparar a mesma imagem. O benchmark em movimento mantém os 24 carros e usa gotas e retrovisor na cabine. O comparador mede os canais RGB de 8 bits dos PNGs.

| Perfil e vista | Pixels RGB idênticos |
| --- | ---: |
| Econômico, Avenida | 99,999% |
| Econômico, Praça | 99,999% |
| Econômico, Baixada | 99,998% |
| Econômico, piso molhado | 99,998% |
| Equilibrado, Avenida | 99,999% |
| Equilibrado, Praça | 99,942% |
| Equilibrado, Baixada | 99,998% |
| Equilibrado, piso molhado | 99,994% |
| Qualidade, Avenida | 99,999% |
| Qualidade, Praça | 99,969% |
| Qualidade, Baixada | 99,998% |
| Qualidade, piso molhado | 99,990% |

As vistas fixas foram capturadas em 853 × 480 no Econômico, 1280 × 720 no Equilibrado e 1797 × 1011 no Qualidade. O último tamanho é o viewport efetivo na janela do X11. As imagens de Qualidade incluem o minimapa e o painel.

[Avenida antes](capturas/avenida-antes.png) · [Avenida depois](capturas/avenida-depois.png) · [Chuva antes](capturas/chuva-antes.png) · [Chuva depois](capturas/chuva-depois.png)

## Entrada no mapa

Mediana de três medições por pacote, em processos distintos com renderização desligada. O relógio começou antes de carregar o recurso da cena e terminou ao anexar o mundo à árvore. A memória abaixo é a do alocador da Godot.

| Métrica | Antes | Depois |
| --- | ---: | ---: |
| Tempo total até a cena pronta | 4,09 s | 3,68 s |
| Anexação do mundo | 512 ms | 165 ms |
| Nós na sessão após anexação | 6.513 | 3.397 |
| Nós de colisão dos sólidos | 2.944 | 0 |
| Formas nativas de colisão dos sólidos | 2.944 | 2.944 |
| Memória estática da Godot | 263,7 MiB | 255,9 MiB |

A comparação do mapa gerado verificou individualmente a classe, as dimensões ou faces, as transformações, o estado habilitado, as camadas e as máscaras das 2.944 formas. Todos esses valores coincidiram.

## Condução

Linux no Dell Inspiron 5547 com Core i7-4510U, 16 GiB, Godot 4.7.2, Mesa 25.0.7, X11 e Compatibility. Os pares finais usaram cinco segundos de aquecimento, 12 segundos de coleta, 24 carros no trânsito, foco contínuo, sincronização vertical desligada e a mesma trajetória e câmera. Todas as passagens percorreram cerca de 137 m a 41 km/h.

| GPU, perfil e trecho | FPS médio | P95 de quadro | Chamadas por quadro |
| --- | ---: | ---: | ---: |
| Intel HD 4400, Econômico, Avenida | 15,45 → 16,15 | 81,0 → 80,3 ms | 477 → 421 |
| Radeon R7 M260, Equilibrado, Avenida | 34,84 → 33,15 | 36,7 → 40,0 ms | 611 → 542 |
| Radeon R7 M260, Equilibrado, cabine com chuva | 25,49 → 25,51 | 48,9 → 49,8 ms | 641 → 570 |

Na Intel, a janela era de 854 × 480, com viewport de 569 × 320. Na Radeon, ambos eram de 1280 × 720. Os lotes ainda podem enviar mais triângulos quando suas bordas cruzam a vista. Na Avenida da Radeon, a média de primitivas passou de 434 mil para 458 mil. A redução de chamadas é consistente e o FPS médio respondeu de formas diferentes nessas passagens curtas. O P95 dos trechos permaneceu acima do orçamento de 33,3 ms por quadro. As repetições do protótipo de lotes largos mostram a oscilação entre execuções na Intel. [Dados brutos](medicoes.json)

O benchmark usa os dois PCKs a partir de um diretório vazio, com perfis e dados de usuário de ensaio. No script, `--preset=economy` seleciona o Econômico, `--preset=medium` o Equilibrado, `--route=avenida` a pista seca e `--route=cabine --rain` a cabine molhada. Os parâmetros medidos foram `--warmup=5 --seconds=12`. [Script de condução](../../../../tests/figueiras_benchmark.gd)

## Validação e builds

As dez suítes direcionadas do projeto passaram 287 verificações ao longo da revisão. O pacote final passou 69 verificações de Qualidade, Copa e Baixada, além da guarda de carregamento exclusivo do PCK. O executável Linux abriu e encerrou sem avisos no teste nativo. Linux e Windows receberam o mesmo PCK, com 285.411.876 bytes. A execução nativa foi verificada no Linux.

O ajuste final de encerramento liberou os dois WAVs de ambiente apontados pela suíte da Copa. A validação completa do PCK passou após a correção. O JSON preserva o hash da versão aferida e o hash da distribuição com esse ajuste de áudio. [Medições, diagnósticos e contagens](medicoes.json)
