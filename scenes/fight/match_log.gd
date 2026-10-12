class_name MatchLog
extends Node
## Le journal des combats : après chaque combat d'Arcade contre l'IA, une ligne
## est ajoutée au fichier user://match_log.csv (qui gagne, en combien de temps,
## combien de coups portés, parés...). Sert à régler l'IA contre de vrais
## joueurs, et pas seulement contre elle-même.
##
## Sur ordinateur, le fichier est dans :
##   %APPDATA%/Godot/app_userdata/Legendz Fighting/match_log.csv
## Résumé par difficulté : python tools/summarize_match_log.py

const LOG_PATH := "user://match_log.csv"
const COLUMNS := ["date", "difficulty", "player", "opponent", "result", "score", "seconds",
		"player_hits", "player_blocked", "ai_hits", "ai_blocked", "player_throws", "ai_parries", "player_dodges", "ai_dodges"]

## Le fichier du journal (les tests en utilisent un autre).
var log_path := LOG_PATH
var stats := {}
var _frames := 0
var _player: Fighter
var _dummy: Fighter


func setup(player: Fighter, dummy: Fighter) -> void:
	_player = player
	_dummy = dummy
	player.dodged.connect(func(): _add("player_dodges"))
	dummy.dodged.connect(func(): _add("ai_dodges"))
	reset()


func reset() -> void:
	_frames = 0
	stats = {}
	for column in COLUMNS.slice(7):
		stats[column] = 0


## Une frame de combat de plus (pour la durée).
func tick() -> void:
	_frames += 1


## Appelée par l'arène après chaque coup qui atteint sa cible.
func on_hit(result: Fighter.HitResult, attack: AttackData, attacker: Fighter, defender: Fighter) -> void:
	var by_player := attacker == _player
	match result:
		Fighter.HitResult.HIT:
			_add("player_hits" if by_player else "ai_hits")
			if by_player and attack.is_throw:
				_add("player_throws")
		Fighter.HitResult.BLOCKED:
			# « player_blocked » : coups du joueur parés par l'IA.
			_add("player_blocked" if by_player else "ai_blocked")
		Fighter.HitResult.PARRIED:
			if defender == _dummy:
				_add("ai_parries")


func _add(column: String) -> void:
	stats[column] = stats.get(column, 0) + 1


## Écrit la ligne du combat qui vient de finir.
func write(difficulty: String, result: String, score: String) -> void:
	var exists := FileAccess.file_exists(log_path)
	var file := FileAccess.open(log_path, FileAccess.READ_WRITE if exists else FileAccess.WRITE)
	if file == null:
		push_warning("Journal des combats : impossible d'écrire " + log_path)
		return
	if exists:
		file.seek_end()
	else:
		file.store_csv_line(PackedStringArray(COLUMNS))
	var line := PackedStringArray([
		Time.get_datetime_string_from_system(), difficulty, String(_player.data.id), String(_dummy.data.id),
		result, score, str(snappedf(_frames / 60.0, 0.1)),
	])
	for column in COLUMNS.slice(7):
		line.append(str(stats[column]))
	file.store_csv_line(line)
	file.close()
