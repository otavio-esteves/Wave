# Asfalto original · realismo v1

Modo: geração pelo imagegen integrado, sem referência de imagem. Não contém assets de Need for Speed. Fonte preservada em `asphalt-realism-v1.png`; importação Godot limitada a 512 px, com mipmaps e compressão VRAM.

Prompt exato:

> Use case: photorealistic-natural. Asset type: square seamless repeating base-color texture for an original real-time driving game road. Primary request: ultra realistic dry medium-dark gray asphalt seen exactly straight overhead, covering a two meter square. Tiny crushed stone aggregate with restrained neutral gray variation, naturally worn binder, subtle broad weathering. Uniform soft diffuse lighting, no directional shadows, no perspective, no highlights baked into the surface. Seamlessly tileable edges on all four sides. Fine scale grains, no large cracks, no painted markings, no leaves, no objects, no text, no watermark, no border. This is an albedo material texture, not a rendered road scene.

As superfícies `stucco`, `limestone`, `timber` e `paving` são originais, procedurais e reproduzíveis por `scripts/tools/build_neighborhood_materials.gd`. São geradas offline como ImageTexture com mipmaps, sem trabalho procedural durante a condução. O mapa normal representa micro-relevo visual; não altera colisões.
