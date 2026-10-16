extends "res://tests/test_base.gd"
## Tests des menus : réglages enregistrés, boutons tactiles déplaçables,
## sélection des combattants, enchaînement de l'Arcade, menu pause.
## Les changements d'écran sont seulement notés (gs.dry_run).

const TEST_SETTINGS := "user://test_settings.cfg"

## L'autoload GameState (dans un script de test, on le prend dans l'arbre).
var gs


func approx(a: Vector2, b: Vector2) -> bool:
	return a.distance_to(b) < 0.5


func _initialize() -> void:
	gs = await use_test_settings()
	gs.dry_run = true
	gs.settings_path = TEST_SETTINGS
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	# Les menus ne proposent que les personnages jouables (pas les combattants de test).
	var roster: Array[FighterData] = gs.playable_roster()

	section("Réglages enregistrés")
	gs.set_sfx_volume(0.5)
	gs.set_music_volume(0.25)
	gs.vibration = false
	gs.touch_opacity = 0.4
	gs.touch_layout = {"Attack": {"position": Vector2(0.5, 0.5), "scale": 1.3}}
	gs.set_language("en")
	gs.set_sfx_volume(1.0)
	gs.vibration = true
	gs.touch_layout = {}
	gs.load_settings()
	check("les volumes sont gardés", is_equal_approx(gs.sfx_volume, 0.5) and is_equal_approx(gs.music_volume, 0.25))
	check("la vibration et la transparence sont gardées", not gs.vibration and is_equal_approx(gs.touch_opacity, 0.4))
	check("la disposition des boutons est gardée", gs.get_touch_layout("Attack").get("scale", 0.0) == 1.3)
	check("la langue est gardée", gs.language == "en" and TranslationServer.get_locale().begins_with("en"))
	var sfx_db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))
	check("le volume des bruitages agit sur le bus SFX", absf(sfx_db - linear_to_db(0.5)) < 0.01, "%.2f dB" % sfx_db)
	gs.set_language("fr")
	gs.touch_layout = {}
	gs.touch_opacity = 0.8

	section("Boutons tactiles")
	var controls = load("res://scenes/ui/touch_controls.tscn").instantiate()
	root.add_child(controls)
	await process_frame
	var screen: Vector2 = controls.screen_size()
	var attack: Node2D = controls.get_node("Attack")
	check("disposition d'origine", approx(attack.position, Vector2(430, 222) / Vector2(480, 270) * screen), str(attack.position))
	controls.apply_layout({"Attack": {"position": Vector2(0.5, 0.5), "scale": 1.5}}, 0.5)
	check("un bouton se place et s'agrandit", approx(attack.position, screen * 0.5) and attack.scale.x == 1.5 and attack.modulate.a == 0.5)
	check("les autres gardent leur place", approx(controls.get_node("Guard").position, controls.default_position("Guard")))
	var layout: Dictionary = controls.current_layout()
	check("la disposition se relit", approx(layout.Attack.position, Vector2(0.5, 0.5)) and layout.Attack.scale == 1.5)

	var joystick: TouchJoystick = controls.get_node("Joystick")
	joystick.scale = Vector2.ONE * 1.5
	check("un joystick agrandi se prend de plus loin", joystick.can_grab(joystick.global_position + Vector2(110, 0)) \
			and not joystick.can_grab(joystick.global_position + Vector2(130, 0)))
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = joystick.global_position + Vector2(-36, 0)
	joystick._input(touch)
	check("un joystick agrandi marche toujours", Input.is_action_pressed("move_left") and not Input.is_action_pressed("crouch"))
	touch.pressed = false
	joystick._input(touch)
	check("lâcher le joystick relâche tout", not Input.is_action_pressed("move_left"))
	controls.queue_free()

	section("Disposer les boutons")
	var editor = load("res://scenes/menus/controls_editor.tscn").instantiate()
	root.add_child(editor)
	await process_frame
	var edited = editor.controls.get_node("Attack")
	check("en édition, les boutons ne déclenchent rien", edited.action == "")
	touch = InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = edited.position + Vector2(3, 2)
	editor._input(touch)
	check("toucher un bouton le sélectionne", editor.selected == "Attack")
	var drag := InputEventScreenDrag.new()
	drag.position = Vector2(103, 102)
	editor._input(drag)
	check("on le fait glisser", approx(edited.position, Vector2(100, 100)), str(edited.position))
	drag.position = Vector2(-50, 500)
	editor._input(drag)
	check("il ne sort pas de l'écran", edited.position.x > 0 and edited.position.y < screen.y)
	drag.position = Vector2(103, 102)
	editor._input(drag)
	touch.pressed = false
	editor._input(touch)
	editor.size_slider.value = 1.4
	check("le curseur change sa taille", is_equal_approx(edited.scale.x, 1.4))
	editor.opacity_slider.value = 0.6
	editor.save()
	await process_frame
	var saved: Dictionary = gs.get_touch_layout("Attack")
	check("Enregistrer garde la disposition", approx(saved.position * screen, Vector2(100, 100)) and is_equal_approx(saved.scale, 1.4) \
			and is_equal_approx(gs.touch_opacity, 0.6))
	check("l'écran se ferme", not is_instance_valid(editor) or editor.is_queued_for_deletion())

	editor = load("res://scenes/menus/controls_editor.tscn").instantiate()
	root.add_child(editor)
	await process_frame
	check("à la réouverture, la disposition enregistrée est là", approx(editor.controls.get_node("Attack").position, Vector2(100, 100)))
	editor.reset_layout()
	check("Par défaut remet les boutons en place", approx(editor.controls.get_node("Attack").position, editor.controls.default_position("Attack")))
	editor.close()
	check("Annuler ne change pas l'enregistrement", gs.get_touch_layout("Attack").has("position"))
	gs.touch_layout = {}

	section("Menu principal et sélection")
	var menu = load("res://scenes/menus/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	check("Histoire est ouverte, l'Encyclopédie grisée", not menu.story_button.disabled and menu.encyclopedia_button.disabled)
	menu.open_story()
	check("Histoire ouvre la carte des chapitres", gs.last_screen == gs.STORY_MAP and gs.mode == gs.Mode.STORY)
	var settings = menu.open_settings()
	await process_frame
	settings.language_button.pressed.emit()
	check("le bouton de langue change la langue", gs.language == "en")
	settings.language_button.pressed.emit()
	settings.go_back()
	check("les réglages se ferment", not menu.has_overlay() or settings.is_queued_for_deletion())
	menu.arcade_button.pressed.emit()
	check("Arcade ouvre la sélection", gs.last_screen == gs.FIGHTER_SELECT and gs.mode == gs.Mode.ARCADE)
	menu.queue_free()

	var select = load("res://scenes/menus/fighter_select.tscn").instantiate()
	root.add_child(select)
	await process_frame
	check("en Arcade, pas de choix d'adversaire", not select.opponent_cards.visible)
	select.select_fighter(roster[1])
	check("on ne peut pas être son propre soutien", select.support != roster[1] and select._support_cards[roster[1]].disabled)
	select.select_difficulty(FighterAI.Difficulty.HARD)
	select.start()
	check("Combattre lance l'Arcade avec les choix faits", gs.player_fighter == roster[1] and gs.difficulty == FighterAI.Difficulty.HARD \
			and gs.arcade_opponents.size() == gs.ARCADE_LENGTH and gs.last_screen == gs.FIGHT)
	var all_present := true
	for fighter_data in roster:
		all_present = all_present and gs.arcade_opponents.any(func(e): return e.fighter == fighter_data)
	check("l'Arcade fait affronter tous les personnages jouables", all_present)
	var no_test: bool = gs.arcade_opponents.all(func(e): return e.fighter.id not in gs.TEST_FIGHTERS)
	check("pas de combattant de test en Arcade", no_test)
	select.queue_free()

	gs.mode = gs.Mode.TRAINING
	select = load("res://scenes/menus/fighter_select.tscn").instantiate()
	root.add_child(select)
	await process_frame
	select.select_opponent(roster[2])
	check("en Entraînement, on choisit le décor", select.stage_button != null and select.stage_button.visible)
	select.next_stage()
	var chosen: String = select.selected_stage()
	select.start()
	check("le décor choisi est gardé", gs.training_stage == chosen and chosen != "")
	check("en Entraînement, on choisit l'adversaire", select.opponent_cards.visible and gs.opponent_fighter == roster[2] and gs.mode == gs.Mode.TRAINING)
	select.queue_free()

	section("Arcade")
	gs.start_arcade(roster[0], roster[1], FighterAI.Difficulty.EASY, 7)
	fight = load(FIGHT_SCENE).instantiate()
	root.add_child(fight)
	await process_frame
	p = fight.player
	d = fight.dummy
	var first: Dictionary = gs.arcade_opponents[0]
	check("le combat prend les choix des menus", p.data == roster[0] and p.support == roster[1] and d.data == first.fighter and d.support == first.support)
	check("l'adversaire est l'IA à la difficulté choisie", fight.tools.dummy_mode == TrainingTools.DummyMode.AI and fight.tools.ai.difficulty == FighterAI.Difficulty.EASY)
	check("pas d'outils de test en Arcade", not fight.tools.debug_label.visible and not p.show_boxes)
	await run(5)
	check("l'intro annonce « Combat 1 / 6 »", fight.hud.announce_label.text.begins_with(tr("ARCADE_FIGHT_N") % [1, 6]), fight.hud.announce_label.text)

	fight.flow.player_wins = 2
	fight.flow.set_phase(fight.flow.Phase.ROUND_OVER)
	fight.flow.phase_frames = fight.flow.ROUND_OVER_FRAMES
	await run(2)
	check("victoire : fenêtre « Combat suivant »", fight.match_result.visible and fight.match_result.outcome == MatchResult.Outcome.WIN)
	fight.match_result.main_button.pressed.emit()
	await run(2)
	check("combat suivant : nouvel adversaire, nouveau match", gs.arcade_index == 1 and d.data == gs.arcade_opponents[1].fighter \
			and fight.flow.phase == fight.flow.Phase.INTRO and fight.flow.player_wins == 0 and not fight.match_result.visible)

	fight.flow.dummy_wins = 2
	fight.flow.set_phase(fight.flow.Phase.ROUND_OVER)
	fight.flow.phase_frames = fight.flow.ROUND_OVER_FRAMES
	await run(2)
	check("défaite : fenêtre « Réessayer »", fight.match_result.visible and fight.match_result.outcome == MatchResult.Outcome.LOSS)
	fight.match_result.main_button.pressed.emit()
	await run(2)
	check("réessayer : même adversaire", gs.arcade_index == 1 and fight.flow.phase == fight.flow.Phase.INTRO)

	gs.arcade_index = 5
	fight.flow.player_wins = 2
	fight.flow.set_phase(fight.flow.Phase.ROUND_OVER)
	fight.flow.phase_frames = fight.flow.ROUND_OVER_FRAMES
	await run(2)
	check("6e victoire : Arcade terminée", fight.match_result.outcome == MatchResult.Outcome.COMPLETE and not fight.match_result.main_button.visible)
	fight.match_result.menu_button.pressed.emit()
	check("retour au menu principal", gs.last_screen == gs.MAIN_MENU)

	section("Journal des combats")
	var log_file := "user://test_match_log.csv"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(log_file))
	fight.match_log.log_path = log_file
	fight.match_log.reset()
	fight.match_log.on_hit(Fighter.HitResult.HIT, p.data.combo[0], p, d)
	fight.match_log.on_hit(Fighter.HitResult.BLOCKED, d.data.combo[0], d, p)
	fight.match_log.write("NORMAL", "win", "2-1")
	fight.match_log.write("NORMAL", "loss", "0-2")
	var lines := FileAccess.get_file_as_string(log_file).strip_edges().split("
")
	check("une ligne par combat, sous un en-tête", lines.size() == 3 and lines[0].begins_with("date,difficulty"), str(lines.size()))
	check("les coups sont comptés", lines[1].contains(",win,2-1,") and lines[1].ends_with("1,0,0,1,0,0,0,0"), lines[1])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(log_file))

	section("Menu pause")
	check("pas de bouton « mode entraînement » en Arcade", not fight.pause_menu.mode_button.visible)
	fight.pause_menu.set_paused(true)
	var pause_settings = fight.pause_menu.open_settings()
	await process_frame
	check("les réglages s'ouvrent en pleine pause", pause_settings.is_inside_tree() and not fight.pause_menu.box.visible)
	pause_settings.go_back()
	check("en les fermant, on revient au menu pause", fight.pause_menu.box.visible and paused)
	gs.last_screen = ""
	fight.pause_menu.menu_button.pressed.emit()
	check("Menu principal quitte le combat", gs.last_screen == gs.MAIN_MENU and not paused)
	fight.queue_free()

	section("Entraînement")
	gs.start_training(roster[2], roster[0], roster[1], FighterAI.Difficulty.NORMAL)
	fight = load(FIGHT_SCENE).instantiate()
	root.add_child(fight)
	await process_frame
	p = fight.player
	d = fight.dummy
	await run(2)
	check("entraînement : bons combattants, pas de chrono", fight.training and p.data == roster[2] and d.data == roster[1] and fight.hud.timer_label.text == "--")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	finish()
