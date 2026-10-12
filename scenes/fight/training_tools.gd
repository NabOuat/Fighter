class_name TrainingTools
extends Node
## Outils de test du prototype, rangés à part de l'arène pour pouvoir les
## retirer facilement du jeu final :
## - ce que fait l'adversaire (touches 1 à 8) : immobile, garde, attaques en
##   boucle... ou l'IA (8, par défaut), dont on change la difficulté avec Y ;
## - changer le soutien du joueur (T), vider l'énergie (0) ;
## - le texte de débogage en haut de l'écran.

## Ce que fait le mannequin. AI = l'ordinateur joue vraiment.
enum DummyMode { STAND, GUARD_HIGH, GUARD_LOW, ATTACK, ATTACK_LOW, PROJECTILE, ASSIST, AI }

## Soutiens de test, à faire défiler avec la touche T : attaque, protection, soin.
const TEST_SUPPORTS: Array[FighterData] = [
	preload("res://data/fighters/test_a.tres"),
	preload("res://data/fighters/test_b.tres"),
	preload("res://data/fighters/test_c.tres"),
]
## Le mannequin agit toutes les 80 frames (1,3 seconde).
const DUMMY_PERIOD := 80

var dummy_mode: DummyMode = DummyMode.AI
## L'adversaire contrôlé par l'ordinateur.
var ai := FighterAI.new(FighterAI.Difficulty.NORMAL)
var support_index := 0
## Frames comptées pour rythmer les actions du mannequin.
var frame_count := 0

var _player: Fighter
var _dummy: Fighter

@onready var debug_label: Label = $DebugLabel


## Branche les outils sur les deux combattants et leur donne leurs soutiens de test.
func setup(player: Fighter, dummy: Fighter) -> void:
	_player = player
	_dummy = dummy
	player.support = TEST_SUPPORTS[0]
	dummy.support = TEST_SUPPORTS[1]


## Donne ses commandes au mannequin pour cette frame.
func drive_dummy(projectiles: Array[Projectile]) -> void:
	frame_count += 1
	if dummy_mode == DummyMode.AI:
		ai.update(_dummy, _player, projectiles)
		return
	var intent := _dummy.intent
	var beat := frame_count % DUMMY_PERIOD
	intent.guard = dummy_mode in [DummyMode.GUARD_HIGH, DummyMode.GUARD_LOW]
	intent.crouch = dummy_mode in [DummyMode.GUARD_LOW, DummyMode.ATTACK_LOW]
	if dummy_mode in [DummyMode.ATTACK, DummyMode.ATTACK_LOW]:
		# Trois appuis espacés de 6 frames : le combo complet (ou un coup bas).
		intent.attack = beat in [0, 6, 12]
	# Un appui court sur Spécial : le mannequin lance son projectile.
	intent.special = dummy_mode == DummyMode.PROJECTILE and beat < 3
	if dummy_mode == DummyMode.PROJECTILE:
		_dummy.energy = Fighter.MAX_ENERGY
	# Le mannequin appelle son soutien dès qu'il est rechargé.
	intent.assist = dummy_mode == DummyMode.ASSIST and beat == 0


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_0:
			_player.energy = 0.0
			_dummy.energy = 0.0
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8:
			dummy_mode = (event.physical_keycode - KEY_1) as DummyMode
			frame_count = 0
		KEY_Y:
			ai.difficulty = ((ai.difficulty + 1) % FighterAI.Difficulty.size()) as FighterAI.Difficulty
		KEY_T:
			support_index = (support_index + 1) % TEST_SUPPORTS.size()
			_player.support = TEST_SUPPORTS[support_index]
			_player.assist_cooldown = 0


## Texte de débogage pour le développeur, absent du jeu final
## (c'est pour ça qu'il n'est pas dans le fichier de traductions).
func show_debug(status: String) -> void:
	debug_label.text = "%s | P1 %s E%d [T: %s] | Dummy [%s %s] | M mode 1-8 dummy Y IA R reset" % [
		status, Fighter.State.keys()[_player.state], int(_player.energy), _player.support.id,
		DummyMode.keys()[dummy_mode], FighterAI.Difficulty.keys()[ai.difficulty],
	]
