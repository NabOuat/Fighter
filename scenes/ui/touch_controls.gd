class_name TouchControls
extends CanvasLayer
## Les contrôles tactiles : un joystick à gauche, les boutons d'action à droite.
##
## Chaque bouton est un TouchScreenButton relié à une action (attack, special...) :
## appuyer dessus revient à appuyer sur la touche du clavier correspondante.
## Plusieurs doigts peuvent appuyer en même temps (bouger et frapper).

## Coché : visibles aussi sur ordinateur, cliquables à la souris (pour tester).
@export var show_on_desktop := true

## Le combattant contrôlé, pour griser l'ultime et le soutien quand ils ne sont pas prêts.
var fighter: Fighter

@onready var ultimate_look := $Ultimate/Look
@onready var assist_look := $Assist/Look


func _ready() -> void:
	var touchscreen := DisplayServer.is_touchscreen_available()
	visible = touchscreen or show_on_desktop
	if not touchscreen and show_on_desktop:
		# Sur ordinateur, la souris imite un doigt (un seul à la fois).
		Input.emulate_touch_from_mouse = true


func _process(_delta: float) -> void:
	if fighter == null:
		return
	ultimate_look.set_dimmed(fighter.energy < Fighter.MAX_ENERGY)
	assist_look.set_dimmed(not fighter.can_call_assist())
