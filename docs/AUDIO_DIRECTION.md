# Audio Direction

Tags: #GameDev #Audio #SFX #Godot

## Tese sonora

O audio deve vender massa, perigo e velocidade. O helicoptero do jogador precisa soar presente o tempo inteiro, mas nunca mascarar informacao de combate.

## Direcao geral

- Nada de chiptune
- Nada de nostalgia sonora literal
- Redesign moderno com foco em camadas, espacializacao e mix limpo
- Prioridade para legibilidade: o jogador deve distinguir seu rotor, fogo inimigo, explosao, pickup e objetivo sem confusao

## Helicoptero do jogador

### Camadas

- `rotor_loop`: loop principal com pitch e volume reagindo ao throttle/velocidade
- `turbine_loop`: base constante de motor
- `bank_whip`: acento curto em manobras fortes
- `near_ground_wash`: camada de wash/poeira quando perto do solo

### Regras

- rotor sempre audivel
- turbina preenche o corpo do som
- banking adiciona agressividade sem parecer arcade cartunesco

## Armas

### Metralhadora

- corpo seco
- camada mecanica
- cauda curta com reflexao desertica

### Foguetes

- saida impulsiva
- rastro mais "rasgado"
- impacto com grave curto e debris

### Misseis

- launch mais sofisticado
- sustain com assobio controlado
- impacto mais largo e premium do arsenal

## Explosoes e impactos

- explosao sempre em camadas: flash, corpo, debris, fumaca
- impacto de blindado precisa soar diferente de impacto em estrutura leve
- kills importantes podem usar micro hitstop sonoro via ducking momentaneo

## Musica

- 2 camadas principais
- `exploracao_tensa`
- `combate`
- transicao por crossfade conforme estado de ameaca

### Fase atual

- placeholder com trilhas `CC0`
- composicao original so depois do vertical slice

## Implementacao tecnica

- `AudioStreamPlayer3D` para elementos diegeticos
- `AudioStreamPlayer` para musica e UI
- buses:
  - `Master`
  - `Music`
  - `SFX`
  - `UI`

## Mix alvo

- rotor do player sempre presente, mas abaixo dos eventos de maior urgencia
- alvo de fundo sugerido para o rotor: `~ -18 LUFS percebido`
- explosoes grandes fazem duck leve na musica
- UI nunca compete com combate

## Efeitos de mix e processamento

- compressor leve no `Master`
- ducking simples da musica acionado por barramento de SFX de alta prioridade
- low-pass ou rolloff leve por distancia nos eventos 3D
- reverb curto e seco, sugerindo vastidao desertica sem lavar o mix

## Fontes de placeholder

- efeitos `CC0` e bibliotecas livres
- gravacao/processamento proprio quando possivel
- manter planilha ou nota de proveniencia de todo audio usado

## O que define sucesso desta direcao

- o helicoptero soa prazeroso por si so
- cada arma tem assinatura propria
- o campo de batalha parece vivo mesmo com placeholder art
- musica sustenta tensao sem engolir informacao tatica
