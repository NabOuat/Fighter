class_name TouchControls
extends CanvasLayer
## Les contrôles tactiles : un joystick à gauche, les boutons d'action à droite.
##
## Chaque bouton est un TouchScreenButton relié à une action (attack, special...) :
## appuyer dessus revient à appuyer sur la touche du clavier correspondante.
## Plusieurs doigts peuvent appuyer en même temps (bouger et frapper).
##
## Le joueur peut déplacer et agrandir chaque bouton (Réglages → Disposer les
## boutons). Les positions sont enregistrées en proportion de l'écran (0 à 1),
## pour rester bien placées sur les téléphones plus larges.
## Deux dispositions toutes faites : droitier (joystick à gauche) et gaucher
## (tout en miroir). Les boutons « en plus » s'affichent selon les réglages.

## Taille de l'écran pour laquelle la scène a été dessinée.
const BASE_SIZE := Vector2(480, 270)

## Coché : visibles aussi sur ordinateur, cliquables à la souris (pour tester).
@export var show_on_desktop := true

## Le combattant contrôlé, pour griser l'ultime et le soutien quand ils ne sont pas prêts.
var fighter: Fighter
## Vrai dans l'écran de disposition : les boutons ne déclenchent plus d'action.
var edit_mode := false

## Positions d'origine (en proportion de l'écran), lues dans la scène.
var _default_positions := {}
## Action de chaque bouton, gardée pour la remettre en quittant le mode édition.
var _actions := {}

@onready var ultimate_look := $Ultimate/Look
@onready var assist_look := $Assist/Look
@onready var joystick: TouchJoystick = $Joystick


func _ready() -> void:
	for control_name in GameState.TOUCH_CONTROLS:
		var node: Node2D = get_node(control_name)
		_default_positions[control_name] = node.position / BASE_SIZE
		if node is TouchScreenButton:
			_actions[control_name] = node.action
	var touchscreen := DisplayServer.is_touchscreen_available()
	visible = touchscreen or show_on_desktop
	if not touchscreen and show_on_desktop:
		# Sur ordinateur, la souris imite un doigt (un seul à la fois).
		Input.emulate_touch_from_mouse = true
	GameState.settings_saved.connect(apply_saved_layout)
	get_viewport().size_changed.connect(apply_saved_layout)
	apply_saved_layout()


func _process(_delta: float) -> void:
	if fighter == null:
		return
	ultimate_look.set_dimmed(fighter.energy < Fighter.MAX_ENERGY)
	assist_look.set_dimmed(not fighter.can_call_assist())


## Place les boutons comme le joueur les a enregistrés.
func apply_saved_layout() -> void:
	apply_layout(GameState.touch_layout, GameState.touch_opacity)


## layout : {nom du bouton: {"position": Vector2 de 0 à 1, "scale": float}}.
## Un bouton absent du dictionnaire reprend sa place et sa taille d'origine.
func apply_layout(layout: Dictionary, opacity: float) -> void:
	var screen := screen_size()
	for control_name in GameState.TOUCH_CONTROLS:
		var node: Node2D = get_node(control_name)
		var entry: Dictionary = layout.get(control_name, {})
		node.position = (entry.get("position", _default_positions[control_name]) as Vector2) * screen
		node.scale = Vector2.ONE * float(entry.get("scale", 1.0))
		node.modulate.a = opacity
		node.visible = is_shown(control_name)


## Vrai si ce bouton est affiché (les boutons « en plus » seulement si le joueur les a choisis).
func is_shown(control_name: String) -> bool:
	return control_name not in GameState.EXTRA_BUTTONS or GameState.is_extra_button_on(control_name)


## Disposition toute faite : droitier (celle d'origine) ou gaucher (en miroir).
func preset_layout(left_handed: bool) -> Dictionary:
	var layout := {}
	for control_name in GameState.TOUCH_CONTROLS:
		var position: Vector2 = _default_positions[control_name]
		if left_handed:
			position.x = 1.0 - position.x
		layout[control_name] = {"position": position, "scale": 1.0}
	return layout


## La disposition actuelle, au format enregistré dans les réglages.
func current_layout() -> Dictionary:
	var layout := {}
	var screen := screen_size()
	for control_name in GameState.TOUCH_CONTROLS:
		var node: Node2D = get_node(control_name)
		layout[control_name] = {"position": node.position / screen, "scale": node.scale.x}
	return layout


func default_position(control_name: String) -> Vector2:
	return _default_positions[control_name] * screen_size()


## Mode édition : on peut toucher les boutons sans déclencher d'action.
func set_edit_mode(value: bool) -> void:
	edit_mode = value
	visible = true
	joystick.set_process_input(not value)
	for control_name in _actions:
		get_node(control_name).action = "" if value else _actions[control_name]


## Rayon d'un bouton à l'écran (taille d'origine × agrandissement), pour le saisir.
func control_radius(control_name: String) -> float:
	var node: Node2D = get_node(control_name)
	var radius := 20.0
	if node is TouchJoystick:
		radius = node.radius
	elif node is TouchScreenButton and node.shape is CircleShape2D:
		radius = node.shape.radius
	return radius * node.scale.x


func screen_size() -> Vector2:
	if not is_inside_tree():
		return BASE_SIZE
	return get_viewport().get_visible_rect().size
