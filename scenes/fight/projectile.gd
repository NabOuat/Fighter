class_name Projectile
extends Node2D
## Un projectile en vol. L'arène le crée, le fait avancer et vérifie s'il touche.

## Ce que le rollback sauvegarde (le tireur est sauvegardé à part, par l'arène).
const STATE_VARS := ["data", "position", "direction", "age", "from_assist"]

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
	# Le dessin animé du projectile s'il existe, sinon un rectangle de couleur.
	if data.sprite_frames and data.sprite_frames.has_animation(data.animation):
		var art := AnimatedSprite2D.new()
		art.sprite_frames = data.sprite_frames
		art.animation = data.animation
		art.flip_h = dir == -1
		art.scale = Vector2.ONE * FighterSprite.ART_SCALE
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(art)
		art.play()
		return
	var view := ColorRect.new()
	view.color = data.color
	view.size = data.size
	view.position = -data.size / 2.0
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)


func get_state() -> Dictionary:
	var saved := {}
	for key in STATE_VARS:
		saved[key] = get(key)
	return saved


## Un projectile recréé par le rollback reprend exactement là où il en était.
func set_state(saved: Dictionary) -> void:
	for key in STATE_VARS:
		set(key, saved[key])


## Une frame de vol.
func tick(delta: float) -> void:
	position.x += direction * data.speed * delta
	age += 1


func get_rect() -> Rect2:
	return Rect2(global_position - data.size / 2.0, data.size)


func is_expired(left: float, right: float) -> bool:
	return age >= data.lifetime or global_position.x < left or global_position.x > right
