class_name FighterData
extends Resource
## Fiche d'identité d'un combattant.
##
## Tout ce qui décrit un personnage sans être du code (nom, histoire,
## statistiques, attaques, images) vit ici. Chaque combattant a son propre
## fichier .tres dans data/fighters/, modifiable dans l'Inspecteur de Godot.
## La vie n'est pas ici : elle est identique pour tous (Fighter.MAX_HEALTH).

## Style de combat, qui guide le choix des coups et de l'IA.
enum Reach { MELEE, LONG_WEAPON, RANGED }

## Identifiant unique, en minuscules et sans espace (ex : abla_pokou).
@export var id: StringName

@export_group("Textes (clés de traduction)")
## Clé du nom dans localization/translations.csv.
@export var name_key: String
## Clé du royaume ou de la région d'origine.
@export var origin_key: String
## Clé de la courte biographie affichée dans l'Encyclopédie.
@export var bio_key: String

@export_group("Histoire")
## Année de naissance (approximative si inconnue).
@export var birth_year: int
## Année de décès.
@export var death_year: int

@export_group("Statistiques (1 à 5, 3 = moyenne)")
## Dégâts infligés : chaque point au-dessus de 3 ajoute 10 %.
@export_range(1, 5) var power := 3
## Dégâts reçus : chaque point au-dessus de 3 retire 8 %.
@export_range(1, 5) var defense := 3
## Vitesse de marche : de 80 à 120 pixels par seconde.
@export_range(1, 5) var speed := 3
## Corps à corps, arme longue ou distance.
@export var reach: Reach = Reach.MELEE
## Force du saut : plus le nombre est grand, plus il saute haut.
@export_range(200, 500) var jump_strength: float = 330.0

@export_group("Attaques")
## Les coups enchaînés en tapant plusieurs fois sur Attaque.
@export var combo: Array[AttackData] = []
## Attaque accroupie (coup bas).
@export var low_attack: AttackData
## Attaque en l'air.
@export var air_attack: AttackData

@export_group("Coups spéciaux")
## Spécial 1 : bouton Spécial seul (1 segment d'énergie).
@export var special_1: AttackData
## Spécial 2 : direction avant + Spécial (1 segment d'énergie).
@export var special_2: AttackData
## Ultime : bouton Ultime, barre d'énergie pleine.
@export var ultimate: AttackData

@export_group("Soutien")
## Ce que fait ce personnage quand un autre l'appelle en soutien.
@export var assist: AssistData

@export_group("Visuel")
## Couleur du rectangle temporaire, en attendant les vrais sprites.
@export var placeholder_color: Color = Color.WHITE
## Portrait pour l'écran de sélection (plus tard).
@export var portrait: Texture2D
## Animations du personnage (plus tard).
@export var sprite_frames: SpriteFrames


func damage_multiplier() -> float:
	return 1.0 + (power - 3) * 0.1


func defense_multiplier() -> float:
	return 1.0 - (defense - 3) * 0.08


func walk_speed() -> float:
	return 70.0 + speed * 10.0
