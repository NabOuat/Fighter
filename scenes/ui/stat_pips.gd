@tool
class_name StatPips
extends Control
## Une statistique de 1 à 5, dessinée en 5 petits carrés (pleins jusqu'à la valeur).

const MAX_VALUE := 5
const PIP_SIZE := 7.0
const GAP := 3.0

@export_range(0, 5) var value := 3:
	set(v):
		value = v
		queue_redraw()
@export var color := Color("e6ad3c")
@export var empty_color := Color("3d2314")


func _ready() -> void:
	custom_minimum_size = Vector2(MAX_VALUE * (PIP_SIZE + GAP), PIP_SIZE)


func _draw() -> void:
	var y := (size.y - PIP_SIZE) / 2.0
	for i in MAX_VALUE:
		var rect := Rect2(i * (PIP_SIZE + GAP), y, PIP_SIZE, PIP_SIZE)
		draw_rect(rect, color if i < value else empty_color)
		draw_rect(rect, color.darkened(0.4), false, 1.0)
