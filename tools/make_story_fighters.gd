extends SceneTree
## Crée les personnages propres au mode Histoire, sans crédit SpriteLab :
## - les guerriers d'Itsa : le dessin de Dakon, assombri, avec des stats plus faibles ;
## - le génie de la Comoé : une silhouette d'eau turquoise (en attendant son dessin).
##   Godot --headless --path . --script res://tools/make_story_fighters.gd


func _initialize() -> void:
	var warrior: FighterData = load("res://data/fighters/dakon.tres").duplicate(true)
	warrior.id = &"guerrier_itsa"
	warrior.name_key = "FIGHTER_GUERRIER_NAME"
	warrior.origin_key = "FIGHTER_ITSA_ORIGIN"
	warrior.bio_key = ""
	warrior.power = 2
	warrior.defense = 2
	warrior.speed = 3
	warrior.sprite_frames = load("res://assets/characters/dakon/dakon_frames.tres")
	warrior.tint = Color(0.62, 0.52, 0.45)
	_save(warrior, "res://data/fighters/guerrier_itsa.tres")

	# Stats du dossier de recherche (section 6) : puissance 4, défense 4, vitesse 2.
	var genie: FighterData = load("res://data/fighters/test_c.tres").duplicate(true)
	genie.id = &"genie_comoe"
	genie.name_key = "FIGHTER_GENIE_NAME"
	genie.origin_key = ""
	genie.bio_key = ""
	genie.power = 4
	genie.defense = 4
	genie.speed = 2
	genie.reach = FighterData.Reach.RANGED
	genie.placeholder_color = Color(0.25, 0.72, 0.78)
	if genie.special_1 and genie.special_1.projectile:
		genie.special_1.projectile.color = Color(0.35, 0.85, 0.9)
		genie.special_1.projectile.size = Vector2(26, 18)
	_save(genie, "res://data/fighters/genie_comoe.tres")
	quit()


func _save(fighter: FighterData, path: String) -> void:
	print(path, " : ", "ok" if ResourceSaver.save(fighter, path) == OK else "erreur")
