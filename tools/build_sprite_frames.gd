extends SceneTree
## Fabrique la ressource d'animations (SpriteFrames) d'un héros à partir des images
## rangées par tools/import_spritelab.py dans assets/characters/<héros>/sprites/<animation>/.
## Crée aussi sa fiche FighterData si elle n'existe pas (coups provisoires copiés
## sur le combattant de test A, à régler ensuite).
##   Godot --headless --path . --script res://tools/build_sprite_frames.gd -- abla_pokou

## Vitesse de lecture par défaut (le combat règle lui-même l'image affichée
## pour les coups, d'après leurs frames ; ceci sert à l'éditeur et aux boucles).
const FPS := 10.0
## Animations qui tournent en boucle.
const LOOPS := ["idle", "walk_forward", "walk_back", "charge", "special_1_fx"]

## Fiches à créer si besoin : nom, origine, stats provisoires.
const NEW_FIGHTERS := {
	"abla_pokou": {
		"name_key": "FIGHTER_POKOU_NAME", "origin_key": "FIGHTER_POKOU_ORIGIN", "bio_key": "FIGHTER_POKOU_BIO",
		"power": 3, "defense": 4, "speed": 2, "reach": FighterData.Reach.LONG_WEAPON,
		"color": Color(0.85, 0.55, 0.2),
	},
}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Indique le héros : -- abla_pokou")
		quit(1)
		return
	var hero: String = args[0]
	var folder := "res://assets/characters/%s/sprites" % hero
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	var dir := DirAccess.open(folder)
	if dir == null:
		push_error("Dossier introuvable : " + folder)
		quit(1)
		return
	var names := Array(dir.get_directories())
	names.sort()
	for anim in names:
		frames.add_animation(anim)
		frames.set_animation_speed(anim, FPS)
		frames.set_animation_loop(anim, anim in LOOPS)
		var files := Array(DirAccess.get_files_at(folder + "/" + anim)).filter(func(f): return f.ends_with(".png"))
		files.sort()
		for file in files:
			frames.add_frame(anim, load(folder + "/" + anim + "/" + file))
		print(anim, " : ", files.size(), " images")
	var frames_path := "res://assets/characters/%s/%s_frames.tres" % [hero, hero]
	print("SpriteFrames : ", "ok" if ResourceSaver.save(frames, frames_path) == OK else "erreur")

	var fighter_path := "res://data/fighters/%s.tres" % hero
	var fighter: FighterData
	if ResourceLoader.exists(fighter_path):
		fighter = load(fighter_path)
	elif NEW_FIGHTERS.has(hero):
		fighter = _new_fighter(hero, NEW_FIGHTERS[hero])
	else:
		push_warning("Pas de fiche pour " + hero + " : crée-la, puis relance.")
		quit()
		return
	fighter.sprite_frames = load(frames_path)
	_use_projectile_art(fighter)
	print("Fiche : ", "ok" if ResourceSaver.save(fighter, fighter_path) == OK else "erreur")
	quit()


## Le projectile du spécial 1 prend son dessin (animation « special_1_fx »), et sa
## zone de frappe prend la taille du dessin (un peu plus petite, pour rester juste).
## Il part à hauteur des genoux et roule au ras du sol.
func _use_projectile_art(fighter: FighterData) -> void:
	var frames := fighter.sprite_frames
	if not frames.has_animation(&"special_1_fx") or fighter.special_1 == null or fighter.special_1.projectile == null:
		return
	var projectile := fighter.special_1.projectile
	projectile.sprite_frames = frames
	projectile.animation = &"special_1_fx"
	var art_size := Vector2(frames.get_frame_texture(&"special_1_fx", 0).get_size())
	projectile.size = (art_size * FighterSprite.ART_SCALE * 0.8).round()
	projectile.spawn_offset = Vector2(projectile.size.x / 2.0 + 6.0, -projectile.size.y / 2.0)
	print("Projectile : dessin ", art_size, ", zone de frappe ", projectile.size)


## Nouvelle fiche : textes et stats du héros, coups copiés sur le combattant de test A.
func _new_fighter(hero: String, info: Dictionary) -> FighterData:
	var model: FighterData = load("res://data/fighters/test_a.tres").duplicate(true)
	model.id = StringName(hero)
	model.name_key = info.name_key
	model.origin_key = info.origin_key
	model.bio_key = info.bio_key
	model.power = info.power
	model.defense = info.defense
	model.speed = info.speed
	model.reach = info.reach
	model.placeholder_color = info.color
	return model
