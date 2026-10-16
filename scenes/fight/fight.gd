extends Node2D
## L'arène : elle fait avancer le combat image par image.
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
## Les autres rôles sont dans des nœuds à part :
## - MatchFlow (match_flow.gd) : manches, chrono, K.O., annonces ;
## - Feedback (fight_feedback.gd) : étincelles, sons, tremblement, vibration ;
## - HUD (scenes/ui/fight_hud) : tout l'affichage ;
## - MatchLog (match_log.gd) : journal des combats d'Arcade (pour régler l'IA) ;
## - TrainingTools : mannequin, IA de l'adversaire, outils de test.
##
## Deux façons de jouer : combat (2 manches gagnantes, 60 secondes) ou
## entraînement (pas de chrono, personne n'est mis K.O., énergie pleine).
## Les combattants, soutiens et la difficulté viennent des menus (GameState).
## Lancée seule avec F6, l'arène prend les combattants de test (touche M :
## combat / entraînement, R : recommencer).

## Émis après chaque coup qui atteint sa cible (sert au tutoriel).
signal hit_landed(result: Fighter.HitResult, attack: AttackData, attacker: Fighter, defender: Fighter)

const TUTORIAL_SCENE := preload("res://scenes/fight/tutorial.tscn")

## Après un K.O., le combat passe au ralenti un moment.
const KO_SLOWMO_FRAMES := 60
## Largeur minimale entre les centres des deux combattants.
const PUSHBOX_WIDTH := 20.0
## Limites de l'arène pour le centre des combattants.
const ARENA_LEFT := 12.0
const ARENA_RIGHT := 468.0
const START_X_PLAYER := 170.0
const START_X_DUMMY := 310.0
## Hauteur du sol (les soutiens apparaissent toujours au sol).
const FLOOR_Y := 230.0
## Avec de vrais dessins, la caméra zoome sur l'action et suit les combattants
## (comme Street Fighter) : chaque pixel du dessin tombe sur un pixel de l'écran.
const ART_ZOOM := 1.75
## Écart maximal entre les deux combattants avec la caméra zoomée : ils restent
## tous les deux à l'écran (marge de 16 unités de chaque côté).
const SCREEN_MARGIN := 16.0
## La caméra suit les combattants en douceur (0 = immobile, 1 = immédiat).
const CAMERA_FOLLOW := 0.2
## Taille de l'écran en unités de combat, sans zoom.
const SCREEN_SIZE := Vector2(480, 270)

## Durée de l'arrêt du combat au début de l'ultime.
const ULTIMATE_FREEZE_FRAMES := 45

## Énergie gagnée selon ce qui arrive (sur 400 pour la barre pleine).
const ENERGY_ON_HIT := 20.0
const ENERGY_WHEN_HIT := 12.0
const ENERGY_ON_BLOCKED := 8.0
const ENERGY_WHEN_BLOCKING := 5.0
const ENERGY_ON_PARRY := 25.0

var training := false
var slowmo_frames := 0
var hitstop := 0
var ultimate_freeze := 0
var frame_count := 0
var projectiles: Array[Projectile] = []
var assists: Array[Assist] = []
## Vrai si un des combattants a de vrais dessins : caméra zoomée qui suit l'action.
var art_camera := false

@onready var player: Fighter = $Player
@onready var dummy: Fighter = $Dummy
@onready var fighters: Array[Fighter] = [player, dummy]
@onready var flow: MatchFlow = $MatchFlow
@onready var feedback: FightFeedback = $Feedback
@onready var match_log: MatchLog = $MatchLog
@onready var hud: FightHUD = $HUD
@onready var tools: TrainingTools = $TrainingTools
@onready var dim: ColorRect = $Dim
@onready var touch_controls: TouchControls = $TouchControls
@onready var pause_menu: PauseMenu = $PauseMenu
@onready var match_result: MatchResult = $MatchResult
@onready var camera: Camera2D = $Camera
@onready var stage: Stage = $Stage


func _ready() -> void:
	player.opponent = dummy
	dummy.opponent = player
	feedback.setup($HitEffects, $Sounds, $Camera, hud, player)
	flow.setup(player, dummy)
	flow.round_started.connect(_on_round_started)
	flow.round_ended.connect(_on_round_ended)
	flow.match_over.connect(_on_match_over)
	match_log.setup(player, dummy)
	hit_landed.connect(match_log.on_hit)
	for fighter in fighters:
		fighter.dodged.connect(feedback.dodged)
		fighter.projectile_launched.connect(_on_projectile_launched)
		fighter.ultimate_started.connect(_on_ultimate_started)
		fighter.assist_called.connect(_on_assist_called)
		fighter.attack_started.connect(feedback.attack_started)
	pause_menu.restart_requested.connect(restart)
	pause_menu.mode_toggled.connect(toggle_training)
	pause_menu.menu_requested.connect(GameState.go_to.bind(GameState.MAIN_MENU))
	pause_menu.can_toggle_mode = GameState.mode == GameState.Mode.QUICK
	match_result.next_requested.connect(_next_arcade_fight)
	match_result.retry_requested.connect(start_match)
	match_result.menu_requested.connect(GameState.go_to.bind(GameState.MAIN_MENU))
	tools.setup(player, dummy)
	_setup_from_menus()
	touch_controls.fighter = player
	_apply_control_settings()
	# Les réglages peuvent changer en pleine pause.
	GameState.settings_saved.connect(_apply_control_settings)
	if GameState.mode in [GameState.Mode.TRAINING, GameState.Mode.TUTORIAL]:
		training = true
		reset_training()
	else:
		start_match()
	if GameState.mode == GameState.Mode.TUTORIAL:
		var tutorial: Tutorial = TUTORIAL_SCENE.instantiate()
		add_child(tutorial)
		tutorial.start(self)


## Les combattants, soutiens et la difficulté choisis dans les menus.
## (Lancée seule avec F6, l'arène garde les combattants de test.)
func _setup_from_menus() -> void:
	var arcade := GameState.mode == GameState.Mode.ARCADE
	match GameState.mode:
		GameState.Mode.ARCADE:
			var entry: Dictionary = GameState.arcade_opponents[GameState.arcade_index]
			player.data = GameState.player_fighter
			player.support = GameState.player_support
			dummy.data = entry.fighter
			dummy.support = entry.support
		GameState.Mode.TUTORIAL:
			player.data = GameState.roster[0]
			dummy.data = GameState.roster[1]
		GameState.Mode.TRAINING:
			player.data = GameState.player_fighter
			player.support = GameState.player_support
			dummy.data = GameState.opponent_fighter
	if GameState.mode in [GameState.Mode.ARCADE, GameState.Mode.TRAINING]:
		tools.ai = FighterAI.new(GameState.difficulty)
		tools.dummy_mode = TrainingTools.DummyMode.AI
	# En Arcade et dans le tutoriel, pas d'outils de test (touches du mannequin,
	# texte de débogage, zones de frappe).
	var clean := arcade or GameState.mode == GameState.Mode.TUTORIAL
	tools.set_process_unhandled_input(not clean)
	tools.debug_label.visible = not clean
	# Zones de frappe (rouge) et vulnérables (vert) : seulement pour régler les coups
	# (arène lancée seule), ou avec la touche B en entraînement.
	for fighter in fighters:
		fighter.show_boxes = GameState.mode == GameState.Mode.QUICK
	hud.show_names(player, dummy)
	# Le décor dessiné du combat (sinon, le fond uni du prototype).
	var has_stage := stage.load_stage(GameState.stage_for_fight(dummy.data), FLOOR_Y)
	$Background.visible = not has_stage
	$Floor/View.visible = not has_stage
	art_camera = has_stage or player.data.sprite_frames != null or dummy.data.sprite_frames != null
	camera.zoom = Vector2.ONE * (ART_ZOOM if art_camera else 1.0)
	_update_camera(true)


func _physics_process(delta: float) -> void:
	frame_count += 1
	if training or flow.is_fighting():
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
		flow.update()
		if flow.phase == MatchFlow.Phase.MATCH_OVER and GameState.mode == GameState.Mode.QUICK \
				and Input.is_action_just_pressed("attack"):
			start_match()
	feedback.update()
	_update_camera()
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
	if training or flow.is_fighting():
		_resolve_hits()
		_resolve_assists()
		_resolve_projectiles()
		_end_finished_combos()
		if not training:
			flow.tick_timer()
			match_log.tick()
	else:
		_remove_finished_assists()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	# Raccourcis de test, seulement quand l'arène est lancée seule (F6).
	if GameState.mode != GameState.Mode.QUICK:
		return
	match event.physical_keycode:
		KEY_R:
			restart()
		KEY_M:
			toggle_training()


# --- Combat, entraînement, Arcade --------------------------------------------

## Recommence : le combat entier, ou la mise en place de l'entraînement.
func restart() -> void:
	if training:
		reset_training()
	else:
		start_match()


## Passe du mode combat au mode entraînement, et inversement.
func toggle_training() -> void:
	training = not training
	restart()


func start_match() -> void:
	training = false
	match_result.hide_result()
	match_log.reset()
	for fighter in fighters:
		fighter.immortal = false
	flow.start_match()


## Nouvelle manche : tout repart à zéro (vie pleine, énergie vide, soutien prêt).
func _on_round_started() -> void:
	_reset_fighters(0.0)
	feedback.round_started()


func _on_round_ended(by_ko: bool) -> void:
	if by_ko:
		slowmo_frames = KO_SLOWMO_FRAMES
	feedback.round_ended(by_ko)


## En entraînement : pas de chrono, personne ne peut être mis K.O., énergie pleine.
func reset_training() -> void:
	_reset_fighters(Fighter.MAX_ENERGY)
	for fighter in fighters:
		fighter.immortal = true
	flow.set_phase(MatchFlow.Phase.FIGHT)


func _reset_fighters(energy: float) -> void:
	_clear_effects()
	for fighter in fighters:
		fighter.reset()
		fighter.energy = energy
	player.position = Vector2(START_X_PLAYER, FLOOR_Y)
	dummy.position = Vector2(START_X_DUMMY, FLOOR_Y)


## Fin du combat. En Arcade : le journal, puis la fenêtre de résultat.
func _on_match_over() -> void:
	if GameState.mode != GameState.Mode.ARCADE:
		return
	var result := "win" if flow.player_won() else ("loss" if flow.dummy_wins >= MatchFlow.ROUNDS_TO_WIN and flow.player_wins < MatchFlow.ROUNDS_TO_WIN else "draw")
	# Pendant les tests automatiques, on n'écrit pas dans le vrai journal.
	if not GameState.dry_run:
		match_log.write(FighterAI.Difficulty.keys()[GameState.difficulty], result, "%d-%d" % [flow.player_wins, flow.dummy_wins])
	_show_arcade_result()


## Arcade : victoire (le joueur seul à 2 manches), défaite ou série terminée.
func _show_arcade_result() -> void:
	var number := GameState.arcade_index + 1
	var count := GameState.arcade_opponents.size()
	var won := flow.player_won()
	if won and number == count:
		match_result.show_result(MatchResult.Outcome.COMPLETE, number, count)
	else:
		match_result.show_result(MatchResult.Outcome.WIN if won else MatchResult.Outcome.LOSS, number, count)


## Avec un bouton Charge, le bouton Spécial du joueur part dès l'appui.
func _apply_control_settings() -> void:
	player.special_hold_charges = GameState.special_hold_charges()
	for fighter in fighters:
		fighter.show_markers = GameState.attack_markers


## Arcade : combat gagné, on passe au suivant (ou c'est la fin de la série).
func _next_arcade_fight() -> void:
	if GameState.next_arcade_fight():
		_setup_from_menus()
		start_match()


# --- Collisions et coups -----------------------------------------------------

func _separate_fighters() -> void:
	var gap := dummy.global_position.x - player.global_position.x
	var both_low := absf(player.global_position.y - dummy.global_position.y) < Fighter.STAND_HEIGHT * 0.7
	if both_low and absf(gap) < PUSHBOX_WIDTH:
		var push := (PUSHBOX_WIDTH - absf(gap)) / 2.0
		var side := signf(gap) if gap != 0.0 else float(player.facing)
		player.position.x -= side * push
		dummy.position.x += side * push
	# Caméra zoomée : les deux combattants restent à l'écran, on ne peut pas trop s'éloigner.
	if art_camera:
		var max_gap := SCREEN_SIZE.x / ART_ZOOM - 2.0 * SCREEN_MARGIN
		var spread := dummy.position.x - player.position.x
		if absf(spread) > max_gap:
			var excess := (absf(spread) - max_gap) / 2.0 * signf(spread)
			player.position.x += excess
			dummy.position.x -= excess
	for fighter in fighters:
		fighter.position.x = clampf(fighter.position.x, ARENA_LEFT, ARENA_RIGHT)


## Caméra : fixe au centre avec les rectangles ; avec de vrais dessins, elle zoome
## et suit le milieu des deux combattants, sans sortir de l'arène.
func _update_camera(snap := false) -> void:
	if not art_camera:
		camera.position = SCREEN_SIZE / 2.0
		stage.scroll(camera.position.x)
		return
	var half := SCREEN_SIZE / ART_ZOOM / 2.0
	var middle := (player.position.x + dummy.position.x) / 2.0
	var target := Vector2(clampf(middle, half.x, SCREEN_SIZE.x - half.x), FLOOR_Y + SCREEN_MARGIN - half.y)
	camera.position = target if snap else camera.position.lerp(target, CAMERA_FOLLOW)
	stage.scroll(camera.position.x)


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
			feedback.barrier(hitbox.get_center())
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
				feedback.clash((projectile.global_position + other.global_position) / 2.0)
				break
		if projectile in finished:
			continue
		var target := projectile.shooter.opponent
		if _hits_barrier(projectile.get_rect(), target):
			finished.append(projectile)
			feedback.barrier(projectile.global_position)
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


## Ce qui se passe après un coup : arrêt sur image, combo, énergie.
## (Les étincelles, sons et messages sont dans Feedback.)
func _apply(result: Fighter.HitResult, attack: AttackData, attacker: Fighter, defender: Fighter, grants_energy: bool, point: Vector2) -> void:
	feedback.on_hit(result, attack, attacker, defender, point)
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
		Fighter.HitResult.TECHED:
			hitstop = maxi(hitstop, 6)
	# Après la mise à jour du combo et de l'énergie (le tutoriel les lit).
	hit_landed.emit(result, attack, attacker, defender)


## Vrai si cette zone touche le bouclier d'un soutien qui protège ce combattant.
func _hits_barrier(rect: Rect2, protected: Fighter) -> bool:
	for assist in assists:
		if assist.caller == protected and rect.intersects(assist.get_barrier_rect()):
			assist.barrier_flash = 4
			return true
	return false


## Un combo s'arrête dès que celui qui encaisse peut de nouveau agir.
func _end_finished_combos() -> void:
	for fighter in fighters:
		if fighter.is_free():
			fighter.opponent.combo_hits = 0


# --- Soutiens, projectiles, ultime -------------------------------------------

func _on_assist_called(caller: Fighter) -> void:
	feedback.assist_called()
	var assist := Assist.new()
	assist.summon(caller.support.assist, caller, FLOOR_Y, ARENA_LEFT, ARENA_RIGHT)
	assist.projectile_requested.connect(_launch_projectile.bind(true))
	add_child(assist)
	# Le soutien est dessiné derrière les combattants.
	move_child(assist, player.get_index())
	assists.append(assist)


func _remove_finished_assists() -> void:
	var finished: Array[Assist] = []
	for assist in assists:
		if assist.is_finished():
			finished.append(assist)
	for assist in finished:
		assists.erase(assist)
		_remove_assist(assist)


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


func _on_ultimate_started(_fighter: Fighter) -> void:
	ultimate_freeze = ULTIMATE_FREEZE_FRAMES
	feedback.ultimate_started()


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
	feedback.clear()


# --- Affichage ---------------------------------------------------------------

## Poses de mise en scène des vrais dessins : entrée en début de manche,
## victoire pour le gagnant une fois le résultat annoncé.
func _update_cinematics() -> void:
	for fighter in fighters:
		var sprite := fighter.view.sprite
		if sprite == null:
			continue
		sprite.cinematic = ""
		if training:
			continue
		match flow.phase:
			MatchFlow.Phase.INTRO:
				sprite.cinematic = "intro"
				sprite.cinematic_progress = clampf(float(flow.phase_frames) / MatchFlow.INTRO_ROUND_FRAMES, 0.0, 1.0)
			MatchFlow.Phase.ROUND_OVER, MatchFlow.Phase.MATCH_OVER:
				var shown := flow.phase == MatchFlow.Phase.MATCH_OVER or flow.phase_frames >= MatchFlow.RESULT_SHOW_FRAMES
				if shown and fighter in flow.round_winners and fighter.health > 0 and fighter.is_free():
					sprite.cinematic = "victory"
					var since := flow.phase_frames - (0 if flow.phase == MatchFlow.Phase.MATCH_OVER else MatchFlow.RESULT_SHOW_FRAMES)
					sprite.cinematic_progress = clampf(since / 50.0, 0.0, 1.0)
	# Une pose de mise en scène doit s'afficher même quand le combat est figé.
	for fighter in fighters:
		if fighter.view.sprite and fighter.view.sprite.cinematic != "":
			fighter.view.sprite.refresh()


func _update_hud() -> void:
	_update_cinematics()
	var header := ""
	if GameState.mode == GameState.Mode.ARCADE:
		header = tr("ARCADE_FIGHT_N") % [GameState.arcade_index + 1, GameState.arcade_opponents.size()]
	var footer := tr("FIGHT_PRESS_RESTART") if GameState.mode == GameState.Mode.QUICK else ""
	hud.refresh(player, dummy, flow.player_wins, flow.dummy_wins, not training,
			-1 if training else flow.timer_frames, "" if training else flow.announce_text(header, footer))
	# Pendant l'arrêt de l'ultime, l'écran s'assombrit.
	dim.visible = ultimate_freeze > 0
	pause_menu.show_mode(training)
	tools.show_debug("TRAINING" if training else MatchFlow.Phase.keys()[flow.phase])
