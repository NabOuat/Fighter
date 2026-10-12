@tool
class_name PatternBand
extends Control
## Une bande décorative à motifs géométriques (triangles et losanges), inspirée
## des tissus d'Afrique de l'Ouest. Dessinée par le code : pas d'image à charger.
## Elle s'étire sur toute la largeur du nœud ; la hauteur donne la taille des motifs.

@export var gold := Color("e6ad3c"):
	set(value):
		gold = value
		queue_redraw()
@export var ochre := Color("b8661f"):
	set(value):
		ochre = value
		queue_redraw()
@export var dark := Color("1c100a"):
	set(value):
		dark = value
		queue_redraw()
## Retourne les triangles (pour une bande en bas de l'écran).
@export var flipped := false:
	set(value):
		flipped = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var h := size.y
	if h <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), dark)
	var step := h * 2.0
	var count := ceili(size.x / step) + 1
	var top := 0.0 if not flipped else h
	var bottom := h if not flipped else 0.0
	for i in count:
		var x := i * step
		# Triangle doré, puis losange ocre entre deux triangles.
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, top), Vector2(x + step, top), Vector2(x + step / 2.0, bottom),
		]), gold)
		var mid := h / 2.0
		var cx := x + step
		var r := h * 0.32
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx, mid - r), Vector2(cx + r, mid), Vector2(cx, mid + r), Vector2(cx - r, mid),
		]), ochre)
	# Liserés.
	draw_line(Vector2(0, 0.5), Vector2(size.x, 0.5), ochre)
	draw_line(Vector2(0, h - 0.5), Vector2(size.x, h - 0.5), ochre)
