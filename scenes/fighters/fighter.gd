class_name Fighter
extends Node2D
## Un combattant : marcher, sauter, s'accroupir, frapper, parer, esquiver.
##
## Pour l'instant c'est un rectangle de couleur. Les vrais sprites
## remplaceront le nœud Body plus tard, sans changer cette logique.
##
## Le combattant est une « machine à états » : à chaque instant il est dans
## UN état (debout, saut, attaque, garde, touché...) et chaque état a ses règles.
## Il n'avance pas tout seul : l'arène (fight.gd) appelle tick() 60 fois
## par seconde, puis vérifie les coups. Tout se joue donc image par image.
##
## Pas de moteur physique : le sol est plat et les murs droits, les mouvements
## sont calculés ici (_move). Ainsi tout l'état du combattant tient dans ses
## variables, qu'on peut sauvegarder et recharger (get_state / set_state) :
## c'est ce qui permet le « rollback » du jeu en ligne.

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

## JUGGLE : lancé en l'air par un coup, on peut encore être frappé (jonglage).
enum State { IDLE, WALK, CROUCH, JUMP, ATTACK, GUARD, BLOCKSTUN, HITSTUN, KNOCKDOWN, GETUP, DODGE, CHARGE, JUGGLE }
## Ce qui arrive quand un coup atteint le combattant.
## MISSED : projection sur un adversaire qu'on ne peut pas saisir (en l'air, sonné...).
## TECHED : les deux ont projeté en même temps, personne n'est saisi.
enum HitResult { HIT, BLOCKED, PARRIED, MISSED, TECHED }

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
## Les murs de l'arène, pour le centre du corps (l'écran fait 480 de large,
## le corps 20 : le centre ne passe jamais sous 10 ni au-dessus de 470).
const WALL_LEFT := 10.0
const WALL_RIGHT := 470.0
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
## Projection : distance maximale entre les deux combattants pour la tenter (collés).
const THROW_RANGE := 36.0
## Projection évitée : les deux combattants se repoussent et reprennent leurs esprits.
const THROW_TECH_FRAMES := 14
const THROW_TECH_PUSH := 150.0
## Ralentissement du recul à chaque frame (0,85 = perd 15 % de sa vitesse).
const PUSHBACK_FRICTION := 0.85
const KNOCKDOWN_LAUNCH := 220.0
## Jonglage : chaque coup reçu en l'air relance vers le haut, un peu moins à chaque fois.
const JUGGLE_POP := 200.0
const JUGGLE_DECAY := 0.8
const JUGGLE_PUSH := 40.0
## Au-delà de ce nombre de coups en l'air, on retombe sans pouvoir être touché (pas de combo infini).
const MAX_JUGGLE_HITS := 4
## Coups en l'air par saut (le 2e seulement si le 1er a touché).
const AIR_ATTACKS_PER_JUMP := 2
## Dégâts des longs combos : -10 % par coup à partir du 3e, jamais moins de 40 %.
const COMBO_SCALING_STEP := 0.1
const MIN_COMBO_SCALING := 0.4
## Pendant un serment, on ne reçoit que 60 % des dégâts.
const OATH_DAMAGE_TAKEN := 0.6
const KNOCKDOWN_FRAMES := 40
const GETUP_FRAMES := 20
const FLASH_FRAMES := 4
const HIT_FLASH := Color.WHITE
const BLOCK_FLASH := Color(0.6, 0.85, 1.0)
const PARRY_FLASH := Color(0.3, 1.0, 1.0)

## La fiche du combattant (stats, attaques...).
@export var data: FighterData:
	set(value):
		data = value
		# Nouvelle fiche (choisie dans les menus) : le dessin change aussi.
		if is_node_ready():
			view.use_data(value)
## Coché : contrôlé par le joueur. Décoché : contrôlé par l'IA ou mannequin.
@export var is_player := true
## Affiche les zones de frappe (rouge) et vulnérables (vert) pour régler les coups.
@export var show_boxes := true
## Affiche les repères des coups qui se préparent (réglage « Repères des coups »).
@export var show_markers := true

## L'adversaire, donné par l'arène.
var opponent: Fighter
## Hauteur du sol (donnée par l'arène).
var floor_y := 230.0
## Vitesse en unités par seconde (x : vers la droite, y : vers le bas).
var velocity := Vector2.ZERO
## Vrai quand les pieds touchent le sol (calculé par _move).
var on_floor := false
## Vrai quand l'état a changé depuis le dernier affichage : l'arène redessine
## le combattant une seule fois par image affichée (et pas pendant l'arrêt sur image).
var needs_redraw := true
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
## Vrai si Attaque a été appuyé pendant le coup en cours : le coup suivant du
## combo partira dès que possible (on peut taper vite sans perdre d'appui).
var chain_queued := false
## Vrai quand l'attaque en cours a déjà touché (un coup ne touche qu'une fois).
var attack_has_hit := false
## Nombre de coups portés d'affilée sans que l'adversaire puisse réagir.
var combo_hits := 0
var stun_frames := 0
var air_attack_used := false
## Coups donnés pendant ce saut.
var air_hits := 0
## Coups reçus en l'air depuis le lancer (jonglage).
var juggle_hits := 0
## Vrai quand la garde est basse (accroupie).
var guard_low := false
var buffered_attack := 0
var buffered_guard := 0
var buffered_special := 0
var buffered_ultimate := 0
var buffered_assist := 0
## Boutons « en plus » (optionnels, pour le tactile) : projection et coup bas en un appui.
var buffered_throw := 0
## Serment en cours : frames restantes pendant lesquelles on encaisse moins.
var oath_frames := 0
var buffered_low := false
## Vrai : maintenir Spécial charge l'énergie (un appui court lance le spécial).
## Faux (le joueur a un bouton Charge) : Spécial part dès l'appui, sans attendre.
var special_hold_charges := true
## Vrai si le dernier appui sur Spécial était accompagné de la direction avant.
var special_forward := false
## Vrai si le dernier appui sur Garde était accompagné de la direction avant (projection).
var guard_forward := false
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
## « attack », « guard_pressed », « ultimate », « assist », « throw », « special_2 »
## et « low_attack » = appui à cette frame ; les autres (dont « special » et
## « charge ») = touche maintenue.
var intent := {
	"left": false, "right": false, "jump": false, "crouch": false,
	"attack": false, "guard": false, "guard_pressed": false,
	"special": false, "ultimate": false, "assist": false,
	"throw": false, "special_2": false, "low_attack": false, "charge": false,
}

## L'apparence et les aides visuelles (fighter_view.gd).
@onready var view: FighterView = $View


func _ready() -> void:
	if data == null:
		push_error("Fighter : aucune fiche FighterData assignée dans l'Inspecteur.")
		return
	view.use_data(data)
	reset()


## Remet le combattant en début de manche (l'arène règle l'énergie).
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
	buffered_throw = 0
	buffered_low = false
	special_held_frames = 0
	parry_window = 0
	oath_frames = 0
	# Le soutien est disponible dès le début de chaque manche.
	assist_cooldown = 0
	modulate.a = 1.0
	_change_state(State.IDLE)
	refresh_view()


## Lit les commandes. Appelée à chaque frame, même pendant les arrêts sur image,
## pour ne perdre aucun appui.
func poll_input() -> void:
	if is_player:
		PlayerInput.read(intent)
	_read_special_button()
	if intent.special_2:
		# Bouton « Spécial 2 » : comme avant + Spécial, en un seul appui.
		special_forward = true
		buffered_special = INPUT_BUFFER_FRAMES
	if intent.throw:
		buffered_throw = INPUT_BUFFER_FRAMES
	if intent.low_attack:
		buffered_attack = INPUT_BUFFER_FRAMES
		buffered_low = true
	if intent.assist:
		buffered_assist = INPUT_BUFFER_FRAMES
	if intent.ultimate:
		buffered_ultimate = INPUT_BUFFER_FRAMES
	if intent.attack:
		buffered_attack = INPUT_BUFFER_FRAMES
	if intent.guard_pressed:
		buffered_guard = INPUT_BUFFER_FRAMES
		guard_forward = _input_direction() == facing
		parry_window = PARRY_WINDOW_FRAMES
	intent.attack = false
	intent.guard_pressed = false
	intent.ultimate = false
	intent.assist = false
	intent.throw = false
	intent.special_2 = false
	intent.low_attack = false


## Le bouton Spécial sert à deux choses : un appui court lance un coup spécial
## (au relâchement), un appui long charge l'énergie. Avec un bouton Charge à
## part (special_hold_charges faux), le spécial part dès l'appui.
func _read_special_button() -> void:
	if intent.special:
		special_held_frames += 1
		# La direction est lue au moment de l'appui : on la lâche souvent avant le bouton.
		if special_held_frames == 1:
			special_forward = _input_direction() == facing
			if not special_hold_charges:
				buffered_special = INPUT_BUFFER_FRAMES
	elif special_held_frames > 0 and not special_hold_charges:
		special_held_frames = 0
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
	buffered_throw = 0
	buffered_low = false


## Une frame de jeu.
func tick(delta: float) -> void:
	buffered_attack = maxi(0, buffered_attack - 1)
	if buffered_attack == 0:
		buffered_low = false
	buffered_guard = maxi(0, buffered_guard - 1)
	buffered_special = maxi(0, buffered_special - 1)
	buffered_throw = maxi(0, buffered_throw - 1)
	buffered_ultimate = maxi(0, buffered_ultimate - 1)
	buffered_assist = maxi(0, buffered_assist - 1)
	assist_cooldown = maxi(0, assist_cooldown - 1)
	parry_window = maxi(0, parry_window - 1)
	flash_frames = maxi(0, flash_frames - 1)
	oath_frames = maxi(0, oath_frames - 1)
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
		State.JUGGLE:
			_juggle_state()
		State.GETUP:
			_getup_state()
		State.DODGE:
			_dodge_state()
		State.CHARGE:
			_charge_state()

	velocity.y += GRAVITY * delta
	var was_in_air := not on_floor
	_move(delta)
	if was_in_air and on_floor:
		_on_landed()
	needs_redraw = true


## Avance selon la vitesse, sans traverser le sol ni les murs (qui arrêtent
## le mouvement dans leur direction).
func _move(delta: float) -> void:
	position += velocity * delta
	if position.x < WALL_LEFT or position.x > WALL_RIGHT:
		position.x = clampf(position.x, WALL_LEFT, WALL_RIGHT)
		velocity.x = 0.0
	on_floor = position.y >= floor_y
	if on_floor:
		position.y = floor_y
		velocity.y = minf(velocity.y, 0.0)


## Vrai quand les pieds touchent le sol.
func is_on_floor() -> bool:
	return on_floor


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
	if intent.charge or (special_hold_charges and special_held_frames >= CHARGE_THRESHOLD_FRAMES):
		velocity.x = 0
		_change_state(State.CHARGE)
		return
	# Projection : collé à l'adversaire, avant + Garde. Plus loin, Garde reste
	# une garde ou un contre parfait, même en avançant.
	var throw_asked := buffered_throw > 0 or (buffered_guard > 0 and guard_forward)
	if throw_asked and data.throw and _opponent_in_throw_range():
		buffered_guard = 0
		buffered_throw = 0
		parry_window = 0
		_start_attack(data.throw)
		return
	if _consume_attack():
		var low: bool = intent.crouch or buffered_low
		buffered_low = false
		if low:
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
		air_hits = 0
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


## En l'air : on garde son élan. Un coup par saut, et un 2e s'il a touché
## (enchaînement aérien, pour jongler).
func _jump_state() -> void:
	if current_attack:
		attack_frame += 1
		var chain_ok := attack_has_hit and air_hits < AIR_ATTACKS_PER_JUMP \
				and attack_frame > current_attack.startup + 2
		if chain_ok and _consume_attack():
			air_hits += 1
			_prepare_attack(data.air_attack)
	elif not air_attack_used and data.air_attack and _consume_attack():
		air_attack_used = true
		air_hits = 1
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
	# Serment : le bonus de défense commence à la fin de la préparation.
	if attack.guard_buff_frames > 0 and attack_frame == attack.startup:
		oath_frames = attack.guard_buff_frames
	var in_recovery := attack_frame > attack.startup + attack.active
	# Annulation : un coup du combo qui a touché (ou été paré) peut être
	# interrompu par un coup spécial. C'est la base des gros combos.
	if in_recovery and attack.energy_cost == 0 and attack_has_hit and buffered_special > 0 and _try_special():
		return
	# Un coup du combo qui a touché peut aussi s'annuler en ultime (barre pleine).
	if attack.energy_cost == 0 and attack_has_hit and buffered_ultimate > 0 and energy >= MAX_ENERGY and data.ultimate:
		buffered_ultimate = 0
		_start_special(data.ultimate)
		return
	# Enchaînement : un nouvel appui pendant le coup lance le coup suivant
	# du combo dès que le coup actuel a fini de pouvoir toucher. Un appui
	# arrivé trop tôt est gardé jusque-là.
	if _can_chain() and not in_recovery and not chain_queued and _consume_attack():
		chain_queued = true
	if in_recovery and _can_chain() and (chain_queued or _consume_attack()):
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


## Jonglé : on vole sans rien pouvoir faire ; en touchant le sol, on est à terre.
func _juggle_state() -> void:
	velocity.x *= 0.98


func _getup_state() -> void:
	stun_frames -= 1
	if stun_frames <= 0:
		_change_state(State.IDLE)


## Charger : immobile et sans défense, l'énergie monte tant que Spécial est maintenu.
func _charge_state() -> void:
	velocity.x = 0
	add_energy(CHARGE_RATE)
	var holding: bool = intent.charge or (special_hold_charges and special_held_frames > 0)
	if not holding or energy >= MAX_ENERGY:
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
	elif state == State.JUGGLE:
		juggle_hits = 0
		velocity.x = 0
		stun_frames = KNOCKDOWN_FRAMES
		_change_state(State.KNOCKDOWN)


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
	chain_queued = false
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
	return state not in [State.HITSTUN, State.KNOCKDOWN, State.GETUP, State.DODGE, State.CHARGE, State.JUGGLE]


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


func _opponent_in_throw_range() -> bool:
	return opponent != null and absf(opponent.global_position.x - global_position.x) <= THROW_RANGE


## Vrai si on peut être saisi : au sol, et ni sonné, ni à terre, ni en plein coup.
func _can_be_thrown() -> bool:
	return is_on_floor() and state in [State.IDLE, State.WALK, State.CROUCH, State.GUARD, State.CHARGE]


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
	return state not in [State.HITSTUN, State.KNOCKDOWN, State.JUGGLE]


## Zone de frappe actuelle, en coordonnées de l'arène. Vide si aucun coup ne peut toucher.
func get_hitbox_rect() -> Rect2:
	if current_attack == null or attack_has_hit:
		return Rect2()
	if not current_attack.is_active_frame(attack_frame):
		return Rect2()
	return attack_rect(current_attack)


## Zone où le combattant peut être touché. Vide s'il est intouchable.
func get_hurtbox_rect() -> Rect2:
	if state in [State.KNOCKDOWN, State.GETUP, State.DODGE]:
		return Rect2()
	# Trop jonglé : on retombe sans pouvoir être touché.
	if state == State.JUGGLE and juggle_hits >= MAX_JUGGLE_HITS:
		return Rect2()
	if current_attack and current_attack.invulnerable_startup and attack_frame <= current_attack.startup:
		return Rect2()
	var height := current_height()
	return Rect2(global_position + Vector2(-BODY_WIDTH / 2.0, -height), Vector2(BODY_WIDTH, height))


## Appelée par l'arène quand un coup de l'adversaire atteint ce combattant.
## Renvoie ce qui s'est passé : touché, paré ou contré.
## remote : le coup ne vient pas du corps de l'attaquant (projectile ou soutien).
func receive_attack(attack: AttackData, attacker: Fighter, remote := false) -> HitResult:
	if attack.is_throw:
		return _receive_throw(attack, attacker)
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


## Une projection traverse la garde et le contre parfait. On l'évite en étant en
## l'air ou déjà occupé, ou en projetant soi-même au même moment.
func _receive_throw(attack: AttackData, attacker: Fighter) -> HitResult:
	var throwing := current_attack != null and current_attack.is_throw 			and attack_frame <= current_attack.startup + current_attack.active
	if throwing:
		tech_throw(attacker)
		attacker.tech_throw(self)
		return HitResult.TECHED
	if not _can_be_thrown():
		return HitResult.MISSED
	_take_damage(attack, attacker)
	return HitResult.HIT


## Projection évitée : on est repoussé, sans dégâts.
func tech_throw(other: Fighter) -> void:
	current_attack = null
	combo_index = -1
	velocity.x = _direction_from(other) * THROW_TECH_PUSH
	stun_frames = THROW_TECH_FRAMES
	_flash(BLOCK_FLASH)
	_change_state(State.BLOCKSTUN)


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
	# Les longs combos font de moins en moins mal (combo_hits = coups déjà portés).
	var scaling := clampf(1.0 - COMBO_SCALING_STEP * maxi(0, attacker.combo_hits - 1), MIN_COMBO_SCALING, 1.0)
	var oath := OATH_DAMAGE_TAKEN if oath_frames > 0 else 1.0
	var damage := roundi(attack.damage * attacker.data.damage_multiplier() * data.defense_multiplier() * scaling * oath)
	health = maxi(1 if immortal else 0, health - damage)
	special_held_frames = 0
	# Seul un appui sur Garde PENDANT qu'on encaisse déclenche l'esquive : un contre
	# parfait tenté un peu trop tôt ne doit pas se transformer en esquive.
	buffered_guard = 0
	current_attack = null
	combo_index = -1
	_flash(HIT_FLASH)
	var direction := _direction_from(attacker)
	if health > 0 and (state == State.JUGGLE or not is_on_floor()):
		# Déjà en l'air : le coup relance (jonglage).
		juggle_hits += 1
		# Multiplications simples (pas de pow) : résultat identique sur tous les téléphones.
		var pop := JUGGLE_POP
		for i in juggle_hits - 1:
			pop *= JUGGLE_DECAY
		velocity = Vector2(direction * JUGGLE_PUSH, -maxf(pop, attack.launch))
		_change_state(State.JUGGLE)
	elif health > 0 and attack.launch > 0.0:
		# Coup lanceur : l'adversaire décolle et peut être jonglé.
		juggle_hits = 0
		velocity = Vector2(direction * attack.pushback * 0.3, -attack.launch)
		_change_state(State.JUGGLE)
	elif attack.knockdown or health == 0:
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


func current_height() -> float:
	if _is_low():
		return CROUCH_HEIGHT
	if state == State.KNOCKDOWN or state == State.GETUP:
		return CROUCH_HEIGHT * 0.6
	if not is_on_floor():
		return AIR_HEIGHT
	return STAND_HEIGHT


## Rectangle d'une attaque, retourné selon le côté où regarde le combattant.
func attack_rect(attack: AttackData) -> Rect2:
	var box := attack.hitbox
	var x := box.position.x if facing == 1 else -box.position.x - box.size.x
	return Rect2(global_position + Vector2(x, box.position.y), box.size)


## L'affichage suit l'état du combattant (voir fighter_view.gd).
func refresh_view() -> void:
	view.refresh()
	needs_redraw = false
