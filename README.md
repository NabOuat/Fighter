# Legendz Fighting

Jeu de combat 2D en pixel art pour mobile, avec des héros historiques africains.
Moteur : Godot 4.7 (version Standard, langage GDScript).

## Ouvrir le projet

1. Lance Godot (`Godot_v4.7.2-stable_win64.exe`).
2. Dans le gestionnaire de projets, ouvre `Documents/legendz-fighting`.
3. Appuie sur **F5** (ou le bouton ▶ en haut à droite) pour lancer le jeu.

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
| Poing / pied / spécial | J / K / L |
| Pause | Échap ou P |

Les contrôles tactiles viendront avec l'écran de combat.

## Règles du projet

- **Noms de fichiers et dossiers** en minuscules avec `_` : `samory_toure.tres`, `health_bar.tscn`.
- **Aucun texte écrit en dur** dans les scènes ou le code : on ajoute une clé dans
  `localization/translations.csv` (ex : `MENU_PLAY`) et on utilise la clé.
- **Un script à côté de sa scène** : `scenes/main/main.tscn` + `scenes/main/main.gd`.
- **Les infos d'un combattant** (vie, vitesse, textes) vont dans sa fiche `.tres`, pas dans le code.

## Ajouter un combattant

1. Dans Godot, clic droit sur `data/fighters/` → **Créer nouveau** → **Ressource** → `FighterData`.
2. Remplis la fiche dans l'Inspecteur (à droite).
3. Ajoute ses textes dans `localization/translations.csv`.
4. Ajoute sa fiche à la liste `roster` dans `autoload/game_state.gd`.
