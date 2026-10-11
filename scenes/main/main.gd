extends Control
## Écran de vérification des fondations.
##
## Il prouve que tout est bien branché : la résolution pixel art,
## les traductions FR/EN et les fiches des combattants.
## Il sera remplacé plus tard par l'écran titre.

@onready var fighter_info: Label = %FighterInfo
@onready var language_button: Button = %LanguageButton


func _ready() -> void:
	language_button.pressed.connect(_on_language_button_pressed)
	_refresh()


func _on_language_button_pressed() -> void:
	var next := "en" if GameState.language == "fr" else "fr"
	GameState.set_language(next)
	_refresh()


func _refresh() -> void:
	var samory: FighterData = GameState.roster[0]
	fighter_info.text = "%s  (%d - %d)\n%s\n\n%s" % [
		tr(samory.name_key),
		samory.birth_year,
		samory.death_year,
		tr(samory.origin_key),
		tr(samory.bio_key),
	]
