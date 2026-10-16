extends SceneTree
## Enregistre la « trace » d'un combat IA contre IA toujours identique (mêmes
## graines) : à chaque frame, positions, vies, états, projectiles et soutiens.
## Sert à vérifier qu'une modification du moteur de combat ne change rien au jeu :
## on compare la trace d'avant et celle d'après (elles doivent être identiques).
##   Godot --headless --fixed-fps 60 --path . --script res://tools/trace_fight.gd -- <fichier>

const FRAMES := 3600


func _initialize() -> void:
	var out_path: String = OS.get_cmdline_user_args()[0]
	await process_frame
	var gs: Node = root.get_node("GameState")
	gs.reset_settings("user://trace_settings.cfg")
	gs.story.reset("user://trace_progress.cfg", true)
	var fight = load("res://scenes/fight/fight.tscn").instantiate()
	root.add_child(fight)
	await process_frame
	var p: Fighter = fight.get_node("Player")
	var d: Fighter = fight.get_node("Dummy")
	p.is_player = false
	# Deux personnages dessinés (caméra zoomée), avec soutiens (projectiles, boucliers...).
	p.data = gs.fighter_by_id(&"abla_pokou")
	d.data = gs.fighter_by_id(&"itsa")
	p.support = gs.fighter_by_id(&"test_c")
	d.support = gs.fighter_by_id(&"test_b")
	fight.art_camera = true
	fight.start_match()
	fight.tools.dummy_mode = fight.tools.DummyMode.AI
	fight.tools.ai = FighterAI.new(FighterAI.Difficulty.HARD, 11)
	var ai_p := FighterAI.new(FighterAI.Difficulty.HARD, 23)
	var lines := PackedStringArray()
	for i in FRAMES:
		ai_p.update(p, d, fight.projectiles)
		await physics_frame
		var extra := ""
		for projectile in fight.projectiles:
			extra += " P%.3f" % projectile.position.x
		for assist in fight.assists:
			extra += " A%d" % assist.frame
		lines.append("%d %.3f %.3f %.3f %.3f %d %d %s %s %.1f %.1f %d %d%s" % [i,
				p.position.x, p.position.y, d.position.x, d.position.y, p.health, d.health,
				Fighter.State.keys()[p.state], Fighter.State.keys()[d.state], p.energy, d.energy,
				fight.flow.player_wins, fight.flow.dummy_wins, extra])
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()
	print("trace : ", FRAMES, " frames, score ", fight.flow.player_wins, "-", fight.flow.dummy_wins,
			", vies ", p.health, " / ", d.health)
	fight.queue_free()
	for i in 5:
		await process_frame
	quit()
