# Desert Strike Rebuild

Remake espiritual e estudo de reimplementacao moderna inspirado em `Desert Strike`, com foco em preservacao, engenharia reversa limpa e executavel nativo para desktop.

## Status

Planejamento ativo.

Este repositório foi criado para organizar a estrategia do projeto, documentar riscos, definir arquitetura e preparar um roadmap de execucao. Nenhuma implementacao do jogo foi iniciada neste momento.

## Objetivo

Construir uma base segura para um remake moderno que:

- preserve a sensacao de voo, missao e leitura tatica do jogo original
- rode nativamente em macOS, Windows e Linux
- mantenha separacao estrita entre codigo novo e assets proprietarios
- permita evoluir de um prototipo para um vertical slice e depois para uma experiencia completa

## Principios

- Clean-room reimplementation: nenhum codigo proprietario sera copiado
- Asset separation: qualquer suporte a dados originais sera opcional e desacoplado
- Playability first: foco inicial em sensacao de controle, camera, combate e loop de missao
- Preservation mindset: documentar mecanismos, formatos e comportamento antes de reescrever
- Vertical slice before scale: provar uma fase curta e divertida antes de ampliar escopo

## Estrutura

- `docs/MASTERPLAN.md`: plano mestre, fases, trilhas de trabalho, riscos e criterios de sucesso
- `docs/TECHNICAL_STRATEGY.md`: stack recomendada, opcoes avaliadas e ordem de execucao tecnica
- `docs/LEGAL_AND_ASSETS.md`: guardrails legais, politica de assets e limites do projeto
- `.github/ISSUE_TEMPLATE/`: templates para backlog de pesquisa e milestones futuros

## Resultado esperado desta fase

Ao final da fase de planejamento, o projeto deve ter:

- escopo inicial aprovado
- direcao tecnica definida
- backlog da fase 1 priorizado
- criterio claro para inicio da implementacao

## Fora de escopo por enquanto

- portar fielmente todos os assets originais
- distribuir ROMs, executaveis ou dados proprietarios
- implementar campanha completa antes de validar um vertical slice
