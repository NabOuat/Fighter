extends "res://tests/test_base.gd"
## Tests du tutoriel : quelques leçons réussies pour de vrai, le bouton
## « Passer », les consignes complètes, et la fin du tutoriel.

var gs
var tutorial


## Attend la fin du « Bravo ! » et le passage à la leçon suivante.
func wait_next_lesson() -> void:
	await run(tutorial.SUCCESS_FRAMES + 5)


func skip_to(lesson_id: String) -> void:
	while tutorial.current_id() != lesson_id:
		tutorial.skip_button.pressed.emit()
		await run(1)


func _initialize() -> void:
	gs = await use_test_settings()
	gs.dry_run = true
	gs.mode = gs.Mode.TUTORIAL
	fight = load(FIGHT_SCENE).instantiate()
	root.add_child(fight)
	await process_frame
	p = fight.player
	d = fight.dummy
	p.is_player = false
	tutorial = fight.get_node("Tutorial")

	section("Mise en place")
	check("le tutoriel commence à la leçon 1", tutorial.current_id() == "MOVE")
	check("entraînement : personne n'est mis K.O.", fight.training and p.immortal and d.immortal)
	check("pas d'outils de test", not fight.tools.debug_label.visible)

	section("Leçons réussies")
	await run(45, {"right": true})
	await run(3, {"jump": true})
	await run(30)
	check("se déplacer et sauter : réussi", tutorial.text_label.text == tr("TUTO_WELL_DONE"))
	await wait_next_lesson()
	check("on passe à la leçon du combo", tutorial.current_id() == "COMBO")

	for i in 2:
		p.position.x = 285
		d.position.x = 310
		await run(45, {}, {"attack": [0, 7, 14]})
		# Le 3e coup fait tomber : on attend qu'il se relève.
		await run(110)
	await wait_next_lesson()
	check("le combo de 3 coups, deux fois : réussi", tutorial.current_id() == "JUGGLE", tutorial.current_id())

	# Jonglage : J J J (lanceur), puis saut vers lui et 2 coups en l'air.
	p.position.x = 280
	d.position.x = 302
	await run(30, {}, {"attack": [0, 5, 10]})
	while p.current_attack != null:
		await run(1)
	for i in 60:
		await run(1, {"jump": i < 3, "right": i < 3}, {"attack": [0]} if i in [6, 12] else {})
	await wait_next_lesson()
	check("le jonglage (5 coups) : réussi", tutorial.current_id() == "GUARD", tutorial.current_id())

	await skip_to("LOW")
	for i in 2:
		p.position.x = 285
		d.position.x = 310
		await run(35, {"crouch": true}, {"attack": [0]})
	check("coup bas contre une garde debout : réussi", tutorial.progress == 2)
	await wait_next_lesson()

	await skip_to("THROW")
	p.position.x = 285
	d.position.x = 310
	await run(2)
	await run(1, {"right": true}, {"guard_pressed": [0]})
	await run(20)
	check("projection : réussie", tutorial.progress == 1)
	await wait_next_lesson()

	section("Consignes")
	var complete := true
	for lesson in tutorial.LESSONS:
		var text: String = tutorial.instruction(lesson.id)
		var title := tr("TUTO_%s_TITLE" % lesson.id)
		if text.contains("{") or text.begins_with("TUTO_") or title.begins_with("TUTO_"):
			complete = false
			print("    consigne incomplète : ", lesson.id, " -> ", text)
	check("chaque leçon a un titre et une consigne complète", complete)

	section("Fin")
	await skip_to("ULTIMATE")
	await run(2, {}, {"ultimate": [0]})
	await run(140)
	check("dernière leçon (ultime) : réussie", tutorial.finished and tutorial.end_panel.visible)
	tutorial.training_button.pressed.emit()
	check("fin : on peut passer à l'entraînement", gs.mode == gs.Mode.TRAINING and gs.last_screen == gs.FIGHT)

	finish()
