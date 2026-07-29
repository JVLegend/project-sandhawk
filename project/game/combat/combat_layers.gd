class_name CombatLayers
extends RefCounted

## Camadas de colisao do jogo. Centralizadas aqui para evitar numeros magicos
## espalhados pelos atores, armas e projeteis.

const WORLD := 1 << 0
const PLAYER := 1 << 1
const ENEMY := 1 << 2
const PLAYER_SHOT := 1 << 3
const ENEMY_SHOT := 1 << 4

## Tiro do jogador atinge cenario e inimigos.
const PLAYER_SHOT_MASK := WORLD | ENEMY

## Tiro inimigo atinge cenario e o jogador.
const ENEMY_SHOT_MASK := WORLD | PLAYER

## Consulta de linha de visada: so o cenario bloqueia.
const LINE_OF_SIGHT_MASK := WORLD
