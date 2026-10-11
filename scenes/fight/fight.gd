extends Node2D
## L'arène d'entraînement : elle fait avancer le combat image par image.
##
## À chaque frame (60 par seconde), dans cet ordre :
##   1. chaque combattant lit ses commandes (le mannequin reçoit les siennes) ;
##   2. chaque combattant joue une frame (tick), puis les projectiles avancent ;
##   3. on empêche les deux corps de se chevaucher ;
##   4. on vérifie si une zone de frappe (ou un projectile) touche une zone vulnérable.
## Quand un coup touche, tout le combat se fige quelques frames (« hitstop ») :
## c'est ce qui donne la sensation d'impact. L'ultime fige tout plus longtemps
## pour sa mise en scène.
##
## Lance cette scène seule avec F6 pour tester.

## Ce que fait le mannequin (touches 1 à 6 pendant le test).
enum DummyMode { STAND, GUARD_HIGH, GUARD_LOW, ATTACK, ATTACK_LOW, PROJECTILE }

## Largeur minimale entre les centres des deux combattants.
const PUSHBOX_WIDTH := 20.0
## Limites de l'arène pour le centre des combattants.
const ARENA_LEFT := 12.0
const ARENA_RIGHT := 468.0
## Le mannequin agit toutes les 80 frames (1,3 seconde).
const DUMMY_PERIOD := 80
const POPUP_FRAMES := 50
## Durée de l'arrêt du combat au début de l'ultime.
const ULTIMATE_FREEZE_FRAMES := 45

## Énergie gagnée selon ce qui arrive (sur 400 pour la barre pleine).
const ENERGY_ON_HIT := 20.0
const ENERGY_WHEN_HIT := 12.0
const ENERGY_ON_BLOCKED := 8.0
const ENERGY_WHEN_BLOCKING := 5.0
const ENERGY_ON_PARRY := 25.0

var hitstop := 0
var ultimate_freeze := 0
var dummy_mode: DummyMode = DummyMode.STAND
var frame_count := 0
var popup_frames := 0
var projectiles: Array[Projectile] = []

@onready var player: Fighter = $Player
@onready var dummy: Fighter = $Dummy
@onready var fighters: Array[Fighter] = [player, dummy]
@onready var player_bar: HealthBar = $HUD/PlayerBar
@onready var dummy_bar: HealthBar = $HUD/DummyBar
@onready var player_energy: EnergyBar = $HUD/PlayerEnergy
@onready var dummy_energy: EnergyBar = $HUD/DummyEnergy
@onready var player_name: Label = $HUD/PlayerName
@onready var dummy_name: Label = $HUD/DummyName
@onready var combo_label: Label = $HUD/ComboLabel
@onready var popup_label: Label = $HUD/PopupLabel
@onready var dim: ColorRect = $Dim
@onready var debug_label: Label = $DebugLabel


func _ready() -> void:
	player.opponent = dummy
	dummy.opponent = player
	player_name.text = player.data.name_key
	dummy_name.text = dummy.data.name_key
	for fighter in fighters:
		fighter.dodged.connect(_show_popup.bind("FIGHT_DODGE"))
		fighter.projectile_launched.connect(_on_projectile_launched)
		fighter.ultimate_started.connect(_on_ultimate_started)
	_reset_training()


func _physics_process(delta: float) -> void:
	frame_count += 1
	_drive_dummy()
	for fighter in fighters:
		fighter.poll_input()
	if ultimate_freeze > 0:
		ultimate_freeze -= 1
	elif hitstop > 0:
		hitstop -= 1
	else:
		for fighter in fighters:
			fighter.tick(delta)
		for projectile in projectiles:
			projectile.tick(delta)
		_separate_fighters()
		_resolve_hits()
		_resolve_projectiles()
		_end_finished_combos()
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_R:
			_reset_training()
		KEY_0:
			for fighter in fighters:
				fighter.energy = 0.0
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
			dummy_mode = (event.physical_keycode - KEY_1) as DummyMode
			frame_count = 0


## En entraînement : positions de départ et énergie pleine pour tout tester.
## Touche 0 : vider l'énergie pour tester comment elle se remplit.
func _reset_training() -> void:
	player.position.x = 170
	dummy.position.x = 310
	for projectile in projectiles:
		_remove_projectile(projectile)
	projectiles.clear()
	for fighter in fighters:
		fighter.reset()
		fighter.energy = Fighter.MAX_ENERGY


## Donne ses commandes au mannequin selon le mode choisi.
func _drive_dummy() -> void:
	var intent := dummy.intent
	var beat := frame_count % DUMMY_PERIOD
	intent.guard = dummy_mode in [DummyMode.GUARD_HIGH, DummyMode.GUARD_LOW]
	intent.crouch = dummy_mode in [DummyMode.GUARD_LOW, DummyMode.ATTACK_LOW]
	if dummy_mode in [DummyMode.ATTACK, DummyMode.ATTACK_LOW]:
		# Trois appuis espacés de 6 frames : le combo complet (ou un coup bas).
		intent.attack = beat in [0, 6, 12]
	# Un appui court sur Spécial : le mannequin lance son projectile.
	intent.special = dummy_mode == DummyMode.PROJECTILE and beat < 3
	if dummy_mode == DummyMode.PROJECTILE:
		dummy.energy = Fighter.MAX_ENERGY


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
		# Les coups qui coûtent de l'énergie n'en rapportent pas.
		var grants_energy := attack.energy_cost == 0
		_apply(defender.receive_attack(attack, attacker), attack, attacker, defender, grants_energy)


func _resolve_projectiles() -> void:
	var finished: Array[Projectile] = []
	for projectile in projectiles:
		if projectile in finished:
			continue
		# Deux projectiles adverses qui se rencontrent s'annulent.
		for other in projectiles:
			if other != projectile and other.shooter != projectile.shooter and other not in finished \
					and projectile.get_rect().intersects(other.get_rect()):
				finished.append_array([projectile, other])
				hitstop = maxi(hitstop, 4)
				break
		if projectile in finished:
			continue
		var target := projectile.shooter.opponent
		if projectile.get_rect().intersects(target.get_hurtbox_rect()):
			finished.append(projectile)
			var hit := projectile.data.hit
			# Un projectile vient toujours d'un coup spécial : il ne rapporte pas d'énergie.
			_apply(target.receive_attack(hit, projectile.shooter, true), hit, projectile.shooter, target, false)
		elif projectile.is_expired(ARENA_LEFT - 20.0, ARENA_RIGHT + 20.0):
			finished.append(projectile)
	for projectile in finished:
		projectiles.erase(projectile)
		_remove_projectile(projectile)


## Ce qui se passe après un coup : arrêt sur image, combo, énergie, messages.
func _apply(result: Fighter.HitResult, attack: AttackData, attacker: Fighter, defender: Fighter, grants_energy: bool) -> void:
	match result:
		Fighter.HitResult.HIT:
			attacker.combo_hits += 1
			hitstop = maxi(hitstop, attack.hitstop)
			if grants_energy:
				attacker.add_energy(ENERGY_ON_HIT)
			defender.add_energy(ENERGY_WHEN_HIT)
		Fighter.HitResult.BLOCKED:
			hitstop = maxi(hitstop, int(attack.hitstop * 0.5))
			if grants_energy:
				attacker.add_energy(ENERGY_ON_BLOCKED)
			defender.add_energy(ENERGY_WHEN_BLOCKING)
		Fighter.HitResult.PARRIED:
			hitstop = maxi(hitstop, 12)
			defender.add_energy(ENERGY_ON_PARRY)
			_show_popup("FIGHT_PARRY")


func _on_projectile_launched(data: ProjectileData, shooter: Fighter) -> void:
	var projectile := Projectile.new()
	projectile.launch(data, shooter)
	add_child(projectile)
	projectiles.append(projectile)
	shooter.active_projectiles += 1


func _remove_projectile(projectile: Projectile) -> void:
	projectile.shooter.active_projectiles = maxi(0, projectile.shooter.active_projectiles - 1)
	projectile.queue_free()


func _on_ultimate_started(_fighter: Fighter) -> void:
	ultimate_freeze = ULTIMATE_FREEZE_FRAMES
	_show_popup("FIGHT_ULTIMATE")


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
	player_energy.set_ratio(player.energy / Fighter.MAX_ENERGY)
	dummy_energy.set_ratio(dummy.energy / Fighter.MAX_ENERGY)
	combo_label.visible = player.combo_hits >= 2
	combo_label.text = tr("FIGHT_COMBO_HITS") % player.combo_hits
	popup_frames = maxi(0, popup_frames - 1)
	popup_label.visible = popup_frames > 0
	# Pendant l'arrêt de l'ultime, l'écran s'assombrit.
	dim.visible = ultimate_freeze > 0
	# Texte de débogage pour le développeur, absent du jeu final
	# (c'est pour ça qu'il n'est pas dans le fichier de traductions).
	debug_label.text = "P1 %s E%d | Dummy %s [%s] | 1-6 dummy  0 energie  R reset" % [
		Fighter.State.keys()[player.state], int(player.energy),
		Fighter.State.keys()[dummy.state], DummyMode.keys()[dummy_mode],
	]
