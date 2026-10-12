class_name MatchResult
extends CanvasLayer
## La fenêtre de fin de combat en Arcade : victoire (combat suivant), défaite
## (réessayer), ou fin de la série (Arcade terminée). Toujours un bouton Menu.

signal next_requested
signal retry_requested
signal menu_requested

enum Outcome { WIN, LOSS, COMPLETE }

var outcome: Outcome = Outcome.WIN

@onready var title_label: Label = %TitleLabel
@onready var detail_label: Label = %DetailLabel
@onready var main_button: Button = %MainButton
@onready var menu_button: Button = %MenuButton


func _ready() -> void:
	visible = false
	main_button.pressed.connect(_on_main_pressed)
	menu_button.pressed.connect(menu_requested.emit)


## fight_number : le combat qui vient de se terminer (1 à 6).
func show_result(result: Outcome, fight_number: int, fight_count: int) -> void:
	outcome = result
	visible = true
	match result:
		Outcome.WIN:
			title_label.text = tr("RESULT_WIN")
			detail_label.text = tr("ARCADE_FIGHT_N") % [fight_number, fight_count]
			main_button.text = "RESULT_NEXT"
		Outcome.LOSS:
			title_label.text = tr("RESULT_LOSS")
			detail_label.text = tr("ARCADE_FIGHT_N") % [fight_number, fight_count]
			main_button.text = "RESULT_RETRY"
		Outcome.COMPLETE:
			title_label.text = tr("ARCADE_COMPLETE")
			detail_label.text = tr("ARCADE_COMPLETE_DETAIL") % fight_count
	main_button.visible = result != Outcome.COMPLETE
	(menu_button if result == Outcome.COMPLETE else main_button).grab_focus.call_deferred()


func hide_result() -> void:
	visible = false


func _on_main_pressed() -> void:
	if outcome == Outcome.WIN:
		next_requested.emit()
	else:
		retry_requested.emit()
