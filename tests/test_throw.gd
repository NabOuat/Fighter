extends "res://tests/test_base.gd"
## Tests de la projection (collé + avant + Garde) et d'une IA qui joue à la loyale
## (temps de réaction, hauteur de garde devinée).


## Met l'IA du mannequin en attente : elle ne fait que se défendre.
func idle_ai(level: FighterAI.Difficulty, seed: int) -> FighterAI:
	var ai := FighterAI.new(level, seed)
	fight.tools.ai = ai
	fight.tools.dummy_mode = fight.tools.DummyMode.AI
	ai._start_plan(FighterAI.Plan.WAIT, 9999)
	ai._think_cooldown = 9999
	return ai


func _initialize() -> void:
	await start_arena()
	var M = fight.tools.DummyMode

	section("Projection")
	await setup(280, 305, M.GUARD_HIGH)
	await run(1, {"right": true}, {"guard_pressed": [0]})
	await run(40)
	check("la projection traverse la garde haute", d.health < 1000 and fight.hud.popup_label.text == "FIGHT_THROW", "vie %d" % d.health)

	await setup(280, 305, M.GUARD_LOW)
	await run(1, {"right": true}, {"guard_pressed": [0]})
	await run(8)
	check("la projection traverse la garde basse et fait tomber", d.health < 1000 and d.state == Fighter.State.KNOCKDOWN, "vie %d, %s" % [d.health, state_name(d)])

	await setup(200, 300, M.STAND)
	await run(1, {"right": true}, {"guard_pressed": [0]})
	check("de loin, avant + Garde n'est pas une projection", p.current_attack == null)

	await setup(280, 305, M.STAND)
	await run(1, {}, {"guard_pressed": [0]})
	check("Garde sans direction n'est pas une projection", p.current_attack == null)

	await setup(280, 305, M.STAND)
	d.intent.jump = true
	await run(3)
	d.intent.jump = false
	await run(1, {"right": true}, {"guard_pressed": [0]})
	await run(10)
	check("on évite la projection en sautant", d.health == 1000, "vie %d" % d.health)
	check("une projection ratée laisse sans défense un moment", p.state == Fighter.State.ATTACK and p.current_attack.is_throw, state_name(p))
	await run(60)

	await setup(280, 305, M.STAND)
	d.stun_frames = 30
	d.state = Fighter.State.HITSTUN
	await run(1, {"right": true}, {"guard_pressed": [0]})
	await run(10)
	check("on ne projette pas un adversaire sonné (pas de combo infini)", d.health == 1000, "vie %d" % d.health)

	await setup(280, 305, M.STAND)
	d.intent.left = true
	d.intent.guard_pressed = true
	await run(1, {"right": true}, {"guard_pressed": [0]})
	d.intent.left = false
	await run(20)
	check("deux projections en même temps : personne n'est saisi", p.health == 1000 and d.health == 1000 and fight.hud.popup_label.text == "FIGHT_THROW_TECH", "vies %d / %d" % [p.health, d.health])

	section("IA : temps de réaction")
	var hits := 0
	for trial in 6:
		await setup(280, 305, M.STAND)
		idle_ai(FighterAI.Difficulty.HARD, 50 + trial)
		await run(20)
		var low := trial % 2 == 1
		await run(4, {"crouch": low}, {"attack": [0]})
		await run(20)
		if d.health < 1000:
			hits += 1
	check("même en difficile, l'IA ne pare pas un coup rapide sans être déjà en garde", hits >= 5, "%d coups sur 6 ont touché" % hits)

	var blocked := 0
	for trial in 6:
		await setup(150, 330, M.STAND)
		idle_ai(FighterAI.Difficulty.HARD, 70 + trial)
		await run(3, {"special": true})
		await run(90)
		if d.health > 950:
			blocked += 1
	check("en difficile, l'IA pare un projectile qu'elle voit venir", blocked >= 4, "%d sur 6" % blocked)

	section("IA : apprendre les habitudes")
	var ai := idle_ai(FighterAI.Difficulty.HARD, 90)
	for i in 8:
		await setup(280, 305, M.STAND)
		fight.tools.ai = ai
		fight.tools.dummy_mode = M.AI
		await run(4, {"crouch": true}, {"attack": [0]})
		await run(20)
	var crouch_guesses := 0
	for i in 100:
		if ai._pick_guard_height(FighterAI.SETTINGS[FighterAI.Difficulty.HARD]):
			crouch_guesses += 1
	check("après des coups bas répétés, l'IA difficile se garde surtout en bas", crouch_guesses > 60, "%d %% en bas" % crouch_guesses)

	finish()
