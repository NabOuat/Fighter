class_name Projectile
extends Node2D
## Un projectile en vol. L'arène le crée, le fait avancer et vérifie s'il touche.

var data: ProjectileData
var shooter: Fighter
var direction := 1
var age := 0
## Vrai si le projectile vient d'un soutien : il ne compte pas dans la limite
## d'un seul projectile à la fois du combattant.
var from_assist := false


## Prépare le projectile au moment où il est lancé.
## shooter : le combattant à qui il appartient (même s'il vient de son soutien).
func launch(projectile_data: ProjectileData, from: Fighter, origin: Vector2, dir: int, by_assist := false) -> void:
	data = projectile_data
	shooter = from
	direction = dir
	position = origin
	from_assist = by_assist
	var view := ColorRect.new()
	view.color = data.color
	view.size = data.size
	view.position = -data.size / 2.0
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)


## Une frame de vol.
func tick(delta: float) -> void:
	position.x += direction * data.speed * delta
	age += 1


func get_rect() -> Rect2:
	return Rect2(global_position - data.size / 2.0, data.size)


func is_expired(left: float, right: float) -> bool:
	return age >= data.lifetime or global_position.x < left or global_position.x > right
