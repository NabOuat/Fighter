extends SceneTree
## Le 3e coup du combo de chaque combattant devient un « lanceur » : il envoie
## l'adversaire en l'air, où on peut le jongler (sauter et frapper).
##   Godot --headless --path . --script res://tools/add_launchers.gd

## Vitesse de lancer vers le haut (330 = environ 0,7 seconde en l'air).
const LAUNCH := 330.0


func _initialize() -> void:
	for id in ["test_a", "test_b", "test_c", "abla_pokou"]:
		var path := "res://data/fighters/%s.tres" % id
		var fighter: FighterData = load(path)
		fighter.combo[2].launch = LAUNCH
		print(id, " : ", "ok" if ResourceSaver.save(fighter, path) == OK else "erreur")
	quit()
