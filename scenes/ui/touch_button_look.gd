extends Node2D
## Dessin d'un bouton tactile rond (en attendant les vrais graphismes) : une
## icône dessinée par le code (lisible quelle que soit la langue) et un petit nom.
## Placé sous un TouchScreenButton : il s'éclaire quand le bouton est enfoncé.

enum Icon { NONE, FIST, SWIRL, SHIELD, ALLY, STAR, PAUSE, HAND, DASH, LOW, CHARGE }

@export var radius := 18.0
@export var color := Color(1.0, 0.76, 0.24)
@export var icon: Icon = Icon.NONE
## Clé du texte affiché sous l'icône (fichier de traductions).
@export var label_key := ""
@export var font_size := 7

const OUTLINE := Color(0.08, 0.05, 0.09, 0.85)
const INK := Color(1, 1, 1, 0.95)

## Mis à vrai par les contrôles quand l'action n'est pas disponible (ex : ultime).
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


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		queue_redraw()


func _draw() -> void:
	var fill := color.lightened(0.35) if _was_pressed else color
	fill.a = 0.25 if dimmed else (0.85 if _was_pressed else 0.55)
	draw_circle(Vector2.ZERO, radius + 1.5, OUTLINE)
	draw_circle(Vector2.ZERO, radius, fill)
	draw_arc(Vector2.ZERO, radius - 1.5, 0, TAU, 32, Color(1, 1, 1, 0.25), 1.0)
	var ink := Color(INK, 0.5 if dimmed else INK.a)
	var has_label := label_key != ""
	# L'icône occupe le haut du bouton, le nom le bas.
	var center := Vector2(0, -radius * 0.18) if has_label else Vector2.ZERO
	_draw_icon(center, radius * (0.42 if has_label else 0.55), ink)
	if has_label:
		var font := ThemeDB.fallback_font
		var width := radius * 2.0
		var baseline := radius * 0.62
		draw_string_outline(font, Vector2(-radius, baseline), tr(label_key), HORIZONTAL_ALIGNMENT_CENTER, width, font_size, 2, OUTLINE)
		draw_string(font, Vector2(-radius, baseline), tr(label_key), HORIZONTAL_ALIGNMENT_CENTER, width, font_size, ink)


func _draw_icon(c: Vector2, s: float, ink: Color) -> void:
	match icon:
		Icon.FIST:
			# Un poing : un carré arrondi avec des jointures.
			draw_rect(Rect2(c - Vector2(s * 0.8, s * 0.6), Vector2(s * 1.6, s * 1.2)), ink)
			for i in 3:
				draw_line(c + Vector2(-s * 0.8 + s * 0.53 * (i + 1), -s * 0.6), c + Vector2(-s * 0.8 + s * 0.53 * (i + 1), -s * 0.1), OUTLINE, 1.0)
		Icon.SWIRL:
			# Une spirale d'énergie.
			var points := PackedVector2Array()
			for i in 24:
				var t := i / 23.0
				points.append(c + Vector2.from_angle(t * TAU * 1.6) * s * (0.2 + 0.8 * t))
			draw_polyline(points, ink, 2.0)
		Icon.SHIELD:
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-s * 0.8, -s * 0.8), c + Vector2(s * 0.8, -s * 0.8),
				c + Vector2(s * 0.8, 0), c + Vector2(0, s), c + Vector2(-s * 0.8, 0),
			]), ink)
		Icon.ALLY:
			# Deux silhouettes côte à côte.
			for dx in [-0.45, 0.45]:
				draw_circle(c + Vector2(s * dx, -s * 0.45), s * 0.3, ink)
				draw_rect(Rect2(c + Vector2(s * (dx - 0.35), -s * 0.1), Vector2(s * 0.7, s * 0.9)), ink)
		Icon.STAR:
			var points := PackedVector2Array()
			for i in 10:
				var r := s if i % 2 == 0 else s * 0.45
				points.append(c + Vector2.from_angle(-PI / 2.0 + i * PI / 5.0) * r)
			draw_colored_polygon(points, ink)
		Icon.PAUSE:
			draw_rect(Rect2(c + Vector2(-s * 0.6, -s * 0.7), Vector2(s * 0.4, s * 1.4)), ink)
			draw_rect(Rect2(c + Vector2(s * 0.2, -s * 0.7), Vector2(s * 0.4, s * 1.4)), ink)
		Icon.HAND:
			# Une main qui saisit : un crochet.
			draw_line(c + Vector2(s * 0.8, -s * 0.7), c + Vector2(-s * 0.6, -s * 0.7), ink, 2.0)
			draw_line(c + Vector2(-s * 0.6, -s * 0.7), c + Vector2(-s * 0.6, s * 0.7), ink, 2.0)
			draw_line(c + Vector2(-s * 0.6, s * 0.7), c + Vector2(s * 0.8, s * 0.7), ink, 2.0)
		Icon.DASH:
			# Une flèche vers l'avant : le spécial 2 (avant + Spécial).
			draw_line(c + Vector2(-s, 0), c + Vector2(s * 0.5, 0), ink, 2.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(s, 0), c + Vector2(s * 0.3, -s * 0.6), c + Vector2(s * 0.3, s * 0.6)]), ink)
		Icon.LOW:
			# Un chevron vers le bas, comme le repère des coups bas.
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s, -s * 0.4), c + Vector2(s, -s * 0.4), c + Vector2(0, s * 0.8)]), ink)
		Icon.CHARGE:
			# Deux chevrons vers le haut : l'énergie monte.
			for dy in [-0.5, 0.3]:
				draw_polyline(PackedVector2Array([c + Vector2(-s * 0.8, s * (dy + 0.5)), c + Vector2(0, s * (dy - 0.2)), c + Vector2(s * 0.8, s * (dy + 0.5))]), ink, 2.0)
