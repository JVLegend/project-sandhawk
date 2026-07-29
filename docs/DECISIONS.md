# Decisions

Tags: #GameDev #Remake #Godot #Planejamento

## Estado

Decisoes congeladas para destravar a implementacao inicial.

## Decisoes ativas

### 1. Codinome interno

- Codinome provisório: `Project Sandhawk`
- Motivo: evita nascer com naming ligado a marca registrada de terceiros
- Observacao: o repositório remoto continua privado e pode ser renomeado depois sem impacto tecnico

### 2. Engine

- Engine escolhida: `Godot 4.7.1`
- Base da escolha: versao estavel atual em 29 de julho de 2026
- Racional: ciclo rapido de prototipagem, export desktop simples e melhor custo/beneficio para validar o feel de voo

### 3. Linguagem

- Linguagem principal: `GDScript`
- Escalada permitida: `C#` ou `GDExtension` apenas se profiler provar gargalo real

### 4. Direcao visual

- Direcao escolhida: `Opcao A · 3D estilizado com camera isometrica fixa`
- Principio: parecer 2026 via luz, camera, sombra, VFX e leitura limpa, sem depender de fidelidade literal ao original

### 5. Plataforma minima

- `macOS (Apple Silicon)`
- `Windows x64`
- `Linux` entra como bonus, nao como gate inicial

### 6. Politica de assets

Revisada em 29/07/2026. A regra anterior era `100% originais/autoria propria no
repositório`. Ela foi flexibilizada para permitir material de licenca livre,
mantendo intacto o objetivo original, que e nao carregar risco de copyright.

- Zero codigo, arte, audio, mapas ou dados proprietarios da EA versionados no repo
- Assets de terceiros sao permitidos **apenas** sob CC0 ou licenca livre
  equivalente (OFL para fontes). Nada de CC-BY-NC, "free for personal use" ou
  licenca ambigua
- Todo asset de terceiro entra registrado em `project/assets/CREDITS.md`, com
  origem, licenca e se exige atribuicao
- Modelos 3D, audio, VFX e shaders continuam autorais e gerados em codigo. O
  material externo entra so como textura e tipografia, que sao caros de produzir
  e baratos de licenciar limpo

Racional da mudanca: a politica antiga protegia contra o risco certo (EA), mas
tambem barrava dominio publico, que nao oferece risco nenhum. Texturas PBR e uma
fonte condensada dao um salto de qualidade visual que nao se consegue apenas com
geracao procedural, e CC0/OFL sao redistribuiveis inclusive em produto comercial.

### 7. Recorte do vertical slice

- 1 mapa desertico de aproximadamente `1 km²`
- 3 objetivos principais
- 1 objetivo opcional
- 3 tipos de inimigo
- 1 loop completo de `fuel/ammo/armor/resgate`

### 8. Definicao operacional de "fiel o bastante"

O projeto nao busca copiar o original byte a byte. A fidelidade inicial sera julgada por:

- helicoptero com peso, inercia e resposta satisfatorios em menos de 30 segundos
- camera que antecipa direcao e favorece leitura tatica
- combate com tensao de recursos
- missao curta que mistura rota, ataque e retorno em vez de apenas tiro

## Guardrails

- O codinome deve ser usado em nomes internos de jogo, cenas, branding e UI enquanto o repo permanecer privado
- O nome comercial final so deve ser decidido depois de validar estrategia legal e identidade propria
