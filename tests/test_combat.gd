extends "res://tests/test_base.gd"
## Tests du combat : coups (étape 1), défense (étape 2), énergie et spéciaux (étape 3).
## Les valeurs attendues viennent des combattants de test A (joueur) et B (mannequin).


func _initialize() -> void:
	await start_arena()
	var M = fight.DummyMode

	section("Étape 1 : toucher et encaisser")
	await setup(287, 310, M.STAND)
	var best_combo := 0
	var knocked_down := false
	for i in 60:
		await run(1, {}, {"attack": [0]} if i % 6 == 0 else {})
		best_combo = maxi(best_combo, p.combo_hits)
		knocked_down = knocked_down or d.state == Fighter.State.KNOCKDOWN
	check("le combo enchaîne 3 coups", best_combo == 3, "meilleur combo %d" % best_combo)
	check("le 3e coup projette au sol", knocked_down)
	check("dégâts du combo (142)", d.health == 858, "vie %d" % d.health)

	await setup(280, 305, M.STAND)
	await run(25, {"crouch": true}, {"attack": [2]})
	check("le coup bas touche (46)", d.health == 954, "vie %d" % d.health)

	await setup(250, 300, M.STAND)
	for i in 50:
		var hold := {"jump": true, "right": true} if i < 30 else {}
		await run(1, hold, {"attack": [0]} if i == 22 else {})
	check("le coup sauté touche (55)", d.health == 945, "vie %d" % d.health)

	section("Étape 2 : défense")
	await setup(280, 305, M.GUARD_HIGH)
	await run(60, {}, {"attack": [0, 6, 12]})
	check("garde haute : le combo est paré", d.health == 1000, "vie %d" % d.health)
	await run(40, {"crouch": true}, {"attack": [0]})
	check("garde haute : le coup bas passe", d.health < 1000, "vie %d" % d.health)

	await setup(280, 305, M.GUARD_LOW)
	await run(40, {"crouch": true}, {"attack": [2]})
	check("garde basse : le coup bas est paré", d.health == 1000, "vie %d" % d.health)

	await setup(200, 300, M.GUARD_LOW)
	for i in 75:
		var hold := {"jump": true, "right": true} if i < 45 else {}
		await run(1, hold, {"attack": [0]} if i == 30 else {})
	check("garde basse : le coup sauté passe", d.health < 1000, "vie %d" % d.health)

	await setup(280, 305, M.ATTACK)
	await run(100, {"left": true})
	check("reculer pare le combo du mannequin", p.health == 1000, "vie %d" % p.health)

	await setup(280, 305, M.ATTACK)
	fight.frame_count = 79
	await run(30, {}, {"guard_pressed": [4]})
	check("contre parfait : le joueur n'est pas touché", p.health == 1000, "vie %d" % p.health)
	check("contre parfait : l'attaquant est sans défense", d.state == Fighter.State.HITSTUN, state_name(d))

	await setup(280, 305, M.ATTACK)
	fight.frame_count = 79
	await run(8)
	var dodged := false
	for i in 30:
		await run(1, {}, {"guard_pressed": [0]} if i == 1 else {})
		dodged = dodged or p.state == Fighter.State.DODGE
	check("esquive mystique déclenchée en encaissant", dodged)
	check("l'esquive coûte 1 segment", int(p.energy) == 300, "énergie %d" % int(p.energy))
	check("l'esquive fait réapparaître dans le dos", p.position.x > d.position.x, "joueur %.0f, mannequin %.0f" % [p.position.x, d.position.x])

	await setup(280, 305, M.ATTACK)
	fight.frame_count = 74
	var accidental_dodge := false
	for i in 24:
		await run(1, {}, {"guard_pressed": [0]} if i == 4 else {})
		accidental_dodge = accidental_dodge or p.state == Fighter.State.DODGE
	check("contre tenté trop tôt : pas d'esquive involontaire", not accidental_dodge and int(p.energy) == 400, "énergie %d" % int(p.energy))

	section("Étape 3 : énergie et coups spéciaux")
	await setup(170, 310, M.STAND, 0.0)
	await run(30, {"special": true})
	check("maintenir Spécial charge l'énergie", p.state == Fighter.State.CHARGE and p.energy > 25 and p.energy < 35, "%s, énergie %.1f" % [state_name(p), p.energy])

	await setup(170, 310, M.STAND)
	await run(3, {"special": true})
	await run(16)
	check("spécial 1 : un projectile part", fight.projectiles.size() == 1)
	check("spécial 1 : coûte 1 segment", int(p.energy) == 300, "énergie %d" % int(p.energy))
	await run(60)
	check("le projectile touche (74)", d.health == 926, "vie %d" % d.health)
	check("le projectile ne rapporte pas d'énergie", int(p.energy) == 300, "énergie %d" % int(p.energy))

	await setup(170, 310, M.GUARD_HIGH)
	await run(3, {"special": true})
	await run(80)
	check("projectile paré : usure de 15", d.health == 985, "vie %d" % d.health)

	await setup(150, 330, M.PROJECTILE)
	fight.frame_count = 79
	await run(3, {"special": true})
	var both_seen := false
	for i in 60:
		await run(1)
		both_seen = both_seen or fight.projectiles.size() == 2
	check("deux projectiles qui se croisent s'annulent", both_seen and fight.projectiles.is_empty() and p.health == 1000 and d.health == 1000)

	await setup(200, 270, M.STAND)
	await run(3, {"special": true, "right": true})
	await run(30)
	check("spécial 2 (avant + Spécial) : touche et projette", d.health == 917 and d.state == Fighter.State.KNOCKDOWN, "vie %d, %s" % [d.health, state_name(d)])

	await setup(280, 305, M.STAND)
	await run(4, {}, {"attack": [0]})
	await run(5, {"special": true})
	var cancelled := false
	for i in 25:
		await run(1)
		cancelled = cancelled or p.current_attack == p.data.special_1
	check("un coup du combo s'annule en spécial", cancelled)

	await setup(250, 290, M.STAND)
	await run(2, {}, {"ultimate": [0]})
	check("ultime : le combat se fige et s'assombrit", fight.ultimate_freeze > 0 and fight.dim.visible)
	await run(80)
	check("ultime : touche (276) et projette", d.health == 724 and d.state == Fighter.State.KNOCKDOWN, "vie %d, %s" % [d.health, state_name(d)])
	check("ultime : vide la barre", int(p.energy) == 0, "énergie %d" % int(p.energy))

	await setup(170, 310, M.STAND, 50.0)
	await run(3, {"special": true})
	await run(16)
	check("sans énergie, aucun spécial ne part", fight.projectiles.is_empty() and int(p.energy) == 50)

	await setup(150, 330, M.PROJECTILE, 0.0)
	fight.frame_count = 79
	var parried := false
	for i in 90:
		var near := false
		for projectile in fight.projectiles:
			if projectile.shooter == d and absf(projectile.global_position.x - p.global_position.x) < 26:
				near = true
		await run(1, {}, {"guard_pressed": [0]} if near and not parried else {})
		parried = parried or (fight.popup_label.visible and fight.popup_label.text == "FIGHT_PARRY")
	check("contrer un projectile n'étourdit pas le lanceur", parried and d.state != Fighter.State.HITSTUN and p.health == 1000, "%s, vie %d" % [state_name(d), p.health])

	finish()
