extends MenuScreen
## Le menu principal : Histoire, Arcade, Entraînement, Tutoriel, Encyclopédie, Réglages.
## Histoire et Encyclopédie sont grisés (« bientôt ») tant qu'ils n'existent pas.

const SETTINGS_SCENE := preload("res://scenes/menus/settings_menu.tscn")

@onready var story_button: Button = %StoryButton
@onready var arcade_button: Button = %ArcadeButton
@onready var training_button: Button = %TrainingButton
@onready var tutorial_button: Button = %TutorialButton
@onready var encyclopedia_button: Button = %EncyclopediaButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	arcade_button.pressed.connect(_open_select.bind(GameState.Mode.ARCADE))
	training_button.pressed.connect(_open_select.bind(GameState.Mode.TRAINING))
	tutorial_button.pressed.connect(start_tutorial)
	settings_button.pressed.connect(open_settings)
	quit_button.pressed.connect(get_tree().quit)
	# Sur téléphone, on quitte avec le bouton « retour » : pas de bouton Quitter.
	quit_button.visible = not OS.has_feature("mobile")
	_refresh_texts()
	focus_first(arcade_button)


func _notification(what: int) -> void:
	super(what)
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_texts()


## Les modes pas encore faits affichent « (bientôt) ».
func _refresh_texts() -> void:
	story_button.text = "%s  (%s)" % [tr("MENU_STORY"), tr("MENU_SOON")]
	encyclopedia_button.text = "%s  (%s)" % [tr("MENU_ENCYCLOPEDIA"), tr("MENU_SOON")]


func _open_select(mode: GameState.Mode) -> void:
	GameState.mode = mode
	GameState.go_to(GameState.FIGHTER_SELECT)


## Le tutoriel se joue directement, sans écran de sélection.
func start_tutorial() -> void:
	GameState.mode = GameState.Mode.TUTORIAL
	GameState.go_to(GameState.FIGHT)


func open_settings() -> SettingsMenu:
	var settings: SettingsMenu = SETTINGS_SCENE.instantiate()
	add_child(settings)
	settings.closed.connect(focus_first.bind(settings_button))
	return settings


func go_back() -> void:
	GameState.go_to(GameState.TITLE_SCREEN)
