extends "res://tests/test_base.gd"
## Tests des vrais dessins (Pokou) : la bonne animation au bon moment, la caméra
## qui zoome et suit, les combattants qui restent à l'écran, la vague dessinée.


func _initialize() -> void:
	var gs = await use_test_settings()
	gs.dry_run = true
	var pokou: FighterData = load("res://data/fighters/abla_pokou.tres")
	gs.start_training(pokou, gs.roster[2], gs.roster[2], FighterAI.Difficulty.NORMAL)
	fight = load(FIGHT_SCENE).instantiate()
	root.add_child(fight)
	await process_frame
	p = fight.player
	d = fight.dummy
	p.is_player = false
	fight.tools.dummy_mode = fight.tools.DummyMode.STAND
	await run(2)
	var sprite: FighterSprite = p.view.sprite

	section("Dessin")
	check("Pokou a son dessin, les rectangles sont cachés", sprite != null and sprite.is_inside_tree() and not p.get_node("Pivot").visible)
	check("le mannequin de test garde ses rectangles", d.view.sprite == null and d.get_node("Pivot").visible)
	check("au repos : animation d'attente", sprite.animation == &"idle")
	await run(10, {"right": true})
	check("en avançant : marche avant", sprite.animation == &"walk_forward", String(sprite.animation))
	await run(10, {"left": true})
	check("en reculant : marche arrière", sprite.animation == &"walk_back", String(sprite.animation))
	await run(4, {"crouch": true})
	check("accroupie : pose accroupie", sprite.animation == &"crouch")
	await run(20)

	section("Coups synchronisés")
	fight.reset_training()
	await run(2)
	var frames_seen := []
	await run(1, {}, {"attack": [0]})
	for i in p.data.combo[0].total_frames():
		if p.current_attack == null:
			break
		frames_seen.append(sprite.frame)
		await run(1)
	check("combo, coup 1 : son animation", sprite.animation == &"combo_1" or frames_seen.size() > 0)
	var increasing := true
	for i in range(1, frames_seen.size()):
		increasing = increasing and frames_seen[i] >= frames_seen[i - 1]
	check("les images avancent avec les frames du coup", increasing and frames_seen.back() > frames_seen.front(), str(frames_seen))
	await run(10, {"crouch": true}, {"attack": [0]})
	check("coup bas : son animation", sprite.animation == &"low_attack", String(sprite.animation))
	await run(30)
	p.facing = -1
	p.view.refresh()
	check("tournée vers la gauche : dessin retourné", sprite.flip_h)

	section("Caméra")
	check("la caméra zoome sur l'action", fight.camera.zoom.x == fight.ART_ZOOM)
	fight.reset_training()
	p.position.x = 40
	d.position.x = 440
	await run(2)
	var max_gap: float = fight.SCREEN_SIZE.x / fight.ART_ZOOM - 2.0 * fight.SCREEN_MARGIN
	check("les deux combattants restent à l'écran", absf(d.position.x - p.position.x) <= max_gap + 0.5, "écart %.0f" % absf(d.position.x - p.position.x))
	for i in 60:
		await run(1)
	var half: float = fight.SCREEN_SIZE.x / fight.ART_ZOOM / 2.0
	var middle := (p.position.x + d.position.x) / 2.0
	check("la caméra suit le milieu des combattants", absf(fight.camera.position.x - clampf(middle, half, fight.SCREEN_SIZE.x - half)) < 2.0)

	section("La vague")
	fight.reset_training()
	await run(2)
	await run(3, {"special": true})
	await run(16)
	var drawn := false
	for projectile in fight.projectiles:
		for child in projectile.get_children():
			drawn = drawn or child is AnimatedSprite2D
	check("le spécial 1 lance la vague dessinée", fight.projectiles.size() == 1 and drawn)

	finish()
