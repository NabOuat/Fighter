class_name StoryPanels
extends MenuScreen
## Les cases de BD racontées par le griot (une étape « panels » d'un chapitre).
##
## Chaque case : l'image dans un cadre doré et le texte du griot qui s'écrit
## lettre par lettre. Toucher l'écran (ou Attaque / Entrée) : finit d'écrire le
## texte, puis passe à la case suivante. Après la dernière : l'étape suivante du
## chapitre (un combat, ou la carte si le chapitre est fini).
## Une case pas encore dessinée s'affiche comme une carte avec le titre du chapitre.

## Vitesse d'écriture du texte (lettres par seconde).
const LETTERS_PER_SECOND := 45.0
## Durée de l'apparition d'une case.
const FADE_TIME := 0.3

var panels: Array = []
var index := 0
## Le texte n'est pas encore entièrement écrit.
var typing := false

var _tween: Tween

@onready var frame: PanelContainer = %Frame
@onready var image: TextureRect = %Image
@onready var placeholder: Label = %Placeholder
@onready var text_label: Label = %Text
@onready var skip_button: Button = %SkipButton


func _ready() -> void:
	skip_button.pressed.connect(finish)
	panels = GameState.story.current_step().get("panels", [])
	if panels.is_empty():
		finish.call_deferred()
		return
	show_panel(0)


func show_panel(i: int) -> void:
	index = i
	var info := StoryData.panel_info(panels[i])
	var has_image := ResourceLoader.exists(info.image)
	image.texture = load(info.image) if has_image else null
	placeholder.visible = not has_image
	placeholder.text = tr(GameState.story.current_chapter().get("title", ""))
	text_label.text = tr(info.text)
	text_label.visible_ratio = 0.0
	typing = true
	frame.modulate.a = 0.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(frame, "modulate:a", 1.0, FADE_TIME)
	_tween.parallel().tween_property(text_label, "visible_ratio", 1.0,
			text_label.text.length() / LETTERS_PER_SECOND)
	_tween.finished.connect(func() -> void: typing = false)


## Toucher l'écran : finir d'écrire le texte, sinon case suivante.
func next() -> void:
	if typing:
		_tween.kill()
		frame.modulate.a = 1.0
		text_label.visible_ratio = 1.0
		typing = false
	elif index + 1 < panels.size():
		show_panel(index + 1)
	else:
		finish()


## Fin des cases : on passe à l'étape suivante du chapitre.
func finish() -> void:
	if _tween:
		_tween.kill()
	GameState.story_next()


func _gui_input(event: InputEvent) -> void:
	var touched: bool = event is InputEventScreenTouch and event.pressed
	var clicked: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if touched or clicked:
		accept_event()
		next()


func _unhandled_input(event: InputEvent) -> void:
	super(event)
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("attack"):
		get_viewport().set_input_as_handled()
		next()


func go_back() -> void:
	GameState.go_to(GameState.STORY_MAP)
