class_name StoryData
extends RefCounted
## Le contenu du mode Histoire : les chapitres de l'arc d'Abla Pokou (dossier de
## recherche docs/recherche/arc_pokou.md, section 4).
##
## Chaque chapitre est une suite d'étapes :
## - {"panels": [...]} : des cases racontées par le griot. Une case est un nom
##   d'image (assets/story/pokou/<nom>.png, texte STORY_<NOM>) ou un dictionnaire
##   {"image": ..., "text": ...} quand une image sert avec un autre texte ;
## - {"fight": {...}} : un combat (qui joue, contre qui, règle, décor...).
## Règles de combat : "duel" (une manche), "survival" (tenir contre des vagues
## jusqu'à la fin du temps), "boss" (plusieurs phases d'affilée).

const ART_DIR := "res://assets/story/pokou/"

const POKOU_ARC := [
	{
		"id": "ch1", "title": "STORY_CH1_TITLE",
		"steps": [
			{"panels": ["griot", "ch1_1", "ch1_2", "ch1_3", "ch1_4"]},
		],
	},
	{
		"id": "ch2", "title": "STORY_CH2_TITLE",
		"steps": [
			{"panels": ["ch2_1", "ch2_2", "ch2_3"]},
			{"fight": {"player": &"dakon", "opponent": &"abla_pokou", "rule": "duel", "difficulty": FighterAI.Difficulty.EASY,
				"stage": "kumasi_nuit", "intro": "STORY_FIGHT_SPARRING"}},
			{"fight": {"player": &"dakon", "opponent": &"itsa", "rule": "duel", "difficulty": FighterAI.Difficulty.NORMAL,
				"stage": "kumasi_nuit", "intro": "STORY_FIGHT_ITSA_WAR"}},
			{"panels": ["ch2_4"]},
		],
	},
	{
		"id": "ch3", "title": "STORY_CH3_TITLE",
		"steps": [
			{"panels": ["ch3_1", "ch3_2", "ch3_3", "ch3_4"]},
			{"fight": {"player": &"abla_pokou", "opponent": &"guerrier_itsa", "rule": "survival", "waves": 4, "seconds": 60,
				"difficulty": FighterAI.Difficulty.EASY, "stage": "foret_depart", "fallback_stage": "kumasi_nuit",
				"intro": "STORY_FIGHT_DAWN"}},
		],
	},
	{
		"id": "ch4", "title": "STORY_CH4_TITLE",
		"steps": [
			{"panels": ["ch4_1", "ch4_2", "ch4_3"]},
			{"fight": {"player": &"abla_pokou", "opponent": &"itsa", "rule": "boss", "phases": 3,
				"difficulty": FighterAI.Difficulty.NORMAL, "stage": "savane_itsa", "intro": "STORY_FIGHT_ITSA_BOSS"}},
			{"panels": [{"image": "ch4_2", "text": "STORY_CH4_OUTRO"}]},
		],
	},
	{
		"id": "ch5", "title": "STORY_CH5_TITLE",
		"steps": [
			{"panels": ["ch5_1", "ch5_2", "ch5_3"]},
			{"fight": {"player": &"abla_pokou", "opponent": &"genie_comoe", "rule": "boss", "phases": 3,
				"difficulty": FighterAI.Difficulty.NORMAL, "stage": "comoe_crue", "intro": "STORY_FIGHT_GENIE"}},
			{"panels": [{"image": "ch5_3", "text": "STORY_CH5_OUTRO"}]},
		],
	},
	{
		"id": "ch6", "title": "STORY_CH6_TITLE",
		"steps": [
			{"panels": ["ch6_1", "ch6_2", "ch6_3", "ch6_4"]},
		],
	},
	{
		"id": "ch7", "title": "STORY_CH7_TITLE",
		"steps": [
			{"panels": ["ch7_1", "ch7_2", "ch7_3", "ch7_4", "griot"]},
		],
	},
]

## Ce que débloque la fin de chaque chapitre (règle du cahier des charges :
## battre un personnage le débloque en soutien, finir l'arc le rend jouable).
const UNLOCKS := {
	"ch2": {"support": [&"dakon"]},
	"ch4": {"support": [&"itsa"]},
	"ch7": {"playable": [&"dakon", &"itsa"]},
}


## Une case : son image et la clé de son texte.
static func panel_info(panel) -> Dictionary:
	if panel is Dictionary:
		return {"image": ART_DIR + panel.image + ".png", "text": panel.text}
	return {"image": ART_DIR + panel + ".png", "text": "STORY_" + String(panel).to_upper()}
