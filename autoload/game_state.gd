extends Node
## Mémoire globale du jeu.
##
## Ce script est un « autoload » : Godot le charge au démarrage et il reste
## actif pendant toute la partie. On y accède depuis n'importe quel script
## en écrivant simplement GameState (ex : GameState.difficulty).

const SETTINGS_PATH := "user://settings.cfg"
const LANGUAGES := ["fr", "en"]

## Liste de tous les combattants jouables. Pour en ajouter un :
## crée son fichier .tres dans data/fighters/ puis ajoute-le ici.
var roster: Array[FighterData] = [
	preload("res://data/fighters/samory_toure.tres"),
]

## Choix faits dans les menus, utilisés par l'écran de combat.
var player_fighter: FighterData
var opponent_fighter: FighterData
## 0 = facile, 1 = normal, 2 = difficile.
var difficulty := 1

## Réglages sauvegardés sur l'appareil.
var language := ""
var sound_enabled := true


func _ready() -> void:
	load_settings()


func set_language(code: String) -> void:
	language = code
	TranslationServer.set_locale(code)
	save_settings()


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		language = config.get_value("general", "language", "")
		sound_enabled = config.get_value("general", "sound_enabled", true)
	# Première ouverture : on suit la langue du téléphone.
	if language not in LANGUAGES:
		language = "fr" if OS.get_locale_language() == "fr" else "en"
	TranslationServer.set_locale(language)


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("general", "language", language)
	config.set_value("general", "sound_enabled", sound_enabled)
	config.save(SETTINGS_PATH)
