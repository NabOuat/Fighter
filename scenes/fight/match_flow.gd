class_name MatchFlow
extends Node
## Le déroulement d'un combat : annonces, manches, chrono, K.O., victoire.
##
## Il ne touche pas aux combattants : il dit à l'arène quand une manche
## commence (round_started), se termine (round_ended) et quand le combat est
## fini (match_over). L'arène fait le reste (remettre en place, ralenti...).
##
## Règles (Rule) :
## - VERSUS : le combat normal, 2 manches gagnantes ;
## - DUEL : une seule manche (mode Histoire) ;
## - BOSS : battre le boss plusieurs fois d'affilée (une manche = une phase),
##   un seul K.O. du joueur et c'est perdu ;
## - SURVIVAL : tenir jusqu'à la fin du chrono contre des vagues d'ennemis
##   (le chrono ne repart pas à zéro entre deux vagues).

## Une nouvelle manche commence : l'arène remet tout en place.
signal round_started
## La manche est finie (by_ko : par K.O., sinon au chrono).
signal round_ended(by_ko: bool)
## Le combat est fini (un des deux a gagné 2 manches).
signal match_over

## Les étapes d'un combat.
enum Phase { INTRO, FIGHT, ROUND_OVER, MATCH_OVER }
## Les règles du combat (voir en haut du fichier).
enum Rule { VERSUS, DUEL, BOSS, SURVIVAL }

## Manches à gagner pour remporter le combat.
const ROUNDS_TO_WIN := 2
## Durée d'une manche : 60 secondes.
const ROUND_FRAMES := 60 * 60
## Annonce de début de manche : « Round 1 » puis « Combat ! ».
const INTRO_ROUND_FRAMES := 70
const INTRO_TOTAL_FRAMES := 110
## Fin de manche : « K.O. » d'abord, puis le nom du gagnant, puis la manche suivante.
const RESULT_SHOW_FRAMES := 90
const ROUND_OVER_FRAMES := 210
## Entre deux phases de boss ou deux vagues : une pause plus courte.
const NEXT_WAVE_FRAMES := 120

## Ce que le rollback sauvegarde (les gagnants de la manche sont sauvegardés à part).
const STATE_VARS := ["rule", "player_rounds_needed", "dummy_rounds_needed", "round_frames",
		"phase", "phase_frames", "round_number", "player_wins", "dummy_wins", "timer_frames",
		"round_result_key"]

var rule: Rule = Rule.VERSUS
## Manches que le joueur doit gagner (phases du boss, vagues) et que l'adversaire doit gagner.
var player_rounds_needed := ROUNDS_TO_WIN
var dummy_rounds_needed := ROUNDS_TO_WIN
## Durée du chrono (une manche, ou toute la survie).
var round_frames := ROUND_FRAMES

var phase: Phase = Phase.INTRO
## Frames écoulées depuis le début de l'étape en cours.
var phase_frames := 0
var round_number := 1
var player_wins := 0
var dummy_wins := 0
var timer_frames := ROUND_FRAMES
## Texte (clé de traduction) annonçant le résultat de la manche.
var round_result_key := ""
## Gagnant(s) de la dernière manche (les deux en cas d'égalité).
var round_winners: Array[Fighter] = []

var _player: Fighter
var _dummy: Fighter


func setup(player: Fighter, dummy: Fighter) -> void:
	_player = player
	_dummy = dummy


## L'état du déroulement, pour le rollback (gagnants : 0 = joueur, 1 = adversaire).
func get_state() -> Dictionary:
	var saved := {}
	for key in STATE_VARS:
		saved[key] = get(key)
	saved["round_winners"] = round_winners.map(func(f: Fighter) -> int: return 0 if f == _player else 1)
	return saved


func set_state(saved: Dictionary) -> void:
	for key in STATE_VARS:
		set(key, saved[key])
	round_winners.clear()
	for index in saved.round_winners:
		round_winners.append(_player if index == 0 else _dummy)


## Choisit les règles (count : phases du boss ou vagues ; seconds : chrono).
func configure(new_rule: Rule, count := 1, seconds := 60) -> void:
	rule = new_rule
	round_frames = seconds * 60
	dummy_rounds_needed = ROUNDS_TO_WIN if rule == Rule.VERSUS else 1
	match rule:
		Rule.VERSUS:
			player_rounds_needed = ROUNDS_TO_WIN
		Rule.DUEL:
			player_rounds_needed = 1
		Rule.BOSS, Rule.SURVIVAL:
			player_rounds_needed = maxi(1, count)


func start_match() -> void:
	player_wins = 0
	dummy_wins = 0
	round_number = 1
	timer_frames = round_frames
	start_round()


## Une phase de boss ou une vague de plus (pas la première manche) : l'arène
## garde alors la vie du joueur au lieu de tout remettre à neuf.
func is_next_wave() -> bool:
	return rule in [Rule.BOSS, Rule.SURVIVAL] and round_number > 1


func start_round() -> void:
	# En survie, le chrono continue d'une vague à l'autre.
	if rule != Rule.SURVIVAL:
		timer_frames = round_frames
	set_phase(Phase.INTRO)
	round_started.emit()


func set_phase(new_phase: Phase) -> void:
	phase = new_phase
	phase_frames = 0


## Vrai quand les combattants peuvent bouger et frapper.
func is_fighting() -> bool:
	return phase == Phase.FIGHT


## Une seconde de moins au chrono (appelée seulement sur les frames simulées).
func tick_timer() -> void:
	timer_frames = maxi(0, timer_frames - 1)


## Appelée à chaque frame par l'arène.
func update() -> void:
	phase_frames += 1
	match phase:
		Phase.INTRO:
			if phase_frames >= INTRO_TOTAL_FRAMES:
				set_phase(Phase.FIGHT)
		Phase.FIGHT:
			if _player.health <= 0 or _dummy.health <= 0:
				_end_round(true)
			elif timer_frames <= 0:
				_end_round(false)
		Phase.ROUND_OVER:
			var pause := NEXT_WAVE_FRAMES if rule in [Rule.BOSS, Rule.SURVIVAL] and not is_decided() else ROUND_OVER_FRAMES
			if phase_frames >= pause:
				if is_decided():
					set_phase(Phase.MATCH_OVER)
					match_over.emit()
				else:
					round_number += 1
					start_round()


func is_decided() -> bool:
	return player_wins >= player_rounds_needed or dummy_wins >= dummy_rounds_needed


## Vrai si le joueur a gagné le combat seul (un match nul ne compte pas).
func player_won() -> bool:
	return player_wins >= player_rounds_needed and dummy_wins < dummy_rounds_needed


## Vrai si l'adversaire a gagné le combat seul.
func player_lost() -> bool:
	return dummy_wins >= dummy_rounds_needed and player_wins < player_rounds_needed


## Fin de manche, par K.O. ou au chrono. En cas d'égalité, les deux gagnent la manche.
func _end_round(by_ko: bool) -> void:
	round_winners.clear()
	# Survie : au bout du chrono, l'aube se lève et le joueur a tenu.
	if rule == Rule.SURVIVAL and not by_ko:
		round_winners.append(_player)
		player_wins = player_rounds_needed
		round_result_key = "FIGHT_DAWN"
		set_phase(Phase.ROUND_OVER)
		round_ended.emit(by_ko)
		return
	if by_ko:
		for fighter in [_player, _dummy]:
			if fighter.health > 0:
				round_winners.append(fighter)
		round_result_key = "FIGHT_KO" if round_winners.size() == 1 else "FIGHT_DOUBLE_KO"
	else:
		if _player.health > _dummy.health:
			round_winners.append(_player)
		elif _dummy.health > _player.health:
			round_winners.append(_dummy)
		round_result_key = "FIGHT_TIME_UP"
	# Double K.O. ou vie égale au chrono : la manche compte pour les deux.
	if round_winners.is_empty():
		round_winners.append_array([_player, _dummy])
	for fighter in round_winners:
		if fighter == _player:
			player_wins += 1
		else:
			dummy_wins += 1
	set_phase(Phase.ROUND_OVER)
	round_ended.emit(by_ko)


## Texte de la grande annonce au centre de l'écran (vide = rien à annoncer).
## header : une ligne ajoutée au-dessus du premier round (ex : « Combat 2 / 6 »).
## footer : une ligne ajoutée sous le résultat final (ex : « Appuie sur Attaque... »).
func announce_text(header := "", footer := "") -> String:
	match phase:
		Phase.INTRO:
			if phase_frames < INTRO_ROUND_FRAMES:
				var text := _intro_title()
				if header != "" and round_number == 1:
					text = header + ("\n" + text if text != "" else "")
				return text
			return tr("FIGHT_START")
		Phase.ROUND_OVER:
			# Entre deux phases ou vagues, ou à l'aube : seulement le résultat.
			if phase_frames < RESULT_SHOW_FRAMES or rule == Rule.SURVIVAL or (rule == Rule.BOSS and not is_decided()):
				return tr(round_result_key)
			return _winner_text(round_winners, "FIGHT_ROUND_WINNER")
		Phase.MATCH_OVER:
			var champions: Array[Fighter] = []
			if player_wins >= player_rounds_needed:
				champions.append(_player)
			if dummy_wins >= dummy_rounds_needed:
				champions.append(_dummy)
			var text := _winner_text(champions, "FIGHT_MATCH_WINNER")
			if footer != "":
				text += "\n" + footer
			return text
	return ""


## Le titre d'une manche : « Round 2 », « Phase 2 / 3 », « Vague 1 / 4 »...
func _intro_title() -> String:
	match rule:
		Rule.DUEL:
			return ""
		Rule.BOSS:
			return tr("FIGHT_PHASE") % [round_number, player_rounds_needed]
		Rule.SURVIVAL:
			var text: String = tr("FIGHT_WAVE") % [round_number, player_rounds_needed]
			return text + "\n" + tr("FIGHT_SURVIVE") if round_number == 1 else text
	var last := player_wins == ROUNDS_TO_WIN - 1 and dummy_wins == ROUNDS_TO_WIN - 1
	return tr("FIGHT_FINAL_ROUND") if last else tr("FIGHT_ROUND") % round_number


func _winner_text(winners: Array[Fighter], key: String) -> String:
	if winners.size() != 1:
		return tr("FIGHT_DRAW")
	return tr(key) % tr(winners[0].data.name_key)
