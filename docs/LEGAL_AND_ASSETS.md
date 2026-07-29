# Legal and Assets

## Posicionamento do projeto

Este projeto deve ser tratado como:

- reimplementacao inspirada em um classico
- estudo de preservacao de design e mecanicas
- base original de codigo criada do zero

Nao deve ser tratado como redistribuicao do jogo original.

## Regras de ouro

- nao copiar codigo proprietario
- nao commitar ROMs, executaveis ou arquivos de dados proprietarios
- nao distribuir sprites, audio, mapas ou textos do jogo original sem permissao
- usar placeholders proprios durante o desenvolvimento

## Politica de assets

### Fase de prototipagem

- usar assets temporarios autorais
- nomear tudo de modo generico
- validar gameplay sem depender de material protegido

### Fase de referencia interna

Se for necessario estudar comportamento do original:

- trabalhar com material do usuario localmente
- manter qualquer parser/importador desacoplado
- nunca subir os arquivos proprietarios para o repositório

### Fase de distribuicao

Escolher uma das duas estrategias:

1. jogo totalmente original com assets proprios e inspiracao mecanica
2. engine/reimplementation que opcionalmente leia dados fornecidos pelo proprio usuario, se isso for considerado juridicamente aceitavel

## Recomendacao pratica

A rota mais segura para um projeto publico e:

- remake espiritual
- nomes internos proprios quando houver risco de marca
- identidade visual propria
- nenhuma dependencia de assets do original para a versao distribuida

## Riscos

- conflito de copyright por assets ou dados
- conflito de trademark por nome e apresentacao
- escopo preso a "fidelidade literal" em vez de experiencia

## Mitigacao

- documentar referencia sem copiar conteudo
- manter o repo privado ate amadurecer a estrategia
- separar claramente "inspiracao" de "redistribuicao"
- revisar naming do projeto antes de abertura publica
