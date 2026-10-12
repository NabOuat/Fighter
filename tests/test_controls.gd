extends "res://tests/test_base.gd"
## Tests des boutons « en plus » (saisie, spécial 2, coup bas, charge), des
## repères de coups (▼ bas, ▲ haut, main = projection) et des dispositions
## droitier / gaucher.

var gs


## Appuie sur une action pendant une frame, comme un doigt sur un bouton tactile.
func tap(action: String, frames := 1) -> void:
	Input.action_press(action)
	for i in frames:
		await physics_frame
	Input.action_release(action)
	await physics_frame


func _initialize() -> void:
	gs = root.get_node("GameState")
	await start_arena()
	var M = fight.tools.DummyMode

	section("Boutons en plus")
	p.is_player = true
	await setup(280, 305, M.GUARD_HIGH)
	await tap("throw")
	await run(30)
	check("Saisie : une projection en un seul appui", d.health < 1000 and d.state == Fighter.State.KNOCKDOWN, "vie %d" % d.health)

	await setup(200, 300, M.STAND)
	await tap("throw")
	check("Saisie de loin : rien ne se passe", p.current_attack == null)

	await setup(280, 305, M.STAND)
	await tap("low_attack")
	check("Coup bas en un seul appui", p.current_attack == p.data.low_attack)
	await run(30)

	await setup(200, 270, M.STAND)
	await tap("special_2")
	check("Spécial 2 en un seul appui", p.current_attack == p.data.special_2)
	await run(40)

	await setup(150, 400, M.STAND, 0.0)
	p.special_hold_charges = false
	Input.action_press("charge")
	for i in 40:
		await physics_frame
	check("Charge : maintenir le bouton charge l'énergie", p.state == Fighter.State.CHARGE and p.energy > 30.0, "%s, énergie %.0f" % [state_name(p), p.energy])
	Input.action_release("charge")
	await run(2)
	check("Charge : lâcher arrête la charge", p.state != Fighter.State.CHARGE)

	await setup(150, 400, M.STAND, 400.0)
	p.special_hold_charges = false
	Input.action_press("special")
	for i in 16:
		await physics_frame
	check("avec le bouton Charge, Spécial part dès l'appui (sans le lâcher)", fight.projectiles.size() == 1 and p.state != Fighter.State.CHARGE)
	for i in 30:
		await physics_frame
	check("et le maintenir ne charge plus", p.state != Fighter.State.CHARGE)
	Input.action_release("special")
	p.special_hold_charges = true
	await run(60)
	p.is_player = false

	section("Repères des coups")
	await setup(280, 305, M.STAND)
	await run(2, {"crouch": true}, {"attack": [0]})
	var shown: AttackData = p.view.telegraphed_attack()
	check("un coup bas en préparation montre son repère (bas)", shown == p.data.low_attack and shown.hit_level == AttackData.HitLevel.LOW)
	await run(30)
	check("plus de repère une fois le coup fini", p.view.telegraphed_attack() == null)

	await setup(150, 400, M.STAND, 400.0)
	await run(3, {"special": true})
	check("un spécial à projectile n'a pas de repère sur le corps", p.view.telegraphed_attack() == null)
	await run(60)

	await setup(280, 305, M.STAND)
	await run(1, {"right": true}, {"guard_pressed": [0]})
	check("une projection montre son repère (main)", p.view.telegraphed_attack() != null and p.view.telegraphed_attack().is_throw)
	await run(40)

	section("Boutons tactiles")
	var controls = fight.touch_controls
	check("les boutons en plus sont cachés au départ", not controls.get_node("Throw").visible and not controls.get_node("Charge").visible)
	gs.extra_buttons["Throw"] = true
	controls.apply_saved_layout()
	check("on peut les afficher dans les réglages", controls.get_node("Throw").visible)
	var screen: Vector2 = controls.screen_size()
	var left: Dictionary = controls.preset_layout(true)
	var right: Dictionary = controls.preset_layout(false)
	check("disposition gaucher : le joystick passe à droite", left.Joystick.position.x > 0.5 and right.Joystick.position.x < 0.5)
	check("disposition gaucher : l'attaque passe à gauche", left.Attack.position.x < 0.5)
	check("disposition gaucher : en miroir exact", is_equal_approx(left.Attack.position.x + right.Attack.position.x, 1.0))
	controls.apply_layout(left, 0.8)
	var joystick: TouchJoystick = controls.get_node("Joystick")
	check("le joystick à droite se prend à droite", joystick.can_grab(Vector2(screen.x - 60, 212)) and not joystick.can_grab(Vector2(60, 212)))
	gs.extra_buttons["Throw"] = false
	controls.apply_saved_layout()

	finish()
