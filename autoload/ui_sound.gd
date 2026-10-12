extends Node
## Le « clic » des boutons de menu, en un seul endroit.
##
## Autoload : chaque bouton qui apparaît dans le jeu est repéré automatiquement
## et joue le clic quand on appuie dessus. Rien à faire dans les menus.

const CLICK := preload("res://assets/audio/sfx/ui_click.wav")

var _player := AudioStreamPlayer.new()


func _ready() -> void:
	# Le clic doit marcher aussi dans le menu pause.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player.stream = CLICK
	_player.bus = &"SFX"
	_player.volume_db = -6.0
	add_child(_player)
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is BaseButton and not node.pressed.is_connected(play):
		node.pressed.connect(play)


func play() -> void:
	_player.play()


func _exit_tree() -> void:
	_player.stop()
