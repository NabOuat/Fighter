extends SceneTree
## Fabrique le thème des menus (ui/legendz_theme.tres) et les bus audio
## (default_bus_layout.tres : Master, Music, SFX).
## Godot --headless --path . --script res://tools/make_ui_theme.gd
##
## Couleurs : terre sombre, ocre, terre cuite et or, en attendant les vraies
## illustrations. Pour changer une couleur : la modifier ici et relancer.

const EARTH := Color("1c100a")
const PANEL := Color("2a170d")
const BUTTON := Color("3d2314")
const BUTTON_HOVER := Color("553019")
const OCHRE := Color("b8661f")
const TERRACOTTA := Color("9c3d26")
const GOLD := Color("e6ad3c")
const GOLD_DARK := Color("8a6122")
const CREAM := Color("f3e6c8")
const MUTED := Color("6e5c4a")


func _initialize() -> void:
	var theme := Theme.new()
	theme.default_font_size = 10

	theme.set_stylebox("normal", "Button", _box(BUTTON, GOLD_DARK))
	theme.set_stylebox("hover", "Button", _box(BUTTON_HOVER, GOLD))
	theme.set_stylebox("pressed", "Button", _box(OCHRE, GOLD))
	theme.set_stylebox("hover_pressed", "Button", _box(OCHRE, GOLD))
	theme.set_stylebox("disabled", "Button", _box(PANEL, MUTED.darkened(0.3)))
	theme.set_stylebox("focus", "Button", _outline(GOLD))
	theme.set_color("font_color", "Button", CREAM)
	theme.set_color("font_hover_color", "Button", GOLD)
	theme.set_color("font_pressed_color", "Button", EARTH)
	theme.set_color("font_hover_pressed_color", "Button", EARTH)
	theme.set_color("font_focus_color", "Button", GOLD)
	theme.set_color("font_disabled_color", "Button", MUTED)

	theme.set_color("font_color", "Label", CREAM)
	theme.set_stylebox("panel", "PanelContainer", _box(PANEL, GOLD_DARK, 4))
	theme.set_stylebox("panel", "Panel", _box(PANEL, GOLD_DARK, 4))

	# Curseurs (volumes, tailles) : une piste sombre qui se remplit d'ocre.
	var track := _box(EARTH, GOLD_DARK, 0)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	theme.set_stylebox("slider", "HSlider", track)
	var filled := _box(OCHRE, GOLD_DARK, 0)
	filled.content_margin_top = 3
	filled.content_margin_bottom = 3
	theme.set_stylebox("grabber_area", "HSlider", filled)
	theme.set_stylebox("grabber_area_highlight", "HSlider", filled)

	theme.set_color("font_color", "CheckButton", CREAM)
	theme.set_color("font_hover_color", "CheckButton", GOLD)
	theme.set_color("font_pressed_color", "CheckButton", CREAM)
	theme.set_color("font_hover_pressed_color", "CheckButton", GOLD)
	theme.set_color("font_focus_color", "CheckButton", GOLD)
	theme.set_stylebox("focus", "CheckButton", _outline(GOLD))
	theme.set_stylebox("focus", "HSlider", _outline(GOLD))

	_save(theme, "res://ui/legendz_theme.tres")

	# Bus audio : le réglage de volume agit séparément sur la musique et les bruitages.
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	_save(AudioServer.generate_bus_layout(), "res://default_bus_layout.tres")
	quit()


func _box(fill: Color, border: Color, margin := 6) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(2)
	box.content_margin_left = margin
	box.content_margin_right = margin
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	return box


func _outline(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = color
	box.set_border_width_all(1)
	box.set_corner_radius_all(2)
	box.expand_margin_left = 1
	box.expand_margin_right = 1
	box.expand_margin_top = 1
	box.expand_margin_bottom = 1
	return box


func _save(resource: Resource, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var err := ResourceSaver.save(resource, path)
	print(path, " : ", "ok" if err == OK else "erreur %d" % err)
