extends "res://tests/test_base.gd"
## Tests des contrôles tactiles (étape 6) : de faux doigts appuient sur l'écran.

const ACTIONS := ["move_left", "move_right", "jump", "crouch", "attack", "special", "guard", "assist", "ultimate"]
const STICK := Vector2(62, 212)


## Les positions sont données dans l'écran du jeu (480 x 270), puis converties
## en coordonnées de la fenêtre, comme un vrai doigt.
func touch(index: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = root.get_final_transform() * position
	event.pressed = pressed
	Input.parse_input_event(event)


func drag(index: int, position: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = root.get_final_transform() * position
	Input.parse_input_event(event)


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func held() -> Array:
	return ACTIONS.filter(func(action): return Input.is_action_pressed(action))


func _initialize() -> void:
	await start_arena()
	# Ici le joueur doit lire les vraies commandes (les faux doigts), pas le test.
	p.is_player = true
	var controls = fight.get_node("TouchControls")
	check("contrôles affichés et reliés au joueur", controls.visible and controls.fighter == p)

	section("Joystick")
	touch(0, STICK, true)
	await frames(1)
	drag(0, STICK + Vector2(24, 0))
	await frames(10)
	check("à droite : avance", held() == ["move_right"] and p.state == Fighter.State.WALK, str(held()))
	drag(0, STICK + Vector2(-24, 0))
	await frames(2)
	check("à gauche", held() == ["move_left"], str(held()))
	drag(0, STICK + Vector2(0, 24))
	await frames(2)
	check("en bas : s'accroupit", held() == ["crouch"] and p.state == Fighter.State.CROUCH, str(held()))
	drag(0, STICK + Vector2(3, 3))
	await frames(2)
	check("zone morte : rien", held().is_empty(), str(held()))
	drag(0, STICK + Vector2(20, -22))
	await frames(2)
	check("diagonale haut-droite : saute en avançant", held() == ["move_right", "jump"], str(held()))
	touch(0, STICK, false)
	await frames(2)
	check("pouce levé : tout est relâché", held().is_empty(), str(held()))
	await frames(40)

	section("Boutons")
	touch(0, STICK, true)
	drag(0, STICK + Vector2(24, 0))
	touch(1, Vector2(430, 222), true)
	await frames(1)
	check("deux doigts : avancer et frapper en même temps", held() == ["move_right", "attack"], str(held()))
	touch(1, Vector2(430, 222), false)
	touch(0, STICK, false)
	await frames(30)
	for button in [["Spécial", Vector2(378, 240), "special"], ["Garde", Vector2(448, 170), "guard"], ["Soutien", Vector2(396, 190), "assist"], ["Ultime", Vector2(448, 124), "ultimate"]]:
		touch(2, button[1], true)
		await frames(1)
		var pressed := Input.is_action_pressed(button[2])
		touch(2, button[1], false)
		await frames(20)
		check("bouton %s" % button[0], pressed)

	p.energy = 0.0
	await frames(2)
	check("Ultime grisé sans énergie", controls.get_node("Ultimate/Look").dimmed)
	p.energy = Fighter.MAX_ENERGY
	await frames(2)
	check("Ultime actif avec la barre pleine", not controls.get_node("Ultimate/Look").dimmed)

	finish()
