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
## Lance cette scène seule avec F6 pour tester.

## Les étapes d'un combat.
enum Phase { INTRO, FIGHT, ROUND_OVER, MATCH_OVER }
## Ce que fait le mannequin (touches 1 à 8 pendant le test). AI = l'ordinateur joue vraiment.
enum DummyMode { STAND, GUARD_HIGH, GUARD_LOW, ATTACK, ATTACK_LOW, PROJECTILE, ASSIST, AI }

## Soutiens de test, à faire défiler avec la touche T : attaque, protection, soin.
const TEST_SUPPORTS: Array[FighterData] = [
	preload("res://data/fighters/test_a.tres"),
	preload("res://data/fighters/test_b.tres"),
	preload("res://data/fighters/test_c.tres"),
]

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
var dummy_mode: DummyMode = DummyMode.AI
## L'adversaire contrôlé par l'ordinateur (touche Y : changer la difficulté).
var ai := FighterAI.new(FighterAI.Difficulty.NORMAL)
var frame_count := 0
var popup_frames := 0
var projectiles: Array[Projectile] = []
var assists: Array[Assist] = []
var support_index := 0

@onready var player: Fighter = $Player
@onready var dummy: Fighter = $Dummy
@onready var fighters: Array[Fighter] = [player, dummy]
@onready var player_bar: HealthBar = $HUD/PlayerBar
@onready var dummy_bar: HealthBar = $HUD/DummyBar
@onready var player_energy: EnergyBar = $HUD/PlayerEnergy
@onready var dummy_energy: EnergyBar = $HUD/DummyEnergy
@onready var player_assist: AssistGauge = $HUD/PlayerAssist
@onready var dummy_assist: AssistGauge = $HUD/DummyAssist
@onready var player_markers: WinMarkers = $HUD/PlayerWins
@onready var dummy_markers: WinMarkers = $HUD/DummyWins
@onready var player_name: Label = $HUD/PlayerName
@onready var dummy_name: Label = $HUD/DummyName
@onready var timer_label: Label = $HUD/TimerLabel
@onready var announce_label: Label = $HUD/AnnounceLabel
@onready var combo_label: Label = $HUD/ComboLabel
@onready var popup_label: Label = $HUD/PopupLabel
@onready var dim: ColorRect = $Dim
@onready var debug_label: Label = $DebugLabel
@onready var touch_controls: TouchControls = $TouchControls


func _ready() -> void:
	player.opponent = dummy
	dummy.opponent = player
	player_name.text = player.data.name_key
	dummy_name.text = dummy.data.name_key
	for fighter in fighters:
		fighter.dodged.connect(_show_popup.bind("FIGHT_DODGE"))
		fighter.projectile_launched.connect(_on_projectile_launched)
		fighter.ultimate_started.connect(_on_ultimate_started)
		fighter.assist_called.connect(_on_assist_called)
	# Pas encore de menu : le joueur a le soutien A (touche T pour changer),
	# le mannequin a le soutien B.
	player.support = TEST_SUPPORTS[0]
	dummy.support = TEST_SUPPORTS[1]
	touch_controls.fighter = player
	_start_match()


func _physics_process(delta: float) -> void:
	frame_count += 1
	phase_frames += 1
	if training or phase == Phase.FIGHT:
		_drive_dummy()
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
			if training:
				_reset_training()
			else:
				_start_match()
		KEY_M:
			training = not training
			if training:
				_reset_training()
			else:
				_start_match()
		KEY_0:
			for fighter in fighters:
				fighter.energy = 0.0
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8:
			dummy_mode = (event.physical_keycode - KEY_1) as DummyMode
			frame_count = 0
		KEY_Y:
			ai.difficulty = ((ai.difficulty + 1) % FighterAI.Difficulty.size()) as FighterAI.Difficulty
		KEY_T:
			support_index = (support_index + 1) % TEST_SUPPORTS.size()
			player.support = TEST_SUPPORTS[support_index]
			player.assist_cooldown = 0


# --- Déroulement du combat ---------------------------------------------------

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


## En entraînement : pas de chrono, personne ne peut être mis K.O., énergie pleine.
## Touche 0 : vider l'énergie pour tester comment elle se remplit.
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
	else:
		if player.health > dummy.health:
			round_winners.append(player)
		elif dummy.health > player.health:
			round_winners.append(dummy)
		round_result_key = "FIGHT_TIME_UP"
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


# --- Mannequin ---------------------------------------------------------------

## Donne ses commandes au mannequin selon le mode choisi.
func _drive_dummy() -> void:
	if dummy_mode == DummyMode.AI:
		ai.update(dummy, player, projectiles)
		return
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
	# Le mannequin appelle son soutien dès qu'il est rechargé.
	intent.assist = dummy_mode == DummyMode.ASSIST and beat == 0


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
			continue
		if not hitbox.intersects(defender.get_hurtbox_rect()):
			continue
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
		if _hits_barrier(projectile.get_rect(), target):
			finished.append(projectile)
		elif projectile.get_rect().intersects(target.get_hurtbox_rect()):
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


## Les attaques de soutien touchent comme des coups venus de loin :
## l'adversaire peut les parer ou les contrer, mais ne peut pas étourdir le soutien.
func _resolve_assists() -> void:
	for assist in assists:
		var defender := assist.caller.opponent
		var hitbox := assist.get_hitbox_rect()
		if hitbox.has_area() and not _hits_barrier(hitbox, defender) and hitbox.intersects(defender.get_hurtbox_rect()):
			assist.hit_done = true
			var attack := assist.data.attack
			_apply(defender.receive_attack(attack, assist.caller, true), attack, assist.caller, defender, false)
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

func _on_assist_called(caller: Fighter) -> void:
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
	popup_frames = 0


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


# --- Affichage ---------------------------------------------------------------

func _update_hud() -> void:
	player_bar.set_ratio(float(player.health) / Fighter.MAX_HEALTH)
	dummy_bar.set_ratio(float(dummy.health) / Fighter.MAX_HEALTH)
	player_energy.set_ratio(player.energy / Fighter.MAX_ENERGY)
	dummy_energy.set_ratio(dummy.energy / Fighter.MAX_ENERGY)
	player_assist.show_fighter(player)
	dummy_assist.show_fighter(dummy)
	player_markers.visible = not training
	dummy_markers.visible = not training
	player_markers.set_wins(player_wins)
	dummy_markers.set_wins(dummy_wins)
	# Le chrono affiche les secondes restantes, arrondies au-dessus (59,2 s → 60).
	timer_label.text = "--" if training else str(ceili(timer_frames / 60.0))
	announce_label.text = "" if training else _announce_text()
	announce_label.visible = announce_label.text != ""
	combo_label.visible = player.combo_hits >= 2
	combo_label.text = tr("FIGHT_COMBO_HITS") % player.combo_hits
	popup_frames = maxi(0, popup_frames - 1)
	popup_label.visible = popup_frames > 0
	# Pendant l'arrêt de l'ultime, l'écran s'assombrit.
	dim.visible = ultimate_freeze > 0
	# Texte de débogage pour le développeur, absent du jeu final
	# (c'est pour ça qu'il n'est pas dans le fichier de traductions).
	debug_label.text = "%s | P1 %s E%d [T: %s] | Dummy [%s %s] | M mode 1-8 dummy Y IA R reset" % [
		"TRAINING" if training else Phase.keys()[phase],
		Fighter.State.keys()[player.state], int(player.energy), player.support.id,
		DummyMode.keys()[dummy_mode], FighterAI.Difficulty.keys()[ai.difficulty],
	]
