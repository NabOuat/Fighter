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
##   2. si elle VOIT arriver un coup ou un projectile (après son temps de réaction) :
##      parer à la bonne hauteur ou contrer ; sinon garder sa garde pendant une
##      série de coups, à la hauteur qu'elle a devinée ;
##   3. si l'adversaire a raté un coup juste devant elle : le punir ;
##   4. sinon, suivre son plan du moment (avancer, frapper, lancer un projectile...)
##      et en choisir un nouveau quand il est fini.

enum Difficulty { EASY, NORMAL, HARD }
enum Plan { WAIT, APPROACH, RETREAT, COMBO, LOW_ATTACK, JUMP_IN, PROJECTILE, DASH, ULTIMATE, ASSIST, CHARGE, GUARD, THROW }

## Réglages selon la difficulté (les chances vont de 0 à 1).
## think : frames entre deux décisions (plus c'est petit, plus elle réagit vite).
## reaction : frames avant de « voir » un coup qui part. Un humain met 12 à 20 frames :
##   les coups rapides (4 à 8 frames de préparation) ne se parent donc pas en
##   réagissant, il faut être déjà en garde, à la bonne hauteur.
## guard : chance de se mettre en garde par prudence quand l'adversaire est proche.
## read : 0 = devine la hauteur des coups au hasard, 1 = apprend les habitudes du joueur.
## throw : chance de projeter un adversaire qui reste en garde.
const SETTINGS := {
	Difficulty.EASY: {
		"think": 28, "reaction": 22, "block": 0.3, "parry": 0.0, "dodge": 0.0, "aggression": 0.4,
		"guard": 0.1, "read": 0.0, "throw": 0.05,
		"punish": 0.1, "cancel": 0.0, "ultimate": 0.3, "assist": 0.1,
	},
	Difficulty.NORMAL: {
		"think": 16, "reaction": 15, "block": 0.6, "parry": 0.05, "dodge": 0.25, "aggression": 0.6,
		"guard": 0.2, "read": 0.5, "throw": 0.2,
		"punish": 0.45, "cancel": 0.3, "ultimate": 0.7, "assist": 0.2,
	},
	Difficulty.HARD: {
		"think": 7, "reaction": 10, "block": 0.9, "parry": 0.25, "dodge": 0.6, "aggression": 0.7,
		"guard": 0.25, "read": 0.9, "throw": 0.4,
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
## Après avoir paré, l'IA garde sa garde encore un peu (comme un joueur pendant une
## série de coups), sauf si l'adversaire se découvre.
const GUARD_HOLD_FRAMES := 10

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
## Le coup adverse en cours, et depuis combien de frames l'IA le voit.
var _seen_serial := -1
var _seen_frames := 0
## Part des coups bas dans les attaques de l'adversaire (ce que l'IA a appris).
var _low_ratio := 0.3
## Hauteur de garde choisie (vraie = accroupie), et frames de garde restantes.
var _guard_low := false
var _guard_hold := 0


## seed : graine du hasard (0 = différente à chaque partie, autre = parties rejouables).
func _init(level: Difficulty = Difficulty.NORMAL, seed := 0) -> void:
	difficulty = level
	if seed != 0:
		rng.seed = seed
	else:
		rng.randomize()


## Appelée à chaque frame par l'arène, avant que le combattant lise ses intentions.
func update(me: Fighter, op: Fighter, projectiles: Array[Projectile]) -> void:
	_watch(op)
	_decide(me, op, projectiles)
	# Un appui court sur Spécial lance un coup spécial : si l'IA a commencé une
	# CHARGE et qu'elle est interrompue avant 10 frames, elle garde le bouton
	# enfoncé jusqu'au seuil, sinon elle lancerait un spécial sans le vouloir.
	if _charging and not me.intent.special and me.special_held_frames > 0 			and me.special_held_frames < Fighter.CHARGE_THRESHOLD_FRAMES:
		me.intent.special = true
	if not me.intent.special and me.special_held_frames == 0:
		_charging = false


## Observe l'adversaire : depuis quand son coup est parti, et s'il frappe souvent en bas.
## Le temps compte aussi pendant les arrêts sur image : on voit le coup venir.
func _watch(op: Fighter) -> void:
	var attack := op.current_attack
	if attack == null or attack.is_throw:
		return
	if op.attack_serial == _seen_serial:
		_seen_frames += 1
		return
	_seen_serial = op.attack_serial
	_seen_frames = 0
	var low := 1.0 if attack.hit_level == AttackData.HitLevel.LOW else 0.0
	_low_ratio = lerpf(_low_ratio, low, 0.25)


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
			# Presque prête pour l'ultime et encore en forme : elle encaisse plutôt que d'esquiver.
			var keep_for_ultimate := _saving_for_ultimate(me) and me.health > Fighter.MAX_HEALTH * 0.4
			if me.energy >= Fighter.ENERGY_SEGMENT and not keep_for_ultimate and _roll(s.dodge):
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
	var threat := _find_threat(me, op, projectiles, distance, s)
	if me.state == Fighter.State.BLOCKSTUN:
		_guard_hold = GUARD_HOLD_FRAMES
	if threat.is_empty():
		_threat_key = ""
		return _hold_guard(me, op)
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
		_guard_low = threat.low
		_guard_hold = GUARD_HOLD_FRAMES
		intent.guard = true
		intent.crouch = threat.low
		return true
	return _hold_guard(me, op)


## Garder sa garde pendant une série de coups, à la hauteur devinée. On la lâche
## dès que l'adversaire termine un coup (pour pouvoir le punir).
func _hold_guard(me: Fighter, op: Fighter) -> bool:
	if _guard_hold <= 0:
		return false
	_guard_hold -= 1
	var attack := op.current_attack
	if attack and op.state == Fighter.State.ATTACK and op.attack_frame > attack.startup + attack.active \
			and me.state != Fighter.State.BLOCKSTUN:
		_guard_hold = 0
		return false
	me.intent.guard = true
	me.intent.crouch = _guard_low
	return true


## Garde basse ou haute ? Au hasard, ou selon les habitudes du joueur.
func _pick_guard_height(s: Dictionary) -> bool:
	return rng.randf() < lerpf(0.3, _low_ratio, s.read)


## Cherche ce qui va frapper l'IA : un coup de l'adversaire à portée, ou un projectile
## qui arrive. Renvoie {} s'il n'y a rien, sinon {key, low, frames_to_hit}.
## Un coup n'est visible qu'après le temps de réaction de l'IA.
func _find_threat(me: Fighter, op: Fighter, projectiles: Array[Projectile], distance: float, s: Dictionary) -> Dictionary:
	var attack := op.current_attack
	var facing_me := op.facing == (1 if me.global_position.x > op.global_position.x else -1)
	var seen: bool = op.attack_serial == _seen_serial and _seen_frames >= s.reaction
	if attack and not attack.is_throw and seen and facing_me and op.state in [Fighter.State.ATTACK, Fighter.State.JUMP]:
		var before_end := attack.startup + attack.active - op.attack_frame
		var reach := attack.hitbox.position.x + attack.hitbox.size.x + attack.dash_speed / 60.0 * attack.active + 14.0
		if before_end >= 0 and distance < reach and attack.hitbox.has_area():
			return {
				"key": "a%d" % op.attack_serial,
				"low": attack.hit_level == AttackData.HitLevel.LOW,
				"frames_to_hit": maxi(0, attack.startup + 1 - op.attack_frame),
			}
	for projectile in projectiles:
		if projectile.shooter != op or projectile.age < s.reaction:
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
		if op.state == Fighter.State.GUARD and _roll(s.throw):
			_start_plan(Plan.THROW, 30)
		elif r < aggression * 0.5:
			_start_plan(Plan.APPROACH, rng.randi_range(10, 20))
		elif r < aggression * 0.7:
			_start_plan(Plan.JUMP_IN, 70)
		elif r < aggression * 0.85 and me.data.special_2 and _can_spend(me, s):
			_start_plan(Plan.DASH, 40)
		elif r < aggression * 0.85 + s.guard * 0.5:
			_start_guard(rng.randi_range(12, 24), s)
		elif r < 0.9:
			_start_plan(Plan.WAIT, rng.randi_range(8, 20))
		else:
			_start_plan(Plan.RETREAT, rng.randi_range(10, 20))
	else:
		# Un adversaire qui reste en garde se fait projeter.
		if op.state in [Fighter.State.GUARD, Fighter.State.CROUCH] and _roll(s.throw):
			_start_plan(Plan.THROW, 30)
		elif r < aggression:
			_start_plan(Plan.LOW_ATTACK if _wants_low(op) else Plan.COMBO, 40)
		elif r < aggression + s.guard:
			_start_guard(rng.randi_range(15, 30), s)
		elif r < aggression + s.guard + 0.1:
			_start_plan(Plan.RETREAT, rng.randi_range(10, 20))
		else:
			_start_plan(Plan.WAIT, rng.randi_range(5, 12))


## Frapper en bas ? Contre une garde debout qu'on voit, oui ; sinon de temps en temps.
func _wants_low(op: Fighter) -> bool:
	if op.state == Fighter.State.GUARD:
		return not op.guard_low
	return rng.randf() < 0.3


func _start_guard(length: int, s: Dictionary) -> void:
	_start_plan(Plan.GUARD, length)
	_guard_low = _pick_guard_height(s)


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
		Plan.GUARD:
			intent.guard = true
			intent.crouch = _guard_low
		Plan.THROW:
			# S'approcher jusqu'à être collé, puis avant + Garde.
			_hold_direction(intent, toward)
			if distance <= Fighter.THROW_RANGE - 4.0:
				intent.guard_pressed = true
				_plan_length = f + 1
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
