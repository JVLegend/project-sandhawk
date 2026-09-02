# Status

Tags: #GameDev #Execucao #Roadmap #Godot

- Data: 2026-09-02
- Estado: jogo completo publicado (repo publico project-sandhawk, release
  atual v0.2.0 com builds Windows e macOS), campanha de 3 missoes com save,
  bioma por missao via palette/mood no JSON, 6 tipos de inimigo com modelos
  proprios, trilha de 16 bits, minimapa com fog of war
- Ultimo marco: camera afastada para o enquadramento do Desert Strike original
  (tamanho ortografico 50-58); missao 3 "Vigilia Negra" noturna com farol de
  busca no helicoptero (SpotLight sob demanda quando sun_energy < 0.55) e
  fumaca de dano continua na fuselagem (cinza < 45%, preta < 20% de blindagem)
- Proximo passo: playtest de balanceamento com amigos no v0.2.0 (camera nova,
  missao noturna); colher feedback antes de mexer nos numeros
- Performance: ~4,9 ms/frame no M4 com tudo ligado (SSIL desligado por
  medicao: 16% do frame para 0,25% dos pixels). Ver tools/perf_probe.tscn
- Observacao: Godot 4.7.1 via Homebrew no PATH; export templates no HD externo

## Como rodar

```bash
cd project && godot
```

Controles: `W A S D` mover · `Q E` girar · `ESPACO` metralhadora · `F` foguetes ·
`R` misseis · `G` guincho de resgate · `ENTER` avancar telas · `F5` reiniciar.
Gamepad mapeado nos mesmos comandos.

## Como validar

```bash
godot --headless --import                              # reconstroi o cache de classes globais
godot --headless --check-only --quit                   # checagem de sintaxe
godot --headless --script tools/smoke_test.gd          # a cena principal carrega
godot --headless --script tools/combat_smoke_test.gd   # 13 grupos de checagem ponta a ponta
godot --headless --quit-after 300                      # boot real com autoloads, 5s sem erro
godot res://tools/capture_screenshot.tscn -- /caminho/saida.png briefing
```

> Rodar `--headless --import` e obrigatorio depois de criar qualquer script novo
> com `class_name`, senao o `--check-only` acusa classe nao encontrada.

Modos de captura: `briefing`, `arena`, `explosao`, `base`, `zona:<id>`.

## O que existe hoje

### Voo e camera (Fase 3)

Helicoptero com inercia, derrapagem, banking e pitch visuais, rotor principal e de
cauda girando, luzes de navegacao e sombra projetada por `Decal`. Camera isometrica
ortografica com amortecimento critico, look-ahead pela velocidade, zoom por
velocidade e trauma para screen shake. Todo o tuning em `data/flight_tuning.tres`.

### Combate (Fase 4)

Tres armas data-driven em `data/weapons/`: metralhadora hitscan com dispersao,
foguetes com dano em area e misseis com perseguicao. Mira assistida em cone de 12
graus com marcador no alvo. `Health` e `DamageEvent` compartilhados. Projeteis com
raycast de segmento, sem tunelamento. Tres inimigos com maquina de estados: soldado
AK, canhao AAA e lancador SAM, cujo missil e despistavel quebrando a linha de visada.

### Recursos e resgate (Fase 5)

Combustivel com dreno continuo, alarme e queda no zero. Blindagem de 600 sem
regeneracao. Municao por arma. Pickups de combustivel, blindagem e municao.
Guincho de resgate que prende o helicoptero por 4 segundos, com capacidade de 6.
Base amiga que exige pairar sobre o pad e reabastece devagar, criando janela de
vulnerabilidade. Tuning em `data/resource_tuning.tres`.

### Missao (Fase 6)

`MissionManager` le `data/missions/slice_01.json`, que descreve o mapa inteiro:
zonas, estruturas, inimigos, resgatados e pickups. Objetivos de destruir, resgatar
e coletar, com desbloqueio encadeado (o QG so libera depois dos radares). Briefing
com mapa tatico desenhado em runtime e debriefing com tempo contra o par.
Criar missao nova e escrever um JSON, sem tocar em codigo.

### Visual (Fase 7)

Terreno de deserto gerado por ruido com cor por vertice (duna, rocha, cascalho,
argila) e shader proprio de areia com grao, manchas e ondulacoes de vento.
Iluminacao com tonemap ACES, bloom, SSAO, neblina de distancia e sol com sombras
em cascata curta. Helicoptero, radares, QG, canhoes e SAM modelados em codigo.
Explosoes em cinco camadas. Zero asset externo.

### Audio (Fase 8)

16 sons sintetizados amostra por amostra em `audio/audio_synth.gd`: loops de rotor
e turbina com pitch ligado a velocidade, guincho, armas, explosoes por tamanho,
impactos, alarmes e sons de interface. Trilha em duas camadas com crossfade por
"calor de combate". Buses `Master > Music / SFX / UI` com compressor no master.

## Debitos conhecidos

- Balanceamento nao passou por playtest com terceiros
- Vila neutra ainda nao penaliza o jogador que atira nela
- Sem save/checkpoint (previsto para depois do slice)
- Uma unica missao; a campanha e trabalho futuro
