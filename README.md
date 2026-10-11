# Legendz Fighting

Jeu de combat 2D en pixel art pour mobile, avec des héros historiques africains.
Moteur : Godot 4.7 (version Standard, langage GDScript).

## Ouvrir le projet

1. Lance Godot (`Godot_v4.7.2-stable_win64.exe`).
2. Dans le gestionnaire de projets, ouvre `Documents/legendz-fighting`.
3. Appuie sur **F5** (ou le bouton ▶ en haut à droite) pour lancer le jeu : il démarre sur l'arène de combat (prototype).

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
`main/` (écran de démarrage), `menus/`, `fight/` (le combat), `fighters/` (le
personnage jouable), `stages/` (les arènes), `ui/` (barres de vie, boutons tactiles).

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
| Spécial (appui court) / charger l'énergie (maintenir) | K |
| Spécial 2 | avant + K |
| Garde | L |
| Ultime (barre pleine) | U |
| Soutien | I |
| Pause | Échap ou P |

**Sur téléphone** : joystick en bas à gauche (on peut poser le pouce n'importe où dans cette zone), boutons Attaque, Spécial, Garde, Soutien et Ultime à droite (l'Ultime et le Soutien sont grisés quand ils ne sont pas prêts). Sur PC, ils s'affichent aussi et se cliquent à la souris.

## Règles du projet

- **Noms de fichiers et dossiers** en minuscules avec `_` : `samory_toure.tres`, `health_bar.tscn`.
- **Aucun texte écrit en dur** dans les scènes ou le code : on ajoute une clé dans
  `localization/translations.csv` (ex : `MENU_PLAY`) et on utilise la clé.
- **Un script à côté de sa scène** : `scenes/main/main.tscn` + `scenes/main/main.gd`.
- **Les infos d'un combattant** (stats, attaques, textes) vont dans sa fiche `.tres`, pas dans le code.

## Le combat (`scenes/fight/` et `scenes/fighters/`)

- Ouvre `scenes/fight/fight.tscn` et appuie sur **F6** : ton combattant (doré) contre un mannequin (turquoise).
- **Mode combat** (au lancement) : 2 manches gagnantes, chrono de 60 s, K.O. au ralenti, temps écoulé (le plus de vie gagne), égalité ou double K.O. = la manche compte pour les deux. La vie revient à chaque manche, l'énergie est gardée. **R** relance le combat.
- **Mode entraînement** (touche **M**) : pas de chrono, personne ne peut être mis K.O., énergie pleine. **R** remet tout en place.
- Touches **1 à 6** : ce que fait le mannequin. 1 immobile, 2 garde debout, 3 garde accroupie, 4 combo en boucle, 5 coup bas en boucle, 6 projectile en boucle. Touche **0** : vider l'énergie. Touche **7** : le mannequin appelle son soutien (bouclier). Touche **T** : changer ton soutien (A attaque, B bouclier, C soin).
- Énergie : 4 segments. Un spécial ou une esquive coûte 1 segment, l'ultime la barre pleine. Elle se remplit en frappant, en encaissant, en parant et en chargeant (maintenir K, immobile et sans défense). Un coup du combo qui touche peut être annulé en spécial.
- Soutien : 1 par combat, appelé avec **I** (même en plein combo), puis 15 secondes de recharge. Trois types : attaque (il fonce sur l'adversaire), protection (bouclier devant toi pendant 1,5 s, arrête coups et projectiles), soin (100 PV en 1 s). La jauge sous l'énergie clignote quand il est prêt.
- Défense : maintenir **Garde** (L) ou reculer pour parer ; appuyer sur Garde **juste avant** l'impact = contre parfait ; appuyer sur Garde **pendant qu'on encaisse** = esquive mystique (coûte 1 segment d'énergie).
- `fight.gd` (l'arène) fait avancer le combat image par image : commandes → mouvements → séparation des corps → vérification des coups.
- **Rectangle vert** : zone où l'on peut être touché. **Rectangle rouge** : zone de frappe, visible quand le coup peut toucher.
- La vie est la même pour tous : **1 000 points**. Les stats (puissance, défense, vitesse de 1 à 5) et les attaques se règlent dans la fiche du combattant (`data/fighters/*.tres`).
- Chaque attaque se règle en *frames* (60 par seconde) : préparation (`startup`), coup actif (`active`), retour en garde (`recovery`), dégâts, durée d'étourdissement (`hitstun`), recul, projection au sol, arrêt sur image (`hitstop`).

## Ajouter un combattant

1. Dans Godot, clic droit sur `data/fighters/` → **Créer nouveau** → **Ressource** → `FighterData`.
2. Remplis la fiche dans l'Inspecteur (à droite).
3. Ajoute ses textes dans `localization/translations.csv`.
4. Ajoute sa fiche à la liste `roster` dans `autoload/game_state.gd`.
