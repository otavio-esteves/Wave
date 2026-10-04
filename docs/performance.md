# Desempenho

## Referência

- Godot 4.7.2, renderer Compatibility, 1280 × 720.
- GPU de referência: Intel Haswell integrada detectada no notebook.
- Meta: manter pelo menos 30 FPS durante a condução, buscando 45–60 FPS quando possível.

## Estado de 2026-10-04

| Dado do Bairro do Sol | Valor |
| --- | --- |
| Lotes MultiMesh | 24 |
| Instâncias de primitivas no mapa | 1.256 |
| Triângulos das primitivas | 21.096 |
| Formas de colisão estáticas | 168 |
| Luzes dinâmicas | 1 direcional |
| FPS com renderização | Ainda não medido |

Esses números foram extraídos da cena pela Godot. A contagem de triângulos exclui texto, carro e passes de sombras. A quantidade de lotes não é uma medição de draw calls: fontes, carro e sombras acrescentam trabalho. Os testes sem interface validam comportamento e carregamento; os FPS desse modo não representam o desempenho gráfico.

## Rota para comparar versões

1. Execute o projeto com F5 em 1280 × 720 e aguarde dez segundos.
2. Aperte F3 para mostrar FPS, tempo médio por quadro derivado dos FPS e draw calls.
3. Siga pela via central até o cruzamento diante das casas ao norte.
4. Vire à direita e complete uma volta no circuito externo.
5. Volte à via central e entre no estacionamento do posto.
6. Registre o menor FPS observado, FPS típico, draw calls, renderer, GPU em uso e alterações de qualidade. Faça a mesma rota após mudanças relevantes.

Ao observar quedas, use o profiler da Godot para distinguir custo de renderização e física. O teste deve ser feito sem pausa e com a janela do jogo visível.
