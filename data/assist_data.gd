class_name AssistData
extends Resource
## Ce que fait un personnage quand on l'appelle en soutien.
##
## Chaque personnage a UNE action de soutien : attaquer, protéger ou soigner.
## Il apparaît à côté de celui qui l'appelle, agit, puis repart.

enum Kind { ATTACK, PROTECT, HEAL }

@export var kind: Kind = Kind.ATTACK

@export_group("Durées (frames)")
## Temps d'apparition avant d'agir.
@export_range(1, 60) var appear_frames := 10
## Durée de l'action pour la protection et le soin
## (pour une attaque, ce sont les durées de l'attaque qui comptent).
@export_range(1, 300) var active_frames := 60
## Temps pour repartir.
@export_range(1, 60) var leave_frames := 10
## Temps de recharge avant de pouvoir le rappeler (900 frames = 15 secondes).
@export_range(60, 3600) var cooldown_frames := 900

@export_group("Attaque")
## Le coup porté (attaque foncée ou projectile). Utilisé si « kind » = ATTACK.
@export var attack: AttackData

@export_group("Protection")
## Taille du bouclier dressé devant celui qui appelle. Utilisé si « kind » = PROTECT.
@export var barrier_size := Vector2(10, 60)

@export_group("Soin")
## Points de vie rendus, répartis sur la durée de l'action. Utilisé si « kind » = HEAL.
@export_range(0, 300) var heal_amount := 100


## Durée de l'action elle-même, sans l'apparition ni le départ.
func action_frames() -> int:
	if kind == Kind.ATTACK and attack:
		return attack.total_frames()
	return active_frames


func total_frames() -> int:
	return appear_frames + action_frames() + leave_frames
