class_name PauseMenu
extends CanvasLayer
## Le menu pause : Échap (ou P, le bouton tactile « II », ou « retour » sur
## Android) met le jeu en pause.
##
## Quand le jeu est en pause, tout s'arrête sauf ce menu (process_mode = ALWAYS).
## On peut y ouvrir les réglages (et disposer les boutons) en plein combat.

signal restart_requested
signal mode_toggled
signal menu_requested

const SETTINGS_SCENE := preload("res://scenes/menus/settings_menu.tscn")

## Faux hors du combat lancé seul (F6) : pas de bouton « Entraînement / Combat ».
var can_toggle_mode := true:
	set(value):
		can_toggle_mode = value
		if is_node_ready():
			mode_button.visible = value

var _settings: SettingsMenu

@onready var box: Control = $Box
@onready var resume_button: Button = %ResumeButton
@onready var restart_button: Button = %RestartButton
@onready var mode_button: Button = %ModeButton
@onready var settings_button: Button = %SettingsButton
@onready var menu_button: Button = %MenuButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mode_button.visible = can_toggle_mode
	resume_button.pressed.connect(set_paused.bind(false))
	restart_button.pressed.connect(func():
		set_paused(false)
		restart_requested.emit())
	mode_button.pressed.connect(func():
		set_paused(false)
		mode_toggled.emit())
	settings_button.pressed.connect(open_settings)
	menu_button.pressed.connect(func():
		set_paused(false)
		menu_requested.emit())


func _notification(what: int) -> void:
	# Le bouton « retour » d'Android : pause, ou reprise si on est déjà en pause.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and _settings == null:
		set_paused(not get_tree().paused)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and _settings == null:
		set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()


func set_paused(paused: bool) -> void:
	get_tree().paused = paused
	visible = paused
	if paused:
		resume_button.grab_focus()


func open_settings() -> SettingsMenu:
	_settings = SETTINGS_SCENE.instantiate()
	add_child(_settings)
	box.visible = false
	_settings.closed.connect(func():
		_settings = null
		box.visible = true
		settings_button.grab_focus())
	return _settings


## Le texte du bouton de mode dépend du mode actuel.
func show_mode(training: bool) -> void:
	mode_button.text = "PAUSE_MATCH" if training else "PAUSE_TRAINING"
