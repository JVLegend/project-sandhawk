# Plano de Execução · Desert Strike Rebuild com padrão visual/sonoro 2026

> Documento de execução para as próximas sessões de trabalho.
> Cada fase tem: objetivo, specs técnicas, critério "Pronto quando" e um prompt executável
> para colar numa nova sessão do Claude Code. Execute as fases em ordem; não pule o gate.

## Como usar este documento

1. Abra uma sessão nova do Claude Code dentro de `~/Documents/GitHub/desert-strike-rebuild`.
2. Cole o prompt da fase atual (bloco no fim de cada seção).
3. Ao terminar a fase, valide o "Pronto quando" ANTES de avançar.
4. Registre a conclusão em `STATUS.md` na raiz do repo (criado na Fase 0).

Regra de ouro: a sensação de voo é o risco número 1. Nenhum gráfico de 2026 salva um
helicóptero que voa errado. Por isso o plano prova o feel com cubos cinzas antes de
investir em arte.

---

## FASE 0 · Correções imediatas e congelamento de decisões

### Objetivo

Fechar o gate da seção 10 do MASTERPLAN e eliminar os riscos apontados na auditoria
(naming/trademark, decisões soltas em docs).

### Tarefas

1. **Verificar visibilidade do repo.** `gh repo view JVLegend/desert-strike-rebuild --json visibility`.
   Se estiver público, tornar privado até o rename (o próprio LEGAL_AND_ASSETS.md exige isso).
2. **Escolher codinome sem trademark.** "Desert Strike" é marca da EA. Sugestões de codinome
   interno: `Project Sandhawk`, `Dune Rotor`, `Operation Sirocco`. O rename do repo pode
   esperar, mas o nome do jogo dentro do código já nasce com o codinome.
3. **Criar `docs/DECISIONS.md`** com as decisões congeladas:
   - Engine: Godot 4.x (versão estável mais recente no momento da criação do projeto)
   - Linguagem: GDScript para gameplay; C# ou GDExtension só se um profiler provar necessidade
   - Direção visual: definida na Fase 1 deste plano (3D estilizado, ver specs abaixo)
   - Plataforma mínima: macOS (Apple Silicon) + Windows x64; Linux como bônus
   - Política de assets: 100% originais/autorais, zero material da EA no repo
   - Recorte do vertical slice: 1 mapa desértico ~1km², 3 objetivos, 1 opcional,
     3 tipos de inimigo, 1 loop completo de fuel/ammo/armor/resgate
4. **Criar `STATUS.md`** na raiz: fonte de progresso do repo (fase atual, último marco,
   próximo passo). Atualizar ao fim de toda sessão.

### Pronto quando

- [ ] Repo privado (ou já renomeado para codinome)
- [ ] `docs/DECISIONS.md` existe com as 6 decisões acima
- [ ] `STATUS.md` existe e aponta para a Fase 1

### Prompt executável

```text
Leia docs/PLANO_EXECUCAO_2026.md e execute a FASE 0 completa: verifique a visibilidade
do repo com gh, crie docs/DECISIONS.md com as decisões congeladas e STATUS.md na raiz.
Me pergunte apenas qual codinome eu escolho entre as opções sugeridas. Ao final, mostre
o checklist "Pronto quando" validado item a item.
```

---

## FASE 1 · Direção de arte e áudio 2026 (o doc que falta)

### Objetivo

Transformar "gráficos de 2026" em especificação executável. Sem isso, todo asset criado
depois vira retrabalho.

### Decisão visual: recomendação e alternativas

**Recomendado: Opção A · 3D estilizado com câmera isométrica fixa.**

| Critério | A. 3D estilizado isométrico | B. HD-2D (sprites + luz 3D) | C. Pixel art moderna |
|---|---|---|---|
| Leitura "2026" | Alta (luz dinâmica, sombras, VFX) | Alta, mas nichada | Média (retrô intencional) |
| Custo por asset (solo dev) | Médio (modelos low-poly reusáveis) | Alto (sprites em 8 direções) | Alto (frames de animação à mão) |
| Fidelidade ao feel isométrico do original | Alta (câmera controla tudo) | Alta | Alta |
| Animação de helicóptero (banking, rotor) | Grátis via transform 3D | Cara (re-render por pose) | Muito cara |
| Iteração de gameplay | Rápida | Lenta | Lenta |

A Opção A vence porque banking, pitch, rotor e sombras vêm de graça da engine, e é
exatamente nesses detalhes que o jogo vai parecer "de 2026".

### Specs da direção de arte (Opção A)

- **Câmera**: ortográfica (ou perspectiva com FOV ~20° para leve paralaxe), ângulo fixo
  ~45° yaw / ~35° pitch, herdando a leitura do original.
- **Estilo**: low-poly estilizado com materiais PBR simplificados (albedo forte, roughness
  variada, metallic só em veículos). Referências de estilo: militar estilizado tipo
  "toy soldiers realistas", paleta desértica quente (areia, ocre, oliva) com acentos
  saturados para gameplay (vermelho = inimigo/perigo, azul = amigo, amarelo = pickup).
- **Iluminação**: 1 DirectionalLight3D (sol) com sombras, ambiente HDRI de deserto,
  SDFGI ou LightmapGI desligados no protótipo (ligar só no polish).
- **VFX (o que mais grita "2026")**:
  - explosões com GPUParticles3D em camadas (flash + fireball + fumaça + debris + onda de choque via shader)
  - rastros de míssil (Trail/Ribbon), poeira do rotor perto do chão (efeito wash), heat haze via shader de distorção
  - decals de cratera e queimado no terreno
- **Pipeline**: Blender para modelos (exporta glTF), texturas via paleta/gradiente (estilo
  low-poly não exige texturas pintadas), 1 arquivo `.blend` por categoria de asset.
- **Placeholder até a Fase 6**: primitivas Godot (CSGBox) com os MESMOS pontos de pivô e
  dimensões dos modelos finais, para trocar sem quebrar gameplay.

### Specs da direção de áudio

- **SFX**: redesign moderno, não chiptune. Camadas do helicóptero: rotor (loop com pitch
  ligado ao throttle), turbina (loop constante), chop-chop acentuado em banking. Armas com
  camadas corpo + mecânica + cauda (reverb de deserto). Fontes: gravações CC0 (freesound,
  Sonniss GDC packs) + processamento próprio.
- **Música**: trilha dinâmica em 2 camadas (exploração tensa / combate) com crossfade por
  estado de ameaça. Placeholder: faixas CC0; produção própria só depois do vertical slice.
- **Implementação**: AudioStreamPlayer3D para diegéticos (posicional), bus layout:
  `Master > Music / SFX / UI`, compressor leve no Master. FMOD/Wwise NÃO entram: o áudio
  nativo do Godot cobre o escopo.
- **Mix alvo**: rotor do player sempre audível mas nunca dominante (~-18 LUFS de fundo),
  explosões com sidechain duck na música.

### Pronto quando

- [ ] `docs/ART_DIRECTION.md` criado com as specs acima + 5 a 10 imagens de referência linkadas
- [ ] `docs/AUDIO_DIRECTION.md` criado com specs de SFX/música/bus layout
- [ ] Decisão visual registrada em `DECISIONS.md`

### Prompt executável

```text
Leia docs/PLANO_EXECUCAO_2026.md (FASE 1) e crie docs/ART_DIRECTION.md e
docs/AUDIO_DIRECTION.md expandindo as specs do plano. Busque na web 5-10 referências
visuais de jogos isométricos militares estilizados modernos e liste os links. Atualize
DECISIONS.md com a direção visual escolhida (Opção A, 3D estilizado isométrico).
```

---

## FASE 2 · Fundação do projeto Godot

### Objetivo

Projeto Godot 4.x versionado, estruturado e exportando um executável vazio nas 2 plataformas.

### Specs

- Estrutura de pastas (do TECHNICAL_STRATEGY, adaptada para 3D):

```text
project/
  game/          # autoloads: GameState, MissionManager, AudioManager
  actors/        # helicopter/, enemies/, pickups/
  world/         # terrain/, props/, triggers/
  ui/            # hud/, menus/, briefing/
  data/          # .tres ou .json: armas, inimigos, missões, tuning
  vfx/           # cenas de partículas e shaders
  audio/         # sfx/, music/ (só CC0/autoral)
  tools/         # scripts de editor
```

- `project.godot`: renderer Forward+, física a 60 ticks fixos, `Engine.max_fps = 0` com vsync.
- Input map: `move_forward/back/left/right`, `fire_primary/secondary/special`, `winch`,
  `pause`. Suporte a teclado + gamepad desde o dia 1 (o feel de voo pede analógico).
- Export presets macOS + Windows configurados e testados (build vazio abre e fecha).
- `.gitignore` Godot padrão (`.godot/`, builds). CI opcional: GitHub Action que valida
  `godot --headless --check-only` a cada push.

### Pronto quando

- [ ] `godot --headless --check-only` passa
- [ ] Export macOS abre uma cena vazia com céu e chão
- [ ] Estrutura de pastas commitada

### Prompt executável

```text
Leia docs/PLANO_EXECUCAO_2026.md (FASE 2). Verifique se o Godot 4 está instalado
(godot --version); se não estiver, me instrua a instalar via brew. Crie o projeto Godot
na pasta project/ com a estrutura, input map e configurações especificadas. Valide com
godot --headless --check-only e faça um export de teste para macOS.
```

---

## FASE 3 · Protótipo de voo + câmera (o coração do projeto)

### Objetivo

Helicóptero cinza sobre plano cinza que "parece certo" em 30 segundos de controle.

### Specs do controlador de voo (modelo arcade, não simulação)

Estado: posição XZ, altitude Y fixa por enquanto (~12m), yaw, velocidade (Vector2 no plano).

Parâmetros tunáveis (valores iniciais propostos, expostos num `flight_tuning.tres`):

| Parâmetro | Valor inicial | Nota |
|---|---|---|
| `max_speed` | 14 m/s | velocidade de cruzeiro |
| `accel` | 18 m/s² | resposta rápida mas com rampa |
| `decel_drag` | 8 m/s² | soltar o stick NÃO para na hora: derrapa |
| `turn_rate` | 160°/s | yaw responsivo |
| `bank_max` | 25° | roll visual proporcional à velocidade lateral |
| `pitch_max` | 15° | nariz baixa ao acelerar, sobe ao frear |
| `bank_lerp` | 8.0 | suavização do banking (lerp exponencial) |
| `strafe_ratio` | 0.7 | strafe mais lento que avanço, como no original |

Regras de feel:

- movimento relativo ao MUNDO (como o original), não à câmera: 8 direções analógicas + yaw independente no stick direito (ou Q/E)
- banking e pitch são PURAMENTE visuais (mesh filha inclina, colisão não)
- sombra circular projetada no chão (Decal) é a âncora de leitura de altitude
- rotor: mesh girando a ~1500°/s + blur disc quando em velocidade

### Specs da câmera

- Câmera isométrica em rig próprio, seguindo com **amortecimento crítico**
  (`smooth_time ~0.35s`, sem overshoot)
- **Look-ahead**: alvo da câmera = posição do heli + velocidade normalizada * `lookahead`
  (inicial 6m), para o jogador ver para onde voa
- Zoom sutil por velocidade: size ortográfico 22 parado a 26 no max speed, lerp lento
- Screen shake por trauma (0 a 1, decai 1.5/s) para explosões futuras: já deixar o hook

### Pronto quando

- [ ] Voar 60 segundos entre 4 obstáculos é agradável (playtest seu, JV: se não sentir o "peso", ajustar tuning antes de avançar)
- [ ] Nenhum valor de tuning hardcoded no script (tudo no .tres)
- [ ] Vídeo de 30s gravado como registro do marco

### Prompt executável

```text
Leia docs/PLANO_EXECUCAO_2026.md (FASE 3). Implemente o controlador de voo e a câmera
exatamente com as specs e parâmetros do plano, usando CSGBox como helicóptero placeholder
(corpo + cauda + rotor girando) e um plano com grid como chão. Todos os parâmetros num
Resource flight_tuning.tres. Rode o projeto para eu testar o feel e me peça feedback
de tuning antes de encerrar.
```

---

## FASE 4 · Combate: armas, dano e inimigos básicos

### Objetivo

Loop de tiro com as 3 armas clássicas reinterpretadas, contra alvos que reagem.

### Specs de armas (data-driven, 1 `.tres` por arma)

| Arma | Munição inicial | Cadência | Dano | Comportamento |
|---|---|---|---|---|
| Metralhadora | 1178 | 10/s | 1 | hitscan curto (~35m), cone 3°, tracers |
| Foguetes | 38 | 2/s | 8 | projétil rápido reto, splash 3m |
| Mísseis | 7 | 1/1.5s | 40 | projétil com leve homing no alvo mais próximo do cursor de mira |

- Auto-mira assistida: raycast do nariz + snap suave para alvo num cone de 12° (o original
  tinha mira "grudenta"; sem isso o combate isométrico frustra)
- Sistema de dano: componente `Health` (int, sem regen) + `DamageEvent` (valor, tipo, origem)
- Feedback obrigatório por hit: flash branco no mesh (shader), som, número de dano opcional
  (decidir no playtest), hitstop de 2 frames em kill

### Specs de inimigos (Fase 4 usa só os 2 primeiros)

| Inimigo | HP | Arma | Comportamento |
|---|---|---|---|
| Soldado AK | 2 | hitscan fraco, alcance 20m | idle > alert (persegue) > flee com 1 HP |
| AAA (canhão fixo) | 15 | projétil médio, alcance 45m | torre: dorme > trava mira com line-of-sight > dispara em rajadas |
| Lançador SAM (Fase 6) | 25 | míssil homing lento | míssil despistável quebrando line-of-sight ou com flare futuro |

- IA por state machine simples (enum + match), NADA de behavior tree nesta fase
- Spawn via `SpawnVolume` no mundo, definição do inimigo em `data/enemies/*.tres`

### Pronto quando

- [ ] Destruir 10 alvos espalhados é divertido sem nenhum asset final
- [ ] Trocar valores de arma no .tres muda o jogo sem tocar em código
- [ ] AAA cria tensão real (dá para morrer)

### Prompt executável

```text
Leia docs/PLANO_EXECUCAO_2026.md (FASE 4). Implemente as 3 armas data-driven, o sistema
Health/DamageEvent, a auto-mira assistida e os 2 primeiros inimigos com as specs do plano.
Placeholders: caixas coloridas (vermelho inimigo). Inclua os feedbacks de hit obrigatórios.
Ao final me deixe um mapa de teste com 10 alvos para playtest.
```

---

## FASE 5 · Recursos e resgate: a alma do Desert Strike

### Objetivo

O triângulo fuel/ammo/armor + winch de resgate, que transforma tiro em decisão tática.

### Specs

- **Combustível**: tanque 100, dreno 1.0/s em voo (tunável). Abaixo de 25: alarme sonoro +
  HUD pisca. Zero: queda (fade out + respawn na base com penalidade, sem tela de morte
  violenta). Pickup de fuel restaura 50.
- **Blindagem**: 600 HP do heli (números na escala do original). Sem regen. Pickup armor +200.
- **Munição**: pickups por tipo (caixas). Base amiga: pousar num pad (manter posição 2s)
  reabastece TUDO devagar (10s para full), criando janela de vulnerabilidade.
- **Winch/resgate**: segurar botão sobre um POW/piloto abatido: desce cabo (2s), sobe (2s),
  heli vira alvo fácil durante. Capacidade 6 passageiros; entregar na base = pontos + armor bonus.
  É O momento icônico: merece animação e som caprichados na fase de polish.
- **HUD (versão funcional)**: canto inferior: fuel (barra + número), armor (barra),
  munição das 3 armas (números), passageiros (ícones), bússola/indicador de objetivo no topo.
  Estilo visual final só na Fase 7; aqui é legibilidade pura.

### Pronto quando

- [ ] Ficar sem fuel longe da base gera pânico genuíno
- [ ] O jogador escolhe entre "mais um alvo" e "voltar para reabastecer"
- [ ] Resgatar 1 POW sob fogo é o melhor momento do playtest

### Prompt executável

```text
Leia docs/PLANO_EXECUCAO_2026.md (FASE 5). Implemente fuel, armor, munição, pickups,
base amiga com pad de reabastecimento, winch de resgate com POWs e o HUD funcional,
com as specs e números do plano (tudo tunável em .tres). Monte um mapa de teste onde
eu precise gerenciar fuel para completar 2 resgates.
```

---

## FASE 6 · Vertical slice: missão completa

### Objetivo

Uma missão de 8 a 12 minutos, de briefing a debriefing, compartilhável para playtest fechado.

### Specs

- **Formato de missão** `data/missions/slice_01.json`:

```json
{
  "id": "slice_01",
  "name": "Tempestade no Deserto de Ferro",
  "map": "res://world/maps/slice_01.tscn",
  "briefing": ["linhas de texto", "..."],
  "objectives": [
    {"id": "radar", "type": "destroy", "targets": ["radar_1", "radar_2"], "required": true},
    {"id": "pows", "type": "rescue", "count": 4, "required": true},
    {"id": "hq", "type": "destroy", "targets": ["hq"], "required": true, "locked_by": ["radar"]},
    {"id": "intel", "type": "collect", "targets": ["intel_1"], "required": false}
  ],
  "debriefing": {"par_time_sec": 600, "score_rules": "padrao"}
}
```

- `MissionManager` (autoload): carrega JSON, valida, emite `objective_completed`,
  `mission_completed`, `mission_failed` (heli destruído 3x = fail)
- Mapa ~1km²: 1 base amiga, vila neutra (não atirar!), campo de radar, campo de POWs,
  QG inimigo protegido por 2 AAA + 1 SAM, rotas alternativas de aproximação
- Terceiro inimigo entra aqui: lançador SAM (spec na tabela da Fase 4)
- Briefing: tela estática com mapa + texto (estilo tenda militar). Debriefing: score,
  tempo, POWs, precisão

### Pronto quando

- [ ] 3 pessoas jogam a missão sem instrução verbal e terminam
- [ ] Pelo menos 1 playtester tenta a rota "errada" e a missão continua funcionando
- [ ] Score final motiva um segundo run

### Prompt executável

```text
Leia docs/PLANO_EXECUCAO_2026.md (FASE 6). Implemente o MissionManager com o formato
JSON do plano, o inimigo SAM, o mapa do slice com os locais descritos, e as telas de
briefing/debriefing. Placeholders visuais ainda. Ao final valide: consigo completar a
missão de ponta a ponta?
```

---

## FASE 7 · Passe visual 2026

### Objetivo

Substituir todos os placeholders pela direção de arte da Fase 1. É AQUI que o jogo passa a
parecer de 2026, sobre um gameplay já provado.

### Specs (ordem de impacto)

1. **Helicóptero**: modelo low-poly estilizado (Blender, ~3k tris), rotor com blur disc,
   luzes de navegação piscando, trem de pouso
2. **VFX pack**: explosão em camadas (spec da Fase 1), muzzle flash, tracers, trilhas de
   míssil, poeira de rotor perto do chão, heat haze sobre areia
3. **Terreno**: mesh esculpido com 3 materiais blend (areia/rocha/estrada), scatter de props
   (pedras, palmeiras, destroços), decals de cratera dinâmicos
4. **Iluminação e pós**: sol quente ~15h, sombras médias, pós-processo: tonemap ACES,
   bloom sutil, vignette leve, color grade quente. NADA de motion blur
5. **Unidades**: soldados (anim: idle/run/shoot/die via mixamo retarget ou anim própria
   simples), AAA, SAM, prédios da base e QG
6. **HUD estilizado**: visual militar moderno (linhas finas, tipografia stencil, verde-âmbar),
   animações de transição, hit markers
7. **Juice final**: hitstop, screen shake calibrado, rumble de gamepad, câmera kick ao disparar míssil

### Pronto quando

- [ ] Screenshot do jogo impressiona alguém que nunca viu o projeto
- [ ] 0 placeholders visíveis na missão do slice
- [ ] 60 fps estáveis no seu Mac no export release

### Prompt executável

```text
Leia docs/PLANO_EXECUCAO_2026.md (FASE 7) e docs/ART_DIRECTION.md. Vamos executar o passe
visual na ordem de impacto do plano, item por item, começando pelo helicóptero e VFX.
Para modelos 3D, gere e me guie nos passos de Blender quando necessário. Valide fps após
cada item pesado.
```

---

## FASE 8 · Passe de áudio 2026

### Objetivo

Implementar a direção de áudio da Fase 1 sobre o slice pronto.

### Specs

1. Camadas do helicóptero (rotor pitch-linked, turbina, chop em banking) via AudioStreamPlayer3D
2. SFX de armas em camadas + variação (3 samples aleatórios por arma, pitch ±5%)
3. Explosões com camada sub (peso físico) + slap de deserto
4. Trilha dinâmica 2 camadas com crossfade por estado de ameaça (inimigo com line-of-sight = combate)
5. UI sounds discretos, voz de rádio com filtro bandpass para briefing (texto-para-voz aceitável como placeholder)
6. Mix final nos buses com compressor e sidechain (specs da Fase 1)

### Pronto quando

- [ ] Jogar de olhos fechados: dá para saber se está em combate, com fuel baixo, ou perto da base
- [ ] Nenhum asset de áudio sem licença clara (CC0 ou autoral) no repo

### Prompt executável

```text
Leia docs/PLANO_EXECUCAO_2026.md (FASE 8) e docs/AUDIO_DIRECTION.md. Implemente o passe
de áudio completo na ordem do plano. Para SFX, busque fontes CC0 (freesound/Sonniss),
liste cada arquivo com sua licença em audio/CREDITS.md antes de commitar.
```

---

## Riscos e regras permanentes

| Risco | Mitigação |
|---|---|
| Pular o playtest de feel (Fase 3) e ir para arte | O gate é obrigatório: sem "voo bom", não há Fase 4 |
| Escopo crescer ("e se tivesse tanque jogável...") | Tudo que não está no slice vai para `docs/BACKLOG_FUTURO.md` |
| Asset da EA entrar no repo por descuido | Nunca commitar sprites/sons extraídos; CI pode checar extensões suspeitas |
| Nome "Desert Strike" público | Repo privado até rename; codinome no código desde a Fase 0 |
| Burnout de projeto longo | Cada fase termina com algo jogável e um vídeo de marco |

## Ordem resumida (colar no kanban do vault como card único)

Fase 0 decisões > Fase 1 direção arte/áudio > Fase 2 projeto Godot > Fase 3 voo+câmera (GATE) >
Fase 4 combate > Fase 5 recursos+resgate > Fase 6 vertical slice > Fase 7 visual 2026 > Fase 8 áudio 2026.
