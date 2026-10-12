extends "res://tests/test_base.gd"
## Tests des sensations : effets d'impact, tremblement d'écran, sons, menu pause.


func _initialize() -> void:
	await start_arena()
	var M = fight.DummyMode

	section("Sons")
	var missing := []
	for sound in SoundBank.SOUNDS:
		if not fight.sounds._streams.has(sound):
			missing.append(sound)
	check("les 12 sons sont chargés", missing.is_empty(), "manquants : %s" % str(missing))

	section("Effets d'impact")
	await setup(280, 305, M.STAND)
	var before: int = fight.effects.spawned
	await run(4, {}, {"attack": [0]})
	await run(10)
	check("un coup qui touche fait des étincelles", fight.effects.spawned > before)

	await setup(287, 310, M.STAND)
	var shook := false
	for i in 60:
		await run(1, {}, {"attack": [0]} if i % 6 == 0 else {})
		shook = shook or fight.camera.offset != Vector2.ZERO
	check("le 3e coup du combo (lourd) fait trembler l'écran", shook)
	await run(30)
	check("l'écran revient en place", fight.camera.offset == Vector2.ZERO)

	await setup(280, 305, M.GUARD_HIGH)
	before = fight.effects.spawned
	await run(30, {}, {"attack": [0]})
	check("un coup paré fait des étincelles bleues", fight.effects.spawned > before)

	await setup(280, 305, M.ATTACK)
	fight.frame_count = 79
	before = fight.effects.spawned
	await run(30, {}, {"guard_pressed": [4]})
	check("un contre parfait fait son effet", fight.effects.spawned > before)

	section("Menu pause")
	var x_before := d.position.x
	fight.pause_menu.set_paused(true)
	check("la pause affiche le menu", paused and fight.pause_menu.visible)
	fight.dummy_mode = M.ATTACK
	for i in 30:
		await process_frame
	check("pendant la pause, le combat est figé", d.position.x == x_before and d.state != Fighter.State.ATTACK)
	fight.pause_menu.set_paused(false)
	check("reprendre enlève la pause", not paused and not fight.pause_menu.visible)

	fight.pause_menu.set_paused(true)
	fight.pause_menu.mode_button.pressed.emit()
	await run(2)
	check("le menu change de mode (entraînement → combat)", not fight.training and not paused)
	fight.pause_menu.set_paused(true)
	fight.pause_menu.restart_button.pressed.emit()
	await run(2)
	check("le menu relance le combat", fight.phase == fight.Phase.INTRO and not paused)

	finish()
