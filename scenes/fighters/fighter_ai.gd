class_name FighterAI
extends RefCounted
## L'intelligence artificielle d'un combattant contrôlé par l'ordinateur.
##
## Elle ne triche pas : elle remplit les « intentions » du combattant (avancer,
## frapper, parer...) exactement comme un joueur avec sa manette, et le
## combattant applique les mêmes règles. La difficulté change seulement la
## vitesse de réaction et la qualité des choix.
##
## Chaque frame, dans cet ordre :
##   1. si elle encaisse un coup : tenter l'esquive mystique ;
##   2. si un coup ou un projectile arrive : parer ou contrer (selon la difficulté) ;
##   3. si l'adversaire a raté un coup juste devant elle : le punir ;
##   4. sinon, suivre son plan du moment (avancer, frapper, lancer un projectile...)
##      et en choisir un nouveau quand il est fini.

enum Difficulty { EASY, NORMAL, HARD }
enum Plan { WAIT, APPROACH, RETREAT, COMBO, LOW_ATTACK, JUMP_IN, PROJECTILE, DASH, ULTIMATE, ASSIST, CHARGE }

## Réglages selon la difficulté (les chances vont de 0 à 1).
## think : frames entre deux décisions (plus c'est petit, plus elle réagit vite).
const SETTINGS := {
	Difficulty.EASY: {
		"think": 28, "block": 0.15, "parry": 0.0, "dodge": 0.0, "aggression": 0.35,
		"punish": 0.1, "cancel": 0.0, "ultimate": 0.3, "assist": 0.1,
	},
	Difficulty.NORMAL: {
		"think": 16, "block": 0.5, "parry": 0.05, "dodge": 0.25, "aggression": 0.55,
		"punish": 0.45, "cancel": 0.3, "ultimate": 0.7, "assist": 0.2,
	},
	Difficulty.HARD: {
		"think": 7, "block": 0.85, "parry": 0.25, "dodge": 0.6, "aggression": 0.7,
		"punish": 0.9, "cancel": 0.8, "ultimate": 1.0, "assist": 0.3,
	},
}
## Distances, en pixels : à portée du combo, et distance moyenne.
const CLOSE := 34.0
const MID := 90.0
## Écart entre deux appuis sur Attaque dans un combo.
const COMBO_GAP := 7
## Un appui court sur Spécial dure 3 frames (au-delà de 10, on chargerait).
const SPECIAL_TAP := 3
## Un projectile est une menace quand il est à moins de cette distance.
const PROJECTILE_ALERT := 110.0

var difficulty: Difficulty
var rng := RandomNumberGenerator.new()

var _plan: Plan = Plan.WAIT
var _plan_frame := 0
var _plan_length := 0
var _think_cooldown := 0
## La menace déjà évaluée (pour ne tirer au sort qu'une fois par coup adverse).
var _threat_key := ""
var _will_block := false
var _will_parry := false
var _parry_done := false
var _dodge_tried := false
var _punish_key := ""
var _cancel_key := ""
var _air_attack_done := false
## Vrai pendant une charge d'énergie (et non un appui court sur Spécial).
var _charging := false


## seed : graine du hasard (0 = différente à chaque partie, autre = parties rejouables).
func _init(level: Difficulty = Difficulty.NORMAL, seed := 0) -> void:
	difficulty = level
	if seed != 0:
		rng.seed = seed
	else:
		rng.randomize()


## Appelée à chaque frame par l'arène, avant que le combattant lise ses intentions.
func update(me: Fighter, op: Fighter, projectiles: Array[Projectile]) -> void:
	_decide(me, op, projectiles)
	# Un appui court sur Spécial lance un coup spécial : si l'IA a commencé une
	# CHARGE et qu'elle est interrompue avant 10 frames, elle garde le bouton
	# enfoncé jusqu'au seuil, sinon elle lancerait un spécial sans le vouloir.
	if _charging and not me.intent.special and me.special_held_frames > 0 			and me.special_held_frames < Fighter.CHARGE_THRESHOLD_FRAMES:
		me.intent.special = true
	if not me.intent.special and me.special_held_frames == 0:
		_charging = false


func _decide(me: Fighter, op: Fighter, projectiles: Array[Projectile]) -> void:
	var intent := me.intent
	for key in intent:
		intent[key] = false
	var s: Dictionary = SETTINGS[difficulty]
	var toward := 1 if op.global_position.x > me.global_position.x else -1
	var distance := absf(op.global_position.x - me.global_position.x)
	_think_cooldown = maxi(0, _think_cooldown - 1)

	# 1. Encaisser : une seule tentative d'esquive par coup reçu.
	if me.state == Fighter.State.HITSTUN:
		if not _dodge_tried:
			_dodge_tried = true
			if me.energy >= Fighter.ENERGY_SEGMENT and _roll(s.dodge):
				intent.guard_pressed = true
		return
	_dodge_tried = false

	# 2. Se défendre.
	if _defend(me, op, projectiles, distance, toward, s):
		return

	# 3. Annuler un combo qui a touché en attaque foncée (spécial 2).
	if _try_cancel(me, toward, s):
		return

	# 4. Punir un coup raté juste devant soi.
	if _try_punish(me, op, distance, s):
		return

	# 5. Suivre le plan. Quand il est fini, attendre la prochaine décision sans rien faire.
	if _plan_frame >= _plan_length:
		if _think_cooldown > 0:
			return
		_choose_plan(me, op, distance, s)
	_follow_plan(me, op, distance, toward)
	_plan_frame += 1


# --- Défense -----------------------------------------------------------------

## Renvoie vrai si l'IA se défend à cette frame (elle ne fait rien d'autre).
func _defend(me: Fighter, op: Fighter, projectiles: Array[Projectile], distance: float, toward: int, s: Dictionary) -> bool:
	var threat := _find_threat(me, op, projectiles, distance)
	if threat.is_empty():
		_threat_key = ""
		return false
	if threat.key != _threat_key:
		# Nouvelle menace : on décide une seule fois si on la pare ou si on la contre.
		_threat_key = threat.key
		_will_block = _roll(s.block)
		_will_parry = _roll(s.parry)
		_parry_done = false
	var intent := me.intent
	# Contre parfait : appuyer sur Garde 2 à 3 frames avant l'impact.
	if _will_parry and not _parry_done and threat.frames_to_hit <= 3:
		_parry_done = true
		intent.guard_pressed = true
		return true
	if _will_block:
		intent.guard = true
		intent.crouch = threat.low
		return true
	return false


## Cherche ce qui va frapper l'IA : un coup de l'adversaire à portée, ou un projectile
## qui arrive. Renvoie {} s'il n'y a rien, sinon {key, low, frames_to_hit}.
func _find_threat(me: Fighter, op: Fighter, projectiles: Array[Projectile], distance: float) -> Dictionary:
	var attack := op.current_attack
	var facing_me := op.facing == (1 if me.global_position.x > op.global_position.x else -1)
	if attack and facing_me and op.state in [Fighter.State.ATTACK, Fighter.State.JUMP]:
		var before_end := attack.startup + attack.active - op.attack_frame
		var reach := attack.hitbox.position.x + attack.hitbox.size.x + attack.dash_speed / 60.0 * attack.active + 14.0
		if before_end >= 0 and distance < reach and attack.hitbox.has_area():
			return {
				"key": "a%d" % op.attack_serial,
				"low": attack.hit_level == AttackData.HitLevel.LOW,
				"frames_to_hit": maxi(0, attack.startup + 1 - op.attack_frame),
			}
	for projectile in projectiles:
		if projectile.shooter != op:
			continue
		var gap := me.global_position.x - projectile.global_position.x
		var coming := signf(gap) == float(projectile.direction)
		if coming and absf(gap) < PROJECTILE_ALERT:
			return {
				"key": "p%d" % projectile.get_instance_id(),
				"low": projectile.data.hit.hit_level == AttackData.HitLevel.LOW,
				"frames_to_hit": int((absf(gap) - 20.0) / projectile.data.speed * 60.0),
			}
	return {}


# --- Opportunités ------------------------------------------------------------

## Après un coup du combo qui a touché : enchaîner sur le spécial 2 (avant + Spécial).
func _try_cancel(me: Fighter, toward: int, s: Dictionary) -> bool:
	if me.state != Fighter.State.ATTACK or not me.attack_has_hit or me.combo_index < 0:
		return false
	if me.data.special_2 == null or not _can_spend(me, s):
		return false
	var key := "c%d" % me.attack_serial
	if key == _cancel_key:
		return false
	_cancel_key = key
	if not _roll(s.cancel):
		return false
	_start_plan(Plan.DASH, 20)
	_follow_plan(me, null, 0.0, toward)
	_plan_frame += 1
	return true


## L'adversaire termine un coup raté juste devant : le frapper avant qu'il se remette.
func _try_punish(me: Fighter, op: Fighter, distance: float, s: Dictionary) -> bool:
	var attack := op.current_attack
	if attack == null or op.state != Fighter.State.ATTACK or distance > CLOSE + 4.0:
		return false
	if op.attack_frame <= attack.startup + attack.active:
		return false
	var key := "x%d" % op.attack_serial
	if key == _punish_key:
		return false
	_punish_key = key
	if not _roll(s.punish):
		return false
	_start_plan(Plan.COMBO, 40)
	return false


# --- Plans -------------------------------------------------------------------

func _choose_plan(me: Fighter, op: Fighter, distance: float, s: Dictionary) -> void:
	_think_cooldown = s.think
	var aggression: float = s.aggression
	var r := rng.randf()
	if me.energy >= Fighter.MAX_ENERGY and me.data.ultimate and distance < 80.0 and _roll(s.ultimate):
		_start_plan(Plan.ULTIMATE, 60)
	elif me.can_call_assist() and distance < 160.0 and _roll(s.assist):
		_start_plan(Plan.ASSIST, 8)
	elif distance > MID:
		var saving := _saving_for_ultimate(me)
		if saving and op.current_attack == null:
			_start_plan(Plan.CHARGE, rng.randi_range(30, 70))
		elif _can_spend(me, s) and me.active_projectiles == 0 and me.data.special_1 and r < 0.45:
			_start_plan(Plan.PROJECTILE, 30)
		elif me.energy < 2 * Fighter.ENERGY_SEGMENT and r < 0.65 and op.current_attack == null:
			_start_plan(Plan.CHARGE, rng.randi_range(30, 70))
		else:
			_start_plan(Plan.APPROACH, rng.randi_range(20, 40))
	elif distance > CLOSE:
		if r < aggression * 0.5:
			_start_plan(Plan.APPROACH, rng.randi_range(10, 20))
		elif r < aggression * 0.7:
			_start_plan(Plan.JUMP_IN, 70)
		elif r < aggression * 0.85 and me.data.special_2 and _can_spend(me, s):
			_start_plan(Plan.DASH, 40)
		elif r < 0.9:
			_start_plan(Plan.WAIT, rng.randi_range(8, 20))
		else:
			_start_plan(Plan.RETREAT, rng.randi_range(10, 20))
	else:
		if r < aggression:
			_start_plan(Plan.LOW_ATTACK if rng.randf() < 0.3 else Plan.COMBO, 40)
		elif r < aggression + 0.15:
			_start_plan(Plan.RETREAT, rng.randi_range(10, 20))
		else:
			_start_plan(Plan.WAIT, rng.randi_range(5, 12))


func _start_plan(plan: Plan, length: int) -> void:
	_plan = plan
	_plan_length = length
	_plan_frame = 0
	_air_attack_done = false


func _follow_plan(me: Fighter, op: Fighter, distance: float, toward: int) -> void:
	var intent := me.intent
	var f := _plan_frame
	match _plan:
		Plan.APPROACH:
			_hold_direction(intent, toward)
			if distance < CLOSE - 4.0:
				_plan_length = f
		Plan.RETREAT:
			_hold_direction(intent, -toward)
		Plan.COMBO:
			intent.attack = f in [0, COMBO_GAP, COMBO_GAP * 2]
		Plan.LOW_ATTACK:
			intent.crouch = f < 20
			intent.attack = f == 1
		Plan.JUMP_IN:
			if f < 3:
				intent.jump = true
				_hold_direction(intent, toward)
			elif me.state == Fighter.State.JUMP:
				# Frapper en redescendant, une fois proche.
				if not _air_attack_done and me.velocity.y > 0.0 and distance < 44.0:
					intent.attack = true
					_air_attack_done = true
			elif f > 5:
				_plan_length = f
		Plan.PROJECTILE:
			intent.special = f < SPECIAL_TAP
		Plan.DASH:
			intent.special = f < SPECIAL_TAP
			if f < SPECIAL_TAP:
				_hold_direction(intent, toward)
		Plan.ULTIMATE:
			intent.ultimate = f == 0
		Plan.ASSIST:
			intent.assist = f == 0
		Plan.CHARGE:
			# On arrête de charger si l'adversaire s'approche.
			_charging = true
			intent.special = true
			if op and distance < MID:
				_plan_length = f


## Vrai si l'IA peut dépenser un segment pour un coup spécial. Si elle sait esquiver,
## elle garde toujours un segment en réserve pour l'esquive mystique.
func _can_spend(me: Fighter, s: Dictionary) -> bool:
	var reserve := Fighter.ENERGY_SEGMENT if s.dodge > 0.0 else 0
	return me.energy >= Fighter.ENERGY_SEGMENT + reserve and not _saving_for_ultimate(me)


## À partir de 3 segments, l'IA garde son énergie pour l'ultime (sauf pour esquiver).
func _saving_for_ultimate(me: Fighter) -> bool:
	return me.data.ultimate != null and me.energy >= 3 * Fighter.ENERGY_SEGMENT and me.energy < Fighter.MAX_ENERGY


func _hold_direction(intent: Dictionary, direction: int) -> void:
	intent.right = direction > 0
	intent.left = direction < 0


func _roll(chance: float) -> bool:
	return rng.randf() < chance
