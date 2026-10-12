class_name HitEffects
extends Node2D
## Les effets d'impact : étincelles au point de contact, anneau du contre parfait.
##
## Chaque effet est créé au moment du coup, puis disparaît tout seul.
## Les particules sont de petits carrés, dans l'esprit du pixel art.

enum Kind { HIT_LIGHT, HIT_HEAVY, BLOCK, PARRY, CLASH }

## Réglages de chaque effet : nombre d'étincelles, vitesse, taille, couleur.
const STYLES := {
	Kind.HIT_LIGHT: {"amount": 10, "speed": 90.0, "size": 2.0, "color": Color(1.0, 0.95, 0.75)},
	Kind.HIT_HEAVY: {"amount": 22, "speed": 150.0, "size": 3.0, "color": Color(1.0, 0.8, 0.35)},
	Kind.BLOCK: {"amount": 8, "speed": 70.0, "size": 2.0, "color": Color(0.6, 0.85, 1.0)},
	Kind.PARRY: {"amount": 16, "speed": 120.0, "size": 2.0, "color": Color(0.3, 1.0, 1.0)},
	Kind.CLASH: {"amount": 14, "speed": 110.0, "size": 2.0, "color": Color(1.0, 1.0, 1.0)},
}
const LIFETIME := 0.28

## Nombre d'effets créés depuis le début (sert aux tests).
var spawned := 0


func burst(kind: Kind, at: Vector2) -> void:
	var style: Dictionary = STYLES[kind]
	var sparks := CPUParticles2D.new()
	sparks.position = at
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = style.amount
	sparks.lifetime = LIFETIME
	sparks.spread = 180.0
	sparks.gravity = Vector2(0, 260)
	sparks.initial_velocity_min = style.speed * 0.5
	sparks.initial_velocity_max = style.speed
	sparks.scale_amount_min = style.size
	sparks.scale_amount_max = style.size
	sparks.color = style.color
	add_child(sparks)
	sparks.emitting = true
	_free_later(sparks, LIFETIME + 0.1)
	if kind == Kind.PARRY:
		var ring := ParryRing.new()
		ring.position = at
		add_child(ring)
		_free_later(ring, ParryRing.DURATION)
	spawned += 1


func _free_later(node: Node, seconds: float) -> void:
	get_tree().create_timer(seconds, false).timeout.connect(node.queue_free)


## Un cercle cyan qui s'agrandit et s'efface : la signature du contre parfait.
class ParryRing:
	extends Node2D

	const DURATION := 0.3
	const MAX_RADIUS := 26.0
	var _age := 0.0

	func _process(delta: float) -> void:
		_age += delta
		queue_redraw()

	func _draw() -> void:
		var progress := clampf(_age / DURATION, 0.0, 1.0)
		var color := Color(0.3, 1.0, 1.0, 1.0 - progress)
		draw_arc(Vector2.ZERO, 6.0 + MAX_RADIUS * progress, 0.0, TAU, 24, color, 2.0)
