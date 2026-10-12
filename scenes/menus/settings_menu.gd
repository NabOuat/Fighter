class_name SettingsMenu
extends MenuScreen
## L'écran des réglages, en deux onglets :
## - Général : langue, volumes, vibration, aides visuelles (repères des coups) ;
## - Contrôles : boutons « en plus » et disposition des boutons tactiles.
##
## Il s'ouvre par-dessus le menu principal ou le menu pause. Chaque réglage
## s'applique tout de suite ; tout est enregistré sur l'appareil en fermant.

signal closed

const CONTROLS_EDITOR := preload("res://scenes/menus/controls_editor.tscn")

@onready var language_button: Button = %LanguageButton
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var vibration_check: CheckButton = %VibrationCheck
@onready var markers_check: CheckButton = %MarkersCheck
@onready var tabs: TabContainer = %Tabs
@onready var extras: GridContainer = %Extras
@onready var layout_button: Button = %LayoutButton
@onready var close_button: Button = %CloseButton


func _ready() -> void:
	# Utilisable aussi quand le jeu est en pause.
	process_mode = Node.PROCESS_MODE_ALWAYS
	music_slider.value = GameState.music_volume
	sfx_slider.value = GameState.sfx_volume
	vibration_check.button_pressed = GameState.vibration
	markers_check.button_pressed = GameState.attack_markers
	tabs.set_tab_title(0, "SETTINGS_TAB_GENERAL")
	tabs.set_tab_title(1, "SETTINGS_TAB_CONTROLS")
	# Une case par bouton « en plus » (le nom du nœud = le nom du bouton).
	for check: CheckButton in extras.get_children():
		check.button_pressed = GameState.is_extra_button_on(String(check.name))
		check.toggled.connect(_on_extra_toggled.bind(String(check.name)))
	markers_check.toggled.connect(func(on): GameState.attack_markers = on)
	language_button.pressed.connect(_next_language)
	music_slider.value_changed.connect(GameState.set_music_volume)
	sfx_slider.value_changed.connect(GameState.set_sfx_volume)
	# On entend le nouveau volume des bruitages en lâchant le curseur.
	sfx_slider.drag_ended.connect(func(_changed): UiSound.play())
	vibration_check.toggled.connect(_on_vibration_toggled)
	layout_button.pressed.connect(open_controls_editor)
	close_button.pressed.connect(go_back)
	focus_first(close_button)


func _next_language() -> void:
	var index := GameState.LANGUAGES.find(GameState.language)
	GameState.set_language(GameState.LANGUAGES[(index + 1) % GameState.LANGUAGES.size()])


func _on_vibration_toggled(on: bool) -> void:
	GameState.vibration = on
	# Petite vibration pour montrer que c'est activé.
	GameState.vibrate(60)


func _on_extra_toggled(on: bool, button_name: String) -> void:
	GameState.extra_buttons[button_name] = on


func open_controls_editor() -> ControlsEditor:
	var editor: ControlsEditor = CONTROLS_EDITOR.instantiate()
	add_child(editor)
	visible = false
	editor.closed.connect(func():
		visible = true
		focus_first(layout_button))
	return editor


## Fermer : on enregistre tout.
func go_back() -> void:
	GameState.save_settings()
	closed.emit()
	queue_free()
