class_name Fighter
extends CharacterBody2D
## Un combattant : marcher, sauter, s'accroupir, frapper, parer, esquiver.
##
## Pour l'instant c'est un rectangle de couleur. Les vrais sprites
## remplaceront le nœud Body plus tard, sans changer cette logique.
##
## Le combattant est une « machine à états » : à chaque instant il est dans
## UN état (debout, saut, attaque, garde, touché...) et chaque état a ses règles.
## Il n'avance pas tout seul : l'arène (fight.gd) appelle tick() 60 fois
## par seconde, puis vérifie les coups. Tout se joue donc image par image.

## Émis quand le combattant réussit une esquive mystique.
signal dodged
## Émis quand un coup spécial lance son projectile (l'arène le crée).
signal projectile_launched(data: ProjectileData, shooter: Fighter)
## Émis au début de l'ultime (l'arène arrête le combat pour la mise en scène).
signal ultimate_started(fighter: Fighter)
## Émis quand le combattant appelle son soutien (l'arène le fait apparaître).
signal assist_called(fighter: Fighter)
## Émis au début de chaque attaque (sert aux bruitages).
signal attack_started(attack: AttackData)

enum State { IDLE, WALK, CROUCH, JUMP, ATTACK, GUARD, BLOCKSTUN, HITSTUN, KNOCKDOWN, GETUP, DODGE, CHARGE }
## Ce qui arrive quand un coup atteint le combattant.
enum HitResult { HIT, BLOCKED, PARRIED }

## La vie est la même pour tous les combattants (décision du cahier des charges).
const MAX_HEALTH := 1000
## L'énergie ancestrale : 4 segments de 100.
const MAX_ENERGY := 400
const ENERGY_SEGMENT := 100
## Énergie gagnée par frame en chargeant (90 par seconde : barre pleine en 4,4 s).
const CHARGE_RATE := 1.5
## Maintenir Spécial plus de 10 frames = charger. Un appui plus court = coup spécial.
const CHARGE_THRESHOLD_FRAMES := 10
const GRAVITY := 900.0
const BODY_WIDTH := 24.0
const STAND_HEIGHT := 56.0
const CROUCH_HEIGHT := 36.0
const AIR_HEIGHT := 44.0
## Reculer est plus lent qu'avancer, comme dans tous les jeux de combat.
const BACKWARD_SPEED_RATIO := 0.8
## Un appui reste en mémoire 8 frames : on peut appuyer un tout petit peu en
## avance, l'action partira dès que possible.
const INPUT_BUFFER_FRAMES := 8
## Contre parfait : il faut appuyer sur Garde au plus 6 frames avant l'impact.
const PARRY_WINDOW_FRAMES := 6
## Temps pendant lequel l'attaquant contré est sans défense.
const PARRIED_STUN_FRAMES := 24
## Durée de l'esquive mystique (le combattant est intouchable).
const DODGE_FRAMES := 14
## Distance de réapparition derrière l'adversaire.
const DODGE_BEHIND_DISTANCE := 28.0
## Ralentissement du recul à chaque frame (0,85 = perd 15 % de sa vitesse).
const PUSHBACK_FRICTION := 0.85
const KNOCKDOWN_LAUNCH := 220.0
const KNOCKDOWN_FRAMES := 40
const GETUP_FRAMES := 20
const FLASH_FRAMES := 4
const HIT_FLASH := Color.WHITE
const BLOCK_FLASH := Color(0.6, 0.85, 1.0)
const PARRY_FLASH := Color(0.3, 1.0, 1.0)

## La fiche du combattant (stats, attaques...).
@export var data: FighterData
## Coché : contrôlé par le joueur. Décoché : contrôlé par l'IA ou mannequin.
@export var is_player := true
## Affiche les zones de frappe (rouge) et vulnérables (vert) pour régler les coups.
@export var show_boxes := true

## L'adversaire, donné par l'arène.
var opponent: Fighter
## Le personnage choisi comme soutien pour ce combat, donné par l'arène.
var support: FighterData
## Coché par l'arène en mode entraînement : la vie ne descend jamais sous 1.
var immortal := false
## Frames restantes avant de pouvoir rappeler le soutien (0 = prêt).
var assist_cooldown := 0
## Vrai tant que le soutien est à l'écran (géré par l'arène).
var assist_active := false
var state: State = State.IDLE
## 1 = tourné vers la droite, -1 = vers la gauche.
var facing := 1
var health := MAX_HEALTH
var energy := 0.0
var current_attack: AttackData
var attack_frame := 0
## Numéro de l'attaque, augmenté à chaque nouveau coup (sert à l'IA pour
## reconnaître un coup qu'elle a déjà vu).
var attack_serial := 0
## Position dans le combo (0 = premier coup).
var combo_index := -1
## Vrai quand l'attaque en cours a déjà touché (un coup ne touche qu'une fois).
var attack_has_hit := false
## Nombre de coups portés d'affilée sans que l'adversaire puisse réagir.
var combo_hits := 0
var stun_frames := 0
var air_attack_used := false
## Vrai quand la garde est basse (accroupie).
var guard_low := false
var buffered_attack := 0
var buffered_guard := 0
var buffered_special := 0
var buffered_ultimate := 0
var buffered_assist := 0
## Vrai si le dernier appui sur Spécial était accompagné de la direction avant.
var special_forward := false
## Depuis combien de frames Spécial est maintenu (0 = relâché).
var special_held_frames := 0
## Nombre de projectiles de ce combattant encore à l'écran (un seul à la fois).
var active_projectiles := 0
var parry_window := 0
var flash_frames := 0
## Reste de soin à moins d'un point de vie (le soin arrive par petites fractions).
var _heal_buffer := 0.0
var flash_color := HIT_FLASH
## Ce que le combattant veut faire à cette frame.
## Rempli par le joueur (clavier, tactile) ou par l'IA / le mannequin.
## « attack », « guard_pressed », « ultimate » et « assist » = appui à cette frame ;
## les autres (dont « special ») = touche maintenue.
var intent := {
	"left": false, "right": false, "jump": false, "crouch": false,
	"attack": false, "guard": false, "guard_pressed": false,
	"special": false, "ultimate": false, "assist": false,
}

@onready var pivot: Node2D = $Pivot
@onready var body: ColorRect = $Pivot/Body
@onready var front: ColorRect = $Pivot/Front
@onready var arm: ColorRect = $Arm
@onready var aura: ColorRect = $Aura
@onready var hurtbox_view: ColorRect = $HurtboxView
@onready var hitbox_view: ColorRect = $HitboxView


func _ready() -> void:
	if data == null:
		push_error("Fighter : aucune fiche FighterData assignée dans l'Inspecteur.")
		return
	body.color = data.placeholder_color
	reset()


## Remet le combattant en début de manche (l'énergie est gardée d'une manche à l'autre).
func reset() -> void:
	health = MAX_HEALTH
	velocity = Vector2.ZERO
	current_attack = null
	combo_index = -1
	combo_hits = 0
	buffered_attack = 0
	buffered_guard = 0
	buffered_special = 0
	buffered_ultimate = 0
	buffered_assist = 0
	special_held_frames = 0
	parry_window = 0
	# Le soutien est disponible dès le début de chaque manche.
	assist_cooldown = 0
	modulate.a = 1.0
	_change_state(State.IDLE)
	_update_visuals()


## Lit les commandes. Appelée à chaque frame, même pendant les arrêts sur image,
## pour ne perdre aucun appui.
func poll_input() -> void:
	if is_player:
		intent.left = Input.is_action_pressed("move_left")
		intent.right = Input.is_action_pressed("move_right")
		intent.jump = Input.is_action_pressed("jump")
		intent.crouch = Input.is_action_pressed("crouch")
		intent.guard = Input.is_action_pressed("guard")
		intent.attack = Input.is_action_just_pressed("attack")
		intent.guard_pressed = Input.is_action_just_pressed("guard")
		intent.special = Input.is_action_pressed("special")
		intent.ultimate = Input.is_action_just_pressed("ultimate")
		intent.assist = Input.is_action_just_pressed("assist")
	_read_special_button()
	if intent.assist:
		buffered_assist = INPUT_BUFFER_FRAMES
	if intent.ultimate:
		buffered_ultimate = INPUT_BUFFER_FRAMES
	if intent.attack:
		buffered_attack = INPUT_BUFFER_FRAMES
	if intent.guard_pressed:
		buffered_guard = INPUT_BUFFER_FRAMES
		parry_window = PARRY_WINDOW_FRAMES
	intent.attack = false
	intent.guard_pressed = false
	intent.ultimate = false
	intent.assist = false


## Le bouton Spécial sert à deux choses : un appui court lance un coup spécial
## (au relâchement), un appui long charge l'énergie.
func _read_special_button() -> void:
	if intent.special:
		special_held_frames += 1
		# La direction est lue au moment de l'appui : on la lâche souvent avant le bouton.
		if special_held_frames == 1:
			special_forward = _input_direction() == facing
	elif special_held_frames > 0:
		if special_held_frames < CHARGE_THRESHOLD_FRAMES:
			buffered_special = INPUT_BUFFER_FRAMES
		special_held_frames = 0


## Commandes bloquées (annonce de manche, fin de manche) : on lâche tout.
func release_controls() -> void:
	for key in intent:
		intent[key] = false
	special_held_frames = 0
	buffered_attack = 0
	buffered_guard = 0
	buffered_special = 0
	buffered_ultimate = 0
	buffered_assist = 0


## Une frame de jeu.
func tick(delta: float) -> void:
	buffered_attack = maxi(0, buffered_attack - 1)
	buffered_guard = maxi(0, buffered_guard - 1)
	buffered_special = maxi(0, buffered_special - 1)
	buffered_ultimate = maxi(0, buffered_ultimate - 1)
	buffered_assist = maxi(0, buffered_assist - 1)
	assist_cooldown = maxi(0, assist_cooldown - 1)
	parry_window = maxi(0, parry_window - 1)
	flash_frames = maxi(0, flash_frames - 1)
	# Le soutien s'appelle sans interrompre ce qu'on fait (même en plein combo).
	if buffered_assist > 0 and can_call_assist():
		buffered_assist = 0
		assist_cooldown = support.assist.cooldown_frames
		assist_active = true
		assist_called.emit(self)

	match state:
		State.IDLE, State.WALK, State.CROUCH, State.GUARD:
			_ground_state()
		State.JUMP:
			_jump_state()
		State.ATTACK:
			_attack_state()
		State.BLOCKSTUN:
			_blockstun_state()
		State.HITSTUN:
			_hitstun_state()
		State.KNOCKDOWN:
			_knockdown_state()
		State.GETUP:
			_getup_state()
		State.DODGE:
			_dodge_state()
		State.CHARGE:
			_charge_state()

	velocity.y += GRAVITY * delta
	var was_in_air := not is_on_floor()
	move_and_slide()
	if was_in_air and is_on_floor():
		_on_landed()
	_update_visuals()


# --- Les états ---------------------------------------------------------------

## Debout, en marche, accroupi ou en garde : le combattant peut tout faire.
func _ground_state() -> void:
	var direction := _input_direction()
	_face_opponent()

	if buffered_ultimate > 0 and energy >= MAX_ENERGY and data.ultimate:
		buffered_ultimate = 0
		_start_special(data.ultimate)
		return
	if buffered_special > 0 and _try_special():
		return
	if special_held_frames >= CHARGE_THRESHOLD_FRAMES:
		velocity.x = 0
		_change_state(State.CHARGE)
		return
	if _consume_attack():
		if intent.crouch:
			_start_attack(data.low_attack)
		else:
			_start_combo(0)
		return
	if intent.guard:
		velocity.x = 0
		guard_low = intent.crouch
		_change_state(State.GUARD)
		return
	if intent.jump:
		velocity.y = -data.jump_strength
		velocity.x = direction * data.walk_speed()
		air_attack_used = false
		_change_state(State.JUMP)
		return
	if intent.crouch:
		velocity.x = 0
		_change_state(State.CROUCH)
		return

	var speed := data.walk_speed()
	if direction != 0 and direction != facing:
		speed *= BACKWARD_SPEED_RATIO
	velocity.x = direction * speed
	_change_state(State.WALK if direction != 0 else State.IDLE)


## En l'air : on garde son élan, on peut donner un seul coup.
func _jump_state() -> void:
	if current_attack:
		attack_frame += 1
	elif not air_attack_used and data.air_attack and _consume_attack():
		air_attack_used = true
		_prepare_attack(data.air_attack)


func _attack_state() -> void:
	attack_frame += 1
	var attack := current_attack
	# Les attaques foncées avancent pendant leur temps actif.
	if attack.dash_speed > 0.0 and attack.is_active_frame(attack_frame):
		velocity.x = facing * attack.dash_speed
	else:
		velocity.x = 0
	if attack.projectile and attack_frame == attack.startup:
		projectile_launched.emit(attack.projectile, self)
	var in_recovery := attack_frame > attack.startup + attack.active
	# Annulation : un coup du combo qui a touché (ou été paré) peut être
	# interrompu par un coup spécial. C'est la base des gros combos.
	if in_recovery and attack.energy_cost == 0 and attack_has_hit and buffered_special > 0 and _try_special():
		return
	# Enchaînement : un nouvel appui pendant le coup lance le coup suivant
	# du combo dès que le coup actuel a fini de pouvoir toucher.
	if in_recovery and _can_chain() and _consume_attack():
		_start_combo(combo_index + 1)
		return
	if attack_frame >= current_attack.total_frames():
		current_attack = null
		combo_index = -1
		_change_state(State.CROUCH if intent.crouch else State.IDLE)


func _blockstun_state() -> void:
	velocity.x *= PUSHBACK_FRICTION
	stun_frames -= 1
	if stun_frames <= 0:
		_change_state(State.IDLE)


func _hitstun_state() -> void:
	velocity.x *= PUSHBACK_FRICTION
	# Esquive mystique : appuyer sur Garde pendant qu'on encaisse, si on a 1 segment.
	if buffered_guard > 0 and energy >= ENERGY_SEGMENT and is_on_floor():
		_start_dodge()
		return
	stun_frames -= 1
	if stun_frames <= 0:
		_change_state(State.IDLE)


## Projeté : on vole, on tombe, on reste au sol, puis on se relève.
func _knockdown_state() -> void:
	if is_on_floor():
		velocity.x *= PUSHBACK_FRICTION
		stun_frames -= 1
		if stun_frames <= 0 and health > 0:
			stun_frames = GETUP_FRAMES
			_change_state(State.GETUP)


func _getup_state() -> void:
	stun_frames -= 1
	if stun_frames <= 0:
		_change_state(State.IDLE)


## Charger : immobile et sans défense, l'énergie monte tant que Spécial est maintenu.
func _charge_state() -> void:
	velocity.x = 0
	add_energy(CHARGE_RATE)
	if special_held_frames == 0 or energy >= MAX_ENERGY:
		_change_state(State.IDLE)


func _dodge_state() -> void:
	velocity.x = 0
	stun_frames -= 1
	if stun_frames <= 0:
		_face_opponent()
		_change_state(State.IDLE)


func _on_landed() -> void:
	if state == State.JUMP:
		current_attack = null
		velocity.x = 0
		_change_state(State.IDLE)
	elif state == State.KNOCKDOWN:
		stun_frames = KNOCKDOWN_FRAMES


# --- Attaques ----------------------------------------------------------------

func _start_combo(index: int) -> void:
	if index >= data.combo.size():
		return
	combo_index = index
	_start_attack(data.combo[index])


func _start_attack(attack: AttackData) -> void:
	if attack == null:
		return
	_prepare_attack(attack)
	velocity.x = 0
	_change_state(State.ATTACK)


func _prepare_attack(attack: AttackData) -> void:
	current_attack = attack
	attack_frame = 0
	attack_has_hit = false
	attack_serial += 1
	attack_started.emit(attack)


## Lance le spécial demandé (1 ou 2) s'il y a assez d'énergie. Renvoie vrai s'il part.
func _try_special() -> bool:
	buffered_special = 0
	var special := data.special_2 if special_forward else data.special_1
	if special == null or energy < special.energy_cost:
		return false
	if special.projectile and active_projectiles > 0:
		return false
	_start_special(special)
	return true


func _start_special(attack: AttackData) -> void:
	energy -= attack.energy_cost
	combo_index = -1
	_start_attack(attack)
	if attack.is_ultimate:
		ultimate_started.emit(self)


## Vrai si le soutien peut être appelé maintenant.
func can_call_assist() -> bool:
	if support == null or support.assist == null:
		return false
	if assist_cooldown > 0 or assist_active:
		return false
	return state not in [State.HITSTUN, State.KNOCKDOWN, State.GETUP, State.DODGE, State.CHARGE]


## Rend des points de vie (soutien de soin), sans dépasser le maximum.
func heal(amount: float) -> void:
	if health <= 0:
		return
	_heal_buffer += amount
	var whole := int(_heal_buffer)
	_heal_buffer -= whole
	health = mini(MAX_HEALTH, health + whole)


func add_energy(amount: float) -> void:
	energy = clampf(energy + amount, 0.0, MAX_ENERGY)


func _can_chain() -> bool:
	return combo_index >= 0 and combo_index < data.combo.size() - 1


func _consume_attack() -> bool:
	if buffered_attack > 0:
		buffered_attack = 0
		return true
	return false


# --- Défense -----------------------------------------------------------------

## Vrai si le combattant pare ce coup : garde maintenue ou recul, à la bonne hauteur.
func _can_block(attack: AttackData, attacker: Fighter) -> bool:
	if not is_on_floor():
		return false
	if state not in [State.IDLE, State.WALK, State.CROUCH, State.GUARD, State.BLOCKSTUN]:
		return false
	if not (intent.guard or _is_holding_back(attacker)):
		return false
	var low: bool = intent.crouch
	match attack.hit_level:
		AttackData.HitLevel.HIGH:
			return not low
		AttackData.HitLevel.LOW:
			return low
	return true


func _is_holding_back(attacker: Fighter) -> bool:
	var away := 1 if global_position.x >= attacker.global_position.x else -1
	return _input_direction() == away


func _start_dodge() -> void:
	energy -= ENERGY_SEGMENT
	buffered_guard = 0
	# On réapparaît dans le dos de l'adversaire.
	var behind := opponent.global_position.x - opponent.facing * DODGE_BEHIND_DISTANCE
	global_position.x = behind
	stun_frames = DODGE_FRAMES
	_change_state(State.DODGE)
	dodged.emit()


# --- Utilisé par l'arène -----------------------------------------------------

## Vrai si le combattant n'est pas pris dans un combo (sert à compter les combos).
func is_free() -> bool:
	return state not in [State.HITSTUN, State.KNOCKDOWN]


## Zone de frappe actuelle, en coordonnées de l'arène. Vide si aucun coup ne peut toucher.
func get_hitbox_rect() -> Rect2:
	if current_attack == null or attack_has_hit:
		return Rect2()
	if not current_attack.is_active_frame(attack_frame):
		return Rect2()
	return _attack_rect(current_attack)


## Zone où le combattant peut être touché. Vide s'il est intouchable.
func get_hurtbox_rect() -> Rect2:
	if state in [State.KNOCKDOWN, State.GETUP, State.DODGE]:
		return Rect2()
	if current_attack and current_attack.invulnerable_startup and attack_frame <= current_attack.startup:
		return Rect2()
	var height := _current_height()
	return Rect2(global_position + Vector2(-BODY_WIDTH / 2.0, -height), Vector2(BODY_WIDTH, height))


## Appelée par l'arène quand un coup de l'adversaire atteint ce combattant.
## Renvoie ce qui s'est passé : touché, paré ou contré.
## remote : le coup ne vient pas du corps de l'attaquant (projectile ou soutien).
func receive_attack(attack: AttackData, attacker: Fighter, remote := false) -> HitResult:
	var can_parry := is_on_floor() and state in [State.IDLE, State.WALK, State.CROUCH, State.GUARD, State.BLOCKSTUN]
	if parry_window > 0 and can_parry:
		parry_window = 0
		_flash(PARRY_FLASH)
		_change_state(State.IDLE)
		# Contrer un projectile ou un soutien l'arrête seulement : l'attaquant n'est pas touché.
		if not remote:
			attacker.get_parried()
		return HitResult.PARRIED
	if _can_block(attack, attacker):
		_block(attack, attacker)
		return HitResult.BLOCKED
	_take_damage(attack, attacker)
	return HitResult.HIT


## Appelée quand l'adversaire a contré notre coup : on reste sans défense un moment.
func get_parried() -> void:
	buffered_guard = 0
	current_attack = null
	combo_index = -1
	velocity.x = 0
	stun_frames = PARRIED_STUN_FRAMES
	_flash(HIT_FLASH)
	_change_state(State.HITSTUN)


func _block(attack: AttackData, attacker: Fighter) -> void:
	guard_low = intent.crouch
	# Les coups spéciaux retirent un peu de vie même quand on pare.
	if attack.chip_damage > 0:
		health = maxi(1, health - attack.chip_damage)
	velocity.x = _direction_from(attacker) * attack.pushback
	stun_frames = attack.blockstun
	_flash(BLOCK_FLASH)
	_change_state(State.BLOCKSTUN)


func _take_damage(attack: AttackData, attacker: Fighter) -> void:
	var damage := roundi(attack.damage * attacker.data.damage_multiplier() * data.defense_multiplier())
	health = maxi(1 if immortal else 0, health - damage)
	special_held_frames = 0
	# Seul un appui sur Garde PENDANT qu'on encaisse déclenche l'esquive : un contre
	# parfait tenté un peu trop tôt ne doit pas se transformer en esquive.
	buffered_guard = 0
	current_attack = null
	combo_index = -1
	_flash(HIT_FLASH)
	var direction := _direction_from(attacker)
	if attack.knockdown or not is_on_floor() or health == 0:
		velocity = Vector2(direction * attack.pushback, -KNOCKDOWN_LAUNCH)
		stun_frames = KNOCKDOWN_FRAMES
		_change_state(State.KNOCKDOWN)
	else:
		velocity.x = direction * attack.pushback
		stun_frames = attack.hitstun
		_change_state(State.HITSTUN)


# --- Outils ------------------------------------------------------------------

func _change_state(new_state: State) -> void:
	state = new_state


## -1 = gauche, 1 = droite, 0 = aucune direction (ou les deux à la fois).
func _input_direction() -> int:
	return int(intent.right) - int(intent.left)


## Sens dans lequel on est repoussé par un coup de cet attaquant.
func _direction_from(attacker: Fighter) -> int:
	return 1 if global_position.x >= attacker.global_position.x else -1


func _face_opponent() -> void:
	if opponent and opponent.global_position.x != global_position.x:
		facing = 1 if opponent.global_position.x > global_position.x else -1


func _flash(color: Color) -> void:
	flash_color = color
	flash_frames = FLASH_FRAMES


func _is_low() -> bool:
	if state == State.CROUCH:
		return true
	if state in [State.GUARD, State.BLOCKSTUN]:
		return guard_low
	return state == State.ATTACK and current_attack == data.low_attack


func _current_height() -> float:
	if _is_low():
		return CROUCH_HEIGHT
	if state == State.KNOCKDOWN or state == State.GETUP:
		return CROUCH_HEIGHT * 0.6
	if not is_on_floor():
		return AIR_HEIGHT
	return STAND_HEIGHT


## Rectangle d'une attaque, retourné selon le côté où regarde le combattant.
func _attack_rect(attack: AttackData) -> Rect2:
	var box := attack.hitbox
	var x := box.position.x if facing == 1 else -box.position.x - box.size.x
	return Rect2(global_position + Vector2(x, box.position.y), box.size)


## Met les rectangles à jour pour qu'ils montrent l'état du combattant.
func _update_visuals() -> void:
	var height := _current_height()
	pivot.scale.x = facing
	body.size = Vector2(BODY_WIDTH, height)
	body.position = Vector2(-BODY_WIDTH / 2.0, -height)
	body.color = flash_color if flash_frames > 0 else data.placeholder_color
	front.position.y = -height + 6
	front.visible = state != State.KNOCKDOWN
	# Pendant l'esquive, le combattant devient presque transparent.
	modulate.a = 0.3 if state == State.DODGE else 1.0

	hurtbox_view.visible = show_boxes and get_hurtbox_rect().has_area()
	hurtbox_view.size = body.size
	hurtbox_view.position = body.position

	var attacking := current_attack != null and attack_frame <= current_attack.startup + current_attack.active
	hitbox_view.visible = show_boxes and attacking and current_attack.is_active_frame(attack_frame)
	if attacking:
		# Le « bras » montre le coup pendant sa préparation et son temps actif.
		var rect := _attack_rect(current_attack)
		rect.position -= global_position
		arm.visible = attack_frame >= current_attack.startup / 2.0
		arm.color = data.placeholder_color.darkened(0.2)
		arm.position = rect.position
		arm.size = rect.size
		hitbox_view.position = rect.position
		hitbox_view.size = rect.size
	elif state in [State.GUARD, State.BLOCKSTUN]:
		# En garde, le « bras » devient un bouclier levé devant le corps.
		arm.visible = true
		arm.color = data.placeholder_color.darkened(0.45)
		arm.size = Vector2(5, height * 0.7)
		arm.position = Vector2(facing * (BODY_WIDTH / 2.0) - (5 if facing == 1 else 0) + facing * 2, -height + 2)
	else:
		arm.visible = false

	# L'aura : bleue quand on charge, dorée pendant la préparation de l'ultime.
	var ultimate_startup := current_attack != null and current_attack.is_ultimate and attack_frame <= current_attack.startup
	aura.visible = state == State.CHARGE or ultimate_startup
	if aura.visible:
		var pulse := 0.25 + 0.15 * sin(Time.get_ticks_msec() / 60.0)
		var aura_color := Color(1.0, 0.85, 0.35) if ultimate_startup else Color(0.3, 0.85, 1.0)
		aura.color = Color(aura_color, pulse)
		aura.size = body.size + Vector2(12, 10)
		aura.position = body.position - Vector2(6, 10)
