extends SceneTree
## Base commune des tests automatiques.
##
## Chaque test crée l'arène sans fenêtre, joue des situations précises image par
## image (comme un joueur très précis), puis vérifie le résultat.
## Lancer tous les tests : python tools/run_tests.py

const FIGHT_SCENE := "res://scenes/fight/fight.tscn"

var fight
var p: Fighter
var d: Fighter
var checks := 0
var failures := 0


## Les réglages des tests : jamais ceux du joueur (ni lus, ni écrits).
const TEST_SETTINGS_PATH := "user://test_settings.cfg"


## GameState (autoload) finit de démarrer à la première frame ; ensuite on lui
## donne des réglages neutres, dans un fichier à part.
func use_test_settings() -> Node:
	await process_frame
	var gs: Node = root.get_node("GameState")
	gs.reset_settings(TEST_SETTINGS_PATH)
	return gs


## Crée l'arène, en mode entraînement (pas de chrono, personne n'est mis K.O.).
func start_arena(training := true) -> void:
	await use_test_settings()
	fight = load(FIGHT_SCENE).instantiate()
	root.add_child(fight)
	await process_frame
	p = fight.get_node("Player")
	d = fight.get_node("Dummy")
	p.is_player = false
	fight.tools.dummy_mode = fight.tools.DummyMode.STAND
	if training:
		fight.training = true
		fight.reset_training()
	await physics_frame


## Joue n frames. hold = touches maintenues ; taps = {touche: [frames où on appuie]}.
func run(n: int, hold := {}, taps := {}) -> void:
	for i in n:
		for key in p.intent:
			p.intent[key] = hold.get(key, false)
		for key in taps:
			if i in taps[key]:
				p.intent[key] = true
		await physics_frame


## Remet tout en place : positions, mode du mannequin, énergie du joueur.
## Le mannequin reste immobile pendant la mise en place, puis passe au mode demandé
## au moment exact où commence la situation testée.
func setup(player_x: float, dummy_x: float, mode: int, energy := 400.0, support := 0) -> void:
	fight.tools.dummy_mode = fight.tools.DummyMode.STAND
	fight.reset_training()
	fight.tools.support_index = support
	p.support = fight.tools.TEST_SUPPORTS[support]
	await run(1)
	p.position.x = player_x
	d.position.x = dummy_x
	await run(8)
	fight.tools.dummy_mode = mode
	fight.tools.frame_count = 1000
	p.health = Fighter.MAX_HEALTH
	d.health = Fighter.MAX_HEALTH
	p.energy = energy
	d.energy = 0.0


func check(label: String, ok: bool, detail := "") -> void:
	checks += 1
	if ok:
		print("  OK     ", label)
	else:
		failures += 1
		print("  ÉCHEC  ", label, "   (", detail, ")")


func section(title: String) -> void:
	print("\n", title)


func finish() -> void:
	print("\n%d/%d vérifications réussies" % [checks - failures, checks])
	# Fermeture propre : on libère l'arène, puis on laisse au moteur audio (qui
	# tourne à part, en temps réel) le temps de libérer les sons arrêtés.
	paused = false
	fight.queue_free()
	for i in 10:
		OS.delay_msec(20)
		await process_frame
	quit(1 if failures > 0 else 0)


func state_name(fighter: Fighter) -> String:
	return Fighter.State.keys()[fighter.state]
