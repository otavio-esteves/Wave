# Bairro de 72 quarteirões e ciclo de dia/noite

[Comparação interativa dos horários e zonas](compare.html). Bairro ampliado de 768 × 616 para 1.536 × 1.232 m: quatro vezes a área anterior, mantendo uma rede conectada de 162 ruas. São 369 imóveis, 1.156 árvores, 161 carros estacionados e 33.309 tufos de grama, além de 324 postes com posições de iluminação. Ruas com espaçamentos e curvas distintos, seis praças, zonas de casas baixas, residências maiores e prédios centrais. Relevo com vale e colinas largas; jardins, gramíneas, flores, rochas e árvores de diferentes proporções.

O céu é um shader próprio: sol/lua em posições sincronizadas com as luzes direcionais, nuvens procedurais e estrelas. O ciclo muda a iluminação ambiente, névoa, reflexos, emissão de postes/janelas e até oito luzes locais próximas ao carro. Um dia completo dura 24 minutos reais, iniciando às 16h30. F6/R1 avança três horas. Pausa congela relógio e nuvens; reiniciar o carro conserva o horário.

Capturas estáticas em Compatibility, Equilibrado, 1280 × 720, AMD Radeon R7 M260. `driving-spawn.png` mantém a câmera/HUD/configurações reais do jogo. As demais usam câmera de inspeção, com névoa e descarte por distância desligados. Amanhecer, dia, pôr do sol e noite usam a mesma câmera e o sistema real de iluminação; o relógio é congelado para a captura. A foto da lua aponta para o céu. `context.json` contém parâmetros e GPU.

Sem benchmark ou certificação de desempenho nesta etapa. Imagens e testes headless não aprovam o requisito de FPS/8 GB. Avaliação jogada e Windows nativo permanecem pendentes. [Validação funcional](../../../development-results/2026-10-09/pilot-day-night/README.md).
