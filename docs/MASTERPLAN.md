# Master Plan

## 1. Visao do projeto

Criar um remake moderno inspirado em `Desert Strike` que reproduza o sentimento central do original:

- helicoptero com inercia e peso
- combate tatico em mapa aberto
- gestao de combustivel, blindagem e municao
- objetivos encadeados com liberdade parcial de abordagem
- leitura clara de terreno, ameaças e rotas

O alvo inicial nao e "clonar tudo". O alvo e reconstruir o nucleo jogavel com qualidade suficiente para validar que o projeto merece escalar.

## 2. Objetivo macro

Entregar um produto nativo de desktop dividido em fases:

1. pesquisa e preservacao
2. prototipo de voo e camera
3. vertical slice de uma missao curta
4. pipeline de conteudo e ferramentas
5. expansao para campanha e polimento

## 3. Trilha de execucao

### Fase 0. Fundacao

Objetivo:
alinhar escopo, arquitetura, guardrails legais e metodo de trabalho.

Entregaveis:

- repositorio estruturado
- documentos de estrategia
- backlog inicial
- definicao de ferramentas

Critério de saida:

- decisao de engine aprovada
- definicao de plataforma minima
- recorte do vertical slice aprovado

### Fase 1. Pesquisa e referencia

Objetivo:
entender profundamente o original sem depender de codigo proprietario.

Frentes:

- capturar videos e frame study do jogo original
- mapear HUD, camera, velocidade, turning radius e comportamento de armas
- analisar formatos de dados e ferramentas existentes
- catalogar mecanicas obrigatorias e desejaveis

Entregaveis:

- biblia de referencia jogavel
- matriz de mecanicas
- lista de sistemas por prioridade

Risco principal:

- confundir fidelidade emocional com copia literal

### Fase 2. Prototipo do core loop

Objetivo:
validar movimento, camera e combate basico.

Sistemas minimos:

- movimentacao do helicoptero
- aim/fire basico
- camera com atraso e amortecimento
- sistema de dano simples
- pickups de combustivel e municao
- inimigo terrestre simples

Critério de saida:

- playtest de 3 a 5 minutos divertido sem conteudo final

### Fase 3. Vertical slice

Objetivo:
criar uma missao curta completa de ponta a ponta.

Escopo sugerido:

- um mapa pequeno
- briefing e debriefing simples
- 3 objetivos principais
- 1 objetivo opcional
- 3 tipos de inimigo
- 1 loop completo de abastecimento/rearm

Critério de saida:

- demonstracao compartilhavel para playtest fechado

### Fase 4. Pipeline e ferramentas

Objetivo:
reduzir custo de producao antes de escalar conteudo.

Sistemas:

- editor de missao ou formato de missao legivel
- pipeline de sprites, tiles e efeitos
- serializacao de dados de inimigos, pickups e objetivos
- telemetria simples para balanceamento

Critério de saida:

- adicionar conteudo novo sem alterar codigo central toda hora

### Fase 5. Escala controlada

Objetivo:
expandir missoes, inimigos, narrativa, audio e polimento.

Prioridades:

- campanha curta antes de campanha longa
- UX de HUD e briefing
- audio diegetico e feedback de armas
- save/checkpoint

## 4. Workstreams

### A. Gameplay

- fisica arcade do helicoptero
- combate e lock de armas
- IA basica terrestre
- recursos e pickups
- objetivos e scripting

### B. Rendering e camera

- tilemap/isometria
- sorting de sprites
- camera com look-ahead
- sombras e legibilidade
- efeitos de explosao e fumaca

### C. Conteudo e design

- topologia de mapa
- ritmo de missao
- visibilidade do jogador
- risco vs recompensa
- tuning de recursos

### D. Ferramentas e dados

- formatos de missao
- loaders
- importacao de assets originais apenas para referencia interna, se necessario
- pipeline de assets substitutos

### E. Legal e distribuicao

- politica de nao distribuir assets proprietarios
- versao jogavel com assets originais do usuario apenas se juridicamente aceitavel
- opcao paralela de assets totalmente originais

## 5. Recomendacao de recorte inicial

O projeto deve comecar pequeno:

- 1 helicoptero jogavel
- 1 arena desertica pequena
- 1 base amiga
- 3 tipos de alvo inimigo
- 1 loop de combustivel, municao e dano
- 1 missao curta com inicio, meio e fim

Tudo fora disso entra depois da validacao do vertical slice.

## 6. Criterios de sucesso

- controle do helicoptero "parece certo" em menos de 30 segundos
- jogador entende HUD e objetivo sem explicacao longa
- combate tem tensao de recursos
- mapa incentiva rota e decisao, nao apenas tiro
- sessao curta gera vontade de jogar outra vez

## 7. Riscos centrais

- escopo amplo demais cedo demais
- tentativa de reproduzir 100% do original antes de validar o fun factor
- dependencia de assets proprietarios
- toolchain pesada antes de provar o gameplay

## 8. Mitigacoes

- vertical slice como gate obrigatorio
- backlog por prioridade MoSCoW
- assets placeholder desde o dia 1 de implementacao
- milestones curtos com playtest real

## 9. Estimativa de esforco

Estimativa qualitativa, nao compromisso:

- Fase 0-1: baixa a media complexidade
- Fase 2: media complexidade
- Fase 3: media a alta complexidade
- Fase 4-5: alta complexidade

O maior risco tecnico nao esta no render. Esta na combinacao de sensacao de voo, camera, leitura de mapa e pacing de missao.

## 10. Gate para iniciar desenvolvimento

O codigo so deve comecar quando existir consenso sobre:

- engine escolhida
- escopo do vertical slice
- politica de assets
- meta de plataforma
- definicao do que significa "fiel o bastante"
