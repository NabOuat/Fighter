# SpriteLab : réglages et prompts des 3 héros

Ce fichier remplace la découpe à la main des planches ChatGPT pour les **animations**.
ChatGPT reste utilisé pour les fiches de personnage, les portraits, les cases de BD et
les **décors des ultimes** (scènes plein écran).

Les prompts sont **en anglais** : SpriteLab les comprend mieux. Copie-colle chaque bloc
tel quel.

---

## 1. Règles communes (à lire une fois)

### Le personnage de départ (onglet **Create**)
| Réglage | Valeur |
|---|---|
| Style | **Pixel 16-bit** |
| Asset type | **Characters** (attention : « Weapons » est coché par défaut) |
| Quality | **HD** (3 crédits) : il servira pour toutes les animations, il doit être parfait |
| Color palette | **Auto** |

**Vérifie avant d'animer** (sinon regénère) :
1. Vu de **profil**, tourné vers la **droite**, en entier de la tête aux pieds.
2. En **garde de combat** (genoux pliés, pieds écartés), pas en train de marcher.
3. L'arme est dans la **main avant**, bien visible, et il n'y a **aucun objet en trop**
   (tache blanche, deuxième arme…).
4. Les détails de la fiche : coiffe, bijoux, motifs du tissu.

Toutes les animations partent de ce dessin : un défaut ici se retrouve partout.

### Les animations (onglet **Animate**)
- **Sprite** : toujours le personnage de départ validé (« Change image » si besoin).
- **Directions** : **ne rien cocher** (c'est pour les jeux vus de dessus).
- **Motion** : prends le mouvement proposé quand il existe (indiqué « Préréglage » plus bas),
  sinon **Custom…** avec le texte donné.
- Termine **chaque** description par `feet stay planted` (sauf saut et esquive), pour que les
  pieds restent sur la même ligne.
- **Pas besoin de « Remove BG »** : le fond est déjà transparent (vérifié sur le test du sceptre).

### Nommer et ranger les fichiers
Renomme chaque zip téléchargé avec le **nom de l'animation** (colonne « Fichier ») et range-le
dans `assets/characters/<héros>/spritelab/`, par exemple
`assets/characters/abla_pokou/spritelab/idle.zip`. Je m'occupe du reste (réduction à la bonne
taille, découpage des images, branchement dans le jeu).

### Licence et crédits
- Les images faites avec l'offre **gratuite** servent à tester : pour le jeu publié, il faut une
  offre **payante** (licence commerciale).
- Coûts : personnage HD 3 crédits, attente 2 crédits, autres animations 6 à 10 crédits.
- **Par héros** : environ 3 + 2 + 23 × 8 ≈ **190 crédits**. Pour les 3 héros, environ 570 crédits :
  **Pro (500 crédits)** un mois puis **Starter (250)** le mois suivant, ou **Studio (1 200)** un
  seul mois. Commence par Pokou seule pour valider le rendu dans le jeu.

---

## 2. Les animations à faire (pour chaque héros)

Les animations **communes** ont le même texte pour les trois : SpriteLab garde l'arme et la
tenue de l'image de départ. Les animations **propres au héros** sont dans sa section.

| # | Fichier | Animation | Préréglage SpriteLab | Texte (Custom) |
|---|---|---|---|---|
| 1 | `idle` | Attente en garde | **Idle Breathing** | (celui proposé) |
| 2 | `walk_forward` | Marche avant | **Walk** | `walks forward in fighting stance, weapon ready, short steps` |
| 3 | `walk_back` | Marche arrière | Custom | `steps backward cautiously in fighting stance, weapon raised in guard, short steps, keeps facing right` |
| 4 | `crouch` | S'accroupir | Custom | `crouches down low into a defensive squat, weapon held across the body, then holds the pose, feet stay planted` |
| 5 | `jump` | Saut | Custom | `jumps straight up with knees tucked, cloth and hair flowing, then lands back in fighting stance` |
| 6 | `guard` | Garde debout | Custom | `raises the weapon horizontally in front of the face and chest to block, braces, holds the block, feet stay planted` |
| 7 | `guard_crouch` | Garde accroupie | Custom | `crouching low, holds the weapon in front of the legs to block a low attack, braces, feet stay planted` |
| 8 | `hit` | Coup reçu | **Hurt** | `recoils backward from a hit, head snaps back, then recovers to stance, feet stay planted` |
| 9 | `knockdown` | Projeté au sol et relevé | Custom | `knocked off the feet by a heavy blow, falls on the back, lies down briefly, then gets back up into fighting stance` |
| 10 | `ko` | K.O. | **Defeat** | `collapses to the knees then falls to the ground, defeated, weapon drops` |
| 11 | `charge` | Charge d'énergie | Custom | `plants the feet wide, clenches fists, glowing golden spiritual aura rises around the body, energy builds, feet stay planted` |
| 12 | `dodge` | Esquive mystique | Custom | `body dissolves into glowing spirit mist and fades out, then reappears from the mist in fighting stance` |
| 13 | `throw` | Projection (saisie) | Custom | `steps in, grabs the opponent with the free hand and flings them over the shoulder to the ground behind, then returns to stance, feet stay planted` |
| 14 | `victory` | Victoire | Custom ou **Royal Command** | `raises the weapon high in triumph, proud pose, cloth flowing` |
| 15 | `intro` | Entrée en scène | Custom | `walks in proudly, spins the weapon once and settles into fighting stance` |

Les animations 16 à 23 (combo, coup bas, coup sauté, spéciaux, ultime, soutien) sont dans la
section de chaque héros.

**Durées dans le jeu** : je règle la vitesse de chaque animation sur les frames du combat
(préparation, coup actif, retour en garde). Peu importe que SpriteLab donne 6 ou 12 images.
Pour les coups rapides (combo 1 et 2), prends **6 poses clés** si on te propose le choix.

---

## 3. Reine Abla Pokou (`abla_pokou`)

Style : frappes amples au **sceptre royal** à mi-distance. Éléments mystiques : l'**eau de la
Comoé** (turquoise) et le **kaolin blanc** des rites baoulé.

### Personnage de départ (Create, HD)
```
Full-body side view fighting game character facing right, Abla Pokou, Akan queen of the Baoule, dark brown skin, athletic build, fighting stance with knees bent and feet apart, long black braids with gold beads and an ornate gold headpiece, large gold disc earrings, gold necklace, strapless kente dress in red, green and gold with a layered flowing skirt, gold arm and ankle bands, gold sandals, long golden Ashanti royal scepter held forward in both hands, no other objects
```

### Ses coups
| # | Fichier | Coup | Préréglage | Texte (Custom) |
|---|---|---|---|---|
| 16 | `combo_1` | Combo, coup 1 (rapide) | Custom | `quick short jab forward with the head of the golden scepter, then back to stance, feet stay planted` |
| 17 | `combo_2` | Combo, coup 2 | **Staff Strike** | `swings the golden scepter in a fast horizontal arc at chest height, then back to stance, feet stay planted` |
| 18 | `combo_3` | Combo, coup 3 (lourd) | **Staff Strike** | `raises the golden scepter high overhead then swings it down and forward in a big powerful arc with a golden trail, then back to stance, feet stay planted` (déjà testé : réutilisable si le personnage de départ ne change pas) |
| 19 | `low_attack` | Coup bas | **Staff Slam** ou Custom | `crouches and sweeps the golden scepter low along the ground at ankle height, then back to stance, feet stay planted` |
| 20 | `air_attack` | Coup sauté | Custom | `in mid-air, swings the golden scepter downward in front of her, braids and skirt flying` |
| 21 | `special_1` | Spécial 1, Vague de la Comoé | Custom | `thrusts the golden scepter forward and summons a rolling wave of turquoise river water that surges ahead of her, feet stay planted` |
| 22 | `special_2` | Spécial 2, Cercle de kaolin | Custom | `dashes forward and strikes with the scepter while a glowing circle of white kaolin clay dust swirls around her body, then back to stance` |
| 23 | `assist` | Action de soutien | **Royal Command** ou Custom | `appears, raises the golden scepter and commands, a protective turquoise water barrier rises in front of her, then she fades away` |
| 24 | `ultimate_pose` | Ultime, L'Exode (sa pose) | Custom | `raises the golden scepter to the sky, turquoise water spirals around her and lifts her cloth and braids, glowing, feet stay planted` |

> L'ultime complet (le fromager qui se penche, les hippopotames, le peuple qui traverse) reste
> une **scène plein écran** faite avec ChatGPT. SpriteLab ne fait que sa pose. Aucun enfant, et
> le fleuve n'a pas de visage (règle de l'arc).

**Projectile du spécial 1** (onglet Create, Asset type **Effects** s'il existe, sinon Environment) :
```
side view rolling wave of turquoise river water moving right, foam crest, pixel art projectile, no character
```
puis Animate → Custom : `the water wave rolls and churns while moving forward, loop`.

---

## 4. Sékou Ouattara (`sekou_ouattara`)

Style : puissant et maîtrisé, grands balayages de **sabre courbe** et **lance de jet** à
distance. Élément mystique : la **poussière d'or et le vent des caravanes** (doré).

### Personnage de départ (Create, HD)
```
Full-body side view fighting game character facing right, Sekou Ouattara, Dioula merchant-king of Kong, dark brown skin, short black beard, strong build, fighting stance with knees bent and feet apart, white and indigo blue turban, flowing white robe with an indigo blue sleeveless coat with gold embroidery, brown leather belt with leather merchant pouches, brown leather boots with gold bands, curved silver saber held forward in the right hand, no other objects
```

### Ses coups
| # | Fichier | Coup | Préréglage | Texte (Custom) |
|---|---|---|---|---|
| 16 | `combo_1` | Combo, coup 1 (rapide) | Custom | `quick forward slash with the curved saber at chest height, then back to stance, feet stay planted` |
| 17 | `combo_2` | Combo, coup 2 | Custom | `fast backhand horizontal sweep with the curved saber leaving a silver arc, then back to stance, feet stay planted` |
| 18 | `combo_3` | Combo, coup 3 (lourd) | Custom | `raises the curved saber overhead and brings it down in a powerful diagonal slash with a bright silver trail, robe flaring, then back to stance, feet stay planted` |
| 19 | `low_attack` | Coup bas | Custom | `drops low and sweeps the curved saber along the ground at ankle height, then back to stance, feet stay planted` |
| 20 | `air_attack` | Coup sauté | Custom | `in mid-air, slashes the curved saber downward in a wide arc, robe and turban tail flying` |
| 21 | `special_1` | Spécial 1, Lance du marchand | Custom | `pulls a short throwing spear from his back and hurls it forward with force, then back to stance, feet stay planted` |
| 22 | `special_2` | Spécial 2, Vent des caravanes | Custom | `dashes forward inside a swirling whirlwind of golden sand dust, saber slashing, then back to stance` |
| 23 | `assist` | Action de soutien | Custom | `appears, hurls a throwing spear forward, then fades away in golden dust` |
| 24 | `ultimate_pose` | Ultime, L'esprit des caravanes (sa pose) | Custom | `raises the curved saber, a golden sandstorm spirals around him, robe and turban flowing, glowing gold, feet stay planted` |

**Projectile du spécial 1** (Create) :
```
side view short throwing spear with iron tip flying right, motion streaks, pixel art projectile, no character
```

> La scène de l'ultime (le décor qui défile, la caravane fantôme) reste faite avec ChatGPT.

---

## 5. Béhanzin (`behanzin`)

Style : lourd et intimidant, coups lents et dévastateurs avec la **récade** (hache dorée).
Élément mystique : l'**esprit du requin**, son emblème royal (eau bleu profond).

### Personnage de départ (Create, HD)
```
Full-body side view fighting game character facing right, Behanzin, king of Dahomey, dark brown skin, short black hair and goatee, very muscular heavy build, wide fighting stance with knees bent, bare chest, necklaces of red and white beads, royal cloth draped over one shoulder in red, navy blue and gold with a shark emblem pattern, gold arm and ankle bands, gold sandals, golden recade ceremonial axe with a double blade held forward in the right hand, no other objects
```

### Ses coups
| # | Fichier | Coup | Préréglage | Texte (Custom) |
|---|---|---|---|---|
| 16 | `combo_1` | Combo, coup 1 (rapide) | Custom | `short forward chop with the golden recade axe, then back to stance, feet stay planted` |
| 17 | `combo_2` | Combo, coup 2 | Custom | `heavy horizontal swing of the golden recade axe with a golden arc, then back to stance, feet stay planted` |
| 18 | `combo_3` | Combo, coup 3 (lourd) | Custom | `lifts the golden recade axe high overhead with both hands and smashes it down to the ground in front, dust burst, then back to stance, feet stay planted` |
| 19 | `low_attack` | Coup bas | Custom | `crouches and swings the golden recade axe low at ankle height, then back to stance, feet stay planted` |
| 20 | `air_attack` | Coup sauté | Custom | `in mid-air, chops the golden recade axe downward, royal cloth flying` |
| 21 | `special_1` | Spécial 1, Morsure du requin | Custom | `swings the recade forward and launches a deep blue water shark spirit that lunges ahead with open jaws, feet stay planted` |
| 22 | `special_2` | Spécial 2, Charge royale | Custom | `charges forward shoulder first like a bull, deep blue water splashing around him, then swings the recade, then back to stance` |
| 23 | `assist` | Action de soutien | Custom | `appears, slams the golden recade into the ground sending a blue water shockwave forward, then fades away` |
| 24 | `ultimate_pose` | Ultime, Le requin en colère (sa pose) | Custom | `raises the golden recade high, a towering deep blue water column with a shark spirit rises behind him, glowing blue, feet stay planted` |

**Projectile du spécial 1** (Create) :
```
side view spectral shark made of deep blue water lunging right with open jaws, pixel art projectile, no character
```

> La scène de l'ultime (l'océan qui monte, le requin qui jaillit) reste faite avec ChatGPT.

---

## 6. Ordre conseillé

1. **Pokou seule** : personnage de départ HD, puis `idle`, `walk_forward`, `combo_1`, `combo_2`,
   `combo_3`, `hit`, `guard`. Envoie-les-moi : je les branche dans le jeu et on juge le rendu en
   combat avant de dépenser le reste.
2. Le reste de Pokou.
3. Sékou, puis Béhanzin, dans le même ordre.

Si une animation déforme le personnage (tenue qui change, arme qui disparaît), regénère-la
plutôt que de la garder : la cohérence compte plus que le nombre d'images.
