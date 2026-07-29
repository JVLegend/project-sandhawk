# Asset Storage

## O que sobe no GitHub

Suba no repositório apenas assets já prontos para rodar no jogo:

- texturas finais otimizadas
- sprites finais usados em runtime
- áudio final compactado
- dados `.tres`, `.tscn`, `.json`, scripts `.gd`

Regra prática:

- se o arquivo é necessário para abrir e jogar o projeto, ele pode entrar no repo
- se é fonte pesada de trabalho, referência, export intermediário ou build final, ele fica fora do repo

## O que não deve subir

Evite versionar no GitHub:

- arquivos-fonte pesados como `.psd`, `.kra`, `.blend`
- texturas enormes em resolução bruta
- gravações de captura
- builds exportadas
- pacotes `.zip` e backups manuais
- referências visuais baixadas

## Onde salvar os itens pesados

Caminho sugerido no seu HD externo:

`/Volumes/Karine HD Externo/DesertStrikeAssets/`

Estrutura sugerida:

- `/Volumes/Karine HD Externo/DesertStrikeAssets/textures_raw/`
- `/Volumes/Karine HD Externo/DesertStrikeAssets/source_art/`
- `/Volumes/Karine HD Externo/DesertStrikeAssets/audio_raw/`
- `/Volumes/Karine HD Externo/DesertStrikeAssets/reference/`
- `/Volumes/Karine HD Externo/DesertStrikeAssets/captures/`
- `/Volumes/Karine HD Externo/DesertStrikeAssets/build_exports/`

## Pastas locais já ignoradas

Se você preferir trabalhar com material pesado ao lado do projeto sem subir para o GitHub, estas pastas estão ignoradas pelo `.gitignore`:

- `project/assets_raw/`
- `project/textures_hd/`
- `project/audio_raw/`
- `project/reference_media/`
- `project/exports_raw/`

## Fluxo recomendado

1. Crie ou guarde o material bruto no HD externo.
2. Exporte a versão final otimizada.
3. Copie só o asset final para dentro do projeto, em uma pasta versionada de runtime.
4. Commit apenas do que o jogo realmente usa.

## Se você quiser versionar arquivos grandes mesmo assim

Use Git LFS para fontes pesadas que realmente precisem de histórico no GitHub. Para este projeto, eu manteria isso como exceção, não como padrão.
