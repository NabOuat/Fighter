class_name PauseMenu
extends CanvasLayer
## Le menu pause : Échap (ou P, ou le bouton tactile « II ») met le jeu en pause.
##
## Quand le jeu est en pause, tout s'arrête sauf ce menu (process_mode = ALWAYS).

signal restart_requested
signal mode_toggled

@onready var resume_button: Button = %ResumeButton
@onready var restart_button: Button = %RestartButton
@onready var mode_button: Button = %ModeButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	resume_button.pressed.connect(set_paused.bind(false))
	restart_button.pressed.connect(func():
		set_paused(false)
		restart_requested.emit())
	mode_button.pressed.connect(func():
		set_paused(false)
		mode_toggled.emit())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()


func set_paused(paused: bool) -> void:
	get_tree().paused = paused
	visible = paused
	if paused:
		resume_button.grab_focus()


## Le texte du bouton de mode dépend du mode actuel.
func show_mode(training: bool) -> void:
	mode_button.text = "PAUSE_MATCH" if training else "PAUSE_TRAINING"
