class_name StoryProgress
extends RefCounted
## La progression du mode Histoire et ce qu'elle débloque, enregistrées sur
## l'appareil (user://progress.cfg, à part des réglages).
##
## Règles du cahier des charges :
## - les héros principaux sont jouables dès le départ ;
## - battre un personnage le débloque comme soutien ;
## - finir son histoire le rend jouable.
## Elle sait aussi où en est le joueur dans le chapitre en cours (étape).

const PROGRESS_PATH := "user://progress.cfg"
## Jouables dès le premier lancement (les 3 héros des arcs de la V1).
const BASE_PLAYABLE := [&"abla_pokou", &"sekou_ouattara", &"behanzin"]

var path := PROGRESS_PATH
## Tout débloqué (tests, et plus tard un réglage de démonstration).
var unlock_all := false
var completed := {}
var supports := {}
var playables := {}

## Chapitre en cours (-1 = aucun) et étape dans ce chapitre.
var chapter_index := -1
var step_index := 0
## Ce que le dernier chapitre terminé a débloqué : [[clé de texte, id], ...].
var just_unlocked: Array = []


func reset(new_path: String, everything := false) -> void:
	path = new_path
	unlock_all = everything
	completed = {}
	supports = {}
	playables = {}
	chapter_index = -1
	step_index = 0
	just_unlocked = []


func load_progress() -> void:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return
	completed = config.get_value("story", "completed", {})
	supports = config.get_value("unlocks", "supports", {})
	playables = config.get_value("unlocks", "playables", {})


func save_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("story", "completed", completed)
	config.set_value("unlocks", "supports", supports)
	config.set_value("unlocks", "playables", playables)
	config.save(path)


# --- Déblocages --------------------------------------------------------------

func can_play(fighter: FighterData) -> bool:
	return unlock_all or fighter.id in BASE_PLAYABLE or playables.has(fighter.id)


func can_support(fighter: FighterData) -> bool:
	return can_play(fighter) or supports.has(fighter.id)


## Un personnage battu (Arcade ou Histoire) devient un soutien possible.
func record_defeat(fighter: FighterData) -> void:
	if fighter == null or supports.has(fighter.id) or can_play(fighter):
		return
	supports[fighter.id] = true
	save_progress()


# --- Chapitres ---------------------------------------------------------------

func chapters() -> Array:
	return StoryData.POKOU_ARC


func is_open(index: int) -> bool:
	return unlock_all or index == 0 or completed.has(chapters()[index - 1].id)


func is_completed(index: int) -> bool:
	return completed.has(chapters()[index].id)


func start(index: int) -> void:
	chapter_index = index
	step_index = 0
	just_unlocked = []


func current_chapter() -> Dictionary:
	return chapters()[chapter_index] if chapter_index >= 0 else {}


func current_step() -> Dictionary:
	var steps: Array = current_chapter().get("steps", [])
	return steps[step_index] if step_index < steps.size() else {}


## Passe à l'étape suivante. Renvoie faux quand le chapitre est fini (il est alors
## enregistré comme terminé, avec ce qu'il débloque).
func advance() -> bool:
	step_index += 1
	if step_index < current_chapter().steps.size():
		return true
	_complete()
	return false


func _complete() -> void:
	var id: String = current_chapter().id
	completed[id] = true
	just_unlocked = []
	var unlocks: Dictionary = StoryData.UNLOCKS.get(id, {})
	for fighter_id in unlocks.get("support", []):
		if not supports.has(fighter_id):
			supports[fighter_id] = true
			just_unlocked.append(["STORY_UNLOCK_SUPPORT", fighter_id])
	for fighter_id in unlocks.get("playable", []):
		if not playables.has(fighter_id):
			playables[fighter_id] = true
			just_unlocked.append(["STORY_UNLOCK_PLAYABLE", fighter_id])
	save_progress()
