extends SceneTree
## Tournoi IA contre IA : 8 matchs complets par duel, avec les statistiques de chaque IA.
## Plusieurs minutes. À lancer quand on modifie l'IA ou l'équilibrage :
##   Godot --headless --fixed-fps 60 --path . --script res://tests/tournament_ai.gd

var fight; var p; var d
var stats := {}

func new_stats() -> Dictionary:
	return {"hits": 0, "blocks": 0, "parries": 0, "dodges": 0, "projectiles": 0, "ultimates": 0, "assists": 0, "jumps": 0, "charges": 0}

func reset_stats():
	stats = {p: new_stats(), d: new_stats()}

func play_match(ai_p, ai_d, max_frames := 15000) -> Dictionary:
	fight.start_match()
	fight.tools.dummy_mode = fight.tools.DummyMode.AI
	fight.tools.ai = ai_d
	var prev := {p: p.state, d: d.state}
	var time_ups := 0
	var last_phase = fight.flow.phase
	for i in max_frames:
		if ai_p:
			ai_p.update(p, d, fight.projectiles)
		else:
			for k in p.intent: p.intent[k] = false
		await physics_frame
		for f in [p, d]:
			var o = d if f == p else p
			if f.state != prev[f]:
				if f.state == Fighter.State.BLOCKSTUN: stats[f].blocks += 1
				if f.state in [Fighter.State.HITSTUN, Fighter.State.KNOCKDOWN] and prev[f] not in [Fighter.State.HITSTUN, Fighter.State.KNOCKDOWN]: stats[o].hits += 1
				if f.state == Fighter.State.JUMP: stats[f].jumps += 1
				if f.state == Fighter.State.CHARGE: stats[f].charges += 1
				prev[f] = f.state
		if fight.hud.popup_label.visible and fight.hud.popup_label.text == "FIGHT_PARRY" and fight.hud.popup_frames == fight.hud.POPUP_FRAMES - 1:
			for f in [p, d]:
				if f.flash_frames > 0 and f.flash_color == Fighter.PARRY_FLASH: stats[f].parries += 1
		if fight.flow.phase == fight.flow.Phase.ROUND_OVER and last_phase == fight.flow.Phase.FIGHT and fight.flow.round_result_key == "FIGHT_TIME_UP":
			time_ups += 1
		last_phase = fight.flow.phase
		if fight.flow.phase == fight.flow.Phase.MATCH_OVER:
			break
	var winner := "nul"
	if fight.flow.player_wins > fight.flow.dummy_wins: winner = "P"
	elif fight.flow.dummy_wins > fight.flow.player_wins: winner = "D"
	return {"winner": winner, "score": "%d-%d" % [fight.flow.player_wins, fight.flow.dummy_wins], "time_ups": time_ups, "finished": fight.flow.phase == fight.flow.Phase.MATCH_OVER}

func _initialize():
	fight = load("res://scenes/fight/fight.tscn").instantiate()
	root.add_child(fight)
	await process_frame
	p = fight.get_node("Player"); d = fight.get_node("Dummy"); p.is_player = false
	fight.tools.dummy_mode = fight.tools.DummyMode.AI
	# Même fiche et même soutien des deux côtés, pour un duel équitable.
	d.data = p.data
	d.support = p.support
	for f in [p, d]:
		f.dodged.connect(func(): stats[f].dodges += 1)
		f.projectile_launched.connect(func(_a, _b): stats[f].projectiles += 1)
		f.ultimate_started.connect(func(_a): stats[f].ultimates += 1)
		f.assist_called.connect(func(_a): stats[f].assists += 1)
	var D = FighterAI.Difficulty
	var pairings = [["HARD", D.HARD, "EASY", D.EASY], ["HARD", D.HARD, "NORMAL", D.NORMAL], ["NORMAL", D.NORMAL, "HARD", D.HARD], ["NORMAL", D.NORMAL, "EASY", D.EASY], ["NORMAL", D.NORMAL, "NORMAL", D.NORMAL], ["EASY", D.EASY, "EASY", D.EASY]]
	var seed := 1
	for pr in pairings:
		var wins := {"P": 0, "D": 0, "nul": 0}
		var tu := 0
		var unfinished := 0
		reset_stats()
		for m in 8:
			seed += 1
			var res = await play_match(FighterAI.new(pr[1], seed * 7), FighterAI.new(pr[3], seed * 13))
			wins[res.winner] += 1
			tu += res.time_ups
			if not res.finished: unfinished += 1
		print("%s (joueur) contre %s (mannequin) : %d - %d (nuls %d), manches au chrono %d, matchs non finis %d" % [pr[0], pr[2], wins.P, wins.D, wins.nul, tu, unfinished])
		print("   joueur    : ", stats[p])
		print("   mannequin : ", stats[d])

	# IA normale contre un joueur qui ne fait rien.
	reset_stats()
	var res = await play_match(null, FighterAI.new(D.NORMAL, 99))
	print("NORMAL contre un joueur immobile : score ", res.score, " chrono ", res.time_ups, " -> ", stats[d])
	quit()
