class_name FightFeedback
extends Node
## Les sensations du combat : étincelles, bruitages, tremblement de l'écran,
## vibration du téléphone et petits messages (« Contre parfait ! »...).
##
## L'arène lui dit ce qui vient de se passer ; lui ne change rien au combat.
## Pour régler la « sensation » d'un coup, c'est ici (et dans HitEffects / SoundBank).

## Tremblement de l'écran sur les gros coups : force (pixels) et durée (frames).
const SHAKE_HEAVY := 3.0
const SHAKE_HEAVY_FRAMES := 8
const SHAKE_KO := 5.0
const SHAKE_KO_FRAMES := 20
## Un coup est « lourd » (gros bruit, grosses étincelles) à partir de ces dégâts.
const HEAVY_DAMAGE := 60
## Vibrations du téléphone (en millisecondes) quand le joueur frappe ou encaisse fort.
const VIBRATE_HEAVY_MS := 35
const VIBRATE_KO_MS := 160

## Jeu en ligne : le rollback rejoue des frames déjà affichées. Chaque effet est
## noté avec sa frame ; une frame rejouée ne relance pas un effet déjà joué
## (seuls les effets nouveaux, découverts en rejouant, se déclenchent).
## Effets notés gardés pendant 2 secondes.
const PLAYED_MEMORY_FRAMES := 120

## Nombre d'effets joués depuis le début (sert aux tests).
var effects_played := 0
var shake_frames := 0
var shake_strength := 0.0
var _rng := RandomNumberGenerator.new()
var _frame := 0
var _replaying := false
## Numéro de l'effet dans la frame (deux coups dans la même frame = deux effets).
var _event_index := 0
## Effets déjà joués : frame -> {clé: vrai}.
var _played := {}

var effects: HitEffects
var sounds: SoundBank
var camera: Camera2D
var hud: FightHUD
## Le combattant du joueur (seul lui fait vibrer le téléphone).
var player: Fighter


func setup(hit_effects: HitEffects, sound_bank: SoundBank, fight_camera: Camera2D, fight_hud: FightHUD, human: Fighter) -> void:
	effects = hit_effects
	sounds = sound_bank
	camera = fight_camera
	hud = fight_hud
	player = human


## Appelée par l'arène au début de chaque frame de combat.
func begin_frame(frame: int, replaying: bool) -> void:
	_frame = frame
	_replaying = replaying
	_event_index = 0
	if not replaying:
		_played.erase(frame - PLAYED_MEMORY_FRAMES)
		# Une frame jouée pour de vrai repart de zéro (après un retour en arrière,
		# les frames suivantes sont de nouvelles frames).
		_played.erase(frame)


## Vrai si cet effet doit se jouer : toujours la première fois, jamais quand
## la frame est rejouée et que l'effet y avait déjà été joué.
func _first_time(event: String) -> bool:
	var key := "%d %s" % [_event_index, event]
	_event_index += 1
	var played: Dictionary = _played.get_or_add(_frame, {})
	if _replaying and played.has(key):
		return false
	played[key] = true
	effects_played += 1
	return true


## Un coup vient d'arriver (touché, paré, contré, projection évitée...).
func on_hit(result: Fighter.HitResult, attack: AttackData, attacker: Fighter, defender: Fighter, point: Vector2) -> void:
	if not _first_time("hit %d %s" % [result, attack.resource_path]):
		return
	match result:
		Fighter.HitResult.HIT:
			var heavy := is_heavy(attack)
			effects.burst(HitEffects.Kind.HIT_HEAVY if heavy else HitEffects.Kind.HIT_LIGHT, point)
			sounds.play("hit_heavy" if heavy else "hit_light")
			if heavy:
				shake(SHAKE_HEAVY, SHAKE_HEAVY_FRAMES)
				if player.is_player and player in [attacker, defender]:
					GameState.vibrate(VIBRATE_HEAVY_MS)
			if attack.is_throw:
				hud.show_popup("FIGHT_THROW")
		Fighter.HitResult.BLOCKED:
			effects.burst(HitEffects.Kind.BLOCK, point)
			sounds.play("block")
		Fighter.HitResult.PARRIED:
			effects.burst(HitEffects.Kind.PARRY, point)
			sounds.play("parry")
			hud.show_popup("FIGHT_PARRY")
		Fighter.HitResult.TECHED:
			effects.burst(HitEffects.Kind.BLOCK, point)
			sounds.play("block")
			hud.show_popup("FIGHT_THROW_TECH")


func is_heavy(attack: AttackData) -> bool:
	return attack.damage >= HEAVY_DAMAGE or attack.knockdown


## Un coup ou un projectile arrêté par le bouclier d'un soutien.
func barrier(at: Vector2) -> void:
	if not _first_time("barrier"):
		return
	effects.burst(HitEffects.Kind.BLOCK, at)
	sounds.play("block")


## Deux projectiles qui s'annulent.
func clash(at: Vector2) -> void:
	if not _first_time("clash"):
		return
	effects.burst(HitEffects.Kind.CLASH, at)
	sounds.play("block")


func attack_started(attack: AttackData) -> void:
	if attack.is_ultimate or not _first_time("attack"):
		return
	sounds.play("special" if attack.energy_cost > 0 else "whoosh", -4.0)


func dodged() -> void:
	if not _first_time("dodge"):
		return
	sounds.play("dodge")
	hud.show_popup("FIGHT_DODGE")


func assist_called() -> void:
	if not _first_time("assist"):
		return
	sounds.play("assist")


func ultimate_started() -> void:
	if not _first_time("ultimate"):
		return
	sounds.play("ultimate")
	hud.show_popup("FIGHT_ULTIMATE")


func round_started() -> void:
	if not _first_time("round"):
		return
	sounds.play("gong")


func round_ended(by_ko: bool) -> void:
	if not _first_time("round_end"):
		return
	if by_ko:
		sounds.play("ko")
		GameState.vibrate(VIBRATE_KO_MS)
		shake(SHAKE_KO, SHAKE_KO_FRAMES)
	else:
		sounds.play("gong")


## Tout s'arrête (nouvelle manche, remise en place de l'entraînement).
func clear() -> void:
	if not _first_time("clear"):
		return
	shake_frames = 0
	hud.clear_popup()


func shake(strength: float, frames: int) -> void:
	shake_strength = maxf(shake_strength if shake_frames > 0 else 0.0, strength)
	shake_frames = maxi(shake_frames, frames)


## Le tremblement s'atténue à chaque frame ; seul l'affichage bouge, pas le combat.
func update() -> void:
	if shake_frames > 0:
		shake_frames -= 1
		var strength := minf(shake_strength * shake_frames / float(SHAKE_HEAVY_FRAMES), shake_strength)
		camera.offset = Vector2(_rng.randf_range(-strength, strength), _rng.randf_range(-strength, strength)).round()
	else:
		camera.offset = Vector2.ZERO
