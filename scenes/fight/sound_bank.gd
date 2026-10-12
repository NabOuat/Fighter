class_name SoundBank
extends Node
## Joue les bruitages du combat.
##
## Les sons sont des fichiers de assets/audio/sfx/ (provisoires pour l'instant,
## fabriqués par tools/make_placeholder_sounds.py). Plusieurs sons peuvent se
## jouer en même temps, et chaque son varie un peu de hauteur pour ne pas lasser.

const SOUNDS := [
	"hit_light", "hit_heavy", "block", "parry", "whoosh", "special",
	"ultimate", "ko", "dodge", "assist", "gong", "ui_click",
]
## Nombre de sons qui peuvent se superposer.
const VOICES := 8
## Variation de hauteur au hasard (0,06 = plus ou moins 6 %).
const PITCH_VARIATION := 0.06

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	# Le menu pause doit pouvoir faire « clic » même quand le jeu est en pause.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for sound in SOUNDS:
		var path := "res://assets/audio/sfx/%s.wav" % sound
		if ResourceLoader.exists(path):
			_streams[sound] = load(path)
		else:
			push_warning("Son introuvable : " + path)
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)


## À la fermeture du jeu, on arrête proprement les sons encore en cours.
func _exit_tree() -> void:
	for player in _players:
		player.stop()
		player.stream = null


func play(sound: String, volume_db := 0.0) -> void:
	if not _streams.has(sound):
		return
	var player := _players[_next]
	_next = (_next + 1) % VOICES
	player.stream = _streams[sound]
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + _rng.randf_range(-PITCH_VARIATION, PITCH_VARIATION)
	player.play()
