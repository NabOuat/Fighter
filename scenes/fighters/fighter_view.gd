class_name FighterView
extends Node2D
## L'apparence d'un combattant (pour l'instant des rectangles de couleur) et
## les aides visuelles qui rendent le combat lisible :
## - un contour qui s'allume pendant qu'un coup se prépare (on le voit venir) ;
## - un repère qui dit comment parer le coup : ▼ bleu = coup BAS (garde
##   accroupie), ▲ orange = coup HAUT (garde debout), main violette = PROJECTION
##   (ne se pare pas : sauter ou projeter en même temps).
##
## Les repères sont dessinés devant tout (z_index du nœud View), même devant l'adversaire.
## Il ne décide de rien : il lit l'état du combattant (son parent) à chaque frame.
## Quand les vrais sprites arriveront, ils remplaceront les rectangles ici ;
## les repères resteront (désactivables dans les réglages).

const LOW_COLOR := Color(0.35, 0.75, 1.0)
const HIGH_COLOR := Color(1.0, 0.6, 0.2)
const THROW_COLOR := Color(0.8, 0.45, 1.0)
const STARTUP_COLOR := Color(1.0, 1.0, 0.85)
## Taille des repères, en pixels.
const MARKER_SIZE := 5.0

@onready var fighter: Fighter = get_parent()
@onready var pivot: Node2D = $"../Pivot"
@onready var body: ColorRect = $"../Pivot/Body"
@onready var front: ColorRect = $"../Pivot/Front"
@onready var arm: ColorRect = $"../Arm"
@onready var aura: ColorRect = $"../Aura"
@onready var hurtbox_view: ColorRect = $"../HurtboxView"
@onready var hitbox_view: ColorRect = $"../HitboxView"


## Met les rectangles et les repères à jour. Appelée par le combattant à chaque frame.
func refresh() -> void:
	var data := fighter.data
	var attack := fighter.current_attack
	var frame := fighter.attack_frame
	var height := fighter.current_height()
	pivot.scale.x = fighter.facing
	body.size = Vector2(Fighter.BODY_WIDTH, height)
	body.position = Vector2(-Fighter.BODY_WIDTH / 2.0, -height)
	body.color = fighter.flash_color if fighter.flash_frames > 0 else data.placeholder_color
	front.position.y = -height + 6
	front.visible = fighter.state != Fighter.State.KNOCKDOWN
	# Pendant l'esquive, le combattant devient presque transparent.
	fighter.modulate.a = 0.3 if fighter.state == Fighter.State.DODGE else 1.0

	hurtbox_view.visible = fighter.show_boxes and fighter.get_hurtbox_rect().has_area()
	hurtbox_view.size = body.size
	hurtbox_view.position = body.position

	var attacking := attack != null and frame <= attack.startup + attack.active
	hitbox_view.visible = fighter.show_boxes and attacking and attack.is_active_frame(frame)
	if attacking:
		# Le « bras » montre le coup pendant sa préparation et son temps actif.
		var rect := fighter.attack_rect(attack)
		rect.position -= fighter.global_position
		arm.visible = frame >= attack.startup / 2.0
		arm.color = data.placeholder_color.darkened(0.2)
		arm.position = rect.position
		arm.size = rect.size
		hitbox_view.position = rect.position
		hitbox_view.size = rect.size
	elif fighter.state in [Fighter.State.GUARD, Fighter.State.BLOCKSTUN]:
		# En garde, le « bras » devient un bouclier levé devant le corps.
		arm.visible = true
		arm.color = data.placeholder_color.darkened(0.45)
		arm.size = Vector2(5, height * 0.7)
		arm.position = Vector2(fighter.facing * (Fighter.BODY_WIDTH / 2.0) - (5 if fighter.facing == 1 else 0) + fighter.facing * 2, -height + 2)
	else:
		arm.visible = false

	# L'aura : bleue quand on charge, dorée pendant la préparation de l'ultime.
	var ultimate_startup := attack != null and attack.is_ultimate and frame <= attack.startup
	aura.visible = fighter.state == Fighter.State.CHARGE or ultimate_startup
	if aura.visible:
		var pulse := 0.25 + 0.15 * sin(Time.get_ticks_msec() / 60.0)
		var aura_color := Color(1.0, 0.85, 0.35) if ultimate_startup else Color(0.3, 0.85, 1.0)
		aura.color = Color(aura_color, pulse)
		aura.size = body.size + Vector2(12, 10)
		aura.position = body.position - Vector2(6, 10)
	queue_redraw()


## Le coup en préparation ou actif, s'il faut le montrer (sinon null).
func telegraphed_attack() -> AttackData:
	var attack := fighter.current_attack
	if attack == null or fighter.attack_has_hit:
		return null
	if fighter.attack_frame > attack.startup + attack.active:
		return null
	# Un spécial qui ne frappe qu'avec son projectile n'a rien à montrer sur le corps.
	if not attack.hitbox.has_area():
		return null
	return attack


func _draw() -> void:
	if not fighter.show_markers:
		return
	var attack := telegraphed_attack()
	if attack == null:
		return
	var height := fighter.current_height()
	var in_startup := fighter.attack_frame <= attack.startup
	if in_startup:
		# Contour lumineux : le coup se prépare.
		var outline := Rect2(-Fighter.BODY_WIDTH / 2.0 - 1, -height - 1, Fighter.BODY_WIDTH + 2, height + 2)
		draw_rect(outline, Color(STARTUP_COLOR, 0.8), false, 1.0)
	var ahead := fighter.facing * (Fighter.BODY_WIDTH / 2.0 + 6.0)
	if attack.is_throw:
		_draw_hand(Vector2(ahead, -height * 0.6), THROW_COLOR)
	elif attack.hit_level == AttackData.HitLevel.LOW:
		_draw_arrow(Vector2(ahead, -4), true, LOW_COLOR)
	elif attack.hit_level == AttackData.HitLevel.HIGH:
		_draw_arrow(Vector2(0, -height - 8), false, HIGH_COLOR)


## Un chevron plein : vers le bas (coup bas) ou vers le haut (coup haut).
func _draw_arrow(at: Vector2, down: bool, color: Color) -> void:
	var s := MARKER_SIZE
	var tip := at + Vector2(0, s if down else -s)
	var points := PackedVector2Array([at + Vector2(-s, -s if down else s), at + Vector2(s, -s if down else s), tip])
	draw_colored_polygon(points, color)
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[0]]), Color(0, 0, 0, 0.6), 1.0)


## Une « main » qui saisit : un crochet ouvert vers l'adversaire.
func _draw_hand(at: Vector2, color: Color) -> void:
	var s := MARKER_SIZE
	var d := float(fighter.facing)
	draw_line(at + Vector2(-d * s, -s), at + Vector2(d * s, -s), color, 2.0)
	draw_line(at + Vector2(-d * s, -s), at + Vector2(-d * s, s), color, 2.0)
	draw_line(at + Vector2(-d * s, s), at + Vector2(d * s, s), color, 2.0)
