extends SceneTree
## Prend une capture de chaque écran (menus, réglages, tutoriel, combat) dans
## le dossier donné, pour vérifier la mise en page sans tout cliquer à la main.
## Ouvre une fenêtre quelques secondes (pas en --headless : il faut l'affichage).
##   Godot --path . --script res://tools/capture_screens.gd -- <dossier>

var gs
var out_dir := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else OS.get_user_data_dir()
	gs = root.get_node("GameState")
	await process_frame
	gs.dry_run = true
	# Réglages neutres dans un fichier à part : on ne touche jamais à ceux du joueur.
	gs.reset_settings("user://capture_settings.cfg")

	await shot("res://scenes/menus/title_screen.tscn", "01_titre")
	var menu = await shot("res://scenes/menus/main_menu.tscn", "02_menu", false)
	var settings = menu.open_settings()
	await capture("03_reglages_general")
	settings.tabs.current_tab = 1
	await capture("04_reglages_controles")
	for button in gs.EXTRA_BUTTONS:
		gs.extra_buttons[button] = true
	var editor = settings.open_controls_editor()
	await capture("05_disposition_droitier")
	editor.apply_preset(true)
	await capture("06_disposition_gaucher")
	editor.close()
	settings.go_back()
	menu.queue_free()
	await process_frame

	gs.mode = gs.Mode.TRAINING
	await shot("res://scenes/menus/fighter_select.tscn", "07_selection_entrainement")

	gs.mode = gs.Mode.TUTORIAL
	var fight = await shot("res://scenes/fight/fight.tscn", "08_tutoriel", false)
	var p = fight.player
	p.is_player = false
	p.position.x = 285
	fight.dummy.position.x = 310
	p.intent.crouch = true
	p.intent.attack = true
	await physics_frame
	await physics_frame
	await capture("09_repere_coup_bas")
	fight.queue_free()
	for button in gs.EXTRA_BUTTONS:
		gs.extra_buttons[button] = false
	quit()


func shot(path: String, name: String, free_after := true) -> Node:
	var scene: Node = load(path).instantiate()
	root.add_child(scene)
	await capture(name)
	if free_after:
		scene.queue_free()
		await process_frame
	return scene


func capture(name: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(out_dir.path_join(name + ".png"))
	print("capture : ", name)
