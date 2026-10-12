extends "res://tests/test_base.gd"
## Tests du déroulement d'un combat (étape 5) : annonces, K.O., chrono, manches, victoire.


func to_fight() -> void:
	while fight.flow.phase != fight.flow.Phase.FIGHT:
		await run(1)
	p.position.x = 280
	d.position.x = 305
	await run(2)


func ko_dummy() -> void:
	d.health = 40
	await run(30, {}, {"attack": [0, 6, 12]})


func _initialize() -> void:
	await start_arena(false)
	fight.start_match()
	var P = fight.flow.Phase

	section("Début de manche")
	await run(20, {}, {"attack": [5]})
	check("annonce « Round 1 »", fight.flow.phase == P.INTRO and fight.hud.announce_label.text == tr("FIGHT_ROUND") % 1, fight.hud.announce_label.text)
	check("commandes bloquées pendant l'annonce", p.state == Fighter.State.IDLE, state_name(p))
	check("chrono à 60", fight.hud.timer_label.text == "60", fight.hud.timer_label.text)
	await run(100)
	check("le combat commence", fight.flow.phase == P.FIGHT)

	section("K.O. et manche suivante")
	await to_fight()
	p.energy = 150.0
	await run(2, {}, {"assist": [0]})
	check("le soutien est en recharge", p.assist_cooldown > 0)
	await ko_dummy()
	check("K.O. : fin de manche", fight.flow.phase == P.ROUND_OVER and fight.hud.announce_label.text == tr("FIGHT_KO"), fight.hud.announce_label.text)
	check("K.O. : ralenti", fight.slowmo_frames > 0)
	check("K.O. : manche gagnée", fight.flow.player_wins == 1 and fight.flow.dummy_wins == 0)
	while fight.flow.phase == P.ROUND_OVER:
		await run(1)
	check("manche 2 : vie pleine", p.health == 1000 and d.health == 1000)
	check("manche 2 : énergie remise à zéro", p.energy == 0.0 and d.energy == 0.0, "énergie %.0f / %.0f" % [p.energy, d.energy])
	check("manche 2 : soutiens prêts", p.can_call_assist() and d.can_call_assist() and fight.assists.is_empty(), "recharge %d / %d" % [p.assist_cooldown, d.assist_cooldown])
	check("manche 2 annoncée", fight.hud.announce_label.text == tr("FIGHT_ROUND") % 2, fight.hud.announce_label.text)

	section("Chrono")
	await to_fight()
	p.health = 900
	fight.flow.timer_frames = 3
	await run(5)
	check("temps écoulé : le plus de vie gagne", fight.hud.announce_label.text == tr("FIGHT_TIME_UP") and fight.flow.dummy_wins == 1, "%s %d-%d" % [fight.hud.announce_label.text, fight.flow.player_wins, fight.flow.dummy_wins])
	while fight.flow.phase == P.ROUND_OVER:
		await run(1)
	await run(2)
	check("à 1-1 : « Round final »", fight.hud.announce_label.text == tr("FIGHT_FINAL_ROUND"), fight.hud.announce_label.text)

	section("Victoire et rejouer")
	await to_fight()
	await ko_dummy()
	while fight.flow.phase == P.ROUND_OVER:
		await run(1)
	await run(2)
	check("victoire à 2 manches", fight.flow.phase == P.MATCH_OVER and fight.hud.announce_label.text.contains(tr("FIGHTER_TEST_A_NAME")), fight.hud.announce_label.text)
	Input.action_press("attack")
	await run(1)
	Input.action_release("attack")
	await run(1)
	check("Attaque relance le combat à zéro", fight.flow.phase == P.INTRO and fight.flow.player_wins == 0 and int(p.energy) == 0)

	section("Cas particuliers")
	await to_fight()
	p.health = 0
	d.health = 0
	await run(2)
	check("double K.O. : la manche compte pour les deux", fight.hud.announce_label.text == tr("FIGHT_DOUBLE_KO") and fight.flow.player_wins == 1 and fight.flow.dummy_wins == 1)

	fight.start_match()
	await to_fight()
	p.energy = 400.0
	p.position.x = 150
	d.position.x = 400
	await run(3, {"special": true})
	await run(16)
	d.health = 0
	await run(80)
	check("après un K.O., un projectile ne touche plus", d.health == 0 and fight.flow.phase == P.ROUND_OVER)

	fight.training = true
	fight.reset_training()
	await run(2)
	d.health = 30
	p.position.x = 280
	d.position.x = 305
	await run(40, {}, {"attack": [0, 6, 12]})
	check("entraînement : personne n'est mis K.O.", d.health == 1, "vie %d" % d.health)
	check("entraînement : pas de chrono ni d'annonce", fight.hud.timer_label.text == "--" and not fight.hud.announce_label.visible)

	finish()
