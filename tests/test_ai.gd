extends "res://tests/test_base.gd"
## Tests de l'IA (étape 7) : comportements précis, puis quelques matchs complets.
## Pour un tournoi complet (plusieurs minutes) : tests/tournament_ai.gd.


func play_match(player_ai: FighterAI, dummy_ai: FighterAI) -> String:
	fight.training = false
	fight._start_match()
	fight.tools.dummy_mode = fight.tools.DummyMode.AI
	fight.tools.ai = dummy_ai
	for i in 15000:
		player_ai.update(p, d, fight.projectiles)
		await physics_frame
		if fight.phase == fight.Phase.MATCH_OVER:
			break
	if fight.player_wins > fight.dummy_wins:
		return "joueur"
	if fight.dummy_wins > fight.player_wins:
		return "mannequin"
	return "nul"


func _initialize() -> void:
	await start_arena()
	var D = FighterAI.Difficulty

	section("Comportements")
	# Une charge interrompue avant 10 frames ne doit pas lancer de spécial.
	var wasted := 0
	for trial in 10:
		fight._reset_training()
		fight.tools.dummy_mode = fight.tools.DummyMode.AI
		fight.tools.ai = FighterAI.new(D.NORMAL, 100 + trial)
		d.energy = 150.0
		p.position.x = 60
		d.position.x = 420
		await run(2)
		fight.tools.ai._start_plan(FighterAI.Plan.CHARGE, 60)
		fight.tools.ai._think_cooldown = 99
		await run(4)
		p.position.x = 360
		await run(20)
		if d.energy < 150.0:
			wasted += 1
	check("charge interrompue : pas de spécial involontaire", wasted == 0, "%d essais ratés sur 10" % wasted)

	# Un plan terminé n'est plus exécuté en attendant la décision suivante.
	fight._reset_training()
	fight.tools.dummy_mode = fight.tools.DummyMode.AI
	fight.tools.ai = FighterAI.new(D.EASY, 5)
	p.position.x = 60
	d.position.x = 420
	await run(2)
	fight.tools.ai._start_plan(FighterAI.Plan.APPROACH, 10)
	fight.tools.ai._think_cooldown = 60
	var start_x := d.position.x
	await run(40)
	var walked := start_x - d.position.x
	check("le plan « avancer 10 frames » s'arrête au bout de 10 frames", walked < 25.0, "%.0f pixels parcourus" % walked)

	section("Matchs complets")
	var d_same: FighterData = p.data
	d.data = d_same
	d.support = p.support
	var hard_wins := 0
	for m in 2:
		if await play_match(FighterAI.new(D.HARD, 10 + m), FighterAI.new(D.EASY, 20 + m)) == "joueur":
			hard_wins += 1
	check("difficile bat facile (2 matchs)", hard_wins == 2, "%d/2" % hard_wins)
	var normal_wins := 0
	for m in 2:
		if await play_match(FighterAI.new(D.EASY, 30 + m), FighterAI.new(D.NORMAL, 40 + m)) == "mannequin":
			normal_wins += 1
	check("normale bat facile (2 matchs)", normal_wins == 2, "%d/2" % normal_wins)

	finish()
