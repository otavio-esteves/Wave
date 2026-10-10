# Cidade piloto — três bairros

[Galeria interativa](index.html) · [Mapa completo](expanded-overview.png) · [Centro](skyline.png) · [Condução no build Linux](package-driving-day.png)

O mapa passa de 1.892.352 para **7.569.408 m²**, com 200 quarteirões e 430 trechos conectados. Jardins do Vale combina sobrados e colinas; Vila Aurora reúne casas menores, comércio e prédios residenciais; Centro Horizonte apresenta 245 arranha-céus, avenidas e um conjunto de parques. A cidade tem 927 imóveis, 2.714 árvores em volume, 320 veículos estacionados e 66.463 tufos de grama. Os 18 parques/praças recebem caminhos e pequenos bosques.

As torres variam altura, material, recuos e coroamento. A altura cresce em direção ao miolo do centro. Vidro, pedra e tijolo usam arquitetura procedural original; Manhattan serve como inspiração de composição. Janelas selecionadas acompanham a iluminação noturna. O traçado passa gradualmente de ruas curvas a uma malha mais reta, com avenidas de até 24 m. O minimapa mostra o carro, ruas e parques; o HUD identifica o bairro atual.

Capturas em Compatibility, perfil Equilibrado, 1280×720, Radeon R7 M260. `driving-spawn.png` usa a câmera e o HUD normais. As demais vistas do gerador desativam neblina e cortes de distância para inspeção. `package-driving-day.png` e `package-driving-night.png` são entradas reais pelo menu do PCK Linux, com iluminação, neblina e cortes normais; a fixture exige `project.binary` e ausência de `project.godot`.

A galeria registra o conteúdo e não comprova desempenho nem aprovação artística. A avaliação jogada e a janela combinada para medir FPS continuam pendentes. As capturas terminaram com sucesso, mas o encerramento do renderer GLES registrou dois avisos de texturas de 21.844 bytes em cada sessão, como na etapa anterior. [Validação e logs](../../../development-results/2026-10-10/three-districts/README.md).
