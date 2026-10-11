class_name WinMarkers
extends Control
## Les manches gagnées : un carré par manche à gagner, doré quand elle est gagnée.

const OUTLINE := Color(0.08, 0.05, 0.09)
const EMPTY := Color(0.25, 0.2, 0.3)
const WON := Color(1.0, 0.76, 0.24)
const GAP := 3.0

## Nombre de manches à gagner pour remporter le combat.
@export var rounds_to_win := 2
## Coché : les carrés se remplissent de droite à gauche (joueur de droite).
@export var flip := false

var wins := 0


func set_wins(value: int) -> void:
	if value != wins:
		wins = value
		queue_redraw()


func _draw() -> void:
	var side := size.y
	for i in rounds_to_win:
		var slot := i if not flip else rounds_to_win - 1 - i
		var x := size.x - (slot + 1) * side - slot * GAP if flip else slot * (side + GAP)
		var cell := Rect2(x, 0, side, side)
		draw_rect(cell.grow(1), OUTLINE)
		draw_rect(cell, WON if i < wins else EMPTY)
