class_name ProjectileData
extends Resource
## Un projectile lancé par un coup spécial (vague, lance, aileron de requin...).
##
## Son effet quand il touche (dégâts, étourdissement, hauteur...) est décrit
## par une AttackData, comme un coup normal : seule sa zone de frappe change,
## puisque c'est le projectile qui touche et non le combattant.

## L'effet du projectile sur l'adversaire (sa zone « hitbox » n'est pas utilisée).
@export var hit: AttackData
## Vitesse en pixels par seconde.
@export_range(40, 600) var speed := 220.0
## Taille du projectile, en pixels.
@export var size := Vector2(16, 12)
## Point de départ, mesuré depuis les pieds du lanceur tourné vers la droite.
@export var spawn_offset := Vector2(20, -34)
## Durée de vie maximale, en frames.
@export_range(10, 600) var lifetime := 150
## Couleur du rectangle temporaire.
@export var color := Color(0.3, 0.9, 1.0)
