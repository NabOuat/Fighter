extends SceneTree
## Photographie un héros dessiné en plein combat (entraînement), pour vérifier
## ses animations dans le jeu : attente, marche, combo, coup bas, spécial, garde...
##   Godot --path . --script res://tools/capture_fighter.gd -- <dossier> [index du héros] [index de l'adversaire]

var gs
var fight
var p: Fighter
var d: Fighter
var out_dir := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else OS.get_user_data_dir()
	var index := int(args[1]) if args.size() > 1 else 0
	var foe := int(args[2]) if args.size() > 2 else 2
	gs = root.get_node("GameState")
	await process_frame
	gs.dry_run = true
	gs.reset_settings("user://capture_settings.cfg")
	gs.start_training(gs.roster[index], gs.roster[2], gs.roster[foe], FighterAI.Difficulty.NORMAL)
	fight = load("res://scenes/fight/fight.tscn").instantiate()
	root.add_child(fight)
	await process_frame
	p = fight.player
	d = fight.dummy
	p.is_player = false
	fight.tools.dummy_mode = fight.tools.DummyMode.STAND
	for f in [p, d]:
		f.show_boxes = false

	await act("01_attente", 20)
	await act("02_marche", 12, {"right": true})
	await place()
	await act("03_combo_1", 6, {}, {"attack": [0]})
	await place()
	await act("04_combo_3", 26, {}, {"attack": [0, 5, 10]})
	await place()
	await act("05_coup_bas", 9, {"crouch": true}, {"attack": [0]})
	await place()
	await act("06_garde", 10, {"guard": true})
	await place(150)
	await act("07_special_1", 12, {"special": true} if true else {}, {}, 3)
	await place()
	await act("08_saut", 18, {"jump": true}, {}, 2)
	await place()
	fight.tools.dummy_mode = fight.tools.DummyMode.ATTACK
	fight.tools.frame_count = 79
	await act("09_coup_recu", 10)
	fight.tools.dummy_mode = fight.tools.DummyMode.STAND
	quit()


## Remet les deux combattants face à face, collés.
func place(gap := 30.0) -> void:
	fight.reset_training()
	p.position.x = 220
	d.position.x = 220 + gap
	for i in 12:
		await physics_frame


## Maintient hold pendant `hold_frames` (toutes si 0), appuie sur taps, attend `frames`, puis photographie.
func act(name: String, frames: int, hold := {}, taps := {}, hold_frames := 0) -> void:
	for i in frames:
		for key in p.intent:
			p.intent[key] = false
		if hold_frames == 0 or i < hold_frames:
			for key in hold:
				p.intent[key] = hold[key]
		for key in taps:
			if i in taps[key]:
				p.intent[key] = true
		await physics_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("capture : ", name)
