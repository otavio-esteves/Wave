# Direção de arte — referência visual do Wave

**Meta**, não estado entregue: parecer um excelente racer de 2005–2010 em um Brasil plausível. Most Wanted 2005 orienta riqueza percebida, contraste/atmosfera e velocidade; nenhum asset, mapa, interface ou música é reutilizado. O bairro atual tem primitivas úteis e repetição evidente; circuito/rally demonstram texturas/LOD, mas não aprovam a meta artística.

## Trecho de referência

500 m–1 km com avenida e algumas laterais: comércio/oficina ou posto como landmark, sequência de casas térreas/sobrados, muros/portões, terrenos vazios, concreto, fiação, placas e árvores urbanas. Criar ritmo de massas, áreas abertas e mudanças de idade/uso, com horizonte reconhecível. Não distribuir a mesma casa/árvore a cada intervalo fixo. Reservar duas hero areas com composição autoral e overrides no gerador.

Escala de rua define a velocidade percebida: postes, meio-fio e fachadas próximas dão referência; curvas e cruzamentos devem ser legíveis antes de entrar. A arquitetura é brasileira pelo uso, materiais e proporção, não pela saturação de símbolos. Evitar copiar os nomes/comércios de marcas reais.

## Receita Compatibility

Luz solar de fim de tarde, paleta quente nas áreas iluminadas e ambiente mais frio/controlado; céu e névoa simples integram horizonte. Piso desgastado, remendos e manchas localizados; sombra/oclusão pintada e vertex color dão peso no Legacy sem sombras dinâmicas. Lightmaps por célula só quando houver ganho visual e memória/tempo de bake aceitáveis.

Texturas e UVs métricos são a base. Reutilizar poucos materiais de asfalto/remendos, concreto/calçada, tijolo/reboco/telha, metal/vidro e terra/cascalho/grama. Atlas de fachadas/placas, máscaras e cores produzem variação. Não acrescentar vários normal maps/projeções só para preencher o shader. Interiores distantes são texturas escuras; carro usa céu/cubemap aproximado, não reflexo urbano em tempo real.

Para marcas/decals em Compatibility, usar textura/máscara no material, bake ou malha sobreposta de extensão pequena; não depender do nó `Decal`. Validar z-fighting, distância e overdraw. Preferir recorte alfa para folhagem; partículas transparentes limitadas em área de tela/vida. Vegetação regional é escolhida após definir localidade; o pinheiro do rally é recurso de laboratório, não identidade padrão do bairro.

LOD reduz detalhe preservando silhouette: prédio distante vira massa com fachada; bloco de casas vira HLOD autoral; árvore simplifica até impostor sem sombra; montanhas/bairros de horizonte têm geometria mínima. Não esconder o mundo com neblina tão próxima que se perca a leitura da via. Conferir pop em curvas e retorno da câmera.

SSAO/glow simples existem na Godot atual, mas ficam cosméticos e desligados no Legacy. SSIL/volumetria não compõem a receita base. Lightmaps podem ser renderizados em Compatibility; bake e outras capacidades devem seguir a [matriz oficial de renderers](https://docs.godotengine.org/en/4.7/tutorials/rendering/renderers.html) da versão, evitando regras antigas da Godot 4.0.

## Revisão visual utilizável

Salvar mesmos enquadramentos de entrada, comércio, residencial, curva e horizonte, em Legacy 720p e Medium. Julgar materiais/repetição em baixa velocidade, e silhueta/contraste/escala a 120 km/h. Perguntar: reconhece Brasil? lê curva/cruzamento? sabe onde está pelo landmark? carro parece integrado ao piso? LOW sustenta a direção de arte sem pós-processamento?

Registrar screenshot, seed, preset, câmera e commit junto ao benchmark. Revisão humana compara intenção/composição e diversão; teste de assets detecta bounds, licenças, mipmaps e persistência, mas não certifica beleza. Antes de escalar, corrigir os enquadramentos fracos com textura, luz ou composição; polígonos não são a primeira resposta.

## Base atual para revisão

Avenida do Vale, seed 5547: avenida de 12 m com duas laterais, oficina e mercado autorais; fachadas em atlas original, telhados/muros/portões em geometria simples, árvores broadleaf em cards, postes de concreto com fios curvos, remendos e marcas viárias. O chão usa UVs métricos; oclusão pintada e sombra barata integram objetos no Legacy. Placas opacas são rasterizadas offline. Nenhum efeito essencial exige Forward+.

Abrir pelo botão **Avenida do Vale · referência visual**. `tests/corridor_rendered.gd -- --previews --foreground --no-vsync` salva quatro vistas Legacy 720p; acrescentar `--medium` para a comparação cosmética. A câmera e os enquadramentos são fixos; esse modo não mede pacing. A rota normal usa controles reais com alvo de 120 km/h e não salva screenshots durante a captura.

O trecho é uma base de composição, não uma aprovação da meta MW2005. Repetição de quatro fachadas, laterais pouco decoradas, contraste/material do piso, impostores vistos de perto e morros genéricos ainda limitam a imagem. Corrigir com autoria/material e comparar no mesmo enquadramento antes de ampliar extensão. Tráfego e pedestres não foram adicionados.

## Representação distante exercitada

A variante da Avenida do Vale gera massas/telhados do layout original e piso em uma superfície opaca por célula, com cores médias amostradas offline dos materiais. Árvores continuam em cards, em um lote separado. Proxies preservam ritmo/silhueta ao descarregar; não são novos prédios próximos nem substituem fachadas, materiais e props da área hero. O detalhe entra a 180 m dos limites da célula, sai acima de 200 m, sem fade. Vistas fixas do spawn, retorno e célula residente distante permitem conferir massa, cor e piso contra o desenho anterior. Distâncias são experimentais: manter revisão em condução antes de escalar.

As vistas revelam que o próximo ganho artístico deve vir da composição próxima: variação dos lotes, transição chão/calçada, paredes laterais, volumes da oficina/mercado e sinais de uso. O HLOD resolve continuidade; não aprova qualidade percebida de Most Wanted.

## Revisão próxima — gerador v2

Oficina e mercado recebem autoria localizada: placas na borda frontal dos toldos, transição de pavimento, rodapés/colunas coloridos, pintura de segurança na oficina e vagas no mercado. Marcas de uso têm centros mais escuros e bordas claras, com UVs iguais ao piso, em quatro malhas opacas pequenas com culling a 100 m. Reutilizam as texturas e materiais existentes; não acrescentam alpha, shaders, luzes ou colisores. Pinturas e frisos usam os lotes de MultiMesh existentes. A geometria é gerada offline depois da decoração aleatória, preservando a seed e as posições anteriores.

O horizonte/HLOD mantém a simplificação distante; desgaste e pavimento localizado pertencem ao detalhe próximo. A comparação de quatro câmeras, a contagem de conteúdo e os benchmarks estão em [hero areas](performance-results/2026-10-06/hero-areas/README.md). Inspeção das vistas confirma melhor leitura das placas e dos usos do piso; repetição das fachadas, paredes laterais e árvores próximas ainda precisa de autoria. Avaliação humana dirigindo e aprovação da meta MW2005 continuam abertas.

## Reorientação e prova entre regiões — 2026-10-07

Econômico/854×480 na Intel passa a ser perfil obrigatório de avaliação artística e desempenho, junto ao Equilibrado/720p na Radeon; Legacy/720p permanece para comparações antigas. [Referências traduzidas em critérios](design-references.md) distinguem intenção de Wave de tecnologia interna dos títulos.

Caminho da Serra amplia a prova funcional, não a aprovação do kit: trecho urbano reutilizado, faixa rural com cercas/refúgio, rodovia curvada e núcleo interior plano. As prévias Econômico em [evidências](performance-results/2026-10-07/reorientation/README.md) confirmam leitura da via/horizonte, mas campo repetitivo, casas no gramado, falta de calçadas/identidade própria e cards próximos exigem autoria. A próxima etapa deve corrigir essas transições com materiais, implantação e poucos detalhes seletivos antes de expandir extensão ou efeitos. Serra real/relevo e composição da Cidade B permanecem pendentes.

A [primeira revisão da Vila da Serra](art-results/2026-10-07/vila-da-serra/README.md) acrescenta calçadas, lotes assimétricos, cruzamento, praça aberta, cobertura e bancos com o kit existente. Sete árvores substituem o alinhamento de 26 cards; acessos livres permitem entrar na praça e na rua lateral. Prévias iguais antes/depois registram a mudança. O núcleo continua provisório: arte e diversão aguardam avaliação humana; o aumento de detalhe precisa de medição futura em uso exclusivo.

A [revisão de orientação e paradas](art-results/2026-10-07/transicoes/README.md) acrescenta placas opacas offline, entradas nas cercas, ligação pavimentada e cobertura do refúgio. Campo/rodovia usam grupos de árvores com intervalos abertos e tons de terreno seletivos. O objetivo é orientar a viagem e tornar as paradas reconhecíveis. Comparações usam câmeras iguais; legibilidade dirigindo e qualidade artística continuam abertas.
