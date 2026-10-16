extends "res://tests/test_base.gd"
## Tests du rollback (jeu en ligne), sans réseau :
## 1. rien n'est oublié dans la sauvegarde de l'état (chaque variable est
##    soit sauvegardée, soit un réglage qui ne change pas pendant le combat) ;
## 2. recharger une photo et rejouer les mêmes commandes donne exactement le
##    même combat ;
## 3. deux joueurs reliés par un faux réseau (retard, irrégularité, désordre)
##    finissent avec exactement le même combat qu'un combat joué sans réseau.

## Les variables qui ne font PAS partie de l'état du combat (réglages donnés au
## départ, nœuds d'affichage, ou sauvegardées à part). Toute autre variable doit
## être dans STATE_VARS.
const NOT_STATE := {
	"Fighter": ["data", "is_player", "show_boxes", "show_markers", "opponent", "support", "immortal",
			"special_hold_charges", "floor_y", "needs_redraw", "view", "intent"],
	"Projectile": ["shooter"],
	"Assist": ["caller", "_body", "_effect"],
	"MatchFlow": ["round_winners", "_player", "_dummy"],
	"Fight": ["training", "projectiles", "assists", "art_camera", "player", "dummy", "fighters", "flow",
			"feedback", "match_log", "hud", "tools", "dim", "touch_controls", "pause_menu",
			"match_result", "camera", "stage"],
}
const FRAMES := 2400

var gs: Node
## Commandes jouées par chaque joueur, frame par frame (identiques partout).
var inputs: Array = [[], []]


## Les variables déclarées dans un script.
func script_vars(object: Object) -> Array[String]:
	var names: Array[String] = []
	for property in object.get_script().get_script_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			names.append(property.name)
	return names


func check_state_vars(label: String, object: Object, state_vars: Array) -> void:
	var missing := []
	for name in script_vars(object):
		if name not in state_vars and name not in NOT_STATE[label]:
			missing.append(name)
	check("%s : toutes les variables de jeu sont sauvegardées" % label, missing.is_empty(), "oubliées : %s" % str(missing))


## Une arène pilotée à la main (frame par frame), sans clavier ni IA.
func new_arena() -> Node:
	var arena = load(FIGHT_SCENE).instantiate()
	root.add_child(arena)
	# Tout de suite (avant la moindre frame jouée par Godot) : c'est le test qui
	# fait avancer le combat, sinon les arènes ne partiraient pas du même état.
	arena.set_physics_process(false)
	await process_frame
	var a: Fighter = arena.player
	var b: Fighter = arena.dummy
	a.is_player = false
	a.data = gs.fighter_by_id(&"itsa")
	b.data = gs.fighter_by_id(&"test_c")
	a.support = gs.fighter_by_id(&"test_a")
	b.support = gs.fighter_by_id(&"test_c")
	arena.art_camera = true
	arena.start_match()
	# Barre pleine dès le début (spéciaux, projectiles et ultimes) et peu de vie
	# (des K.O. et des changements de manche pendant le test).
	for fighter in arena.fighters:
		fighter.energy = Fighter.MAX_ENERGY
		fighter.health = 250
	return arena


## Un faux joueur au hasard (graine fixe) : il tient une direction un moment
## (surtout vers l'adversaire, là où il est vraiment), garde, saute, s'accroupit,
## charge, tapote Spécial (projectiles) et appuie souvent sur les boutons.
## Ses commandes sont enregistrées puis rejouées à l'identique en ligne.
class InputBot:
	var rng := RandomNumberGenerator.new()
	var held := ""
	var special_tap := 0

	func _init(seed: int) -> void:
		rng.seed = seed

	func next(me: Fighter) -> int:
		var distance := absf(me.opponent.position.x - me.position.x)
		var near := distance < 42.0
		if rng.randf() < 0.08:
			var roll := rng.randf()
			held = ""
			if roll < (0.75 if not near else 0.3):
				held = "toward"
			elif roll < 0.62:
				held = "away"
			elif roll < 0.7:
				held = "crouch"
			elif roll < 0.82:
				held = "guard"
			elif roll < 0.9:
				held = "jump"
			elif roll < 0.92:
				held = "special"
		var bits := 0
		var toward := "right" if me.opponent.position.x > me.position.x else "left"
		match held:
			"toward":
				bits |= 1 << NetInput.KEYS.find(toward)
			"away":
				bits |= 1 << NetInput.KEYS.find("left" if toward == "right" else "right")
			"":
				pass
			_:
				bits |= 1 << NetInput.KEYS.find(held)
		# De loin : appui court sur Spécial sans direction (3 frames) = projectile.
		var full := me.energy >= Fighter.MAX_ENERGY
		if special_tap == 0 and not full and me.energy >= Fighter.ENERGY_SEGMENT and rng.randf() < (0.03 if not near else 0.01):
			special_tap = 3
		if special_tap > 0:
			special_tap -= 1
			bits = 1 << NetInput.KEYS.find("special")
		# Barre pleine : gardée pour l'ultime, lancé de près.
		if full and near and rng.randf() < 0.1:
			bits |= 1 << NetInput.KEYS.find("ultimate")
		# De près : les boutons (attaque surtout).
		var presses := ["attack", "attack", "attack", "attack", "guard_pressed", "special_2", "throw", "low_attack"] if near else ["assist"]
		for key in presses:
			if rng.randf() < 0.025:
				bits |= 1 << NetInput.KEYS.find(key)
		return bits


func inputs_at(f: int) -> Array[int]:
	var both: Array[int] = [inputs[0][f], inputs[1][f]]
	return both


func _initialize() -> void:
	gs = await use_test_settings()
	gs.dry_run = true

	section("Rien n'est oublié dans la sauvegarde")
	var arena = await new_arena()
	check_state_vars("Fighter", arena.player, Fighter.STATE_VARS)
	check_state_vars("MatchFlow", arena.flow, MatchFlow.STATE_VARS)
	check_state_vars("Fight", arena, FightSnapshot.ARENA_VARS)
	var projectile := Projectile.new()
	check_state_vars("Projectile", projectile, Projectile.STATE_VARS)
	projectile.free()
	var assist := Assist.new()
	check_state_vars("Assist", assist, Assist.STATE_VARS)
	assist.free()

	section("Combat de référence (sans réseau)")
	var reference = await new_arena()
	var covered := {"coups": 0, "projectiles": 0, "soutiens": 0, "jonglages": 0, "manches": 0, "ultimes": 0}
	reference.hit_landed.connect(func(_r, _a, _b, _c) -> void: covered.coups += 1)
	reference.flow.round_ended.connect(func(_ko: bool) -> void: covered.manches += 1)
	for fighter in reference.fighters:
		fighter.ultimate_started.connect(func(_f: Fighter) -> void: covered.ultimes += 1)
	var had := {"projectiles": false, "assists": false, "juggle": false}
	# Autre combat possible : Godot ... --script res://tests/test_rollback.gd -- <graine>
	var args := OS.get_cmdline_user_args()
	var seed_base: int = int(args[0]) if args.size() > 0 else 0
	var bots := [InputBot.new(101 + seed_base), InputBot.new(202 + seed_base)]
	inputs = [[], []]
	for f in FRAMES + RollbackSession.INPUT_DELAY:
		for i in 2:
			var early := f < RollbackSession.INPUT_DELAY or f >= FRAMES
			inputs[i].append(0 if early else bots[i].next(reference.fighters[i]))
		if f >= FRAMES:
			continue
		reference.step_with_inputs(inputs_at(f))
		if reference.projectiles.size() > 0 and not had.projectiles:
			covered.projectiles += 1
		if reference.assists.size() > 0 and not had.assists:
			covered.soutiens += 1
		var juggling: bool = reference.player.state == Fighter.State.JUGGLE or reference.dummy.state == Fighter.State.JUGGLE
		if juggling and not had.juggle:
			covered.jonglages += 1
		had = {"projectiles": reference.projectiles.size() > 0, "assists": reference.assists.size() > 0, "juggle": juggling}
	var expected: int = reference.state_checksum(reference.save_state())
	check("combat de référence joué", reference.frame_count == FRAMES)
	check("il contient coups, projectiles, soutiens, jonglages, ultimes et fins de manche",
			covered.coups >= 20 and covered.projectiles >= 1 and covered.soutiens >= 2 and covered.jonglages >= 1
			and covered.ultimes >= 1 and covered.manches >= 1, str(covered))
	reference.queue_free()

	section("Recharger une photo et rejouer = même combat")
	# Les deux commencent avec la barre pleine : spéciaux, projectiles et ultimes.
	var seen := {"projectiles": 0, "assists": 0, "hits": 0}
	arena.hit_landed.connect(func(_r, _a, _b, _c) -> void: seen.hits += 1)
	for f in 400:
		arena.step_with_inputs(inputs_at(f))
	var photo: Dictionary = arena.save_state()
	var first_run: Array[int] = []
	for f in range(400, 2300):
		arena.step_with_inputs(inputs_at(f))
		first_run.append(arena.state_checksum(arena.save_state()))
		seen.projectiles = maxi(seen.projectiles, arena.projectiles.size())
		seen.assists = maxi(seen.assists, arena.assists.size())
	arena.load_state(photo)
	check("la photo rechargée a la même empreinte", arena.state_checksum(arena.save_state()) == arena.state_checksum(photo))
	var second_run: Array[int] = []
	for f in range(400, 2300):
		arena.step_with_inputs(inputs_at(f), true)
		second_run.append(arena.state_checksum(arena.save_state()))
	var differ := -1
	for i in first_run.size():
		if first_run[i] != second_run[i]:
			differ = i + 400
			break
	check("1900 frames rejouées à l'identique", differ == -1, "différence à la frame %d" % differ)
	check("le passage rejoué contient coups, projectiles et soutiens", seen.hits > 20 and seen.projectiles > 0 and seen.assists > 0, str(seen))
	arena.render()
	arena.queue_free()

	section("Effets (sons, étincelles) pendant un retour en arrière")
	# Comme le rollback : photo, 8 frames jouées, retour à la photo, 8 frames rejouées.
	var fx_arena = await new_arena()
	for f in 400:
		fx_arena.step_with_inputs(inputs_at(f))
	var played_first := 0
	var doubled := 0
	var discovered := 0
	for start in range(400, 2280, 8):
		var before: Dictionary = fx_arena.save_state()
		var count: int = fx_arena.feedback.effects_played
		# 1re fois : l'adversaire n'appuie sur rien (une devinette fausse).
		for f in range(start, start + 8):
			var guessed: Array[int] = [inputs[0][f], NetInput.predict(inputs[1][start - 1])]
			fx_arena.step_with_inputs(guessed)
		var after_guess: int = fx_arena.feedback.effects_played
		played_first += after_guess - count
		# On rejoue avec les vraies commandes : seuls les effets nouveaux se jouent.
		fx_arena.load_state(before)
		for f in range(start, start + 8):
			fx_arena.step_with_inputs(inputs_at(f), true)
		discovered += fx_arena.feedback.effects_played - after_guess
		# Encore une fois à l'identique : plus rien de nouveau ne doit se jouer.
		var settled: int = fx_arena.feedback.effects_played
		fx_arena.load_state(before)
		for f in range(start, start + 8):
			fx_arena.step_with_inputs(inputs_at(f), true)
		doubled += fx_arena.feedback.effects_played - settled
	check("rejouer à l'identique ne relance aucun effet", doubled == 0, "%d effets en double" % doubled)
	check("les effets découverts en rejouant se jouent", discovered > 0 and played_first > 0,
			"%d joués, %d découverts" % [played_first, discovered])
	fx_arena.queue_free()

	section("Messages abîmés et désynchronisation")
	var guard_arena = await new_arena()
	var lonely := RollbackSession.new(guard_arena, 0)
	var broken := [null, 12, "texte", {}, {"t": "in"}, {"t": "in", "f": -5, "i": [], "a": 0, "fr": 0, "adv": 0},
			{"t": "in", "f": 0, "i": [1 << 20], "a": 0, "fr": 0, "adv": 0},
			{"t": "in", "f": 0, "i": ["x"], "a": 0, "fr": 0, "adv": 0},
			{"t": "in", "f": 0.5, "i": [], "a": 0, "fr": 0, "adv": 0},
			{"t": "in", "f": 0, "i": range(500), "a": 0, "fr": 0, "adv": 0},
			{"t": "in", "f": 0, "i": [], "a": 0, "fr": 0, "adv": 0, "s": {"abc": 1}},
			{"t": "in", "f": 100000, "i": [1], "a": 0, "fr": 0, "adv": 0},
			{"t": "in", "f": 0, "i": [], "a": 0, "fr": 0, "adv": 0, "s": {"60": 1, "120": 1, "180": 1, "240": 1, "300": 1, "360": 1, "420": 1, "480": 1, "540": 1}}]
	var accepted := 0
	for packet in broken:
		if lonely.is_valid_packet(packet):
			accepted += 1
		lonely.receive(packet)
	check("les messages abîmés sont ignorés (sans planter)", accepted == 0, "%d acceptés" % accepted)
	check("un message correct est accepté", lonely.is_valid_packet(JSON.parse_string(JSON.stringify(lonely.make_packet()))))
	guard_arena.queue_free()
	# Un des deux combats est faussé (vie changée) : les empreintes doivent le voir.
	var pair := [await new_arena(), await new_arena()]
	var twins: Array[RollbackSession] = [RollbackSession.new(pair[0], 0), RollbackSession.new(pair[1], 1)]
	var noticed := [0]
	twins[0].desync_detected.connect(func(_f: int) -> void: noticed[0] += 1)
	twins[1].desync_detected.connect(func(_f: int) -> void: noticed[0] += 1)
	for t in 300:
		if t == 100:
			pair[1].dummy.health -= 1
		for i in 2:
			twins[i].advance(inputs[i][twins[i].frame + RollbackSession.INPUT_DELAY])
		for i in 2:
			twins[1 - i].receive(JSON.parse_string(JSON.stringify(twins[i].make_packet())))
	check("un combat faussé est détecté (désynchronisation)", noticed[0] > 0)
	for arena_left in pair:
		arena_left.queue_free()

	# Faux réseau : [retard aller (frames), retard retour, irrégularité].
	for scenario in [[1, 1, 0], [6, 6, 0], [9, 9, 3], [3, 12, 2], [15, 15, 4]]:
		await play_online(scenario[0], scenario[1], scenario[2], expected)

	finish()


## Deux joueurs reliés par un faux réseau. delay_ab : frames pour qu'un message
## de A arrive chez B (et inversement), jitter : irrégularité (messages en désordre).
func play_online(delay_ab: int, delay_ba: int, jitter: int, expected: int) -> void:
	var ms := func(frames: int) -> int: return roundi(frames * 1000.0 / 60.0)
	section("En ligne : retard %d ms / %d ms, irrégularité ± %d ms" % [ms.call(delay_ab), ms.call(delay_ba), ms.call(jitter)])
	var arenas := [await new_arena(), await new_arena()]
	var sessions: Array[RollbackSession] = [RollbackSession.new(arenas[0], 0), RollbackSession.new(arenas[1], 1)]
	var desyncs := [0]
	for session in sessions:
		session.desync_detected.connect(func(_f: int) -> void: desyncs[0] += 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = delay_ab * 1000 + delay_ba * 10 + jitter
	# Messages en route : [heure d'arrivée, destinataire, message].
	var in_flight := []
	var delays := [delay_ab, delay_ba]
	var tick := 0
	var max_predicted := 0
	while tick < FRAMES * 3:
		tick += 1
		var still := []
		for message in in_flight:
			if message[0] <= tick:
				sessions[message[1]].receive(message[2])
			else:
				still.append(message)
		in_flight = still
		var done := true
		for i in 2:
			var session := sessions[i]
			session.rollback()
			if session.frame < FRAMES and session.can_advance():
				session.advance(inputs[i][session.frame + RollbackSession.INPUT_DELAY])
			max_predicted = maxi(max_predicted, session.predicted_frames())
			# Chaque message est copié (comme s'il passait par le réseau en JSON).
			var packet: Dictionary = JSON.parse_string(JSON.stringify(session.make_packet()))
			var arrival: int = tick + delays[i] + (rng.randi_range(-jitter, jitter) if jitter > 0 else 0)
			in_flight.append([maxi(arrival, tick + 1), 1 - i, packet])
			done = done and session.frame >= FRAMES and session.predicted_frames() <= 0
		if done:
			break
	for i in 2:
		arenas[i].render()
	var sums: Array[int] = [arenas[0].state_checksum(arenas[0].save_state()), arenas[1].state_checksum(arenas[1].save_state())]
	check("les deux joueurs ont joué les %d frames" % FRAMES, sessions[0].frame == FRAMES and sessions[1].frame == FRAMES,
			"%d / %d" % [sessions[0].frame, sessions[1].frame])
	check("même combat chez les deux joueurs et qu'en local", sums[0] == expected and sums[1] == expected)
	check("aucune désynchronisation détectée", desyncs[0] == 0, str(desyncs[0]))
	var rollbacks := sessions[0].rollback_count + sessions[1].rollback_count
	var longest := maxi(sessions[0].longest_rollback, sessions[1].longest_rollback)
	if delay_ab > 2:
		check("des retours en arrière ont eu lieu (le test sert)", rollbacks > 0, str(rollbacks))
	check("retours en arrière jamais plus longs que %d frames" % RollbackSession.MAX_ROLLBACK, longest <= RollbackSession.MAX_ROLLBACK + 1, str(longest))
	print("         (retours en arrière : %d, le plus long : %d frames, attentes : %d, temps total : %d frames)" % [
			rollbacks, longest, sessions[0].wait_count + sessions[1].wait_count, tick])
	for arena in arenas:
		arena.queue_free()
	await process_frame
