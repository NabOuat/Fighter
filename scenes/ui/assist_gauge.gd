class_name AssistGauge
extends Control
## Jauge du soutien : un carré à la couleur du personnage de soutien
## et une barre qui se remplit pendant la recharge. Pleine et clignotante = prêt.

const OUTLINE := Color(0.08, 0.05, 0.09)
const BACKGROUND := Color(0.15, 0.12, 0.18)
const RECHARGING := Color(0.55, 0.5, 0.6)

## Coché : la barre se remplit vers la gauche (joueur de droite).
@export var flip := false

var _ratio := 1.0
var _color := Color.WHITE
var _ready_to_call := true
var _time := 0.0


func show_fighter(fighter: Fighter) -> void:
	if fighter.support == null or fighter.support.assist == null:
		visible = false
		return
	visible = true
	_color = fighter.support.placeholder_color
	_ready_to_call = fighter.can_call_assist()
	_ratio = 1.0 - float(fighter.assist_cooldown) / fighter.support.assist.cooldown_frames
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if _ready_to_call:
		queue_redraw()


func _draw() -> void:
	var icon := size.y
	var icon_x := size.x - icon if flip else 0.0
	draw_rect(Rect2(icon_x - 1, -1, icon + 2, icon + 2), OUTLINE)
	draw_rect(Rect2(icon_x, 0, icon, icon), _color)
	var bar_x := 0.0 if flip else icon + 3.0
	var bar_width := size.x - icon - 3.0
	var bar := Rect2(bar_x, icon * 0.3, bar_width, icon * 0.4)
	draw_rect(bar.grow(1), OUTLINE)
	draw_rect(bar, BACKGROUND)
	var fill_width := roundf(bar_width * _ratio)
	var fill_x := bar_x + bar_width - fill_width if flip else bar_x
	var fill_color := RECHARGING
	if _ready_to_call:
		fill_color = _color.lerp(Color.WHITE, 0.35 + 0.35 * sin(_time * 8.0))
	draw_rect(Rect2(fill_x, bar.position.y, fill_width, bar.size.y), fill_color)
