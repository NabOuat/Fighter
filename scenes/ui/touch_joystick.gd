class_name TouchJoystick
extends Node2D
## Joystick virtuel pour écran tactile.
##
## Il « appuie » sur les mêmes actions que le clavier (move_left, move_right,
## jump, crouch) : le combattant ne fait aucune différence entre les deux.
## On peut poser le pouce n'importe où dans la zone de gauche de l'écran.

## Zone où un doigt peut prendre le joystick (moitié gauche, bas de l'écran).
@export var zone := Rect2(0, 110, 220, 160)
## Rayon de la base, en pixels.
@export var radius := 26.0
## En dessous de cette distance du centre, aucune direction.
@export var dead_zone := 6.0

const BASE_COLOR := Color(0.95, 0.9, 1.0, 0.18)
const RING_COLOR := Color(0.95, 0.9, 1.0, 0.45)
const KNOB_COLOR := Color(1.0, 0.85, 0.4, 0.75)

## Numéro du doigt qui tient le joystick (-1 = aucun).
var _touch_index := -1
var _knob := Vector2.ZERO
var _pressed := {"move_left": false, "move_right": false, "jump": false, "crouch": false}


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1 and zone.has_point(event.position):
			_touch_index = event.index
			_move_knob(event.position)
		elif not event.pressed and event.index == _touch_index:
			_release()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_move_knob(event.position)


func _move_knob(touch_position: Vector2) -> void:
	_knob = (touch_position - global_position).limit_length(radius)
	var active := _knob.length() > dead_zone
	# Les seuils évitent de sauter ou de s'accroupir sans le vouloir
	# en poussant simplement le joystick sur le côté.
	_set_action("move_left", active and _knob.x < -radius * 0.35)
	_set_action("move_right", active and _knob.x > radius * 0.35)
	_set_action("jump", active and _knob.y < -radius * 0.6)
	_set_action("crouch", active and _knob.y > radius * 0.6)
	queue_redraw()


func _release() -> void:
	_touch_index = -1
	_knob = Vector2.ZERO
	for action in _pressed:
		_set_action(action, false)
	queue_redraw()


func _set_action(action: String, pressed: bool) -> void:
	if _pressed[action] == pressed:
		return
	_pressed[action] = pressed
	if pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)


func _exit_tree() -> void:
	_release()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, BASE_COLOR)
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, RING_COLOR, 1.0)
	draw_circle(_knob, radius * 0.45, KNOB_COLOR)
