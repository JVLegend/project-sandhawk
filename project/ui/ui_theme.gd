class_name UiTheme
extends RefCounted

## Tema de interface aplicado em runtime, na raiz da arvore.
##
## Nao usa `gui/theme/custom_font` do project.godot de proposito: aquele caminho
## e resolvido no boot, antes do import rodar, e num clone novo o engine falha
## ao abrir com "No loader found for resource". Instalando por codigo, a fonte
## so e pedida quando a cena ja esta viva e o recurso ja existe.
##
## Fonte: Saira Condensed (SIL Open Font License 1.1). Ver assets/CREDITS.md.

const FONT_REGULAR := preload("res://assets/fonts/SairaCondensed-Medium.ttf")
const FONT_BOLD := preload("res://assets/fonts/SairaCondensed-Bold.ttf")

const DEFAULT_FONT_SIZE := 14

## Tipos de controle usados pelo jogo. Precisam de entrada explicita: o tema
## embutido do engine ja define fonte para eles, e `Theme.default_font` sozinho
## perde a disputa na busca. Entrada por tipo, no tema da raiz, vence.
const STYLED_TYPES := ["Label", "Button", "RichTextLabel", "LineEdit"]


## Aplica o tema no Control raiz de uma camada.
##
## Necessario porque CanvasLayer INTERROMPE a propagacao de tema no Godot 4:
## o tema da janela raiz nao alcanca Controls dentro de um CanvasLayer, e eles
## caem no tema embutido do engine. Cada HUD/tela precisa receber o tema no
## proprio Control de topo, que ai sim propaga para os filhos.
## Um Theme por tela em vez de um cache estatico: `static var` segura o recurso
## ate o fim do processo e aparece como instancia vazada no encerramento. O
## objeto e minusculo e existem tres telas, entao nao ha ganho em cachear.
static func apply(control: Control) -> void:
	if control != null:
		control.theme = build()


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font = FONT_REGULAR
	theme.default_font_size = DEFAULT_FONT_SIZE

	for type_name in STYLED_TYPES:
		theme.set_font("font", type_name, FONT_REGULAR)

	return theme


static func install(tree: SceneTree) -> void:
	if tree == null or tree.root == null:
		return
	tree.root.theme = build()


## Titulos e numeros grandes ganham o peso bold.
static func apply_bold(control: Control) -> void:
	if control != null:
		control.add_theme_font_override("font", FONT_BOLD)
