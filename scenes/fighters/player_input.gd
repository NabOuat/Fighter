class_name PlayerInput
extends RefCounted
## Lit les commandes du joueur (clavier, manette, boutons tactiles) et remplit
## les « intentions » du combattant. L'IA remplit les mêmes intentions à sa façon.

## Actions en plus du mode simple, créées au démarrage (voir GameState) :
## des raccourcis en un seul appui pour le tactile.
## nom de l'action : touche du clavier (pour tester sur ordinateur).
const EXTRA_ACTIONS := {
	"throw": KEY_H,
	"special_2": KEY_B,
	"low_attack": KEY_N,
	"charge": KEY_C,
}


## Crée les actions « en plus » si elles n'existent pas encore.
static func register_extra_actions() -> void:
	for action in EXTRA_ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var key := InputEventKey.new()
		key.physical_keycode = EXTRA_ACTIONS[action]
		InputMap.action_add_event(action, key)


static func read(intent: Dictionary) -> void:
	intent.left = Input.is_action_pressed("move_left")
	intent.right = Input.is_action_pressed("move_right")
	intent.jump = Input.is_action_pressed("jump")
	intent.crouch = Input.is_action_pressed("crouch")
	intent.guard = Input.is_action_pressed("guard")
	intent.attack = Input.is_action_just_pressed("attack")
	intent.guard_pressed = Input.is_action_just_pressed("guard")
	intent.special = Input.is_action_pressed("special")
	intent.ultimate = Input.is_action_just_pressed("ultimate")
	intent.assist = Input.is_action_just_pressed("assist")
	intent.throw = Input.is_action_just_pressed("throw")
	intent.special_2 = Input.is_action_just_pressed("special_2")
	intent.low_attack = Input.is_action_just_pressed("low_attack")
	intent.charge = Input.is_action_pressed("charge")
