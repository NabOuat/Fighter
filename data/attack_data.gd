class_name AttackData
extends Resource
## Description d'une attaque (un coup du combo, un coup bas, un coup sauté...).
##
## Les durées sont en « frames » : le jeu tourne à 60 images par seconde,
## donc 6 frames = 0,1 seconde. C'est l'unité de mesure des jeux de combat.

## À quelle hauteur le coup arrive, donc comment il faut le parer.
## HIGH : parer debout. MID : debout ou accroupi. LOW : parer accroupi.
enum HitLevel { HIGH, MID, LOW }

## Clé du nom de l'attaque dans localization/translations.csv (mode Entraînement).
@export var name_key: String

@export_group("Durées (frames)")
## Préparation : le bras ou la jambe part, mais ne touche pas encore.
@export_range(1, 60) var startup := 4
## Le coup peut toucher pendant ces frames.
@export_range(1, 60) var active := 3
## Retour en garde : le combattant ne peut rien faire et reste vulnérable.
@export_range(0, 60) var recovery := 8

@export_group("Effet sur l'adversaire")
## Points de vie retirés (sur 1 000), avant puissance et défense.
@export_range(0, 300) var damage := 40
@export var hit_level: HitLevel = HitLevel.MID
## Durée pendant laquelle l'adversaire touché ne peut rien faire.
@export_range(1, 60) var hitstun := 16
## Durée pendant laquelle l'adversaire qui pare ne peut rien faire (étape 2).
@export_range(1, 60) var blockstun := 10
## Vitesse du recul de l'adversaire touché, en pixels par seconde.
@export_range(0, 400) var pushback := 90.0
## Coché : l'adversaire est projeté au sol.
@export var knockdown := false
## Arrêt de l'image à l'impact, en frames : donne la sensation de puissance.
@export_range(0, 20) var hitstop := 5
## Lance l'adversaire en l'air (vitesse vers le haut, 0 = non) : il peut alors
## être frappé à nouveau en l'air (jonglage). Prioritaire sur « knockdown ».
@export_range(0, 600) var launch := 0.0

@export_group("Coup spécial")
## Énergie dépensée : 100 = 1 segment, 400 = barre pleine (ultime).
@export_range(0, 400) var energy_cost := 0
## Vie retirée même quand l'adversaire pare (les coups normaux n'en retirent pas).
@export_range(0, 100) var chip_damage := 0
## Vitesse vers l'avant pendant le temps actif (pour les attaques foncées), en pixels par seconde.
@export_range(0, 600) var dash_speed := 0.0
## Projectile lancé à la fin de la préparation (vide = pas de projectile).
@export var projectile: ProjectileData
## Coché : intouchable pendant la préparation.
@export var invulnerable_startup := false
## Coché : c'est l'ultime (arrêt du combat et mise en scène avant le coup).
@export var is_ultimate := false
## Coché : c'est une projection (saisie). Elle ne peut être ni parée ni contrée ;
## on l'évite en sautant, ou en projetant au même moment.
@export var is_throw := false
## Serment (ex : Dakon) : à la fin de la préparation, le combattant encaisse moins
## pendant ce nombre de frames (0 = pas d'effet). Voir Fighter.OATH_DAMAGE_TAKEN.
@export_range(0, 900) var guard_buff_frames := 0

@export_group("Zone de frappe")
## Rectangle qui touche, en pixels, mesuré depuis les pieds du combattant
## tourné vers la droite : x vers l'avant, y négatif vers le haut.
@export var hitbox := Rect2(6, -46, 22, 10)


## Durée totale de l'attaque, du début au retour en garde.
func total_frames() -> int:
	return startup + active + recovery


## Vrai si le coup peut toucher à cette frame.
func is_active_frame(frame: int) -> bool:
	return frame > startup and frame <= startup + active
