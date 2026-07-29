# Art Direction

Tags: #GameDev #ArtDirection #3D #Godot

## Tese visual

`Project Sandhawk` deve parecer um jogo militar moderno com leitura arcade impecavel. A referencia nao e simulacao militar suja nem nostalgia pixelada. A meta e um visual estilizado, limpo, dramatico e imediatamente legivel de cima, em que:

- o helicoptero tem presenca e peso
- o terreno comunica rota e perigo
- explosoes, rastros e poeira vendem o "2026"
- o jogador entende inimigo, aliado e pickup em menos de um segundo

## Escolha visual congelada

- Direcao aprovada: `Opcao A · 3D estilizado com camera isometrica fixa`
- Engine-alvo: `Godot 4.7.1`
- Stack de assets: `Blender -> glTF -> Godot`

## Camera

- Modo principal: ortografico
- Alternativa aceitavel para testes: perspectiva com `FOV ~20°` se a paralaxe ajudar leitura
- Angulo-alvo inicial: `~45° yaw / ~35° pitch`
- Regras:
  - camera fixa no mundo
  - look-ahead baseado na velocidade do helicoptero
  - zoom discreto por velocidade
  - sem movimentos cinematograficos que atrapalhem o controle

## Linguagem de formas

### Helicoptero

- Silhueta forte e compacta
- Fusolagem principal simples, cauda fina, rotor legivel
- Banking e pitch precisam ser claramente visiveis de longe
- A sombra no chao e parte da leitura, nao apenas detalhe

### Veiculos e inimigos

- Volumes grandes, identificaveis por silhouette first
- Pouca microgeometria
- Torres, canhoes e radares devem ser legiveis no angulo isometrico
- Evitar excesso de detalhes horizontais que somem de cima

### Cenario

- Desertico, quente, seco, com contraste entre areia aberta, rocha, estrada, base e estruturas humanas
- Props com funcao visual: cobertura, choke point, landmark, pickup cue, objective cue
- O terreno nunca deve parecer um tapete marrom uniforme

## Materiais

- PBR simplificado
- `albedo` forte e limpo
- `roughness` como principal separador de materiais
- `metallic` usado com parcimonia, focado em veiculos e partes militares
- Evitar texturas ruidosas demais; preferir grandes massas de cor e desgaste seletivo

## Paleta

### Base

- areia clara
- ocre queimado
- marrom mineral
- oliva dessaturado
- cinza quente para metal

### Gameplay accents

- vermelho: inimigo e perigo
- azul/ciano: amigo, base ou zona segura
- amarelo/ambar: pickup e interacao util
- branco: hit feedback e flashes de explosao

## Iluminacao

- 1 `DirectionalLight3D` como sol principal
- Sombras ativas desde o prototipo
- Ambiente HDRI desertico
- `SDFGI` e `LightmapGI` desligados nas fases iniciais
- Meta: contraste claro entre volume iluminado e sombra, sem perder leitura das unidades

## VFX

### Obrigatorios

- explosao multicamada com `GPUParticles3D`
- trilha de missil com ribbon/trail
- poeira de rotor perto do solo
- heat haze leve em eventos de explosao forte
- decal de queimado/cratera no terreno

### Filosofia

O projeto deve parecer moderno mais por:

- camadas de VFX
- timing de luz
- reacao de camera
- sombras e atmosfera

do que por hiper-realismo de modelagem.

## Placeholder policy

Ate a Fase 6, placeholders devem:

- usar primitivas da Godot ou meshes simples do Blender
- manter pivots, bounding boxes e escala final aproximada
- trocar para o asset final sem quebrar gameplay ou colisao

## UI e leitura

- HUD com contraste alto e poucas cores-chave
- alvos e pickups reforcados por cor, icone e composicao
- evitar poluicao visual cyberpunk; o mundo e desertico, a clareza precisa dominar a fantasia

## Pipeline

- 1 arquivo `.blend` por categoria de asset
- export via `glTF`
- nomes de assets baseados no codinome do projeto, nao em IP de terceiros
- variacoes por material/cor antes de variacoes por modelagem

## Lista de referencias visuais

Estas referencias servem para estudar camera, silhouette, VFX, leitura tatica e densidade de detalhe. Nao servem para copiar identidade.

1. Godot Engine 4.7.1 para target visual/tecnico de renderer: https://godotengine.org/download/archive/
2. Brigador: Up-Armored Edition: https://store.steampowered.com/app/274500/Brigador_UpArmored_Edition/
3. Thunder Tier One: https://store.steampowered.com/app/377300/Thunder_Tier_One/
4. Door Kickers 2: Task Force North: https://store.steampowered.com/app/1239080/Door_Kickers_2_Task_Force_North/
5. Red Solstice 2: Survivors: https://store.steampowered.com/app/768520/Red_Solstice_2_Survivors/
6. War Mongrels: https://store.steampowered.com/app/1101790/War_Mongrels/
7. SYNTHETIK 2: https://store.steampowered.com/app/1471410/SYNTHETIK_2/
8. Foxhole: https://store.steampowered.com/app/505460/Foxhole/
9. The Ascent: https://store.steampowered.com/app/979690/The_Ascent/
10. HELLDIVERS Dive Harder Edition: https://store.steampowered.com/app/394510/HELLDIVERS_Dive_Harder_Edition/

## O que absorver de cada referencia

- `Brigador`: destruicao, luz urbana dramatica, silhueta forte
- `Thunder Tier One`: legibilidade militar top-down e escala de props
- `Door Kickers 2`: clareza tatico-operacional e color coding
- `Red Solstice 2`: tensao, fog, VFX e leitura de squad combat
- `War Mongrels`: composicao isometrica e cobertura
- `SYNTHETIK 2`: punch visual de armas, muzzle flashes, ritmo de feedback
- `Foxhole`: leitura de terreno, estradas e infraestrutura militar
- `The Ascent`: densidade de VFX e camada de atmosfera
- `HELLDIVERS`: caos controlado, telemetria visual e explosividade
