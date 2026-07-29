# Status

Tags: #GameDev #Execucao #Roadmap #Godot

- Data: 2026-07-29
- Fases concluidas: `Fase 0`, `Fase 1`, `Fase 2` e `Fase 4`
- Fase atual recomendada: `Fase 5 · Recursos e resgate`, com o gate da `Fase 3` (feel de voo) ainda em playtest aberto
- Ultimo marco: combate completo da Fase 4 implementado e verificado por teste headless (3 armas data-driven, mira assistida, 2 tipos de inimigo com maquina de estados, VFX de explosao em camadas, hitstop, HUD de debug)
- Proximo passo: playtestar o combate na arena de 10 alvos, ajustar tuning de armas/inimigos nos `.tres` e so entao abrir a Fase 5
- Risco principal aberto: calibrar peso, derrapagem e yaw do voo (gate da Fase 3) e validar se o AAA gera tensao suficiente sem virar frustracao
- Observacao: `Godot.app` e os `export_templates` 4.7.1 foram instalados no HD externo em `/Volumes/Karine HD Externo`; o `godot` do PATH (Homebrew) tambem e 4.7.1 e foi o usado nesta sessao

## Como validar o projeto

```bash
godot --headless --import                              # reconstroi o cache de classes globais
godot --headless --check-only --quit                   # checagem de sintaxe
godot --headless --script tools/smoke_test.gd          # a cena principal carrega
godot --headless --script tools/combat_smoke_test.gd   # 7 checagens do combate ponta a ponta
godot --headless --quit-after 240                      # boot real com autoloads, 4s sem erro
godot res://tools/capture_screenshot.tscn -- /caminho/saida.png explosao
```

> Rodar `--headless --import` e obrigatorio depois de criar qualquer script novo
> com `class_name`, senao o `--check-only` acusa classe nao encontrada.

## Estado da Fase 4 (combate)

Implementado e coberto por teste:

- 3 armas data-driven em `data/weapons/` (metralhadora hitscan, foguetes com splash, misseis com homing)
- mira assistida em cone de 12 graus com marcador visual no alvo travado
- `Health` + `DamageEvent` compartilhados entre jogador e inimigos
- soldado AK (idle/alert/attack/flee) e canhao AAA (dorme/trava/rajada) em `actors/enemies/`
- projeteis com raycast de segmento, sem tunelamento, com rastro de fumaca
- explosoes em camadas: clarao, bola de fogo, onda de choque, fumaca e destrocos
- hitstop de 2 frames e trauma de camera no abate
- arena de teste com 7 soldados + 3 AAA e HUD de debug (municao, blindagem, score, alvos)

Controles: `W A S D` mover, `Q E` girar, `ESPACO` metralhadora, `F` foguetes,
`R` misseis, `F5` reiniciar. Gamepad mapeado nos mesmos comandos.
