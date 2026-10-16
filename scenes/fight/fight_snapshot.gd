class_name FightSnapshot
extends RefCounted
## Une « photo » de tout l'état du combat à une frame : les deux combattants,
## le déroulement (manche, chrono), les arrêts sur image, les projectiles et
## les soutiens. C'est la base du rollback du jeu en ligne : on photographie
## chaque frame, et quand la vraie commande de l'adversaire arrive en retard,
## on recharge la photo de cette frame et on rejoue jusqu'à maintenant.
##
## Ne contient que des données (pas de nœuds) : la recharger recrée les
## projectiles et soutiens à l'identique.

## Les variables de l'arène qui font partie de l'état du combat.
const ARENA_VARS := ["frame_count", "hitstop", "ultimate_freeze", "slowmo_frames"]


static func capture(fight: Node) -> Dictionary:
	var fighters: Array = fight.fighters
	var snapshot := {}
	for key in ARENA_VARS:
		snapshot[key] = fight.get(key)
	snapshot["fighters"] = fighters.map(func(f: Fighter) -> Dictionary: return f.get_state())
	snapshot["flow"] = fight.flow.get_state()
	var projectiles := []
	for projectile: Projectile in fight.projectiles:
		var saved := projectile.get_state()
		saved["shooter"] = fighters.find(projectile.shooter)
		projectiles.append(saved)
	snapshot["projectiles"] = projectiles
	var assists := []
	for assist: Assist in fight.assists:
		var saved := assist.get_state()
		saved["caller"] = fighters.find(assist.caller)
		assists.append(saved)
	snapshot["assists"] = assists
	return snapshot


static func restore(fight: Node, snapshot: Dictionary) -> void:
	for key in ARENA_VARS:
		fight.set(key, snapshot[key])
	for i in fight.fighters.size():
		fight.fighters[i].set_state(snapshot.fighters[i])
	fight.flow.set_state(snapshot.flow)
	fight.restore_effects(snapshot.projectiles, snapshot.assists)


## Une empreinte (un nombre) de l'état : deux téléphones qui ont le même combat
## ont la même empreinte. On les compare pour détecter une désynchronisation.
static func checksum(snapshot: Dictionary) -> int:
	var values := []
	for key in ARENA_VARS:
		values.append(snapshot[key])
	for saved in snapshot.fighters:
		values.append_array([saved.position.x, saved.position.y, saved.velocity.x, saved.velocity.y,
				saved.health, saved.energy, saved.state, saved.facing, saved.attack_frame,
				saved.stun_frames, saved.combo_hits, saved.juggle_hits, saved.assist_cooldown])
	var flow: Dictionary = snapshot.flow
	values.append_array([flow.phase, flow.phase_frames, flow.timer_frames, flow.player_wins, flow.dummy_wins])
	for saved in snapshot.projectiles:
		values.append_array([saved.position.x, saved.age, saved.shooter])
	for saved in snapshot.assists:
		values.append_array([saved.position.x, saved.frame, saved.caller])
	return hash(var_to_bytes(values))
