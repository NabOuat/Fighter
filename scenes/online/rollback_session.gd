class_name RollbackSession
extends RefCounted
## Le « rollback » du jeu en ligne, indépendant du réseau.
##
## Principe, à chaque frame :
## 1. ma commande est jouée INPUT_DELAY frames plus tard (2 frames = 33 ms,
##    imperceptible) et envoyée tout de suite à l'autre joueur ;
## 2. si la commande de l'adversaire n'est pas encore arrivée, on la devine
##    (il garde les mêmes touches, sans nouvel appui) et on joue quand même :
##    mon jeu ne ralentit jamais ;
## 3. quand sa vraie commande arrive et qu'on s'était trompé, on recharge la
##    photo de cette frame et on rejoue jusqu'à maintenant, en un instant.
## Si l'adversaire a plus de MAX_ROLLBACK frames de retard, on attend
## (mieux qu'un énorme saut). Toutes les secondes, les deux joueurs comparent
## l'empreinte du combat : si elles diffèrent, desync_detected est émis.
##
## « game » est l'arène : save_state(), load_state(), step_with_inputs(inputs,
## replaying) et state_checksum(state).

## Les empreintes des deux joueurs ne correspondent pas (le combat a divergé).
signal desync_detected(frame: int)

const INPUT_DELAY := 2
const MAX_ROLLBACK := 8
## Une empreinte toutes les 60 frames (1 seconde).
const CHECKSUM_INTERVAL := 60
## Au plus tant de commandes renvoyées par message (les plus anciennes sont
## renvoyées tant que l'autre n'a pas confirmé les avoir reçues).
const MAX_INPUTS_PER_PACKET := 60
## Avance maximale tolérée sur l'autre joueur avant de ralentir (en frames).
const MAX_FRAME_ADVANTAGE := 2
## Après une attente pour se recaler, au moins tant de frames avant la suivante.
const WAIT_COOLDOWN_FRAMES := 10

var game: Object
## Ma place (0 = à gauche, 1 = à droite) et celle de l'adversaire.
var local := 0
var remote := 1
## La prochaine frame à jouer.
var frame := 0
## Statistiques (affichage de la qualité de connexion, tests).
var rollback_count := 0
var longest_rollback := 0
var wait_count := 0

## Commandes connues : une table frame -> nombre par joueur.
var _inputs: Array[Dictionary] = [{}, {}]
## La commande de l'adversaire utilisée pour jouer chaque frame (devinée ou vraie).
var _used := {}
## Photo de l'état AVANT chaque frame jouée.
var _states := {}
## Dernière frame dont on a reçu toutes les commandes de l'adversaire (sans trou).
var _remote_confirmed := -1
## Dernière frame de mes commandes que l'adversaire a confirmé avoir reçue.
var _remote_ack := -1
## Plus ancienne frame à rejouer (-1 = aucune).
var _rollback_from := -1
## Avance de l'adversaire sur moi, telle qu'il la mesure (frames).
var _remote_advantage := 0
## Dernière frame jouée par l'adversaire, d'après son dernier message.
var _remote_frame := 0
var _last_wait_frame := -WAIT_COOLDOWN_FRAMES
## Empreintes : frame -> nombre (les miennes, et celles reçues de l'adversaire).
var _local_sums := {}
var _remote_sums := {}
## Mes empreintes pas encore envoyées : frame -> nombre (gardées à part : la
## comparaison efface _local_sums, parfois avant l'envoi).
var _sums_to_send := {}
var _next_sum_frame := CHECKSUM_INTERVAL
## Les frames plus anciennes que celle-ci sont déjà oubliées.
var _forgotten_until := 0


func _init(target: Object, local_slot: int) -> void:
	game = target
	local = local_slot
	remote = 1 - local_slot
	# Les premières frames (avant le délai) : personne n'appuie sur rien.
	for f in INPUT_DELAY:
		_inputs[0][f] = 0
		_inputs[1][f] = 0
	_remote_confirmed = INPUT_DELAY - 1


# --- Chaque frame ------------------------------------------------------------

## Vrai si on peut jouer une frame de plus sans dépasser le retard maximal
## de l'adversaire ni trop le devancer.
func can_advance() -> bool:
	if frame - _remote_confirmed > MAX_ROLLBACK:
		return false
	# Recalage : si je suis nettement en avance, j'attends une frame (de temps en temps).
	if frame_advantage() - _remote_advantage >= MAX_FRAME_ADVANTAGE * 2 \
			and frame - _last_wait_frame >= WAIT_COOLDOWN_FRAMES:
		_last_wait_frame = frame
		wait_count += 1
		return false
	return true


## Joue une frame avec ma commande (appliquée INPUT_DELAY frames plus tard).
## Avant : rollback() si une commande de l'adversaire a contredit une devinette.
func advance(local_bits: int) -> void:
	_inputs[local][frame + INPUT_DELAY] = local_bits
	_states[frame] = game.save_state()
	game.step_with_inputs(_inputs_for(frame), false)
	frame += 1
	_record_checksums()
	_forget_old_frames()


## Rejoue depuis la plus ancienne frame mal devinée, jusqu'à la frame actuelle.
func rollback() -> void:
	if _rollback_from < 0:
		return
	var start := _rollback_from
	_rollback_from = -1
	rollback_count += 1
	longest_rollback = maxi(longest_rollback, frame - start)
	game.load_state(_states[start])
	for f in range(start, frame):
		_states[f] = game.save_state()
		game.step_with_inputs(_inputs_for(f), true)
	_record_checksums()


# --- Réseau ------------------------------------------------------------------

## Le message à envoyer à l'autre joueur : mes commandes qu'il n'a pas encore
## confirmées, ce que j'ai reçu de lui, où j'en suis, et mes empreintes.
func make_packet() -> Dictionary:
	var first := maxi(_remote_ack + 1, frame + INPUT_DELAY - MAX_INPUTS_PER_PACKET + 1)
	var bits: Array[int] = []
	for f in range(first, frame + INPUT_DELAY):
		bits.append(_inputs[local].get(f, 0))
	var packet := {"t": "in", "f": first, "i": bits, "a": _remote_confirmed, "fr": frame, "adv": frame_advantage()}
	if not _sums_to_send.is_empty():
		var sums := {}
		for f in _sums_to_send:
			sums[str(f)] = _sums_to_send[f]
		packet["s"] = sums
		_sums_to_send.clear()
	return packet


## Un message de l'autre joueur (voir make_packet). Un message abîmé ou
## incohérent (il vient d'Internet) est ignoré.
func receive(packet: Variant) -> void:
	if not is_valid_packet(packet):
		return
	_remote_ack = maxi(_remote_ack, int(packet.a))
	_remote_frame = maxi(_remote_frame, int(packet.fr))
	_remote_advantage = int(packet.adv)
	var first := int(packet.f)
	var bits: Array = packet.i
	for k in bits.size():
		_receive_input(first + k, int(bits[k]))
	if packet.has("s"):
		for key in packet.s:
			_remote_sums[int(key)] = int(packet.s[key])
		_compare_checksums()


## Vrai si le message a la bonne forme : les bons champs, des nombres entiers
## raisonnables, au plus MAX_INPUTS_PER_PACKET commandes valides.
func is_valid_packet(packet: Variant) -> bool:
	if not packet is Dictionary or packet.get("t") != "in":
		return false
	for key in ["f", "a", "fr", "adv"]:
		var value: Variant = packet.get(key)
		if not (value is int or value is float) or absf(value) > 1e9 or value != floorf(value):
			return false
	var bits: Variant = packet.get("i")
	if not bits is Array or bits.size() > MAX_INPUTS_PER_PACKET or int(packet.f) < 0:
		return false
	for value in bits:
		if not (value is int or value is float) or value < 0 or value >= 1 << NetInput.KEYS.size() or value != floorf(value):
			return false
	if packet.has("s"):
		if not packet.s is Dictionary:
			return false
		for key in packet.s:
			var sum: Variant = packet.s[key]
			if not (key is String and key.is_valid_int()) or not (sum is int or sum is float):
				return false
	return true


## Mon avance sur l'adversaire (en frames), d'après son dernier message.
func frame_advantage() -> int:
	return frame - _remote_frame


## Combien de frames je joue en devinant (0 = tout est confirmé).
func predicted_frames() -> int:
	return frame - 1 - _remote_confirmed


# --- Interne -----------------------------------------------------------------

func _receive_input(f: int, bits: int) -> void:
	if f <= _remote_confirmed or _inputs[remote].has(f):
		return
	_inputs[remote][f] = bits
	while _inputs[remote].has(_remote_confirmed + 1):
		_remote_confirmed += 1
	# Cette frame a déjà été jouée avec une devinette fausse : il faudra rejouer.
	if f < frame and _used.get(f, bits) != bits:
		_rollback_from = f if _rollback_from < 0 else mini(_rollback_from, f)


## Les commandes des deux joueurs pour une frame (vraies ou devinées).
func _inputs_for(f: int) -> Array[int]:
	var result: Array[int] = [0, 0]
	result[local] = _inputs[local].get(f, 0)
	var bits: int
	if _inputs[remote].has(f):
		bits = _inputs[remote][f]
	else:
		bits = NetInput.predict(_inputs[remote].get(_remote_confirmed, 0))
	_used[f] = bits
	result[remote] = bits
	return result


## Une empreinte toutes les CHECKSUM_INTERVAL frames, dès que la photo de cette
## frame est sûre (toutes les commandes d'avant sont confirmées et rejouées).
func _record_checksums() -> void:
	while _next_sum_frame < frame and _next_sum_frame - 1 <= _remote_confirmed and _rollback_from < 0:
		var f := _next_sum_frame
		_local_sums[f] = game.state_checksum(_states[f])
		_sums_to_send[f] = _local_sums[f]
		_next_sum_frame += CHECKSUM_INTERVAL
	_compare_checksums()


func _compare_checksums() -> void:
	for f in _remote_sums.keys():
		if _local_sums.has(f):
			if _local_sums[f] != _remote_sums[f]:
				desync_detected.emit(f)
			_local_sums.erase(f)
			_remote_sums.erase(f)


## On garde seulement ce qui peut encore servir à un retour en arrière.
## (Mes commandes, seulement quand l'adversaire a confirmé les avoir reçues.)
func _forget_old_frames() -> void:
	var old := mini(_remote_confirmed, frame) - MAX_ROLLBACK - 2
	while _forgotten_until < old:
		var f := _forgotten_until
		_states.erase(f)
		_used.erase(f)
		_inputs[remote].erase(f)
		_forgotten_until += 1
	for f in _inputs[local].keys():
		if f < old and f <= _remote_ack:
			_inputs[local].erase(f)
