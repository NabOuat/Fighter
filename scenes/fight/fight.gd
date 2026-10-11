extends Node2D
## L'arène : elle fait avancer le combat image par image.
##
## À chaque frame (60 par seconde), dans cet ordre :
##   1. chaque combattant lit ses commandes ;
##   2. chaque combattant joue une frame (tick) ;
##   3. on empêche les deux corps de se chevaucher ;
##   4. on vérifie si une zone de frappe touche une zone vulnérable.
## Quand un coup touche, tout le combat se fige quelques frames (« hitstop ») :
## c'est ce qui donne la sensation d'impact.
##
## Lance cette scène seule avec F6 pour tester.

## Largeur minimale entre les centres des deux combattants.
const PUSHBOX_WIDTH := 20.0
## Limites de l'arène pour le centre des combattants.
const ARENA_LEFT := 12.0
const ARENA_RIGHT := 468.0

var hitstop := 0

@onready var player: Fighter = $Player
@onready var dummy: Fighter = $Dummy
@onready var fighters: Array[Fighter] = [player, dummy]
@onready var player_bar: HealthBar = $HUD/PlayerBar
@onready var dummy_bar: HealthBar = $HUD/DummyBar
@onready var player_name: Label = $HUD/PlayerName
@onready var dummy_name: Label = $HUD/DummyName
@onready var combo_label: Label = $HUD/ComboLabel
@onready var debug_label: Label = $DebugLabel


func _ready() -> void:
	player.opponent = dummy
	dummy.opponent = player
	player_name.text = player.data.name_key
	dummy_name.text = dummy.data.name_key


func _physics_process(delta: float) -> void:
	for fighter in fighters:
		fighter.poll_input()
	if hitstop > 0:
		hitstop -= 1
		return

	for fighter in fighters:
		fighter.tick(delta)
	_separate_fighters()
	_resolve_hits()
	_end_finished_combos()
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	# Touche R : remettre les deux combattants en place (pratique pour tester).
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_R:
		player.position.x = 170
		dummy.position.x = 310
		for fighter in fighters:
			fighter.reset()


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
		attacker.combo_hits += 1
		defender.take_hit(attack, attacker)
		hitstop = maxi(hitstop, attack.hitstop)


## Un combo s'arrête dès que celui qui encaisse peut de nouveau agir.
func _end_finished_combos() -> void:
	for fighter in fighters:
		if fighter.is_free():
			fighter.opponent.combo_hits = 0


func _update_hud() -> void:
	player_bar.set_ratio(float(player.health) / Fighter.MAX_HEALTH)
	dummy_bar.set_ratio(float(dummy.health) / Fighter.MAX_HEALTH)
	combo_label.visible = player.combo_hits >= 2
	combo_label.text = tr("FIGHT_COMBO_HITS") % player.combo_hits
	# Texte de débogage pour le développeur, absent du jeu final
	# (c'est pour ça qu'il n'est pas dans le fichier de traductions).
	debug_label.text = "P1 %s f%d   Dummy %s   HP %d / %d   [R] reset" % [
		Fighter.State.keys()[player.state], player.attack_frame,
		Fighter.State.keys()[dummy.state], player.health, dummy.health,
	]
