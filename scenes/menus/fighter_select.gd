extends MenuScreen
## L'écran de sélection, avant un combat d'Arcade ou d'Entraînement :
## choisir son combattant, son soutien, la difficulté (et l'adversaire en
## entraînement, avec le décor). Les cartes sont créées à partir des personnages
## jouables de GameState (les combattants de test ne sont pas proposés).

const CARD_SIZE := Vector2(54, 54)
const SMALL_CARD_SIZE := Vector2(36, 26)
const ASSIST_KEYS := {
	AssistData.Kind.ATTACK: "SELECT_ASSIST_ATTACK",
	AssistData.Kind.PROTECT: "SELECT_ASSIST_PROTECT",
	AssistData.Kind.HEAL: "SELECT_ASSIST_HEAL",
}

var fighter: FighterData
var support: FighterData
var opponent: FighterData
var difficulty: FighterAI.Difficulty = GameState.difficulty

var _fighter_cards := {}
var _support_cards := {}
var _opponent_cards := {}
## Décors proposés en entraînement : « au hasard » puis chaque décor présent.
var _stage_choices: Array = []
var _stage_index := 0
var stage_button: Button

@onready var title_label: Label = %TitleLabel
@onready var fighter_cards: HBoxContainer = %FighterCards
@onready var support_cards: HBoxContainer = %SupportCards
@onready var opponent_heading: Label = %OpponentHeading
@onready var opponent_cards: HBoxContainer = %OpponentCards
@onready var difficulty_buttons: Array[Button] = [%EasyButton, %NormalButton, %HardButton]
@onready var name_label: Label = %NameLabel
@onready var power_pips: StatPips = %PowerPips
@onready var defense_pips: StatPips = %DefensePips
@onready var speed_pips: StatPips = %SpeedPips
@onready var assist_label: Label = %AssistLabel
@onready var back_button: Button = %BackButton
@onready var fight_button: Button = %FightButton


func _ready() -> void:
	var training := GameState.mode == GameState.Mode.TRAINING
	title_label.text = "MENU_TRAINING" if training else "MENU_ARCADE"
	opponent_heading.visible = training
	opponent_cards.visible = training
	var fighter_group := ButtonGroup.new()
	var support_group := ButtonGroup.new()
	var opponent_group := ButtonGroup.new()
	# Jouables : les débloqués. Soutiens et adversaires d'entraînement : aussi ceux
	# qu'on a déjà battus (règle du cahier des charges).
	for data in GameState.playable_roster():
		_fighter_cards[data] = _add_card(fighter_cards, data, CARD_SIZE, fighter_group, select_fighter)
	for data in GameState.support_roster():
		_support_cards[data] = _add_card(support_cards, data, SMALL_CARD_SIZE, support_group, select_support)
		_opponent_cards[data] = _add_card(opponent_cards, data, SMALL_CARD_SIZE, opponent_group, select_opponent)
	var difficulty_group := ButtonGroup.new()
	for i in difficulty_buttons.size():
		difficulty_buttons[i].toggle_mode = true
		difficulty_buttons[i].button_group = difficulty_group
		difficulty_buttons[i].pressed.connect(select_difficulty.bind(i))
	back_button.pressed.connect(go_back)
	fight_button.pressed.connect(start)
	if training:
		_add_stage_button()

	# Choix de départ : le dernier combattant joué, sinon le premier.
	var heroes := GameState.playable_roster()
	var first: FighterData = GameState.player_fighter if GameState.player_fighter in heroes else heroes[0]
	select_fighter(first)
	if GameState.player_support in _support_cards and GameState.player_support != first:
		select_support(GameState.player_support)
	var foes := GameState.support_roster()
	select_opponent(foes[(foes.find(first) + 1) % foes.size()])
	select_difficulty(difficulty)
	focus_first(fight_button)


func _add_card(row: HBoxContainer, data: FighterData, card_size: Vector2, group: ButtonGroup, on_pressed: Callable) -> Button:
	var card := Button.new()
	card.toggle_mode = true
	card.button_group = group
	card.custom_minimum_size = card_size
	card.pressed.connect(on_pressed.bind(data))
	# Le portrait : l'image si elle existe, sinon la couleur du combattant.
	var portrait: Control
	var picture: Texture2D = data.portrait
	# Pas de portrait : la première image d'attente du personnage dessiné.
	if picture == null and data.sprite_frames and data.sprite_frames.has_animation(&"idle"):
		picture = data.sprite_frames.get_frame_texture(&"idle", 0)
	if picture:
		portrait = TextureRect.new()
		portrait.texture = picture
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	else:
		portrait = ColorRect.new()
		portrait.color = data.placeholder_color
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var name_height := 11.0 if card_size.y > 40 else 0.0
	portrait.offset_left = 4
	portrait.offset_top = 4
	portrait.offset_right = -4
	portrait.offset_bottom = -4 - name_height
	card.add_child(portrait)
	if name_height > 0:
		var label := Label.new()
		label.text = data.name_key
		label.add_theme_font_size_override("font_size", 7)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		label.offset_top = -13
		label.offset_bottom = -2
		card.add_child(label)
	else:
		card.tooltip_text = data.name_key
	row.add_child(card)
	return card


func select_fighter(data: FighterData) -> void:
	fighter = data
	_fighter_cards[data].button_pressed = true
	name_label.text = data.name_key
	power_pips.value = data.power
	defense_pips.value = data.defense
	speed_pips.value = data.speed
	# On ne peut pas être son propre soutien : le soutien change si besoin.
	for other in _support_cards:
		_support_cards[other].disabled = other == data
	if support == null or support == data:
		support = null
		assist_label.text = tr("SELECT_NO_SUPPORT")
		for other in _support_cards:
			if other != data:
				select_support(other)
				break


func select_support(data: FighterData) -> void:
	if data == fighter:
		return
	support = data
	_support_cards[data].button_pressed = true
	var kind_key: String = ASSIST_KEYS[data.assist.kind] if data.assist else "SELECT_ASSIST_NONE"
	assist_label.text = tr("SELECT_SUPPORT_IS") % [tr(data.name_key), tr(kind_key)]


func select_opponent(data: FighterData) -> void:
	opponent = data
	_opponent_cards[data].button_pressed = true


func select_difficulty(level: int) -> void:
	difficulty = level as FighterAI.Difficulty
	difficulty_buttons[level].button_pressed = true


## Lance le combat avec les choix faits.
func start() -> void:
	if GameState.mode == GameState.Mode.TRAINING:
		GameState.training_stage = selected_stage()
		GameState.start_training(fighter, support, opponent, difficulty)
	else:
		GameState.start_arcade(fighter, support, difficulty)
	GameState.go_to(GameState.FIGHT)


## Bouton « Décor » (entraînement) : une vignette du décor ; chaque appui passe au suivant.
func _add_stage_button() -> void:
	_stage_choices = [GameState.RANDOM_STAGE] + GameState.available_stages()
	_stage_index = maxi(0, _stage_choices.find(GameState.training_stage))
	stage_button = Button.new()
	stage_button.custom_minimum_size = Vector2(150, 40)
	stage_button.add_theme_font_size_override("font_size", 8)
	stage_button.expand_icon = true
	stage_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	stage_button.pressed.connect(next_stage)
	$Info/Box.add_child(stage_button)
	_refresh_stage()


func next_stage() -> void:
	_stage_index = (_stage_index + 1) % _stage_choices.size()
	_refresh_stage()


func selected_stage() -> String:
	return _stage_choices[_stage_index] if not _stage_choices.is_empty() else ""


func _refresh_stage() -> void:
	var id: String = selected_stage()
	var name_key := "STAGE_RANDOM" if id == GameState.RANDOM_STAGE else "STAGE_" + id.to_upper()
	stage_button.text = tr("SELECT_STAGE") % tr(name_key)
	stage_button.icon = load(Stage.texture_path(id, "back")) if Stage.exists(id) else null


func go_back() -> void:
	GameState.go_to(GameState.MAIN_MENU)
