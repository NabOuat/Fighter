extends Node
## Mémoire globale du jeu.
##
## Ce script est un « autoload » : Godot le charge au démarrage et il reste
## actif pendant toute la partie. On y accède depuis n'importe quel script
## en écrivant simplement GameState (ex : GameState.difficulty).
##
## Il garde : les choix faits dans les menus (mode, combattant, soutien,
## difficulté), la progression du mode Arcade, les réglages du joueur
## (enregistrés sur l'appareil dans user://settings.cfg) et, dans « story »,
## la progression du mode Histoire et les déblocages (user://progress.cfg).

## Émis après l'enregistrement des réglages (les boutons tactiles se replacent).
signal settings_saved

## QUICK : combat lancé directement depuis l'éditeur (F6), pour tester.
enum Mode { QUICK, ARCADE, TRAINING, TUTORIAL, STORY }

const SETTINGS_PATH := "user://settings.cfg"
const LANGUAGES := ["fr", "en"]
## Nombre de combats d'une partie d'Arcade.
const ARCADE_LENGTH := 6

const TITLE_SCREEN := "res://scenes/menus/title_screen.tscn"
const MAIN_MENU := "res://scenes/menus/main_menu.tscn"
const FIGHTER_SELECT := "res://scenes/menus/fighter_select.tscn"
const FIGHT := "res://scenes/fight/fight.tscn"
const STORY_MAP := "res://scenes/story/story_map.tscn"
const STORY_PANELS := "res://scenes/story/story_panels.tscn"

## Les boutons tactiles qu'on peut déplacer et agrandir dans les réglages.
const TOUCH_CONTROLS := ["Joystick", "Attack", "Special", "Guard", "Assist", "Ultimate", "Pause",
		"Throw", "Special2", "LowAttack", "Charge"]
## Les boutons « en plus », cachés au départ : des raccourcis en un seul appui
## (projection, spécial 2, coup bas) et un bouton pour charger l'énergie.
const EXTRA_BUTTONS := ["Throw", "Special2", "LowAttack", "Charge"]
## Taille minimale et maximale d'un bouton tactile (1 = taille normale).
const TOUCH_SCALE_MIN := 0.6
const TOUCH_SCALE_MAX := 1.6

## Liste de tous les combattants jouables. Pour en ajouter un :
## crée son fichier .tres dans data/fighters/ puis ajoute-le ici.
## Pokou a ses vrais dessins ; les combattants de test attendent les autres héros.
var roster: Array[FighterData] = [
	preload("res://data/fighters/abla_pokou.tres"),
	preload("res://data/fighters/test_a.tres"),
	preload("res://data/fighters/test_b.tres"),
	preload("res://data/fighters/test_c.tres"),
	preload("res://data/fighters/dakon.tres"),
	preload("res://data/fighters/itsa.tres"),
]

## Choix faits dans les menus, utilisés par l'écran de combat.
var mode: Mode = Mode.QUICK
var player_fighter: FighterData
var player_support: FighterData
## Adversaire choisi pour l'entraînement.
var opponent_fighter: FighterData
var difficulty: FighterAI.Difficulty = FighterAI.Difficulty.NORMAL

## Partie d'Arcade en cours : les adversaires ({fighter, support}) et le combat actuel (0 à 5).
var arcade_opponents: Array[Dictionary] = []
var arcade_index := 0

## Mode Histoire : progression, déblocages, chapitre en cours.
var story := StoryProgress.new()
## Le combat d'histoire en cours (voir StoryData : règle, décor, adversaire...).
var story_fight := {}

## Réglages enregistrés sur l'appareil.
var language := ""
## Volumes de 0 (muet) à 1 (plein).
var music_volume := 0.8
var sfx_volume := 0.8
var vibration := true
## Transparence des boutons tactiles (0,2 = presque invisibles, 1 = opaques).
var touch_opacity := 0.8
## Aides visuelles : repères ▼ ▲ et main au-dessus des coups qui se préparent.
var attack_markers := true
## Boutons en plus affichés (nom du bouton : vrai / faux).
var extra_buttons := {"Throw": false, "Special2": false, "LowAttack": false, "Charge": false}
## Disposition personnalisée : {nom du bouton: {"position": Vector2, "scale": float}}.
## Vide = disposition d'origine.
var touch_layout := {}

## Chemin du fichier de réglages (les tests en utilisent un autre).
var settings_path := SETTINGS_PATH
## Vrai pendant les tests : on note l'écran demandé sans changer de scène.
var dry_run := false
var last_screen := ""


func _ready() -> void:
	PlayerInput.register_extra_actions()
	load_settings()
	story.load_progress()


# --- Navigation --------------------------------------------------------------

## Change d'écran (menu, sélection, combat...).
func go_to(scene_path: String) -> void:
	last_screen = scene_path
	if dry_run:
		return
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred(scene_path)


## Les combattants de test (rectangles) : gardés pour les tests, cachés dans les menus.
const TEST_FIGHTERS := [&"test_a", &"test_b", &"test_c"]
## Les décors du jeu, dans l'ordre de l'écran de sélection.
const STAGES := ["village_aube", "kumasi_jour", "kumasi_nuit", "savane_itsa", "comoe_crue"]
## Choix « décor au hasard » de l'entraînement.
const RANDOM_STAGE := "random"

## Décor de chaque personnage quand on l'affronte en Arcade (son « terrain »).
const HOME_STAGES := {
	&"abla_pokou": "comoe_crue", &"dakon": "kumasi_nuit", &"itsa": "savane_itsa",
}
## Décor de l'entraînement et du tutoriel.
const TRAINING_STAGE := "village_aube"

## Décor imposé (chapitre du mode Histoire, outils de capture). Vide = choix automatique.
var forced_stage := ""
## Décor choisi pour l'entraînement ("" = village, RANDOM_STAGE = au hasard).
var training_stage := ""


## Tous les vrais personnages (sans les combattants de test).
func characters() -> Array[FighterData]:
	return roster.filter(func(f): return f.id not in TEST_FIGHTERS)


## Les personnages qu'on peut choisir (débloqués).
func playable_roster() -> Array[FighterData]:
	return characters().filter(story.can_play)


## Les personnages qu'on peut appeler en soutien (jouables ou déjà battus).
func support_roster() -> Array[FighterData]:
	return characters().filter(story.can_support)


## Une fiche par son identifiant (y compris les personnages du mode Histoire
## qui ne sont pas dans le roster : guerriers, génie).
func fighter_by_id(id: StringName) -> FighterData:
	for fighter in roster:
		if fighter.id == id:
			return fighter
	var path := "res://data/fighters/%s.tres" % id
	return load(path) if ResourceLoader.exists(path) else null


## Lance un combat du mode Histoire (spec : voir StoryData).
func start_story_fight(spec: Dictionary) -> void:
	mode = Mode.STORY
	story_fight = spec
	player_fighter = fighter_by_id(spec.player)
	player_support = null
	opponent_fighter = fighter_by_id(spec.opponent)
	difficulty = spec.get("difficulty", FighterAI.Difficulty.NORMAL)


## Mode Histoire : ouvre l'étape en cours du chapitre (cases ou combat).
## S'il n'y a plus d'étape, retour à la carte des chapitres.
func play_story_step() -> void:
	var step := story.current_step()
	if step.has("fight"):
		start_story_fight(step.fight)
		go_to(FIGHT)
	elif step.has("panels"):
		mode = Mode.STORY
		go_to(STORY_PANELS)
	else:
		go_to(STORY_MAP)


## Mode Histoire : étape suivante, ou la carte quand le chapitre est fini
## (elle affiche alors ce qui vient d'être débloqué).
func story_next() -> void:
	if story.advance():
		play_story_step()
	else:
		go_to(STORY_MAP)


## Les décors réellement présents dans le jeu.
func available_stages() -> Array:
	return STAGES.filter(Stage.exists)


## Le décor du prochain combat ("" = fond uni du prototype, pour l'arène lancée seule).
func stage_for_fight(opponent: FighterData) -> String:
	if forced_stage != "":
		return forced_stage
	match mode:
		Mode.TRAINING:
			if training_stage == RANDOM_STAGE and not available_stages().is_empty():
				var all := available_stages()
				return all[randi() % all.size()]
			return training_stage if Stage.exists(training_stage) else TRAINING_STAGE
		Mode.TUTORIAL:
			return TRAINING_STAGE
		Mode.STORY:
			for id in [story_fight.get("stage", ""), story_fight.get("fallback_stage", "")]:
				if Stage.exists(id):
					return id
			return ""
		Mode.ARCADE:
			var home: String = HOME_STAGES.get(opponent.id, "")
			if home != "" and Stage.exists(home):
				return home
			# Les autres : un décor existant, différent à chaque combat de la série.
			var all := available_stages()
			return all[arcade_index % all.size()] if not all.is_empty() else ""
	return ""


## Prépare une partie d'Arcade : 6 adversaires tirés du roster, chacun avec un soutien.
func start_arcade(fighter: FighterData, support: FighterData, level: FighterAI.Difficulty, seed := 0) -> void:
	mode = Mode.ARCADE
	player_fighter = fighter
	player_support = support
	difficulty = level
	var rng := RandomNumberGenerator.new()
	if seed != 0:
		rng.seed = seed
	else:
		rng.randomize()
	arcade_opponents.clear()
	var pool: Array[FighterData] = []
	while arcade_opponents.size() < ARCADE_LENGTH:
		if pool.is_empty():
			# Tout le monde peut être affronté, même pas encore débloqué
			# (le battre le débloque comme soutien).
			pool = characters()
			_shuffle(pool, rng)
		var opponent: FighterData = pool.pop_back()
		arcade_opponents.append({"fighter": opponent, "support": _pick_support(opponent, rng)})
	arcade_index = 0


## Passe au combat suivant. Renvoie faux si la série est terminée.
func next_arcade_fight() -> bool:
	arcade_index += 1
	return arcade_index < arcade_opponents.size()


func start_training(fighter: FighterData, support: FighterData, opponent: FighterData, level: FighterAI.Difficulty) -> void:
	mode = Mode.TRAINING
	player_fighter = fighter
	player_support = support
	opponent_fighter = opponent
	difficulty = level


## Un soutien différent du combattant lui-même.
func _pick_support(fighter: FighterData, rng: RandomNumberGenerator) -> FighterData:
	var others := characters().filter(func(f): return f != fighter)
	if others.is_empty():
		return fighter
	return others[rng.randi_range(0, others.size() - 1)]


func _shuffle(list: Array, rng: RandomNumberGenerator) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp = list[i]
		list[i] = list[j]
		list[j] = temp


# --- Réglages ----------------------------------------------------------------

func set_language(code: String) -> void:
	language = code
	TranslationServer.set_locale(code)
	save_settings()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_volumes()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_volumes()


## Fait vibrer le téléphone (si le joueur l'a permis). Sans effet sur ordinateur.
func vibrate(duration_ms: int) -> void:
	if vibration:
		Input.vibrate_handheld(duration_ms)


func is_extra_button_on(control_name: String) -> bool:
	return extra_buttons.get(control_name, false)


## Avec un bouton Charge, le bouton Spécial ne charge plus : il part dès l'appui.
func special_hold_charges() -> bool:
	return not is_extra_button_on("Charge")


## Position et taille enregistrées d'un bouton tactile ({} = celles d'origine).
func get_touch_layout(control_name: String) -> Dictionary:
	return touch_layout.get(control_name, {})


## Remet tous les réglages à leur valeur de départ (sans enregistrer).
## Sert aux tests et aux outils, pour ne jamais dépendre des réglages du joueur.
func reset_settings(path: String) -> void:
	settings_path = path
	music_volume = 0.8
	sfx_volume = 0.8
	vibration = true
	touch_opacity = 0.8
	touch_layout = {}
	attack_markers = true
	for button in EXTRA_BUTTONS:
		extra_buttons[button] = false
	_apply_volumes()


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(settings_path) == OK:
		language = config.get_value("general", "language", "")
		music_volume = config.get_value("audio", "music_volume", 0.8)
		sfx_volume = config.get_value("audio", "sfx_volume", 0.8)
		vibration = config.get_value("controls", "vibration", true)
		touch_opacity = config.get_value("controls", "touch_opacity", 0.8)
		touch_layout = config.get_value("controls", "touch_layout", {})
		attack_markers = config.get_value("controls", "attack_markers", true)
		var saved_extras: Dictionary = config.get_value("controls", "extra_buttons", {})
		for button in EXTRA_BUTTONS:
			extra_buttons[button] = saved_extras.get(button, false)
	# Première ouverture : on suit la langue du téléphone.
	if language not in LANGUAGES:
		language = "fr" if OS.get_locale_language() == "fr" else "en"
	TranslationServer.set_locale(language)
	_apply_volumes()


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("general", "language", language)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("controls", "vibration", vibration)
	config.set_value("controls", "touch_opacity", touch_opacity)
	config.set_value("controls", "touch_layout", touch_layout)
	config.set_value("controls", "attack_markers", attack_markers)
	config.set_value("controls", "extra_buttons", extra_buttons)
	config.save(settings_path)
	settings_saved.emit()


## Les volumes réglés s'appliquent aux « bus » audio Music et SFX
## (onglet Audio en bas de l'éditeur).
func _apply_volumes() -> void:
	for bus_volume in [["Music", music_volume], ["SFX", sfx_volume]]:
		var bus := AudioServer.get_bus_index(bus_volume[0])
		if bus >= 0:
			AudioServer.set_bus_volume_db(bus, linear_to_db(bus_volume[1]))
			AudioServer.set_bus_mute(bus, bus_volume[1] <= 0.0)
