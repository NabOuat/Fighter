extends Node2D
## L'arène : elle fait avancer le combat image par image et gère les manches.
##
## À chaque frame (60 par seconde), dans cet ordre :
##   1. chaque combattant lit ses commandes (bloquées pendant les annonces) ;
##   2. chaque combattant joue une frame (tick), puis les soutiens et les projectiles ;
##   3. on empêche les deux corps de se chevaucher ;
##   4. on vérifie les coups : combattants, soutiens, projectiles, boucliers.
## Quand un coup touche, tout le combat se fige quelques frames (« hitstop ») :
## c'est ce qui donne la sensation d'impact. L'ultime fige tout plus longtemps
## pour sa mise en scène.
##
## Deux modes (touche M pour passer de l'un à l'autre) :
## - Combat : 2 manches gagnantes, chrono de 60 secondes, K.O. et temps écoulé.
## - Entraînement : pas de chrono, personne ne peut être mis K.O., énergie pleine.
##
## L'affichage est dans la scène HUD (scenes/ui/fight_hud), les outils de test
## (mannequin, touches 0 à 8, Y, T) dans TrainingTools.
##
## Lance cette scène seule avec F6 pour tester.

## Les étapes d'un combat.
enum Phase { INTRO, FIGHT, ROUND_OVER, MATCH_OVER }

## Manches à gagner pour remporter le combat.
const ROUNDS_TO_WIN := 2
## Durée d'une manche : 60 secondes.
const ROUND_FRAMES := 60 * 60
## Annonce de début de manche : « Round 1 » puis « Combat ! ».
const INTRO_ROUND_FRAMES := 70
const INTRO_TOTAL_FRAMES := 110
## Après un K.O., le combat passe au ralenti un moment.
const KO_SLOWMO_FRAMES := 60
## Fin de manche : « K.O. » d'abord, puis le nom du gagnant, puis la manche suivante.
const RESULT_SHOW_FRAMES := 90
const ROUND_OVER_FRAMES := 210

## Largeur minimale entre les centres des deux combattants.
const PUSHBOX_WIDTH := 20.0
## Limites de l'arène pour le centre des combattants.
const ARENA_LEFT := 12.0
const ARENA_RIGHT := 468.0
const START_X_PLAYER := 170.0
const START_X_DUMMY := 310.0
## Hauteur du sol (les soutiens apparaissent toujours au sol).
const FLOOR_Y := 230.0
## Durée de l'arrêt du combat au début de l'ultime.
const ULTIMATE_FREEZE_FRAMES := 45

## Tremblement de l'écran sur les gros coups : force (pixels) et durée (frames).
const SHAKE_HEAVY := 3.0
const SHAKE_HEAVY_FRAMES := 8
const SHAKE_KO := 5.0
const SHAKE_KO_FRAMES := 20
## Un coup est « lourd » (gros bruit, grosses étincelles) à partir de ces dégâts.
const HEAVY_DAMAGE := 60

## Énergie gagnée selon ce qui arrive (sur 400 pour la barre pleine).
const ENERGY_ON_HIT := 20.0
const ENERGY_WHEN_HIT := 12.0
const ENERGY_ON_BLOCKED := 8.0
const ENERGY_WHEN_BLOCKING := 5.0
const ENERGY_ON_PARRY := 25.0

var training := false
var phase: Phase = Phase.INTRO
## Frames écoulées depuis le début de l'étape en cours.
var phase_frames := 0
var round_number := 1
var player_wins := 0
var dummy_wins := 0
var timer_frames := ROUND_FRAMES
var slowmo_frames := 0
## Texte (clé de traduction) annonçant le résultat de la manche.
var round_result_key := ""
## Gagnant(s) de la dernière manche (les deux en cas d'égalité).
var round_winners: Array[Fighter] = []

var hitstop := 0
var ultimate_freeze := 0
var frame_count := 0
var projectiles: Array[Projectile] = []
var assists: Array[Assist] = []
var shake_frames := 0
var shake_strength := 0.0
var _shake_rng := RandomNumberGenerator.new()

@onready var player: Fighter = $Player
@onready var dummy: Fighter = $Dummy
@onready var fighters: Array[Fighter] = [player, dummy]
@onready var hud: FightHUD = $HUD
@onready var tools: TrainingTools = $TrainingTools
@onready var dim: ColorRect = $Dim
@onready var touch_controls: TouchControls = $TouchControls
@onready var camera: Camera2D = $Camera
@onready var effects: HitEffects = $HitEffects
@onready var sounds: SoundBank = $Sounds
@onready var pause_menu: PauseMenu = $PauseMenu


func _ready() -> void:
	player.opponent = dummy
	dummy.opponent = player
	hud.show_names(player, dummy)
	for fighter in fighters:
		fighter.dodged.connect(hud.show_popup.bind("FIGHT_DODGE"))
		fighter.projectile_launched.connect(_on_projectile_launched)
		fighter.ultimate_started.connect(_on_ultimate_started)
		fighter.assist_called.connect(_on_assist_called)
		fighter.attack_started.connect(_on_attack_started)
		fighter.dodged.connect(sounds.play.bind("dodge"))
	pause_menu.restart_requested.connect(restart)
	pause_menu.mode_toggled.connect(toggle_training)
	# Pas encore de menu de sélection : les outils de test donnent les soutiens.
	tools.setup(player, dummy)
	touch_controls.fighter = player
	_start_match()


func _physics_process(delta: float) -> void:
	frame_count += 1
	phase_frames += 1
	if training or phase == Phase.FIGHT:
		tools.drive_dummy(projectiles)
		for fighter in fighters:
			fighter.poll_input()
	else:
		for fighter in fighters:
			fighter.release_controls()

	# Après un K.O., le jeu ne calcule qu'une frame sur deux : effet de ralenti.
	slowmo_frames = maxi(0, slowmo_frames - 1)
	if ultimate_freeze > 0:
		ultimate_freeze -= 1
	elif hitstop > 0:
		hitstop -= 1
	elif slowmo_frames > 0 and frame_count % 2 == 0:
		pass
	else:
		_simulate(delta)

	if not training:
		_update_match()
	_update_shake()
	_update_hud()


## Une frame de combat. Les coups ne comptent que pendant la manche
## (après un K.O., les projectiles encore en vol ne touchent plus).
func _simulate(delta: float) -> void:
	for fighter in fighters:
		fighter.tick(delta)
	for assist in assists:
		assist.tick(delta)
	for projectile in projectiles:
		projectile.tick(delta)
	_separate_fighters()
	if training or phase == Phase.FIGHT:
		_resolve_hits()
		_resolve_assists()
		_resolve_projectiles()
		_end_finished_combos()
		if not training:
			timer_frames = maxi(0, timer_frames - 1)
	else:
		_remove_finished_assists()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_R:
			restart()
		KEY_M:
			toggle_training()


# --- Déroulement du combat ---------------------------------------------------

## Recommence : le combat entier, ou la mise en place de l'entraînement.
func restart() -> void:
	if training:
		_reset_training()
	else:
		_start_match()


## Passe du mode combat au mode entraînement, et inversement.
func toggle_training() -> void:
	training = not training
	restart()


func _start_match() -> void:
	training = false
	player_wins = 0
	dummy_wins = 0
	round_number = 1
	for fighter in fighters:
		fighter.immortal = false
		fighter.energy = 0.0
	_start_round()


## Nouvelle manche : vie pleine, positions de départ. L'énergie est gardée.
func _start_round() -> void:
	_clear_effects()
	for fighter in fighters:
		fighter.reset()
	player.position = Vector2(START_X_PLAYER, FLOOR_Y)
	dummy.position = Vector2(START_X_DUMMY, FLOOR_Y)
	timer_frames = ROUND_FRAMES
	_set_phase(Phase.INTRO)
	sounds.play("gong")


## En entraînement : pas de chrono, personne ne peut être mis K.O., énergie pleine.
func _reset_training() -> void:
	_clear_effects()
	for fighter in fighters:
		fighter.reset()
		fighter.immortal = true
		fighter.energy = Fighter.MAX_ENERGY
	player.position = Vector2(START_X_PLAYER, FLOOR_Y)
	dummy.position = Vector2(START_X_DUMMY, FLOOR_Y)
	_set_phase(Phase.FIGHT)


func _set_phase(new_phase: Phase) -> void:
	phase = new_phase
	phase_frames = 0


func _update_match() -> void:
	match phase:
		Phase.INTRO:
			if phase_frames >= INTRO_TOTAL_FRAMES:
				_set_phase(Phase.FIGHT)
		Phase.FIGHT:
			if player.health <= 0 or dummy.health <= 0:
				_end_round(true)
			elif timer_frames <= 0:
				_end_round(false)
		Phase.ROUND_OVER:
			if phase_frames >= ROUND_OVER_FRAMES:
				if player_wins >= ROUNDS_TO_WIN or dummy_wins >= ROUNDS_TO_WIN:
					_set_phase(Phase.MATCH_OVER)
				else:
					round_number += 1
					_start_round()
		Phase.MATCH_OVER:
			if Input.is_action_just_pressed("attack"):
				_start_match()


## Fin de manche, par K.O. ou au chrono. En cas d'égalité, les deux gagnent la manche.
func _end_round(by_ko: bool) -> void:
	round_winners.clear()
	if by_ko:
		for fighter in fighters:
			if fighter.health > 0:
				round_winners.append(fighter)
		round_result_key = "FIGHT_KO" if round_winners.size() == 1 else "FIGHT_DOUBLE_KO"
		slowmo_frames = KO_SLOWMO_FRAMES
		sounds.play("ko")
		_shake(SHAKE_KO, SHAKE_KO_FRAMES)
	else:
		if player.health > dummy.health:
			round_winners.append(player)
		elif dummy.health > player.health:
			round_winners.append(dummy)
		round_result_key = "FIGHT_TIME_UP"
		sounds.play("gong")
	# Double K.O. ou vie égale au chrono : la manche compte pour les deux.
	if round_winners.is_empty():
		round_winners.append_array(fighters)
	for fighter in round_winners:
		if fighter == player:
			player_wins += 1
		else:
			dummy_wins += 1
	_set_phase(Phase.ROUND_OVER)


## Texte de la grande annonce au centre de l'écran (vide = rien à annoncer).
func _announce_text() -> String:
	match phase:
		Phase.INTRO:
			if phase_frames < INTRO_ROUND_FRAMES:
				var last := player_wins == ROUNDS_TO_WIN - 1 and dummy_wins == ROUNDS_TO_WIN - 1
				return tr("FIGHT_FINAL_ROUND") if last else tr("FIGHT_ROUND") % round_number
			return tr("FIGHT_START")
		Phase.ROUND_OVER:
			if phase_frames < RESULT_SHOW_FRAMES:
				return tr(round_result_key)
			return _winner_text(round_winners, "FIGHT_ROUND_WINNER")
		Phase.MATCH_OVER:
			var champions: Array[Fighter] = []
			if player_wins >= ROUNDS_TO_WIN:
				champions.append(player)
			if dummy_wins >= ROUNDS_TO_WIN:
				champions.append(dummy)
			return _winner_text(champions, "FIGHT_MATCH_WINNER") + "\n" + tr("FIGHT_PRESS_RESTART")
	return ""


func _winner_text(winners: Array[Fighter], key: String) -> String:
	if winners.size() != 1:
		return tr("FIGHT_DRAW")
	return tr(key) % tr(winners[0].data.name_key)


# --- Collisions --------------------------------------------------------------

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
		var attack := attacker.current_attack
		# Le bouclier d'un soutien arrête le coup avant qu'il atteigne le combattant.
		if _hits_barrier(hitbox, defender):
			attacker.attack_has_hit = true
			hitstop = maxi(hitstop, 4)
			_barrier_feedback(hitbox.get_center())
			continue
		var hurtbox := defender.get_hurtbox_rect()
		if not hitbox.intersects(hurtbox):
			continue
		attacker.attack_has_hit = true
		# Les coups qui coûtent de l'énergie n'en rapportent pas.
		var grants_energy := attack.energy_cost == 0
		var point := hitbox.intersection(hurtbox).get_center()
		_apply(defender.receive_attack(attack, attacker), attack, attacker, defender, grants_energy, point)


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
				effects.burst(HitEffects.Kind.CLASH, (projectile.global_position + other.global_position) / 2.0)
				sounds.play("block")
				break
		if projectile in finished:
			continue
		var target := projectile.shooter.opponent
		if _hits_barrier(projectile.get_rect(), target):
			finished.append(projectile)
			_barrier_feedback(projectile.global_position)
		elif projectile.get_rect().intersects(target.get_hurtbox_rect()):
			finished.append(projectile)
			var hit := projectile.data.hit
			# Un projectile vient toujours d'un coup spécial : il ne rapporte pas d'énergie.
			_apply(target.receive_attack(hit, projectile.shooter, true), hit, projectile.shooter, target, false, projectile.global_position)
		elif projectile.is_expired(ARENA_LEFT - 20.0, ARENA_RIGHT + 20.0):
			finished.append(projectile)
	for projectile in finished:
		projectiles.erase(projectile)
		_remove_projectile(projectile)


## Ce qui se passe après un coup : arrêt sur image, combo, énergie, messages,
## étincelles et bruitage au point de contact.
func _apply(result: Fighter.HitResult, attack: AttackData, attacker: Fighter, defender: Fighter, grants_energy: bool, point: Vector2) -> void:
	match result:
		Fighter.HitResult.HIT:
			var heavy := attack.damage >= HEAVY_DAMAGE or attack.knockdown
			effects.burst(HitEffects.Kind.HIT_HEAVY if heavy else HitEffects.Kind.HIT_LIGHT, point)
			sounds.play("hit_heavy" if heavy else "hit_light")
			if heavy:
				_shake(SHAKE_HEAVY, SHAKE_HEAVY_FRAMES)
			attacker.combo_hits += 1
			hitstop = maxi(hitstop, attack.hitstop)
			if grants_energy:
				attacker.add_energy(ENERGY_ON_HIT)
			defender.add_energy(ENERGY_WHEN_HIT)
		Fighter.HitResult.BLOCKED:
			effects.burst(HitEffects.Kind.BLOCK, point)
			sounds.play("block")
			hitstop = maxi(hitstop, int(attack.hitstop * 0.5))
			if grants_energy:
				attacker.add_energy(ENERGY_ON_BLOCKED)
			defender.add_energy(ENERGY_WHEN_BLOCKING)
		Fighter.HitResult.PARRIED:
			effects.burst(HitEffects.Kind.PARRY, point)
			sounds.play("parry")
			hitstop = maxi(hitstop, 12)
			defender.add_energy(ENERGY_ON_PARRY)
			hud.show_popup("FIGHT_PARRY")


## Les attaques de soutien touchent comme des coups venus de loin :
## l'adversaire peut les parer ou les contrer, mais ne peut pas étourdir le soutien.
func _resolve_assists() -> void:
	for assist in assists:
		var defender := assist.caller.opponent
		var hitbox := assist.get_hitbox_rect()
		if hitbox.has_area() and not _hits_barrier(hitbox, defender) and hitbox.intersects(defender.get_hurtbox_rect()):
			assist.hit_done = true
			var attack := assist.data.attack
			var point := hitbox.intersection(defender.get_hurtbox_rect()).get_center()
			_apply(defender.receive_attack(attack, assist.caller, true), attack, assist.caller, defender, false, point)
	_remove_finished_assists()


func _remove_finished_assists() -> void:
	var finished: Array[Assist] = []
	for assist in assists:
		if assist.is_finished():
			finished.append(assist)
	for assist in finished:
		assists.erase(assist)
		_remove_assist(assist)


## Vrai si cette zone touche le bouclier d'un soutien qui protège ce combattant.
func _hits_barrier(rect: Rect2, protected: Fighter) -> bool:
	for assist in assists:
		if assist.caller == protected and rect.intersects(assist.get_barrier_rect()):
			assist.barrier_flash = 4
			return true
	return false


# --- Soutiens, projectiles, effets -------------------------------------------

## Un coup ou un projectile arrêté par le bouclier d'un soutien.
func _barrier_feedback(at: Vector2) -> void:
	effects.burst(HitEffects.Kind.BLOCK, at)
	sounds.play("block")


func _on_attack_started(attack: AttackData) -> void:
	if attack.is_ultimate:
		return
	sounds.play("special" if attack.energy_cost > 0 else "whoosh", -4.0)


func _on_assist_called(caller: Fighter) -> void:
	sounds.play("assist")
	var assist := Assist.new()
	assist.summon(caller.support.assist, caller, FLOOR_Y, ARENA_LEFT, ARENA_RIGHT)
	assist.projectile_requested.connect(_launch_projectile.bind(true))
	add_child(assist)
	# Le soutien est dessiné derrière les combattants.
	move_child(assist, player.get_index())
	assists.append(assist)


func _remove_assist(assist: Assist) -> void:
	assist.caller.assist_active = false
	assist.queue_free()


func _on_projectile_launched(data: ProjectileData, shooter: Fighter) -> void:
	var origin := shooter.global_position + Vector2(data.spawn_offset.x * shooter.facing, data.spawn_offset.y)
	_launch_projectile(data, shooter, origin, shooter.facing)


## by_assist : lancé par un soutien (ne compte pas dans la limite d'un projectile à la fois).
func _launch_projectile(data: ProjectileData, shooter: Fighter, origin: Vector2, direction: int, by_assist := false) -> void:
	var projectile := Projectile.new()
	projectile.launch(data, shooter, origin, direction, by_assist)
	add_child(projectile)
	projectiles.append(projectile)
	if not by_assist:
		shooter.active_projectiles += 1


func _remove_projectile(projectile: Projectile) -> void:
	if not projectile.from_assist:
		projectile.shooter.active_projectiles = maxi(0, projectile.shooter.active_projectiles - 1)
	projectile.queue_free()


## Retire tous les projectiles et soutiens, et annule les arrêts en cours.
func _clear_effects() -> void:
	for projectile in projectiles:
		_remove_projectile(projectile)
	projectiles.clear()
	for assist in assists:
		_remove_assist(assist)
	assists.clear()
	hitstop = 0
	ultimate_freeze = 0
	slowmo_frames = 0
	shake_frames = 0
	hud.clear_popup()


func _on_ultimate_started(_fighter: Fighter) -> void:
	sounds.play("ultimate")
	ultimate_freeze = ULTIMATE_FREEZE_FRAMES
	hud.show_popup("FIGHT_ULTIMATE")


## Un combo s'arrête dès que celui qui encaisse peut de nouveau agir.
func _end_finished_combos() -> void:
	for fighter in fighters:
		if fighter.is_free():
			fighter.opponent.combo_hits = 0


# --- Affichage ---------------------------------------------------------------

func _shake(strength: float, frames: int) -> void:
	shake_strength = maxf(shake_strength if shake_frames > 0 else 0.0, strength)
	shake_frames = maxi(shake_frames, frames)


## Le tremblement s'atténue à chaque frame ; seul l'affichage bouge, pas le combat.
func _update_shake() -> void:
	if shake_frames > 0:
		shake_frames -= 1
		var strength := shake_strength * shake_frames / float(SHAKE_HEAVY_FRAMES)
		strength = minf(strength, shake_strength)
		camera.offset = Vector2(_shake_rng.randf_range(-strength, strength), _shake_rng.randf_range(-strength, strength)).round()
	else:
		camera.offset = Vector2.ZERO


func _update_hud() -> void:
	hud.refresh(player, dummy, player_wins, dummy_wins, not training,
			-1 if training else timer_frames, "" if training else _announce_text())
	# Pendant l'arrêt de l'ultime, l'écran s'assombrit.
	dim.visible = ultimate_freeze > 0
	pause_menu.show_mode(training)
	tools.show_debug("TRAINING" if training else Phase.keys()[phase])
