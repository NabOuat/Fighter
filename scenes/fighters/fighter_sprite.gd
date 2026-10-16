class_name FighterSprite
extends AnimatedSprite2D
## Le vrai dessin animé d'un combattant (images SpriteLab), à la place des rectangles.
##
## Il choisit l'animation et l'image d'après l'état du combattant, à chaque frame
## de combat. Pour les coups, l'image suit exactement les frames du coup
## (préparation, coup actif, retour) : ce qu'on voit correspond à la zone qui touche.
## Les images sont dessinées tournées vers la droite, pieds au centre en bas.

## Les images font 192 x 136, pieds à 128 px du haut (voir tools/import_spritelab.py).
const ART_FEET_Y := 128.0
const ART_HEIGHT := 136.0
## Taille du dessin dans l'arène : 1 pixel du dessin = 1/1,75 d'unité de combat.
## Avec la caméra qui zoome x1,75, chaque pixel du dessin tombe sur un pixel de
## l'écran : le pixel art reste net.
const ART_SCALE := 1.0 / 1.75
## Images par seconde des animations en boucle (attente, marche, charge).
const LOOP_FPS := 9.0
## Image tenue pendant une pose (garde, accroupi) : le moment le plus marqué.
const HOLD_FRAME := {"crouch": 2, "guard": 3, "guard_crouch": 2}
## Couleur du flash quand on est touché, paré ou qu'on contre.
const FLASH_TINT := {
	"hit": Color(1.8, 1.8, 1.8), "block": Color(0.8, 1.1, 1.7), "parry": Color(0.7, 1.7, 1.7),
}

## Éclat du dessin pendant la préparation d'un coup (remplace le contour des rectangles).
const STARTUP_GLOW := Color(1.35, 1.3, 1.1)

## Remplaçants des animations manquantes (on suit la chaîne jusqu'à en trouver une).
const FALLBACK := {
	"walk_back": "walk_forward", "walk_forward": "idle",
	"crouch": "guard_crouch", "guard_crouch": "crouch", "guard": "idle",
	"jump": "idle", "air_attack": "combo_2", "low_attack": "combo_1",
	"combo_2": "combo_1", "combo_3": "combo_2", "combo_1": "idle",
	"special_1": "combo_3", "special_2": "combo_3", "throw": "combo_1",
	"ultimate_pose": "special_1", "assist": "combo_3",
	"hit": "idle", "knockdown": "ko", "ko": "hit",
	"charge": "idle", "dodge": "hit", "victory": "idle", "intro": "walk_forward",
}

## Pose imposée par l'arène (« intro », « victory ») et son avancement de 0 à 1.
var cinematic := ""
var cinematic_progress := 0.0

var _fighter: Fighter
var _ticks := 0


func setup(fighter: Fighter) -> void:
	_fighter = fighter
	sprite_frames = fighter.data.sprite_frames
	centered = true
	offset = Vector2(0, -(ART_FEET_Y - ART_HEIGHT / 2.0))
	scale = Vector2.ONE * ART_SCALE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Une frame de combat : choisit l'image à montrer.
func refresh() -> void:
	_ticks += 1
	var f := _fighter
	flip_h = f.facing == -1
	var choice := _choose()
	_show(choice[0], choice[1])
	modulate = f.data.tint
	# Un coup se prépare : le dessin s'éclaire (on le voit venir).
	var attack := f.current_attack
	if f.show_markers and attack and f.attack_frame <= attack.startup and attack.hitbox.has_area():
		modulate = STARTUP_GLOW
	# Serment en cours : le dessin luit d'or.
	if f.oath_frames > 0:
		var glow := 0.15 + 0.1 * sin(_ticks / 6.0)
		modulate = Color(1.0 + glow, 1.0 + glow * 0.8, 1.0 - glow * 0.3)
	if f.flash_frames > 0:
		var kind := "hit"
		if f.flash_color == Fighter.BLOCK_FLASH:
			kind = "block"
		elif f.flash_color == Fighter.PARRY_FLASH:
			kind = "parry"
		modulate = FLASH_TINT[kind]


## Renvoie [animation, avancement de 0 à 1 (ou -1 = en boucle)].
func _choose() -> Array:
	var f := _fighter
	if cinematic != "":
		return [cinematic, cinematic_progress]
	var attack := f.current_attack
	if attack and f.state in [Fighter.State.ATTACK, Fighter.State.JUMP]:
		return [_attack_animation(attack), clampf(float(f.attack_frame) / attack.total_frames(), 0.0, 1.0)]
	match f.state:
		Fighter.State.WALK:
			var forward := signf(f.velocity.x) == float(f.facing)
			return ["walk_forward" if forward else "walk_back", -1.0]
		Fighter.State.CROUCH:
			return ["crouch", -2.0]
		Fighter.State.GUARD, Fighter.State.BLOCKSTUN:
			return ["guard_crouch" if f.guard_low else "guard", -2.0]
		Fighter.State.JUMP:
			# Montée, sommet puis descente : on suit la vitesse verticale.
			return ["jump", clampf(0.35 + f.velocity.y / 900.0, 0.2, 0.8)]
		Fighter.State.HITSTUN:
			return ["hit", 0.5]
		Fighter.State.JUGGLE:
			return ["knockdown", 0.1]
		Fighter.State.KNOCKDOWN:
			if f.health <= 0:
				return ["ko", 1.0 if f.is_on_floor() else 0.4]
			return ["knockdown", 0.15 if not f.is_on_floor() else 0.45]
		Fighter.State.GETUP:
			return ["knockdown", 1.0 - float(f.stun_frames) / Fighter.GETUP_FRAMES * 0.45]
		Fighter.State.DODGE:
			return ["dodge", 1.0 - float(f.stun_frames) / Fighter.DODGE_FRAMES]
		Fighter.State.CHARGE:
			return ["charge", -1.0]
	return ["idle", -1.0]


func _attack_animation(attack: AttackData) -> String:
	var data := _fighter.data
	var index := data.combo.find(attack)
	if index >= 0:
		return "combo_%d" % (index + 1)
	if attack == data.low_attack:
		return "low_attack"
	if attack == data.air_attack:
		return "air_attack"
	if attack == data.special_1:
		return "special_1"
	if attack == data.special_2:
		return "special_2"
	if attack == data.throw:
		return "throw"
	if attack == data.ultimate:
		return "ultimate_pose"
	return "combo_1"


## L'animation la plus proche quand une animation n'a pas encore été générée :
## un héros est jouable avec seulement attente, marche, combo, coup reçu et K.O.
func _available(anim: String) -> String:
	var tried := {}
	while not sprite_frames.has_animation(anim) and not tried.has(anim):
		tried[anim] = true
		anim = FALLBACK.get(anim, "idle")
	return anim if sprite_frames.has_animation(anim) else String(sprite_frames.get_animation_names()[0])


## progress : de 0 à 1 dans l'animation ; -1 = boucle ; -2 = pose tenue.
func _show(anim: String, progress: float) -> void:
	anim = _available(anim)
	if animation != anim:
		animation = anim
	var count := sprite_frames.get_frame_count(anim)
	if progress == -1.0:
		frame = int(_ticks * LOOP_FPS / 60.0) % count
	elif progress == -2.0:
		frame = mini(HOLD_FRAME.get(anim, count / 2), count - 1)
	else:
		frame = mini(int(progress * count), count - 1)
