extends MenuScreen
## L'écran titre : le nom du jeu, puis « Touchez l'écran pour commencer ».
## N'importe quel appui (doigt, souris, touche) ouvre le menu principal.

## Le texte clignote : visible 40 frames, caché 20.
const BLINK_ON := 0.65
const BLINK_PERIOD := 1.0

var _time := 0.0
var _leaving := false

@onready var press_label: Label = %PressLabel
@onready var version_label: Label = %VersionLabel


func _ready() -> void:
	version_label.text = "v%s" % ProjectSettings.get_setting("application/config/version", "0.1")


func _process(delta: float) -> void:
	_time += delta
	press_label.visible = fmod(_time, BLINK_PERIOD) < BLINK_ON


func _input(event: InputEvent) -> void:
	var pressed := (event is InputEventScreenTouch or event is InputEventMouseButton or event is InputEventKey \
			or event is InputEventJoypadButton) and event.is_pressed()
	if pressed and not _leaving and _time > 0.3:
		_leaving = true
		get_viewport().set_input_as_handled()
		UiSound.play()
		GameState.go_to(GameState.MAIN_MENU)


## Retour depuis l'écran titre = quitter le jeu.
func go_back() -> void:
	get_tree().quit()
