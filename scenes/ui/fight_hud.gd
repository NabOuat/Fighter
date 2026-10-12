class_name FightHUD
extends CanvasLayer
## L'affichage du combat : barres de vie et d'énergie, jauges de soutien,
## manches gagnées, chrono, grandes annonces, compteur de combo et messages.
##
## Il ne décide de rien : l'arène lui dit quoi montrer à chaque frame (refresh).

## Durée d'affichage d'un message (« Contre parfait ! », « Ultime ! »...).
const POPUP_FRAMES := 50

var popup_frames := 0

@onready var player_bar: HealthBar = $PlayerBar
@onready var dummy_bar: HealthBar = $DummyBar
@onready var player_energy: EnergyBar = $PlayerEnergy
@onready var dummy_energy: EnergyBar = $DummyEnergy
@onready var player_assist: AssistGauge = $PlayerAssist
@onready var dummy_assist: AssistGauge = $DummyAssist
@onready var player_markers: WinMarkers = $PlayerWins
@onready var dummy_markers: WinMarkers = $DummyWins
@onready var player_name: Label = $PlayerName
@onready var dummy_name: Label = $DummyName
@onready var timer_label: Label = $TimerLabel
@onready var announce_label: Label = $AnnounceLabel
@onready var combo_label: Label = $ComboLabel
@onready var popup_label: Label = $PopupLabel


## Les noms des deux combattants (clés de traduction).
func show_names(player: Fighter, dummy: Fighter) -> void:
	player_name.text = player.data.name_key
	dummy_name.text = dummy.data.name_key


## Affiche un message quelques instants au centre de l'écran.
func show_popup(text_key: String) -> void:
	popup_label.text = text_key
	popup_frames = POPUP_FRAMES


func clear_popup() -> void:
	popup_frames = 0


## Met tout l'affichage à jour.
## timer_frames < 0 : pas de chrono (« -- »). announce : texte déjà traduit, ou vide.
func refresh(player: Fighter, dummy: Fighter, player_wins: int, dummy_wins: int,
		show_wins: bool, timer_frames: int, announce: String) -> void:
	player_bar.set_ratio(float(player.health) / Fighter.MAX_HEALTH)
	dummy_bar.set_ratio(float(dummy.health) / Fighter.MAX_HEALTH)
	player_energy.set_ratio(player.energy / Fighter.MAX_ENERGY)
	dummy_energy.set_ratio(dummy.energy / Fighter.MAX_ENERGY)
	player_assist.show_fighter(player)
	dummy_assist.show_fighter(dummy)
	player_markers.visible = show_wins
	dummy_markers.visible = show_wins
	player_markers.set_wins(player_wins)
	dummy_markers.set_wins(dummy_wins)
	# Le chrono affiche les secondes restantes, arrondies au-dessus (59,2 s → 60).
	timer_label.text = "--" if timer_frames < 0 else str(ceili(timer_frames / 60.0))
	announce_label.text = announce
	announce_label.visible = announce != ""
	combo_label.visible = player.combo_hits >= 2
	combo_label.text = tr("FIGHT_COMBO_HITS") % player.combo_hits
	popup_frames = maxi(0, popup_frames - 1)
	popup_label.visible = popup_frames > 0
