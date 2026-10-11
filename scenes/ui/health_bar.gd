class_name HealthBar
extends Control
## Barre de vie dessinée en pixels.
##
## La partie dorée est la vie actuelle. La partie rouge derrière montre la vie
## perdue récemment : elle descend doucement, pour qu'on voie l'effet d'un combo.

const BACKGROUND := Color(0.23, 0.06, 0.13)
const TRAIL := Color(1.0, 0.31, 0.18)
const FILL := Color(1.0, 0.76, 0.24)
const SHINE := Color(1.0, 0.94, 0.69)
const OUTLINE := Color(0.08, 0.05, 0.09)
## Vitesse de descente de la partie rouge (fraction de barre par seconde).
const TRAIL_SPEED := 0.6

## Coché : la barre se vide vers la droite (joueur de droite).
@export var flip := false

var ratio := 1.0
var trail_ratio := 1.0


func set_ratio(value: float) -> void:
	ratio = clampf(value, 0.0, 1.0)
	if ratio > trail_ratio:
		trail_ratio = ratio
	queue_redraw()


func _process(delta: float) -> void:
	if trail_ratio > ratio:
		trail_ratio = maxf(ratio, trail_ratio - TRAIL_SPEED * delta)
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2(-1, -1), size + Vector2(2, 2)), OUTLINE)
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	draw_rect(_part(trail_ratio), TRAIL)
	var fill := _part(ratio)
	draw_rect(fill, FILL)
	draw_rect(Rect2(fill.position, Vector2(fill.size.x, 2)), SHINE)


## Rectangle d'une partie de la barre, collé à gauche (ou à droite si flip).
func _part(value: float) -> Rect2:
	var width := roundf(size.x * value)
	var x := size.x - width if flip else 0.0
	return Rect2(x, 0, width, size.y)
