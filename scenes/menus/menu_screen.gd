class_name MenuScreen
extends Control
## Base commune des écrans de menu.
##
## Le bouton « retour » d'Android et la touche Échap appellent go_back().
## Chaque écran dit ce que « retour » veut dire pour lui (revenir au menu
## principal, fermer une fenêtre...).


func _notification(what: int) -> void:
	# Tous les nœuds reçoivent « retour » : seul l'écran du dessus doit réagir.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_visible_in_tree() and not has_overlay():
		go_back()


## Vrai si une fenêtre est ouverte par-dessus cet écran (réglages, disposition...).
func has_overlay() -> bool:
	for child in get_children():
		if child is MenuScreen or child is ControlsEditor:
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and is_visible_in_tree():
		get_viewport().set_input_as_handled()
		go_back()


## À remplacer dans chaque écran.
func go_back() -> void:
	pass


## Donne le focus au premier bouton (pour jouer au clavier ou à la manette).
func focus_first(button: Control) -> void:
	if button and is_inside_tree():
		button.grab_focus.call_deferred()
