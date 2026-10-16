class_name Stage
extends Node2D
## Le décor du combat : trois couches dessinées (fond, milieu, sol) qui défilent
## à des vitesses différentes quand la caméra suit les combattants. Le fond, très
## loin, bouge peu ; le sol bouge avec l'arène. C'est l'effet de profondeur.
##
## Les images viennent de assets/stages/<décor>/game/ (préparées par
## tools/import_stages.py à partir des images générées).

## Taille d'un pixel du décor dans l'arène : la même que pour les personnages
## (avec la caméra zoomée x1,75, 1 pixel du décor = 1 pixel de l'écran).
const ART_SCALE := 1.0 / 1.75
## Part du mouvement de la caméra suivie par chaque couche (1 = colle à l'arène).
const PARALLAX := {"back": 0.35, "middle": 0.75, "ground": 1.0}
## Le bas du décor descend un peu sous les pieds des combattants (bande de sol devant eux).
const BELOW_FEET := 18.0
## Centre de l'arène (la caméra y est quand les combattants sont au milieu).
const ARENA_CENTER_X := 240.0

var stage_id := ""
var _layers := {}


## Charge un décor. Renvoie faux s'il n'existe pas (on garde alors le fond uni).
func load_stage(id: String, floor_y: float) -> bool:
	for sprite in _layers.values():
		sprite.queue_free()
	_layers.clear()
	stage_id = ""
	if id == "" or not ResourceLoader.exists(texture_path(id, "back")):
		return false
	stage_id = id
	for layer in ["back", "middle", "ground"]:
		var path := texture_path(id, layer)
		if not ResourceLoader.exists(path):
			continue
		var sprite := Sprite2D.new()
		sprite.texture = load(path)
		sprite.centered = false
		sprite.scale = Vector2.ONE * ART_SCALE
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# Le bas de l'image est posé un peu sous les pieds des combattants.
		sprite.position.y = floor_y + BELOW_FEET - sprite.texture.get_height() * ART_SCALE
		add_child(sprite)
		_layers[layer] = sprite
	return true


static func texture_path(id: String, layer: String) -> String:
	return "res://assets/stages/%s/game/layer_%s.png" % [id, layer]


static func exists(id: String) -> bool:
	return ResourceLoader.exists(texture_path(id, "back"))


## Fait défiler les couches selon la position de la caméra (effet de profondeur).
func scroll(camera_x: float) -> void:
	for layer in _layers:
		_layers[layer].position.x = (camera_x - ARENA_CENTER_X) * (1.0 - PARALLAX[layer])
