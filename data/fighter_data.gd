class_name FighterData
extends Resource
## Fiche d'identité d'un combattant.
##
## Tout ce qui décrit un personnage sans être du code (nom, histoire,
## statistiques, images) vit ici. Chaque combattant a son propre fichier
## .tres dans data/fighters/, modifiable directement dans l'Inspecteur de Godot.

## Identifiant unique, en minuscules et sans espace (ex : samory_toure).
@export var id: StringName

@export_group("Textes (clés de traduction)")
## Clé du nom dans localization/translations.csv.
@export var name_key: String
## Clé du royaume ou de la région d'origine.
@export var origin_key: String
## Clé de la courte biographie affichée dans les fiches historiques.
@export var bio_key: String

@export_group("Histoire")
## Année de naissance (approximative si inconnue).
@export var birth_year: int
## Année de décès.
@export var death_year: int

@export_group("Statistiques")
## Points de vie au début d'un round.
@export_range(50, 200) var max_health: int = 100
## Vitesse de marche, en pixels par seconde.
@export_range(40, 200) var walk_speed: float = 90.0
## Multiplicateur de dégâts : 1.0 = normal, 1.2 = 20 % plus fort.
@export_range(0.5, 2.0, 0.05) var power: float = 1.0

@export_group("Visuel")
## Couleur du rectangle temporaire, en attendant les vrais sprites.
@export var placeholder_color: Color = Color.WHITE
## Portrait pour l'écran de sélection (à ajouter plus tard).
@export var portrait: Texture2D
## Animations du personnage (à ajouter plus tard).
@export var sprite_frames: SpriteFrames
