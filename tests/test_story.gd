extends "res://tests/test_base.gd"
## Tests du mode Histoire : progression et déblocages, carte des chapitres,
## cases du griot, et les règles de combat (duel, survie, boss).
## Les changements d'écran sont seulement notés (gs.dry_run).

var gs: Node


## Ouvre l'arène pour un combat du mode Histoire (le mannequin reste immobile).
func open_story_fight(spec: Dictionary) -> void:
	if fight:
		fight.queue_free()
		await process_frame
	gs.start_story_fight(spec)
	fight = load(FIGHT_SCENE).instantiate()
	root.add_child(fight)
	await process_frame
	p = fight.get_node("Player")
	d = fight.get_node("Dummy")
	p.is_player = false
	fight.tools.dummy_mode = fight.tools.DummyMode.STAND


func to_fight() -> void:
	while fight.flow.phase != fight.flow.Phase.FIGHT:
		await run(1)


## Met un combattant K.O. et attend la fin de la manche.
func knock_out(fighter: Fighter) -> void:
	await to_fight()
	fighter.health = 0
	await run(2)


func wait_round_over() -> void:
	while fight.flow.phase == fight.flow.Phase.ROUND_OVER:
		await run(1)


func step_spec(chapter: int, step: int) -> Dictionary:
	return gs.story.chapters()[chapter].steps[step].fight


func _initialize() -> void:
	gs = await use_test_settings()
	gs.dry_run = true
	var story = gs.story
	# Progression vierge (comme un premier lancement), dans le fichier des tests.
	story.reset(TEST_PROGRESS_PATH)
	story.save_progress()

	section("Déblocages au départ")
	var dakon: FighterData = gs.fighter_by_id(&"dakon")
	var itsa: FighterData = gs.fighter_by_id(&"itsa")
	check("Pokou jouable d'office", story.can_play(gs.fighter_by_id(&"abla_pokou")))
	check("Dakon et Itsa verrouillés", not story.can_play(dakon) and not story.can_support(itsa))
	var ids: Array = gs.playable_roster().map(func(f: FighterData) -> StringName: return f.id)
	check("sélection : seulement les jouables", ids == [&"abla_pokou"], str(ids))
	check("chapitre 1 ouvert, chapitre 2 fermé", story.is_open(0) and not story.is_open(1))

	section("Carte des chapitres")
	var map = load("res://scenes/story/story_map.tscn").instantiate()
	root.add_child(map)
	await process_frame
	check("7 chapitres", map.chapter_buttons.size() == 7)
	check("chapitre 2 verrouillé", not map.chapter_buttons[0].disabled and map.chapter_buttons[1].disabled)
	map.open_chapter(0)
	check("chapitre 1 : les cases du griot", gs.last_screen == gs.STORY_PANELS and gs.mode == gs.Mode.STORY)
	map.queue_free()

	section("Cases du griot")
	var panels = load("res://scenes/story/story_panels.tscn").instantiate()
	root.add_child(panels)
	await process_frame
	check("5 cases, la première est dessinée", panels.panels.size() == 5 and panels.image.texture != null and not panels.placeholder.visible)
	check("le texte s'écrit lettre par lettre", panels.typing and panels.text_label.visible_ratio < 1.0)
	panels.next()
	check("toucher : le texte s'affiche en entier", not panels.typing and panels.text_label.visible_ratio == 1.0 and panels.index == 0)
	panels.next()
	check("toucher encore : case suivante", panels.index == 1)
	for i in 10:
		panels.next()
	check("après la dernière case : chapitre 1 terminé", story.is_completed(0) and story.is_open(1) and gs.last_screen == gs.STORY_MAP)
	var reloaded := StoryProgress.new()
	reloaded.path = TEST_PROGRESS_PATH
	reloaded.load_progress()
	check("progression enregistrée", reloaded.is_completed(0))
	panels.queue_free()
	story.start(1)
	panels = load("res://scenes/story/story_panels.tscn").instantiate()
	root.add_child(panels)
	await process_frame
	check("case pas encore dessinée : carte avec le titre", panels.placeholder.visible and panels.placeholder.text == tr("STORY_CH2_TITLE"))
	panels.finish()
	check("chapitre 2 : puis le duel Dakon contre Pokou", gs.last_screen == gs.FIGHT and gs.player_fighter.id == &"dakon"
			and gs.opponent_fighter.id == &"abla_pokou" and gs.player_support == null)
	panels.queue_free()

	section("Duel (une manche)")
	await open_story_fight(gs.story_fight)
	var R = fight.flow.Rule
	check("règle duel, sans soutien", fight.flow.rule == R.DUEL and p.support == null and d.support == null)
	check("décor de Kumasi la nuit", fight.stage.visible and not fight.get_node("Background").visible)
	await run(2)
	check("annonce : le titre du combat", fight.hud.announce_label.text == tr("STORY_FIGHT_SPARRING"), fight.hud.announce_label.text)
	await knock_out(d)
	await wait_round_over()
	check("une seule manche suffit", fight.flow.phase == fight.flow.Phase.MATCH_OVER and fight.flow.player_won())
	check("fenêtre : Continuer", fight.match_result.visible and fight.match_result.main_button.text == "STORY_CONTINUE"
			and fight.match_result.menu_button.text == "STORY_BACK_MAP")
	fight.match_result.main_button.pressed.emit()
	check("Continuer : combat suivant (Itsa)", gs.last_screen == gs.FIGHT and gs.opponent_fighter.id == &"itsa")
	await open_story_fight(gs.story_fight)
	await knock_out(p)
	await wait_round_over()
	check("défaite : Réessayer", fight.flow.player_lost() and fight.match_result.main_button.text == "STORY_RETRY")
	fight.match_result.main_button.pressed.emit()
	await run(2)
	check("Réessayer relance le duel", fight.flow.phase == fight.flow.Phase.INTRO and not fight.match_result.visible)
	fight.match_result.menu_button.pressed.emit()
	check("le bouton du bas ramène à la carte", gs.last_screen == gs.STORY_MAP)

	section("Survie (vagues jusqu'à l'aube)")
	story.start(2)
	await open_story_fight(step_spec(2, 1))
	check("règle survie : 4 vagues, 60 s", fight.flow.rule == R.SURVIVAL and fight.flow.player_rounds_needed == 4 and fight.flow.timer_frames == 3600)
	check("pas de décor de forêt : repli sur Kumasi la nuit", gs.stage_for_fight(d.data) == "kumasi_nuit")
	check("le guerrier d'Itsa porte le dessin de Dakon, assombri", d.data.sprite_frames != null and d.data.tint != Color.WHITE)
	await run(2)
	check("annonce : vague 1 / 4", tr("FIGHT_WAVE") % [1, 4] in fight.hud.announce_label.text, fight.hud.announce_label.text)
	await to_fight()
	await run(30)
	p.health = 500
	await knock_out(d)
	var time_left: int = fight.flow.timer_frames
	await wait_round_over()
	check("vague 2 : le joueur garde sa vie (+20 %)", p.health == 700 and d.health == 1000, "%d / %d" % [p.health, d.health])
	check("vague 2 : le chrono continue", fight.flow.timer_frames == time_left, "%d / %d" % [fight.flow.timer_frames, time_left])
	await to_fight()
	fight.flow.timer_frames = 2
	await run(4)
	check("fin du chrono : l'aube se lève", fight.flow.player_won() and fight.hud.announce_label.text == tr("FIGHT_DAWN"), fight.hud.announce_label.text)

	section("Boss (3 phases)")
	story.start(3)
	await open_story_fight(step_spec(3, 1))
	check("règle boss : 3 phases", fight.flow.rule == R.BOSS and fight.flow.player_rounds_needed == 3)
	await run(2)
	check("annonce : phase 1 / 3", tr("FIGHT_PHASE") % [1, 3] in fight.hud.announce_label.text, fight.hud.announce_label.text)
	await knock_out(d)
	check("phase gagnée, pas encore fini", fight.flow.phase == fight.flow.Phase.ROUND_OVER and not fight.flow.is_decided())
	await wait_round_over()
	check("phase 2 : le boss commence avec 1 segment d'énergie", d.energy == 100.0, str(d.energy))
	await knock_out(d)
	await wait_round_over()
	check("phase 3 : l'IA du boss est au plus fort", fight.tools.ai.difficulty == FighterAI.Difficulty.HARD)
	await knock_out(d)
	await wait_round_over()
	check("3 phases gagnées : victoire", fight.flow.player_won() and fight.match_result.visible)
	check("Itsa battu : soutien possible", story.can_support(itsa) and not story.can_play(itsa))
	fight.queue_free()
	fight = null

	section("Fin de chapitre et déblocages")
	story.reset(TEST_PROGRESS_PATH)
	story.start(1)
	story.step_index = story.current_chapter().steps.size() - 1
	check("dernière étape : le chapitre se termine", not story.advance() and story.is_completed(1))
	check("chapitre 2 fini : Dakon devient soutien", story.can_support(dakon) and not story.can_play(dakon))
	map = load("res://scenes/story/story_map.tscn").instantiate()
	root.add_child(map)
	await process_frame
	check("la carte annonce le déblocage", tr(dakon.name_key) in map.unlock_label.text, map.unlock_label.text)
	map.queue_free()
	story.start(6)
	story.step_index = 0
	story.advance()
	check("fin de l'arc : Dakon et Itsa jouables", story.can_play(dakon) and story.can_play(itsa))

	gs.story.reset(TEST_PROGRESS_PATH, true)
	finish()
