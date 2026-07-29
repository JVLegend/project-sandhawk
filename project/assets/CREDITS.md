# Creditos e licencas de assets

Tags: #GameDev #Licencas #Assets

Todo asset de terceiro usado no jogo esta listado aqui, com origem e licenca.
A regra do projeto e simples: **so entra material CC0 ou de licenca livre
equivalente**, e nada que venha do jogo original ou de qualquer material da EA.

Antes de adicionar qualquer asset novo, registre-o nesta tabela. Se a licenca
exigir atribuicao, ela precisa aparecer tambem na tela de creditos do jogo.

## Texturas

| Arquivo | Origem | Licenca | Atribuicao obrigatoria |
|---|---|---|---|
| `textures/sand_color.jpg` | ambientCG, material `Ground054` | CC0 1.0 (dominio publico) | Nao |
| `textures/sand_normal.jpg` | ambientCG, material `Ground054` | CC0 1.0 (dominio publico) | Nao |
| `textures/sand_roughness.jpg` | ambientCG, material `Ground054` | CC0 1.0 (dominio publico) | Nao |

Origem: https://ambientcg.com/view?id=Ground054

Processamento aplicado: reduzidas de 1K para 512x512 e recomprimidas em JPEG
(qualidade 80 para cor, 88 para normal, 70 para rugosidade). O objetivo foi
manter o repositorio leve: os tres arquivos somam cerca de 300 KB, contra os
4,3 MB dos originais em 1K. A 512 o texel cai perto de 1:1 na tela com a camera
isometrica do jogo, entao nao ha perda visual perceptivel.

Os mapas de deslocamento e oclusao de ambiente do pacote original nao foram
usados e nao estao versionados.

## Fontes

| Arquivo | Origem | Licenca | Atribuicao obrigatoria |
|---|---|---|---|
| `fonts/SairaCondensed-Medium.ttf` | Google Fonts, projeto Saira | SIL Open Font License 1.1 | Nao, mas a licenca deve acompanhar |
| `fonts/SairaCondensed-Bold.ttf` | Google Fonts, projeto Saira | SIL Open Font License 1.1 | Nao, mas a licenca deve acompanhar |
| `fonts/OFL.txt` | Google Fonts, projeto Saira | Texto da licenca | - |

Origem: https://github.com/google/fonts/tree/main/ofl/sairacondensed
Autores: The Saira Project Authors.

A OFL exige que o texto da licenca seja distribuido junto com a fonte: e por
isso que `fonts/OFL.txt` esta versionado e nao deve ser removido. A OFL tambem
proibe vender a fonte isolada e exige nome diferente em versoes modificadas;
nenhuma das duas restricoes afeta o uso aqui, que e embutir a fonte no jogo.

## O que continua 100% autoral

Para deixar claro o que NAO veio de fora:

- todos os modelos 3D (helicoptero, inimigos, estruturas, cenario), gerados em codigo
- todo o audio, sintetizado amostra por amostra em `audio/audio_synth.gd`
- todos os efeitos visuais, o shader de areia e a geracao de terreno
- todo o design de missao, HUD e telas
