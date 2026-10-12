extends "res://tests/test_base.gd"
## Tests du déroulement d'un combat (étape 5) : annonces, K.O., chrono, manches, victoire.


func to_fight() -> void:
	while fight.phase != fight.Phase.FIGHT:
		await run(1)
	p.position.x = 280
	d.position.x = 305
	await run(2)


func ko_dummy() -> void:
	d.health = 40
	await run(30, {}, {"attack": [0, 6, 12]})


func _initialize() -> void:
	await start_arena(false)
	fight._start_match()
	var P = fight.Phase

	section("Début de manche")
	await run(20, {}, {"attack": [5]})
	check("annonce « Round 1 »", fight.phase == P.INTRO and fight.announce_label.text == tr("FIGHT_ROUND") % 1, fight.announce_label.text)
	check("commandes bloquées pendant l'annonce", p.state == Fighter.State.IDLE, state_name(p))
	check("chrono à 60", fight.timer_label.text == "60", fight.timer_label.text)
	await run(100)
	check("le combat commence", fight.phase == P.FIGHT)

	section("K.O. et manche suivante")
	await to_fight()
	p.energy = 150.0
	await ko_dummy()
	check("K.O. : fin de manche", fight.phase == P.ROUND_OVER and fight.announce_label.text == tr("FIGHT_KO"), fight.announce_label.text)
	check("K.O. : ralenti", fight.slowmo_frames > 0)
	check("K.O. : manche gagnée", fight.player_wins == 1 and fight.dummy_wins == 0)
	while fight.phase == P.ROUND_OVER:
		await run(1)
	check("manche 2 : vie pleine", p.health == 1000 and d.health == 1000)
	check("manche 2 : énergie gardée", p.energy >= 150.0, "énergie %.0f" % p.energy)
	check("manche 2 annoncée", fight.announce_label.text == tr("FIGHT_ROUND") % 2, fight.announce_label.text)

	section("Chrono")
	await to_fight()
	p.health = 900
	fight.timer_frames = 3
	await run(5)
	check("temps écoulé : le plus de vie gagne", fight.announce_label.text == tr("FIGHT_TIME_UP") and fight.dummy_wins == 1, "%s %d-%d" % [fight.announce_label.text, fight.player_wins, fight.dummy_wins])
	while fight.phase == P.ROUND_OVER:
		await run(1)
	await run(2)
	check("à 1-1 : « Round final »", fight.announce_label.text == tr("FIGHT_FINAL_ROUND"), fight.announce_label.text)

	section("Victoire et rejouer")
	await to_fight()
	await ko_dummy()
	while fight.phase == P.ROUND_OVER:
		await run(1)
	await run(2)
	check("victoire à 2 manches", fight.phase == P.MATCH_OVER and fight.announce_label.text.contains(tr("FIGHTER_TEST_A_NAME")), fight.announce_label.text)
	Input.action_press("attack")
	await run(1)
	Input.action_release("attack")
	await run(1)
	check("Attaque relance le combat à zéro", fight.phase == P.INTRO and fight.player_wins == 0 and int(p.energy) == 0)

	section("Cas particuliers")
	await to_fight()
	p.health = 0
	d.health = 0
	await run(2)
	check("double K.O. : la manche compte pour les deux", fight.announce_label.text == tr("FIGHT_DOUBLE_KO") and fight.player_wins == 1 and fight.dummy_wins == 1)

	fight._start_match()
	await to_fight()
	p.energy = 400.0
	p.position.x = 150
	d.position.x = 400
	await run(3, {"special": true})
	await run(16)
	d.health = 0
	await run(80)
	check("après un K.O., un projectile ne touche plus", d.health == 0 and fight.phase == P.ROUND_OVER)

	fight.training = true
	fight._reset_training()
	await run(2)
	d.health = 30
	p.position.x = 280
	d.position.x = 305
	await run(40, {}, {"attack": [0, 6, 12]})
	check("entraînement : personne n'est mis K.O.", d.health == 1, "vie %d" % d.health)
	check("entraînement : pas de chrono ni d'annonce", fight.timer_label.text == "--" and not fight.announce_label.visible)

	finish()
