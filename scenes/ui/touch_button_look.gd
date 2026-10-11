extends Node2D
## Dessin d'un bouton tactile rond (en attendant les vrais graphismes).
## Placé sous un TouchScreenButton : il s'éclaire quand le bouton est enfoncé.

@export var radius := 18.0
@export var color := Color(1.0, 0.76, 0.24)
## Clé du texte affiché sur le bouton (fichier de traductions).
@export var label_key := ""
@export var font_size := 8

const OUTLINE := Color(0.08, 0.05, 0.09, 0.8)

## Mis à 0.35 par les contrôles quand l'action n'est pas disponible (ex : ultime).
var dimmed := false
var _was_pressed := false


func _process(_delta: float) -> void:
	var pressed: bool = get_parent().is_pressed()
	if pressed != _was_pressed:
		_was_pressed = pressed
		queue_redraw()


func set_dimmed(value: bool) -> void:
	if value != dimmed:
		dimmed = value
		queue_redraw()


func _draw() -> void:
	var fill := color.lightened(0.35) if _was_pressed else color
	fill.a = 0.25 if dimmed else (0.8 if _was_pressed else 0.5)
	draw_circle(Vector2.ZERO, radius + 1, OUTLINE)
	draw_circle(Vector2.ZERO, radius, fill)
	var font := ThemeDB.fallback_font
	var text := tr(label_key)
	var width := radius * 2.0
	draw_string(font, Vector2(-radius, font_size * 0.35), text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, Color(1, 1, 1, 0.5 if dimmed else 0.95))
