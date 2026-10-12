extends "res://tests/test_base.gd"
## Tests du soutien (étape 4). Soutiens de test : 0 = A attaque, 1 = B bouclier, 2 = C soin.


func _initialize() -> void:
	await start_arena()
	var M = fight.tools.DummyMode

	section("Appel et recharge")
	await setup(200, 300, M.STAND, 400.0, 0)
	await run(2, {}, {"assist": [0]})
	check("le soutien apparaît", fight.assists.size() == 1)
	check("la recharge démarre (15 s)", p.assist_cooldown > 890, "recharge %d" % p.assist_cooldown)
	await run(80)
	check("le soutien attaque touche (55)", d.health == 945, "vie %d" % d.health)
	check("le soutien ne rapporte pas d'énergie", int(p.energy) == 400, "énergie %d" % int(p.energy))
	check("le soutien repart", fight.assists.is_empty() and not p.assist_active)
	await run(2, {}, {"assist": [0]})
	check("impossible de le rappeler pendant la recharge", fight.assists.is_empty())

	await setup(280, 305, M.STAND, 400.0, 0)
	await run(3, {}, {"attack": [0]})
	await run(1, {}, {"assist": [0]})
	var best := 0
	for i in 60:
		await run(1)
		best = maxi(best, p.combo_hits)
	check("le soutien prolonge un combo", best >= 2, "meilleur combo %d" % best)

	section("Bouclier")
	await setup(150, 330, M.PROJECTILE, 400.0, 1)
	fight.tools.frame_count = 79
	var called := false
	for i in 90:
		var near := false
		for projectile in fight.projectiles:
			if projectile.shooter == d and absf(projectile.global_position.x - p.global_position.x) < 70:
				near = true
		await run(1, {}, {"assist": [0]} if near and not called else {})
		called = called or near
	check("le bouclier arrête un projectile", p.health == 1000 and fight.projectiles.is_empty(), "vie %d" % p.health)

	await setup(280, 305, M.STAND, 400.0, 1)
	await run(2, {}, {"assist": [0]})
	await run(8)
	fight.tools.dummy_mode = M.ATTACK
	fight.tools.frame_count = 79
	await run(40)
	check("le bouclier arrête un combo, même collé à l'adversaire", p.health == 1000, "vie %d" % p.health)

	section("Soin et règles")
	await setup(200, 300, M.STAND, 400.0, 2)
	p.health = 700
	await run(2, {}, {"assist": [0]})
	await run(90)
	check("le soin rend 100 points de vie", p.health == 800, "vie %d" % p.health)

	await setup(200, 300, M.GUARD_HIGH, 400.0, 0)
	await run(2, {}, {"assist": [0]})
	await run(80)
	check("l'adversaire peut parer le soutien", d.health == 1000, "vie %d" % d.health)

	await setup(280, 305, M.ATTACK, 400.0, 0)
	fight.tools.frame_count = 79
	var tried := false
	for i in 30:
		await run(1, {}, {"assist": [0]} if p.state == Fighter.State.HITSTUN and not tried else {})
		if p.state == Fighter.State.HITSTUN and not tried:
			tried = true
			await run(1)
			check("impossible d'appeler le soutien en encaissant", fight.assists.is_empty())

	await setup(14, 200, M.STAND, 400.0, 0)
	await run(2, {}, {"assist": [0]})
	check("le soutien reste dans l'arène près d'un mur", fight.assists.size() == 1 and fight.assists[0].position.x >= 12.0)

	# Un soutien qui lance un projectile (comme la lance de Sékou) ne doit pas
	# empêcher le combattant de lancer le sien.
	var spear_support: FighterData = fight.tools.TEST_SUPPORTS[0].duplicate(true)
	var spear := AssistData.new()
	spear.kind = AssistData.Kind.ATTACK
	var throw := AttackData.new()
	throw.startup = 6
	throw.active = 1
	throw.recovery = 12
	throw.projectile = fight.tools.TEST_SUPPORTS[0].special_1.projectile
	spear.attack = throw
	spear_support.assist = spear
	await setup(120, 400, M.STAND, 400.0, 0)
	p.support = spear_support
	await run(2, {}, {"assist": [0]})
	await run(20)
	await run(3, {"special": true})
	await run(16)
	check("projectile du soutien et projectile du joueur en même temps", fight.projectiles.size() == 2, "%d projectiles" % fight.projectiles.size())
	await run(120)
	check("le compteur de projectiles revient à zéro", p.active_projectiles == 0)

	fight.tools.dummy_mode = M.ASSIST
	fight.tools.frame_count = 79
	await run(3)
	check("le mannequin appelle son soutien", fight.assists.size() >= 1)
	fight._reset_training()
	await run(1)
	check("la remise en place retire les soutiens", fight.assists.is_empty() and not d.assist_active)

	finish()
