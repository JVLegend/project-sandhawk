# Technical Strategy

## Recomendacao principal

Construir o remake com `Godot 4.x` para acelerar prototipagem, gameplay iteration e distribuicao desktop.

## Por que Godot

- scene system agil para gameplay e UI
- 2D robusto o bastante para isometria e sprites
- editor acelera iteracao em missoes
- export multiplataforma simples
- custo de onboarding menor do que C++/SDL puro
- stack ideal para vertical slice rapido

## Alternativas avaliadas

### Opcao A. C++ com SDL2/SDL3

Vantagens:

- maximo controle
- mais proximo de um engine clone tradicional
- bom para preservacao tecnica detalhada

Desvantagens:

- custo alto de tooling
- loop de iteracao mais lento
- mais tempo em infraestrutura antes de provar gameplay

Uso recomendado:

- ferramentas auxiliares
- importadores
- experimentos de engenharia reversa

### Opcao B. Unity

Vantagens:

- ecossistema maduro
- ferramentas de produtividade

Desvantagens:

- overhead maior para um projeto de preservacao enxuto
- menos atraente para um repositorio autoral e de longo prazo

### Opcao C. Godot

Vantagens:

- equilibrio forte entre rapidez e controle
- projeto leve e amigavel para repositorio limpo
- excelente para vertical slice e gameplay tuning

Desvantagens:

- talvez exigir componentes customizados para sorting e camera exatamente como queremos

## Estrategia tecnica por camadas

### Camada 1. Core gameplay

- helicopter controller
- modelo de dano
- armas
- pickups
- mission state machine

### Camada 2. Mundo

- tilemap ou chunks simples
- obstaculos
- bases amigas
- spawn volumes
- trigger zones

### Camada 3. Visual

- camera
- HUD
- efeitos
- sombras
- feedback de hit

### Camada 4. Dados

- definicoes de inimigos em data files
- definicoes de armas
- configuracao de missoes
- tuning files separados do codigo

## Ordem de implementacao futura

1. prototipo de movimento
2. camera com look-ahead
3. arena pequena
4. armas e alvos
5. recursos e pickups
6. objetivos e fluxo de missao
7. HUD e briefing

## Ferramentas recomendadas

- engine: `Godot 4.x`
- controle de versao: `git` + GitHub
- planejamento: markdown no proprio repo
- assets placeholder: vetorial simples e sprites temporarios proprios
- audio placeholder: efeitos autorais ou livres

## Arquitetura de codigo sugerida

- `game/`: regras de gameplay
- `world/`: mapa, triggers e spawn
- `actors/`: helicoptero, inimigos, pickups
- `ui/`: HUD, menus, briefing
- `data/`: configuracoes e definicoes
- `tools/`: importadores e utilitarios

## Decisao recomendada

Se a meta principal for "ter algo jogavel no computador no menor tempo com boa fidelidade de sensacao", a melhor escolha e `Godot`.

Se a meta mudar para "recriacao tecnica o mais proxima possivel da implementacao historica", vale abrir uma trilha paralela de ferramentas em `C++`.
