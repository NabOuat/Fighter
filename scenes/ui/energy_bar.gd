class_name EnergyBar
extends Control
## Barre d'énergie ancestrale en 4 segments.
##
## Chaque segment plein permet un coup spécial ou une esquive ;
## la barre pleine (les 4) permet l'ultime, et elle se met alors à briller.

const SEGMENTS := 4
const GAP := 2.0
const BACKGROUND := Color(0.1, 0.12, 0.2)
const FILLING := Color(0.18, 0.5, 0.56)
const READY := Color(0.25, 0.88, 0.82)
const FULL_A := Color(1.0, 0.85, 0.35)
const FULL_B := Color(1.0, 1.0, 0.8)
const OUTLINE := Color(0.08, 0.05, 0.09)

## Coché : la barre se remplit vers la gauche (joueur de droite).
@export var flip := false

var ratio := 0.0
var _time := 0.0


func set_ratio(value: float) -> void:
	ratio = clampf(value, 0.0, 1.0)
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if ratio >= 1.0:
		queue_redraw()


func _draw() -> void:
	var width := (size.x - GAP * (SEGMENTS - 1)) / SEGMENTS
	var filled := ratio * SEGMENTS
	var full := ratio >= 1.0
	var glow := FULL_A.lerp(FULL_B, 0.5 + 0.5 * sin(_time * 10.0))
	for i in SEGMENTS:
		var slot := i if not flip else SEGMENTS - 1 - i
		var x := slot * (width + GAP)
		var cell := Rect2(x, 0, width, size.y)
		draw_rect(cell.grow(1), OUTLINE)
		draw_rect(cell, BACKGROUND)
		var amount := clampf(filled - i, 0.0, 1.0)
		if amount <= 0.0:
			continue
		var part_width := roundf(width * amount)
		var part_x := x if not flip else x + width - part_width
		var color := glow if full else (READY if amount >= 1.0 else FILLING)
		draw_rect(Rect2(part_x, 0, part_width, size.y), color)
