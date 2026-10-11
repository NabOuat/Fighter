extends Node2D
## L'arène d'entraînement : elle fait avancer le combat image par image.
##
## À chaque frame (60 par seconde), dans cet ordre :
##   1. chaque combattant lit ses commandes (le mannequin reçoit les siennes) ;
##   2. chaque combattant joue une frame (tick) ;
##   3. on empêche les deux corps de se chevaucher ;
##   4. on vérifie si une zone de frappe touche une zone vulnérable.
## Quand un coup touche, tout le combat se fige quelques frames (« hitstop ») :
## c'est ce qui donne la sensation d'impact.
##
## Lance cette scène seule avec F6 pour tester.

## Ce que fait le mannequin (touches 1 à 5 pendant le test).
enum DummyMode { STAND, GUARD_HIGH, GUARD_LOW, ATTACK, ATTACK_LOW }

## Largeur minimale entre les centres des deux combattants.
const PUSHBOX_WIDTH := 20.0
## Limites de l'arène pour le centre des combattants.
const ARENA_LEFT := 12.0
const ARENA_RIGHT := 468.0
## Le mannequin attaque toutes les 80 frames (1,3 seconde).
const DUMMY_ATTACK_PERIOD := 80
const POPUP_FRAMES := 50

var hitstop := 0
var dummy_mode: DummyMode = DummyMode.STAND
var frame_count := 0
var popup_frames := 0

@onready var player: Fighter = $Player
@onready var dummy: Fighter = $Dummy
@onready var fighters: Array[Fighter] = [player, dummy]
@onready var player_bar: HealthBar = $HUD/PlayerBar
@onready var dummy_bar: HealthBar = $HUD/DummyBar
@onready var player_name: Label = $HUD/PlayerName
@onready var dummy_name: Label = $HUD/DummyName
@onready var combo_label: Label = $HUD/ComboLabel
@onready var popup_label: Label = $HUD/PopupLabel
@onready var debug_label: Label = $DebugLabel


func _ready() -> void:
	player.opponent = dummy
	dummy.opponent = player
	player_name.text = player.data.name_key
	dummy_name.text = dummy.data.name_key
	for fighter in fighters:
		fighter.dodged.connect(_show_popup.bind("FIGHT_DODGE"))
	_reset_training()


func _physics_process(delta: float) -> void:
	frame_count += 1
	_drive_dummy()
	for fighter in fighters:
		fighter.poll_input()
	if hitstop > 0:
		hitstop -= 1
	else:
		for fighter in fighters:
			fighter.tick(delta)
		_separate_fighters()
		_resolve_hits()
		_end_finished_combos()
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_R:
			_reset_training()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			dummy_mode = (event.physical_keycode - KEY_1) as DummyMode
			frame_count = 0


## En entraînement : positions de départ et énergie pleine pour tout tester.
func _reset_training() -> void:
	player.position.x = 170
	dummy.position.x = 310
	for fighter in fighters:
		fighter.reset()
		fighter.energy = Fighter.MAX_ENERGY


## Donne ses commandes au mannequin selon le mode choisi.
func _drive_dummy() -> void:
	var intent := dummy.intent
	intent.guard = dummy_mode in [DummyMode.GUARD_HIGH, DummyMode.GUARD_LOW]
	intent.crouch = dummy_mode in [DummyMode.GUARD_LOW, DummyMode.ATTACK_LOW]
	if dummy_mode in [DummyMode.ATTACK, DummyMode.ATTACK_LOW]:
		# Trois appuis espacés de 6 frames : le combo complet (ou un coup bas).
		var beat := frame_count % DUMMY_ATTACK_PERIOD
		intent.attack = beat in [0, 6, 12]


func _separate_fighters() -> void:
	var gap := dummy.global_position.x - player.global_position.x
	var both_low := absf(player.global_position.y - dummy.global_position.y) < Fighter.STAND_HEIGHT * 0.7
	if both_low and absf(gap) < PUSHBOX_WIDTH:
		var push := (PUSHBOX_WIDTH - absf(gap)) / 2.0
		var side := signf(gap) if gap != 0.0 else float(player.facing)
		player.position.x -= side * push
		dummy.position.x += side * push
	for fighter in fighters:
		fighter.position.x = clampf(fighter.position.x, ARENA_LEFT, ARENA_RIGHT)


func _resolve_hits() -> void:
	for attacker in fighters:
		var defender := attacker.opponent
		var hitbox := attacker.get_hitbox_rect()
		if not hitbox.has_area():
			continue
		if not hitbox.intersects(defender.get_hurtbox_rect()):
			continue
		var attack := attacker.current_attack
		attacker.attack_has_hit = true
		match defender.receive_attack(attack, attacker):
			Fighter.HitResult.HIT:
				attacker.combo_hits += 1
				hitstop = maxi(hitstop, attack.hitstop)
			Fighter.HitResult.BLOCKED:
				hitstop = maxi(hitstop, int(attack.hitstop * 0.5))
			Fighter.HitResult.PARRIED:
				hitstop = maxi(hitstop, 12)
				_show_popup("FIGHT_PARRY")


## Un combo s'arrête dès que celui qui encaisse peut de nouveau agir.
func _end_finished_combos() -> void:
	for fighter in fighters:
		if fighter.is_free():
			fighter.opponent.combo_hits = 0


func _show_popup(text_key: String) -> void:
	popup_label.text = text_key
	popup_frames = POPUP_FRAMES


func _update_hud() -> void:
	player_bar.set_ratio(float(player.health) / Fighter.MAX_HEALTH)
	dummy_bar.set_ratio(float(dummy.health) / Fighter.MAX_HEALTH)
	combo_label.visible = player.combo_hits >= 2
	combo_label.text = tr("FIGHT_COMBO_HITS") % player.combo_hits
	popup_frames = maxi(0, popup_frames - 1)
	popup_label.visible = popup_frames > 0
	# Texte de débogage pour le développeur, absent du jeu final
	# (c'est pour ça qu'il n'est pas dans le fichier de traductions).
	debug_label.text = "P1 %s  E%d | Dummy %s [%s] | 1-5 dummy  R reset" % [
		Fighter.State.keys()[player.state], player.energy,
		Fighter.State.keys()[dummy.state], DummyMode.keys()[dummy_mode],
	]
