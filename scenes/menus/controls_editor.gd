class_name ControlsEditor
extends CanvasLayer
## L'écran « Disposer les boutons » : le joueur glisse chaque bouton tactile où
## il veut, règle sa taille et la transparence de tous les boutons. Deux
## dispositions toutes faites : droitier et gaucher (en miroir).
##
## Il s'ouvre par-dessus les réglages (depuis le menu ou en pleine pause).
## Enregistrer : la disposition est gardée sur l'appareil. Annuler : rien ne change.

signal closed

## Marge autour d'un bouton pour le saisir facilement avec le doigt.
const GRAB_MARGIN := 6.0
const HIGHLIGHT := Color(1.0, 0.85, 0.35)

## Le bouton sélectionné (celui dont on règle la taille), et celui qu'on fait glisser.
var selected := ""
var _drag_index := -1
var _drag_offset := Vector2.ZERO

@onready var controls: TouchControls = $Controls
@onready var highlight: Node2D = %Highlight
@onready var toolbar: Control = %Toolbar
@onready var selected_label: Label = %SelectedLabel
@onready var size_slider: HSlider = %SizeSlider
@onready var opacity_slider: HSlider = %OpacitySlider
@onready var right_handed_button: Button = %RightHandedButton
@onready var left_handed_button: Button = %LeftHandedButton
@onready var cancel_button: Button = %CancelButton
@onready var save_button: Button = %SaveButton


func _ready() -> void:
	# Utilisable aussi quand le jeu est en pause.
	process_mode = Node.PROCESS_MODE_ALWAYS
	controls.set_edit_mode(true)
	size_slider.min_value = GameState.TOUCH_SCALE_MIN
	size_slider.max_value = GameState.TOUCH_SCALE_MAX
	opacity_slider.value = GameState.touch_opacity
	size_slider.value_changed.connect(_on_size_changed)
	opacity_slider.value_changed.connect(_on_opacity_changed)
	right_handed_button.pressed.connect(apply_preset.bind(false))
	left_handed_button.pressed.connect(apply_preset.bind(true))
	cancel_button.pressed.connect(close)
	save_button.pressed.connect(save)
	highlight.draw.connect(_draw_highlight)
	select("")
	save_button.grab_focus.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		close()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## Glisser les boutons avec le doigt (ou la souris, qui imite un doigt sur ordinateur).
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _drag_index == -1:
			var touched := control_at(event.position)
			# Un appui sur la barre d'outils est laissé aux curseurs et aux boutons.
			if touched == "" and _toolbar_rect().has_point(event.position):
				return
			select(touched)
			if touched != "":
				_drag_index = event.index
				_drag_offset = controls.get_node(touched).position - event.position
				get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == _drag_index:
			_drag_index = -1
	elif event is InputEventScreenDrag and event.index == _drag_index and selected != "":
		move_control(selected, event.position + _drag_offset)
		get_viewport().set_input_as_handled()


## Le bouton sous ce point de l'écran ("" = aucun). Le plus proche gagne.
func control_at(point: Vector2) -> String:
	var best := ""
	var best_distance := INF
	for control_name in GameState.TOUCH_CONTROLS:
		var node: Node2D = controls.get_node(control_name)
		if not node.visible:
			continue
		var distance := point.distance_to(node.position)
		if distance <= controls.control_radius(control_name) + GRAB_MARGIN and distance < best_distance:
			best = control_name
			best_distance = distance
	return best


## Déplace un bouton, sans le laisser sortir de l'écran.
func move_control(control_name: String, at: Vector2) -> void:
	var node: Node2D = controls.get_node(control_name)
	var radius := controls.control_radius(control_name)
	var screen := controls.screen_size()
	node.position = Vector2(
		clampf(at.x, radius, screen.x - radius),
		clampf(at.y, radius, screen.y - radius)).round()
	highlight.queue_redraw()


func select(control_name: String) -> void:
	selected = control_name
	size_slider.editable = control_name != ""
	if control_name == "":
		selected_label.text = tr("CONTROLS_HINT")
	else:
		selected_label.text = tr("CONTROLS_SELECTED") % tr("CONTROL_" + control_name.to_upper())
		size_slider.set_value_no_signal(controls.get_node(control_name).scale.x)
	highlight.queue_redraw()


func _on_size_changed(value: float) -> void:
	if selected == "":
		return
	var node: Node2D = controls.get_node(selected)
	node.scale = Vector2.ONE * value
	# Après un agrandissement, le bouton doit rester dans l'écran.
	move_control(selected, node.position)


func _on_opacity_changed(value: float) -> void:
	for control_name in GameState.TOUCH_CONTROLS:
		controls.get_node(control_name).modulate.a = value


## Remet tous les boutons à leur place et à leur taille d'origine.
func reset_layout() -> void:
	apply_preset(false)


## Disposition toute faite : droitier (d'origine) ou gaucher (en miroir).
func apply_preset(left_handed: bool) -> void:
	controls.apply_layout(controls.preset_layout(left_handed), opacity_slider.value)
	select("")


func save() -> void:
	GameState.touch_layout = controls.current_layout()
	GameState.touch_opacity = opacity_slider.value
	GameState.save_settings()
	close()


func close() -> void:
	closed.emit()
	queue_free()


func _toolbar_rect() -> Rect2:
	return toolbar.get_global_rect()


## Un cercle doré autour du bouton sélectionné, des cercles discrets autour des autres.
func _draw_highlight() -> void:
	for control_name in GameState.TOUCH_CONTROLS:
		var node: Node2D = controls.get_node(control_name)
		if not node.visible:
			continue
		var radius := controls.control_radius(control_name) + 3.0
		if control_name == selected:
			highlight.draw_arc(node.position, radius, 0, TAU, 40, HIGHLIGHT, 2.0)
		else:
			highlight.draw_arc(node.position, radius, 0, TAU, 40, Color(1, 1, 1, 0.25), 1.0)
