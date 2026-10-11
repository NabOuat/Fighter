class_name Fighter
extends CharacterBody2D
## Un combattant : marcher, sauter, s'accroupir, frapper, encaisser.
##
## Pour l'instant c'est un rectangle de couleur. Les vrais sprites
## remplaceront le nœud Body plus tard, sans changer cette logique.
##
## Le combattant est une « machine à états » : à chaque instant il est dans
## UN état (debout, saut, attaque, touché...) et chaque état a ses règles.
## Il n'avance pas tout seul : l'arène (fight.gd) appelle tick() 60 fois
## par seconde, puis vérifie les coups. Tout se joue donc image par image.

enum State { IDLE, WALK, CROUCH, JUMP, ATTACK, HITSTUN, KNOCKDOWN, GETUP }

## La vie est la même pour tous les combattants (décision du cahier des charges).
const MAX_HEALTH := 1000
const GRAVITY := 900.0
const BODY_WIDTH := 24.0
const STAND_HEIGHT := 56.0
const CROUCH_HEIGHT := 36.0
const AIR_HEIGHT := 44.0
## Reculer est plus lent qu'avancer, comme dans tous les jeux de combat.
const BACKWARD_SPEED_RATIO := 0.8
## Un appui sur Attaque reste en mémoire 8 frames : on peut appuyer un
## tout petit peu en avance, le coup partira dès que possible.
const INPUT_BUFFER_FRAMES := 8
## Ralentissement du recul à chaque frame (0,85 = perd 15 % de sa vitesse).
const PUSHBACK_FRICTION := 0.85
const KNOCKDOWN_LAUNCH := 220.0
const KNOCKDOWN_FRAMES := 40
const GETUP_FRAMES := 20
const FLASH_FRAMES := 4

## La fiche du combattant (stats, attaques...).
@export var data: FighterData
## Coché : contrôlé par le joueur. Décoché : contrôlé par l'IA ou mannequin.
@export var is_player := true
## Affiche les zones de frappe (rouge) et vulnérables (vert) pour régler les coups.
@export var show_boxes := true

## L'adversaire, donné par l'arène.
var opponent: Fighter
var state: State = State.IDLE
## 1 = tourné vers la droite, -1 = vers la gauche.
var facing := 1
var health := MAX_HEALTH
var current_attack: AttackData
var attack_frame := 0
## Position dans le combo (0 = premier coup).
var combo_index := -1
## Vrai quand l'attaque en cours a déjà touché (un coup ne touche qu'une fois).
var attack_has_hit := false
## Nombre de coups portés d'affilée sans que l'adversaire puisse réagir.
var combo_hits := 0
var stun_frames := 0
var air_attack_used := false
var buffered_attack := 0
var flash_frames := 0
## Ce que le combattant veut faire à cette frame.
## Rempli par le joueur (clavier, tactile) ou plus tard par l'IA.
var intent := {
	"left": false, "right": false, "jump": false,
	"crouch": false, "attack": false,
}

@onready var pivot: Node2D = $Pivot
@onready var body: ColorRect = $Pivot/Body
@onready var front: ColorRect = $Pivot/Front
@onready var arm: ColorRect = $Arm
@onready var hurtbox_view: ColorRect = $HurtboxView
@onready var hitbox_view: ColorRect = $HitboxView


func _ready() -> void:
	if data == null:
		push_error("Fighter : aucune fiche FighterData assignée dans l'Inspecteur.")
		return
	body.color = data.placeholder_color
	arm.color = data.placeholder_color.darkened(0.2)
	reset()


## Remet le combattant en début de manche.
func reset() -> void:
	health = MAX_HEALTH
	velocity = Vector2.ZERO
	current_attack = null
	combo_hits = 0
	buffered_attack = 0
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
		intent.attack = Input.is_action_just_pressed("attack")
	if intent.attack:
		buffered_attack = INPUT_BUFFER_FRAMES
		intent.attack = false


## Une frame de jeu.
func tick(delta: float) -> void:
	if buffered_attack > 0:
		buffered_attack -= 1
	if flash_frames > 0:
		flash_frames -= 1

	match state:
		State.IDLE, State.WALK, State.CROUCH:
			_ground_state()
		State.JUMP:
			_jump_state()
		State.ATTACK:
			_attack_state()
		State.HITSTUN:
			_hitstun_state()
		State.KNOCKDOWN:
			_knockdown_state()
		State.GETUP:
			_getup_state()

	velocity.y += GRAVITY * delta
	var was_in_air := not is_on_floor()
	move_and_slide()
	if was_in_air and is_on_floor():
		_on_landed()
	_update_visuals()


# --- Les états ---------------------------------------------------------------

## Debout, en marche ou accroupi : le combattant peut tout faire.
func _ground_state() -> void:
	var direction := _input_direction()
	_face_opponent()

	if _consume_attack():
		if intent.crouch:
			_start_attack(data.low_attack)
		else:
			_start_combo(0)
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
	velocity.x = 0
	attack_frame += 1
	var in_recovery := attack_frame > current_attack.startup + current_attack.active
	# Enchaînement : un nouvel appui pendant le coup lance le coup suivant
	# du combo dès que le coup actuel a fini de pouvoir toucher.
	if in_recovery and _can_chain() and _consume_attack():
		_start_combo(combo_index + 1)
		return
	if attack_frame >= current_attack.total_frames():
		current_attack = null
		combo_index = -1
		_change_state(State.CROUCH if intent.crouch else State.IDLE)


func _hitstun_state() -> void:
	velocity.x *= PUSHBACK_FRICTION
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


func _can_chain() -> bool:
	return combo_index >= 0 and combo_index < data.combo.size() - 1


func _consume_attack() -> bool:
	if buffered_attack > 0:
		buffered_attack = 0
		return true
	return false


# --- Utilisé par l'arène -----------------------------------------------------

## Vrai si le combattant peut agir librement (sert à finir les combos).
func is_free() -> bool:
	return state in [State.IDLE, State.WALK, State.CROUCH, State.JUMP, State.ATTACK]


## Zone de frappe actuelle, en coordonnées de l'arène. Vide si aucun coup ne peut toucher.
func get_hitbox_rect() -> Rect2:
	if current_attack == null or attack_has_hit:
		return Rect2()
	if not current_attack.is_active_frame(attack_frame):
		return Rect2()
	return _attack_rect(current_attack)


## Zone où le combattant peut être touché. Vide s'il est intouchable (au sol, se relève).
func get_hurtbox_rect() -> Rect2:
	if state in [State.KNOCKDOWN, State.GETUP]:
		return Rect2()
	var height := _current_height()
	return Rect2(global_position + Vector2(-BODY_WIDTH / 2.0, -height), Vector2(BODY_WIDTH, height))


## Appelée par l'arène quand un coup de l'adversaire touche ce combattant.
func take_hit(attack: AttackData, attacker: Fighter) -> void:
	var damage := roundi(attack.damage * attacker.data.damage_multiplier() * data.defense_multiplier())
	health = maxi(0, health - damage)
	current_attack = null
	combo_index = -1
	flash_frames = FLASH_FRAMES
	var direction := 1 if global_position.x >= attacker.global_position.x else -1

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


func _face_opponent() -> void:
	if opponent and opponent.global_position.x != global_position.x:
		facing = 1 if opponent.global_position.x > global_position.x else -1


func _current_height() -> float:
	if state == State.CROUCH or (state == State.ATTACK and current_attack == data.low_attack):
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
	body.color = Color.WHITE if flash_frames > 0 else data.placeholder_color
	front.position.y = -height + 6
	front.visible = state != State.KNOCKDOWN

	hurtbox_view.visible = show_boxes and state not in [State.KNOCKDOWN, State.GETUP]
	hurtbox_view.size = body.size
	hurtbox_view.position = body.position

	# Le « bras » montre le coup pendant sa préparation et son temps actif.
	var showing := current_attack != null and attack_frame <= current_attack.startup + current_attack.active
	arm.visible = showing and attack_frame >= current_attack.startup / 2.0
	hitbox_view.visible = show_boxes and showing and current_attack.is_active_frame(attack_frame)
	if showing:
		var rect := _attack_rect(current_attack)
		rect.position -= global_position
		arm.position = rect.position
		arm.size = rect.size
		hitbox_view.position = rect.position
		hitbox_view.size = rect.size
