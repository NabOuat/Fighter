class_name NetInput
extends RefCounted
## Les commandes d'une frame en un seul nombre (un bit par touche), pour les
## envoyer à l'autre joueur en quelques octets.

## Toutes les commandes d'un combattant (voir Fighter.intent), dans l'ordre des bits.
const KEYS := ["left", "right", "jump", "crouch", "attack", "guard", "guard_pressed",
		"special", "ultimate", "assist", "throw", "special_2", "low_attack", "charge"]
## Les commandes « appui » (vraies une seule frame). Quand on devine les commandes
## de l'adversaire, on suppose qu'il garde ses touches maintenues mais qu'il
## n'appuie pas sur un nouveau bouton.
const PRESS_KEYS := ["attack", "guard_pressed", "ultimate", "assist", "throw", "special_2", "low_attack"]


static func encode(intent: Dictionary) -> int:
	var bits := 0
	for i in KEYS.size():
		if intent[KEYS[i]]:
			bits |= 1 << i
	return bits


## Remplit intent d'après le nombre (toutes les touches sont écrites).
static func decode(bits: int, intent: Dictionary) -> void:
	for i in KEYS.size():
		intent[KEYS[i]] = bits & (1 << i) != 0


## Ce qu'on devine pour la frame suivante : mêmes touches maintenues, aucun appui.
static func predict(bits: int) -> int:
	return bits & ~press_mask()


static func press_mask() -> int:
	var mask := 0
	for key in PRESS_KEYS:
		mask |= 1 << KEYS.find(key)
	return mask
