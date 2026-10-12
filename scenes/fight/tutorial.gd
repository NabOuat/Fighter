class_name Tutorial
extends CanvasLayer
## Le tutoriel : une suite de petites leçons dans l'arène d'entraînement.
##
## Chaque leçon donne une consigne, règle ce que fait le mannequin, puis attend
## que le joueur réussisse le geste (une ou plusieurs fois). « Bravo ! », et on
## passe à la suivante. Le joueur peut passer une leçon.
## Les consignes s'adaptent : boutons tactiles sur téléphone, touches sur ordinateur.

## Temps d'affichage de « Bravo ! » avant la leçon suivante.
const SUCCESS_FRAMES := 70

## Les leçons, dans l'ordre. id : sert aux textes (TUTO_<id>_TITLE et TUTO_<id>).
## dummy : ce que fait le mannequin. count : nombre de réussites demandées.
## energy : énergie du joueur au début de la leçon.
const LESSONS := [
	{"id": "MOVE", "dummy": TrainingTools.DummyMode.STAND, "count": 1},
	{"id": "COMBO", "dummy": TrainingTools.DummyMode.STAND, "count": 2},
	{"id": "GUARD", "dummy": TrainingTools.DummyMode.ATTACK, "count": 3},
	{"id": "LOW", "dummy": TrainingTools.DummyMode.GUARD_HIGH, "count": 2},
	{"id": "OVERHEAD", "dummy": TrainingTools.DummyMode.GUARD_LOW, "count": 1},
	{"id": "THROW", "dummy": TrainingTools.DummyMode.GUARD_HIGH, "count": 1},
	{"id": "SPECIAL", "dummy": TrainingTools.DummyMode.STAND, "count": 1, "energy": 400.0},
	{"id": "SPECIAL2", "dummy": TrainingTools.DummyMode.STAND, "count": 1, "energy": 400.0},
	{"id": "CHARGE", "dummy": TrainingTools.DummyMode.STAND, "count": 1, "energy": 0.0},
	{"id": "DODGE", "dummy": TrainingTools.DummyMode.ATTACK, "count": 1, "energy": 400.0},
	{"id": "PARRY", "dummy": TrainingTools.DummyMode.ATTACK, "count": 1},
	{"id": "ASSIST", "dummy": TrainingTools.DummyMode.STAND, "count": 1},
	{"id": "ULTIMATE", "dummy": TrainingTools.DummyMode.STAND, "count": 1, "energy": 400.0},
]
## Leçon « se déplacer » : distance à parcourir (pixels) et un saut.
const MOVE_DISTANCE := 60.0
## Leçon « charger » : énergie à atteindre.
const CHARGE_TARGET := 200.0

var fight
var lesson_index := 0
var progress := 0
var finished := false
var _success_frames := 0
var _moved := 0.0
var _jumped := false
var _last_x := 0.0

@onready var step_label: Label = %StepLabel
@onready var title_label: Label = %TitleLabel
@onready var text_label: Label = %TextLabel
@onready var progress_label: Label = %ProgressLabel
@onready var skip_button: Button = %SkipButton
@onready var end_panel: Control = %EndPanel
@onready var training_button: Button = %TrainingButton
@onready var menu_button: Button = %MenuButton


func _ready() -> void:
	end_panel.visible = false
	skip_button.pressed.connect(next_lesson)
	training_button.pressed.connect(func():
		GameState.start_training(GameState.roster[0], GameState.roster[1], GameState.roster[1], GameState.difficulty)
		GameState.go_to(GameState.FIGHT))
	menu_button.pressed.connect(GameState.go_to.bind(GameState.MAIN_MENU))


## Branche le tutoriel sur l'arène et commence la première leçon.
func start(arena) -> void:
	fight = arena
	var player: Fighter = fight.player
	fight.hit_landed.connect(_on_hit_landed)
	player.projectile_launched.connect(func(_data, _shooter): _count_if("SPECIAL"))
	player.attack_started.connect(_on_attack_started)
	player.dodged.connect(_count_if.bind("DODGE"))
	player.assist_called.connect(func(_caller): _count_if("ASSIST"))
	player.ultimate_started.connect(func(_fighter): _count_if("ULTIMATE"))
	_begin(0)


func current_id() -> String:
	return "" if finished else LESSONS[lesson_index].id


func _begin(index: int) -> void:
	lesson_index = index
	progress = 0
	_success_frames = 0
	_moved = 0.0
	_jumped = false
	var lesson: Dictionary = LESSONS[index]
	fight.reset_training()
	fight.tools.dummy_mode = lesson.dummy
	fight.tools.frame_count = 0
	fight.player.energy = lesson.get("energy", Fighter.MAX_ENERGY)
	_last_x = fight.player.position.x
	_refresh()


func next_lesson() -> void:
	if lesson_index + 1 < LESSONS.size():
		_begin(lesson_index + 1)
	else:
		_finish()


func _finish() -> void:
	finished = true
	fight.tools.dummy_mode = TrainingTools.DummyMode.STAND
	end_panel.visible = true
	skip_button.visible = false
	training_button.grab_focus.call_deferred()


func _physics_process(_delta: float) -> void:
	if fight == null or finished:
		return
	if _success_frames > 0:
		_success_frames -= 1
		if _success_frames == 0:
			next_lesson()
		return
	var player: Fighter = fight.player
	match current_id():
		"MOVE":
			_moved += absf(player.position.x - _last_x)
			_jumped = _jumped or player.state == Fighter.State.JUMP
			if _moved >= MOVE_DISTANCE and _jumped:
				_succeed()
		"CHARGE":
			if player.energy >= CHARGE_TARGET:
				_succeed()
	_last_x = player.position.x


func _on_hit_landed(result: Fighter.HitResult, attack: AttackData, attacker: Fighter, defender: Fighter) -> void:
	var player: Fighter = fight.player
	var by_player := attacker == player and result == Fighter.HitResult.HIT
	match current_id():
		"COMBO":
			if by_player and player.combo_hits >= 3:
				_add_progress()
		"GUARD":
			if defender == player and result == Fighter.HitResult.BLOCKED:
				_add_progress()
		"LOW":
			if by_player and attack == player.data.low_attack:
				_add_progress()
		"OVERHEAD":
			if by_player and attack == player.data.air_attack:
				_add_progress()
		"THROW":
			if by_player and attack.is_throw:
				_add_progress()
		"PARRY":
			if defender == player and result == Fighter.HitResult.PARRIED:
				_add_progress()


func _on_attack_started(attack: AttackData) -> void:
	if attack == fight.player.data.special_2:
		_count_if("SPECIAL2")


func _count_if(lesson_id: String) -> void:
	if current_id() == lesson_id:
		_add_progress()


func _add_progress() -> void:
	if _success_frames > 0:
		return
	progress += 1
	if progress >= LESSONS[lesson_index].count:
		_succeed()
	else:
		_refresh()


func _succeed() -> void:
	progress = LESSONS[lesson_index].count
	_success_frames = SUCCESS_FRAMES
	fight.feedback.sounds.play("gong")
	_refresh()
	text_label.text = tr("TUTO_WELL_DONE")


func _refresh() -> void:
	var lesson: Dictionary = LESSONS[lesson_index]
	step_label.text = tr("TUTO_STEP") % [lesson_index + 1, LESSONS.size()]
	title_label.text = tr("TUTO_%s_TITLE" % lesson.id)
	text_label.text = instruction(lesson.id)
	progress_label.visible = lesson.count > 1
	progress_label.text = "%d / %d" % [progress, lesson.count]


## La consigne, avec les noms des boutons de l'appareil (tactile ou clavier).
func instruction(lesson_id: String) -> String:
	var touch := DisplayServer.is_touchscreen_available()
	var names := {}
	for key in ["attack", "special", "guard", "assist", "ultimate", "forward", "back", "down", "up", "throw", "special2", "low", "charge"]:
		names[key] = tr("TUTO_%s_%s" % ["TOUCH" if touch else "KEY", key.to_upper()])
	var text := tr("TUTO_%s" % lesson_id)
	# Avec les boutons « en plus », on indique aussi le raccourci.
	var extra := {"THROW": "Throw", "SPECIAL2": "Special2", "LOW": "LowAttack", "CHARGE": "Charge"}
	if touch and extra.has(lesson_id) and GameState.is_extra_button_on(extra[lesson_id]):
		text += "\n" + tr("TUTO_%s_EXTRA" % lesson_id)
	return text.format(names)
