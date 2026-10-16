class_name StoryMap
extends MenuScreen
## La carte des chapitres du mode Histoire (arc d'Abla Pokou).
##
## Un bouton par chapitre : verrouillé tant que le précédent n'est pas fini,
## « À jouer » ou « Terminé ». Au retour d'un chapitre fini, elle annonce ce qui
## vient d'être débloqué (nouveau soutien, nouveau personnage jouable).

## Taille d'un bouton de chapitre.
const CHAPTER_SIZE := Vector2(108, 62)
## Couleur du texte d'un chapitre terminé.
const DONE_COLOR := Color("e6ad3c")

var chapter_buttons: Array[Button] = []

@onready var chapters_grid: GridContainer = %Chapters
@onready var unlock_label: Label = %UnlockLabel
@onready var back_button: Button = %BackButton


func _ready() -> void:
	back_button.pressed.connect(go_back)
	var story := GameState.story
	var to_focus: Button = null
	for i in story.chapters().size():
		var button := Button.new()
		button.custom_minimum_size = CHAPTER_SIZE
		button.add_theme_font_size_override("font_size", 9)
		button.disabled = not story.is_open(i)
		if story.is_completed(i):
			button.add_theme_color_override("font_color", DONE_COLOR)
		button.pressed.connect(open_chapter.bind(i))
		chapters_grid.add_child(button)
		chapter_buttons.append(button)
		# Le focus va au premier chapitre ouvert pas encore terminé.
		if to_focus == null and story.is_open(i) and not story.is_completed(i):
			to_focus = button
	_refresh_texts()
	unlock_label.text = _unlock_text()
	# L'annonce n'est faite qu'une fois.
	story.chapter_index = -1
	story.just_unlocked = []
	focus_first(to_focus if to_focus else chapter_buttons[0])


func _notification(what: int) -> void:
	super(what)
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_texts()


## « Chapitre 2 / L'héritier écarté / Terminé » sur chaque bouton.
func _refresh_texts() -> void:
	var story := GameState.story
	for i in chapter_buttons.size():
		var status := "STORY_NEW"
		if not story.is_open(i):
			status = "STORY_LOCKED"
		elif story.is_completed(i):
			status = "STORY_DONE"
		chapter_buttons[i].text = "%s\n%s\n%s" % [tr("STORY_CHAPTER_N") % (i + 1),
				tr(story.chapters()[i].title), tr(status)]


## Le texte affiché au retour d'un chapitre terminé (vide sinon).
func _unlock_text() -> String:
	var story := GameState.story
	if story.chapter_index < 0 or story.step_index < story.current_chapter().steps.size():
		return ""
	var lines: Array[String] = ["%s : %s" % [tr("STORY_CHAPTER_DONE"), tr(story.current_chapter().title)]]
	for unlock in story.just_unlocked:
		var fighter: FighterData = GameState.fighter_by_id(unlock[1])
		if fighter:
			lines.append(tr(unlock[0]) % tr(fighter.name_key))
	return "\n".join(lines)


## Lance un chapitre depuis le début (cases du griot ou premier combat).
func open_chapter(index: int) -> void:
	GameState.mode = GameState.Mode.STORY
	GameState.story.start(index)
	GameState.play_story_step()


func go_back() -> void:
	GameState.go_to(GameState.MAIN_MENU)
