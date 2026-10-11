class_name Projectile
extends Node2D
## Un projectile en vol. L'arène le crée, le fait avancer et vérifie s'il touche.

var data: ProjectileData
var shooter: Fighter
var direction := 1
var age := 0


## Prépare le projectile au moment où le combattant le lance.
func launch(projectile_data: ProjectileData, from: Fighter) -> void:
	data = projectile_data
	shooter = from
	direction = from.facing
	position = from.global_position + Vector2(data.spawn_offset.x * direction, data.spawn_offset.y)
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
