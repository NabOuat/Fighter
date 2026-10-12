# Legendz Fighting

Jeu de combat 2D en pixel art pour mobile, avec des héros historiques africains.
Moteur : Godot 4.7 (version Standard, langage GDScript).

## Ouvrir le projet

1. Lance Godot (`Godot_v4.7.2-stable_win64.exe`).
2. Dans le gestionnaire de projets, ouvre `Documents/legendz-fighting`.
3. Appuie sur **F5** (ou le bouton ▶ en haut à droite) pour lancer le jeu : écran titre, puis menu principal
   (Arcade, Entraînement, Tutoriel, Réglages). Histoire et Encyclopédie arriveront plus tard.

## Organisation des dossiers

| Dossier | Ce qu'il contient |
|---|---|
| `assets/` | Les fichiers bruts : images, sons, polices. Aucun code. |
| `assets/characters/` | Un sous-dossier par combattant (sprites, portrait). |
| `assets/stages/` | Les décors des arènes. |
| `assets/ui/` | Boutons, barres de vie, icônes. |
| `assets/audio/` | `music/` pour les musiques, `sfx/` pour les bruitages. |
| `autoload/` | Scripts chargés au démarrage et accessibles partout (`GameState`). |
| `data/` | Les fiches des combattants (`fighter_data.gd` = le modèle, `fighters/*.tres` = une fiche par héros). |
| `localization/` | `translations.csv` : tous les textes du jeu en français et en anglais. |
| `scenes/` | Les scènes du jeu, chacune avec son script juste à côté. |

Dans `scenes/` :
- `menus/` : écran titre, menu principal, sélection, réglages, disposition des boutons ;
- `fight/` : l'arène (`fight.gd`), le déroulement des manches (`match_flow.gd`), les
  sensations (`fight_feedback.gd`), le tutoriel, le journal des combats, les outils de test ;
- `fighters/` : le combattant (`fighter.gd`), son apparence et ses repères (`fighter_view.gd`),
  la lecture des commandes du joueur (`player_input.gd`), l'IA (`fighter_ai.gd`) ;
- `ui/` : HUD, menu pause, boutons tactiles, fenêtre de résultat ;
- `stages/` : les arènes (plus tard).

Le thème des menus (couleurs terre, ocre et or) est dans `ui/legendz_theme.tres`, fabriqué
par `tools/make_ui_theme.gd`.

## Les réglages déjà faits

- **Résolution pixel art 480×270**, agrandie pour remplir l'écran du téléphone sans flou.
- **Mode paysage** sur mobile (le téléphone peut être tourné dans les deux sens).
- **Rendu « Compatibility »** : marche sur un maximum de téléphones Android, même anciens.
- **Contrôles clavier** pour tester sur PC (positions QWERTY, donc ZQSD sur ton clavier AZERTY) :

| Action | Touches |
|---|---|
| Gauche / droite | Q / D ou flèches |
| Sauter | Z ou flèche haut |
| S'accroupir | S ou flèche bas |
| Attaque (taper plusieurs fois = combo) | J |
| Coup bas | bas + J (ou N) |
| Spécial (appui court) / charger l'énergie (maintenir) | K |
| Spécial 2 | avant + K (ou B) |
| Garde | L |
| Projection (collé à l'adversaire) | avant + L (ou H) |
| Charger (bouton à part) | C |
| Ultime (barre pleine) | U |
| Soutien | I |
| Pause | Échap ou P |

**Sur téléphone** : joystick en bas à gauche (on peut poser le pouce n'importe où autour), boutons Attaque, Spécial, Garde, Soutien et Ultime à droite (l'Ultime et le Soutien sont grisés quand ils ne sont pas prêts). Sur PC, ils s'affichent aussi et se cliquent à la souris.

**Réglages → Contrôles** :
- **Boutons en plus** : Saisie, Spécial 2, Coup bas et Charge, pour tout faire en un seul appui.
  Avec le bouton Charge, Spécial part dès l'appui.
- **Disposer les boutons** : glisser chaque bouton où on veut, régler sa taille et la
  transparence, ou choisir une disposition toute faite **Droitier** / **Gaucher** (en miroir).

**Repères des coups** (désactivables dans Réglages → Général) : un contour clair quand un coup se
prépare, une **flèche bleue vers le bas** = coup bas (se pare accroupi), une **flèche orange vers
le haut** = coup haut ou sauté (se pare debout), une **main violette** = projection (ne se pare pas :
sauter, ou projeter en même temps).

## Règles du projet

- **Noms de fichiers et dossiers** en minuscules avec `_` : `samory_toure.tres`, `health_bar.tscn`.
- **Aucun texte écrit en dur** dans les scènes ou le code : on ajoute une clé dans
  `localization/translations.csv` (ex : `MENU_ARCADE`) et on utilise la clé.
- **Un script à côté de sa scène** : `scenes/menus/main_menu.tscn` + `scenes/menus/main_menu.gd`.
- **Pas de fichier géant** : un fichier = un rôle (voir la liste de `scenes/` plus haut).
- **Les infos d'un combattant** (stats, attaques, textes) vont dans sa fiche `.tres`, pas dans le code.

## Le combat (`scenes/fight/` et `scenes/fighters/`)

- Ouvre `scenes/fight/fight.tscn` et appuie sur **F6** : ton combattant (doré) contre un mannequin (turquoise).
- **Mode combat** (au lancement) : 2 manches gagnantes, chrono de 60 s, K.O. au ralenti, temps écoulé (le plus de vie gagne), égalité ou double K.O. = la manche compte pour les deux. À chaque manche, la vie revient, l'énergie repart à zéro et le soutien est prêt. **R** relance le combat.
- **Mode entraînement** (touche **M**) : pas de chrono, personne ne peut être mis K.O., énergie pleine. **R** remet tout en place.
- **L'adversaire est contrôlé par l'IA** (par défaut). Touche **Y** : changer la difficulté (facile, normale, difficile). Touche **8** : revenir à l'IA après avoir choisi un autre comportement.
- Touches **1 à 6** : ce que fait le mannequin. 1 immobile, 2 garde debout, 3 garde accroupie, 4 combo en boucle, 5 coup bas en boucle, 6 projectile en boucle. Touche **0** : vider l'énergie. Touche **7** : le mannequin appelle son soutien (bouclier). Touche **T** : changer ton soutien (A attaque, B bouclier, C soin).
- Énergie : 4 segments. Un spécial ou une esquive coûte 1 segment, l'ultime la barre pleine. Elle se remplit en frappant, en encaissant, en parant et en chargeant (maintenir K, immobile et sans défense). Un coup du combo qui touche peut être annulé en spécial.
- Soutien : 1 par combat, appelé avec **I** (même en plein combo), puis 15 secondes de recharge. Trois types : attaque (il fonce sur l'adversaire), protection (bouclier devant toi pendant 1,5 s, arrête coups et projectiles), soin (100 PV en 1 s). La jauge sous l'énergie clignote quand il est prêt.
- Défense : maintenir **Garde** (L) ou reculer pour parer ; appuyer sur Garde **juste avant** l'impact = contre parfait ; appuyer sur Garde **pendant qu'on encaisse** = esquive mystique (coûte 1 segment d'énergie).
- Briser une garde : un **coup bas** contre une garde debout, un **coup sauté** contre une garde accroupie, ou une **projection** (collé, avant + Garde) qui traverse toute garde.
- L'IA joue à la loyale : elle a un temps de réaction (elle ne pare pas les coups rapides si elle n'est pas déjà en garde), elle devine la hauteur des coups, et en difficile elle apprend tes habitudes.
- `fight.gd` (l'arène) fait avancer le combat image par image : commandes → mouvements → séparation des corps → vérification des coups.
- **Rectangle vert** : zone où l'on peut être touché. **Rectangle rouge** : zone de frappe, visible quand le coup peut toucher.
- La vie est la même pour tous : **1 000 points**. Les stats (puissance, défense, vitesse de 1 à 5) et les attaques se règlent dans la fiche du combattant (`data/fighters/*.tres`).
- Chaque attaque se règle en *frames* (60 par seconde) : préparation (`startup`), coup actif (`active`), retour en garde (`recovery`), dégâts, durée d'étourdissement (`hitstun`), recul, projection au sol, arrêt sur image (`hitstop`).

## Ajouter un combattant

1. Dans Godot, clic droit sur `data/fighters/` → **Créer nouveau** → **Ressource** → `FighterData`.
2. Remplis la fiche dans l'Inspecteur (à droite).
3. Ajoute ses textes dans `localization/translations.csv`.
4. Ajoute sa fiche à la liste `roster` dans `autoload/game_state.gd`.

## Tests automatiques

Plus de 80 vérifications rejouent le combat image par image (coups, défense, énergie,
soutien, manches, tactile, IA). Après chaque modification :

```
python tools/run_tests.py
```

Chaque ligne affiche OK ou ÉCHEC ; le bilan final résume tout.

## Régler l'IA contre de vrais joueurs

Après chaque combat d'Arcade, une ligne est ajoutée au **journal des combats**
(`%APPDATA%/Godot/app_userdata/Legendz Fighting/match_log.csv` sur PC). Pour le résumé par
difficulté (part de victoires, coups parés...) :

```
python tools/summarize_match_log.py
```

## Tester sur un téléphone Android

Tout est configuré, sauf une étape à faire une seule fois dans Godot :
**Éditeur → Gérer les modèles d'export → Télécharger et installer** (environ 1 Go).
Ensuite : active le débogage USB du téléphone, branche-le, et clique sur l'icône Android
en haut à droite de Godot.
