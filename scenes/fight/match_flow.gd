class_name MatchFlow
extends Node
## Le déroulement d'un combat : annonces, manches, chrono, K.O., victoire.
##
## Il ne touche pas aux combattants : il dit à l'arène quand une manche
## commence (round_started), se termine (round_ended) et quand le combat est
## fini (match_over). L'arène fait le reste (remettre en place, ralenti...).
## Le mode Histoire pourra avoir son propre déroulement (survie, boss...).

## Une nouvelle manche commence : l'arène remet tout en place.
signal round_started
## La manche est finie (by_ko : par K.O., sinon au chrono).
signal round_ended(by_ko: bool)
## Le combat est fini (un des deux a gagné 2 manches).
signal match_over

## Les étapes d'un combat.
enum Phase { INTRO, FIGHT, ROUND_OVER, MATCH_OVER }

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


func start_match() -> void:
	player_wins = 0
	dummy_wins = 0
	round_number = 1
	start_round()


func start_round() -> void:
	timer_frames = ROUND_FRAMES
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
			if phase_frames >= ROUND_OVER_FRAMES:
				if is_decided():
					set_phase(Phase.MATCH_OVER)
					match_over.emit()
				else:
					round_number += 1
					start_round()


func is_decided() -> bool:
	return player_wins >= ROUNDS_TO_WIN or dummy_wins >= ROUNDS_TO_WIN


## Vrai si le joueur a gagné le combat seul (un match nul ne compte pas).
func player_won() -> bool:
	return player_wins >= ROUNDS_TO_WIN and dummy_wins < ROUNDS_TO_WIN


## Fin de manche, par K.O. ou au chrono. En cas d'égalité, les deux gagnent la manche.
func _end_round(by_ko: bool) -> void:
	round_winners.clear()
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
				var last := player_wins == ROUNDS_TO_WIN - 1 and dummy_wins == ROUNDS_TO_WIN - 1
				var text: String = tr("FIGHT_FINAL_ROUND") if last else tr("FIGHT_ROUND") % round_number
				if header != "" and round_number == 1:
					text = header + "\n" + text
				return text
			return tr("FIGHT_START")
		Phase.ROUND_OVER:
			if phase_frames < RESULT_SHOW_FRAMES:
				return tr(round_result_key)
			return _winner_text(round_winners, "FIGHT_ROUND_WINNER")
		Phase.MATCH_OVER:
			var champions: Array[Fighter] = []
			if player_wins >= ROUNDS_TO_WIN:
				champions.append(_player)
			if dummy_wins >= ROUNDS_TO_WIN:
				champions.append(_dummy)
			var text := _winner_text(champions, "FIGHT_MATCH_WINNER")
			if footer != "":
				text += "\n" + footer
			return text
	return ""


func _winner_text(winners: Array[Fighter], key: String) -> String:
	if winners.size() != 1:
		return tr("FIGHT_DRAW")
	return tr(key) % tr(winners[0].data.name_key)
