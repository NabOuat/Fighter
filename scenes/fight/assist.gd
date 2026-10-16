class_name Assist
extends Node2D
## Un personnage de soutien en action : il apparaît, agit une fois, puis repart.
##
## L'arène le crée quand un combattant l'appelle, le fait avancer image par
## image et vérifie ses coups ou son bouclier.

## Émis quand une attaque de soutien lance un projectile.
signal projectile_requested(data: ProjectileData, caller: Fighter, origin: Vector2, direction: int)

## Distance par rapport à celui qui appelle : derrière pour attaquer ou soigner,
## devant pour protéger.
const OFFSET_BEHIND := -22.0
const OFFSET_FRONT := 26.0
const BODY_SIZE := Vector2(20, 50)
## Le bouclier commence juste devant le corps de celui qui appelle.
const BARRIER_GAP := 13.0

## Ce que le rollback sauvegarde (celui qui appelle est sauvegardé à part, par l'arène).
const STATE_VARS := ["data", "supporter", "position", "facing", "frame", "hit_done",
		"barrier_flash", "floor_level", "_heal_left"]

var data: AssistData
## Celui qui a appelé le soutien (c'est à lui que reviennent les coups et le soin).
var caller: Fighter
var supporter: FighterData
var facing := 1
var frame := 0
var hit_done := false
## Le bouclier a-t-il déjà arrêté quelque chose (pour le faire clignoter) ?
var barrier_flash := 0
## Hauteur du sol, pour poser le bouclier même si celui qui appelle saute.
var floor_level := 0.0
var _heal_left := 0.0

var _body: ColorRect
var _effect: ColorRect


## left / right : limites de l'arène, pour que le soutien apparaisse toujours à l'écran.
func summon(assist_data: AssistData, who: Fighter, floor_y: float, left: float, right: float) -> void:
	data = assist_data
	caller = who
	supporter = who.support
	facing = who.facing
	_heal_left = data.heal_amount
	floor_level = floor_y
	var offset := OFFSET_FRONT if data.kind == AssistData.Kind.PROTECT else OFFSET_BEHIND
	position = Vector2(clampf(who.global_position.x + facing * offset, left, right), floor_y)

	_body = ColorRect.new()
	_body.size = BODY_SIZE
	_body.position = Vector2(-BODY_SIZE.x / 2.0, -BODY_SIZE.y)
	_body.color = supporter.placeholder_color
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body)
	_effect = ColorRect.new()
	_effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effect.visible = false
	add_child(_effect)
	_update_visuals()


func get_state() -> Dictionary:
	var saved := {}
	for key in STATE_VARS:
		saved[key] = get(key)
	return saved


## Un soutien recréé par le rollback reprend exactement là où il en était.
func set_state(saved: Dictionary) -> void:
	for key in STATE_VARS:
		set(key, saved[key])
	_update_visuals()


## Une frame d'action.
func tick(delta: float) -> void:
	frame += 1
	barrier_flash = maxi(0, barrier_flash - 1)
	var action_frame := frame - data.appear_frames
	if action_frame >= 1 and action_frame <= data.action_frames():
		match data.kind:
			AssistData.Kind.ATTACK:
				_attack_tick(action_frame, delta)
			AssistData.Kind.HEAL:
				# Le soin est réparti sur toute la durée de l'action.
				var amount := float(data.heal_amount) / data.active_frames
				_heal_left -= amount
				caller.heal(amount)
	_update_visuals()


func _attack_tick(action_frame: int, delta: float) -> void:
	var attack := data.attack
	if attack.dash_speed > 0.0 and attack.is_active_frame(action_frame):
		position.x += facing * attack.dash_speed * delta
	if attack.projectile and action_frame == attack.startup:
		var origin := position + Vector2(attack.projectile.spawn_offset.x * facing, attack.projectile.spawn_offset.y)
		projectile_requested.emit(attack.projectile, caller, origin, facing)


func is_finished() -> bool:
	return frame >= data.total_frames()


## Zone de frappe de l'attaque de soutien. Vide si elle ne peut pas toucher.
func get_hitbox_rect() -> Rect2:
	if data.kind != AssistData.Kind.ATTACK or hit_done or data.attack == null:
		return Rect2()
	var action_frame := frame - data.appear_frames
	if not data.attack.is_active_frame(action_frame) or not data.attack.hitbox.has_area():
		return Rect2()
	var box := data.attack.hitbox
	var x := box.position.x if facing == 1 else -box.position.x - box.size.x
	return Rect2(global_position + Vector2(x, box.position.y), box.size)


## Bouclier de protection, collé devant celui qui appelle (il le suit s'il bouge).
## Vide en dehors de l'action.
func get_barrier_rect() -> Rect2:
	if data.kind != AssistData.Kind.PROTECT:
		return Rect2()
	var action_frame := frame - data.appear_frames
	if action_frame < 1 or action_frame > data.active_frames:
		return Rect2()
	var size := data.barrier_size
	var side := caller.facing
	var x := BARRIER_GAP if side == 1 else -BARRIER_GAP - size.x
	return Rect2(Vector2(caller.global_position.x + x, floor_level - size.y), size)


func _update_visuals() -> void:
	# Apparition et départ en fondu.
	var alpha := 0.85
	if frame <= data.appear_frames:
		alpha = 0.85 * frame / data.appear_frames
	elif frame > data.total_frames() - data.leave_frames:
		alpha = 0.85 * (data.total_frames() - frame) / data.leave_frames
	_body.modulate.a = alpha

	var barrier := get_barrier_rect()
	var hitbox := get_hitbox_rect()
	var healing := data.kind == AssistData.Kind.HEAL and _heal_left > 0.0 and frame > data.appear_frames
	_effect.visible = barrier.has_area() or hitbox.has_area() or healing
	if barrier.has_area():
		_effect.color = Color(1, 1, 1, 0.8) if barrier_flash > 0 else Color(0.4, 0.9, 1.0, 0.55)
		_set_effect_rect(barrier)
	elif hitbox.has_area():
		_effect.color = Color(1, 0.3, 0.2, 0.5)
		_set_effect_rect(hitbox)
	elif healing:
		_effect.color = Color(0.4, 1.0, 0.5, 0.35)
		var target := Rect2(caller.global_position + Vector2(-16, -64), Vector2(32, 64))
		_set_effect_rect(target)


func _set_effect_rect(rect: Rect2) -> void:
	_effect.position = rect.position - global_position
	_effect.size = rect.size
