# Referências de design — primeira leitura documental, 2026-10-07

Esta etapa traduz a orientação do projeto em decisões verificáveis. Não houve sessão comparativa jogada dos títulos de referência, nem engenharia reversa de seus renderers/física. As receitas para Godot abaixo são propostas para Wave; não descrevem código interno dos jogos.

| Referência | Princípio adotado | Experimento no Wave |
| --- | --- | --- |
| Most Wanted **2005**, EA Black Box | Curvas legíveis, velocidade perceptível, frenagem/derrapagem acessíveis e atmosfera de fim de tarde | Manter controlador, testar três velocidades, ajustar câmera/FOV e ritmo de objetos; avaliar diversão antes de migração física |
| Test Drive Unlimited **2006** | Prazer da viagem e continuidade entre paisagens/destinos | Caminho da Serra mantém um carro e uma sessão entre quatro usos do território; próxima prova inclui alternativa e destino reconhecível |
| San Andreas **2004** | Identidade por região, horizonte e escala com detalhe seletivo | Massas distantes/HLOD e kit compartilhado; medir CPU/GPU/residência, sem tentar copiar a tecnologia original |
| Midnight Club 3 / Underground 2 | Escolhas de rota, atalhos e serviços/progressão automotivos | Laterais e refúgios antes de garagem; não introduzir tuning/progressão nesta prova de streaming |
| Burnout Paradise | Atividades integradas à exploração | Futura atividade ponto a ponto sobre rede viária/checkpoints existentes; não construir outro sistema de mapas |
| 171 | Ambiente urbano brasileiro observado | Uso e proporções de comércio, calçadas, muros, portões, fios e vegetação; nenhuma mecânica de ação/crime entra no escopo |

O [manual da EA de Most Wanted Black Edition (2005), preservado em reprodução](https://www.videogamemanual.com/PS2/Need%20for%20Speed-%20Most%20Wanted%20%28Black%20Edition%29%20%28USA%29.pdf) identifica o título de referência. Páginas modernas da EA com “Most Wanted” frequentemente descrevem a versão de **2012**; não usar requisitos ou comportamento daquela versão para justificar decisões sobre 2005. Atmosfera e sensação descritas aqui são intenção artística do projeto e precisam de comparação humana, não foram medidas a partir do manual.

O [manual oficial de Burnout Paradise Remastered](https://eaassets-a.akamaihd.net/eahelp/manuals/burnout-paradise-remastered-manual_switch_en-gb.pdf), nas seções Freeburn e Events, descreve descoberta de atalhos, início de eventos em cruzamentos e provas ponto a ponto sem rota fixa. A proposta de integrar atividades às ruas do Wave deriva desses princípios; não prevê takedowns, dano ou boost nesta etapa. [Material de suporte da Rockstar para Midnight Club 3](https://support.rockstargames.com/articles/50ixFXwl1jsgSGRhUfgdSG/game-tips-for-midnight-club-3-dub-edition) e [apresentação oficial de 171 na comunidade Steam](https://steamcommunity.com/app/1269370?l=brazilian) são referências documentais adicionais. Não foram baixados assets desses títulos.

## Tradução técnica para Compatibility

A [documentação oficial de carregamento em background](https://docs.godotengine.org/en/stable/tutorials/io/background_loading.html) diferencia solicitar/consultar estado/obter recurso; obter antes de concluir pode bloquear. O loader existente já respeita essa sequência e é reaproveitado. Instanciação/anexação/upload continuam custos a medir, sem promessa de assíncrono completo.

[MultiMesh](https://docs.godotengine.org/en/stable/classes/class_multimesh.html) agrupa desenho e exige bounds que representem as instâncias. No Wave, lotes espaciais e `BakedMultiMesh` preservam os transforms/AABBs salvos, incluindo cards orientados à câmera. Quantidade reduzida de lotes não comprova ganho de FPS por si só. Os [intervalos de visibilidade/HLOD](https://docs.godotengine.org/en/stable/tutorials/3d/visibility_ranges.html) permitem simplificação; aqui o sistema existente separa visibilidade de residência/colisão e usa histerese.

Próxima avaliação de referência: dirigir os títulos disponíveis legalmente em percursos comparáveis, registrar respostas de câmera, curvas e ritmo urbano/rural; documentar observações qualitativas separadas de medidas do Wave. Esse estudo permanece aberto. Não atribuir resultados visuais ou desempenho ao algoritmo de um jogo sem fonte/evidência.
