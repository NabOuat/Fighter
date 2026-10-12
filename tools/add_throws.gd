extends SceneTree
## Ajoute une projection (saisie) aux combattants de test.
## Godot --headless --path . --script res://tools/add_throws.gd

func _initialize() -> void:
	for id in ["test_a", "test_b", "test_c"]:
		var path := "res://data/fighters/%s.tres" % id
		var fighter: FighterData = load(path)
		var throw := AttackData.new()
		throw.startup = 3
		throw.active = 2
		throw.recovery = 24
		throw.damage = 110
		throw.hitstun = 20
		throw.pushback = 130.0
		throw.knockdown = true
		throw.hitstop = 9
		throw.is_throw = true
		throw.hitbox = Rect2(4, -44, 24, 44)
		fighter.throw = throw
		var err := ResourceSaver.save(fighter, path)
		print(id, " : ", "ok" if err == OK else "erreur %d" % err)
	quit()
