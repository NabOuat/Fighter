"""Importe les animations SpriteLab d'un héros dans le jeu.

Pour chaque animation (un zip SpriteLab) :
  1. lit les images du zip ;
  2. les réduit de moitié (le pixel art de SpriteLab est dessiné en blocs de 2 x 2,
     on ne perd donc aucun détail) ;
  3. les recale toutes sur le même point d'ancrage : les pieds du personnage au
     centre en bas de l'image, quelle que soit la largeur donnée par SpriteLab ;
  4. les range dans assets/characters/<héros>/sprites/<animation>/frame_NN.png.

Ensuite, tools/build_sprite_frames.gd fabrique la ressource Godot (SpriteFrames).

    python tools/import_spritelab.py tools/sprite_manifests/abla_pokou_spritelab.json

Le manifeste JSON dit quel zip correspond à quelle animation :
    {"hero": "abla_pokou", "source_dir": "C:/Users/.../Downloads",
     "reference": "idle", "animations": {"idle": "spritelab-custom-xxxx_frames.zip", ...}}

Un zip « pack » (plusieurs animations dans des dossiers) se lit avec un « # » :
    "idle": "spritelab_fighting_set.zip#unity/idle"
Pour ne garder qu'une partie des images : "ko": "spritelab-custom_frames (8).zip[0:7]"

Une animation pas encore générée peut être fabriquée à partir d'une image d'une autre
(« derived »), en attendant la vraie :
    "derived": {"idle": {"from": "guard", "frame": 0, "kind": "bob"}}
kind : still (une image fixe), bob (respiration de 1 pixel), hit (recul), lying (à terre).
"""
import io
import json
import re
import sys
import zipfile
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
# Taille des images dans le jeu : assez large pour les coups, effets compris.
CANVAS_W = 192
CANVAS_H = 136
# Les pieds sont posés à cette hauteur dans l'image (en partant du haut).
BASELINE_Y = 128


def load_frames(source: Path, folder: str = "") -> list:
    """Les images d'une animation, dans l'ordre. folder : dossier dans le zip (pour un pack)."""
    with zipfile.ZipFile(source) as z:
        if folder:
            names = [n for n in z.namelist() if ("/" + folder.strip("/") + "/") in ("/" + n) and re.search(r"(\d+)\.png$", n)]
        else:
            names = [n for n in z.namelist() if re.search(r"frame(\d+)\.png$", n)]
        names.sort(key=lambda n: int(re.search(r"(\d+)\.png$", n).group(1)))
        frames = []
        for name in names:
            image = Image.open(io.BytesIO(z.read(name))).convert("RGBA")
            # Réduction de moitié, sans flou (un bloc de 2 x 2 devient 1 pixel).
            frames.append(image.resize((image.width // 2, image.height // 2), Image.NEAREST))
        return frames


def alpha(image: Image.Image) -> np.ndarray:
    return (np.array(image)[..., 3] > 128).astype(np.float32)


def best_shift(mask: np.ndarray, ref: np.ndarray, ref_anchor: int, search: int = 60) -> tuple:
    """Décalage horizontal qui superpose le mieux cette silhouette à celle de référence.
    Renvoie (ancrage x dans cette image, score de ressemblance de 0 à 1)."""
    h = min(mask.shape[0], ref.shape[0])
    mask, ref = mask[-h:], ref[-h:]
    best = (0, -1.0)
    for anchor in range(ref_anchor - search, ref_anchor + search + 1):
        dx = anchor - ref_anchor
        # On compare la référence décalée de dx avec cette image.
        w = mask.shape[1]
        shifted = np.zeros_like(mask)
        for x in range(ref.shape[1]):
            tx = x + dx
            if 0 <= tx < w:
                shifted[:, tx] = ref[:, x]
        inter = (shifted * mask).sum()
        union = np.maximum(shifted, mask).sum()
        score = inter / union if union else 0.0
        if score > best[1]:
            best = (anchor, score)
    return best


def feet_center(mask: np.ndarray) -> int:
    rows = mask[-14:]
    cols = np.where(rows.any(axis=0))[0]
    return int((cols.min() + cols.max()) / 2) if len(cols) else mask.shape[1] // 2


def lowest_opaque(frames: list) -> int:
    low = 0
    for image in frames:
        ys = np.where(alpha(image).any(axis=1))[0]
        if len(ys):
            low = max(low, int(ys.max()))
    return low


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    manifest = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    hero = manifest["hero"]
    source = Path(manifest["source_dir"])
    out_root = ROOT / "assets" / "characters" / hero / "sprites"
    animations = manifest["animations"]

    loaded = {}
    for name, entry in animations.items():
        # « fichier.zip[0:7] » : seulement les images 0 à 6 (ex : un K.O. sans le relevé).
        entry, _, cut = entry.partition("[")
        zip_name, _, folder = entry.partition("#")
        loaded[name] = load_frames(source / zip_name, folder)
        if cut:
            start, _, end = cut.rstrip("]").partition(":")
            loaded[name] = loaded[name][int(start or 0): int(end) if end else None]
        if not loaded[name]:
            raise SystemExit(f"Aucune image pour « {name} » dans {entry}")
    # Animations fabriquées à partir d'une image d'une autre (en attendant la vraie).
    derived = manifest.get("derived", {})
    for name, spec in derived.items():
        image = loaded[spec["from"]][spec.get("frame", 0)]
        kind = spec.get("kind", "still")
        if kind == "bob":
            up = Image.new("RGBA", image.size)
            up.paste(image, (0, -1), image)
            frames = [image, image, up, up]
        elif kind == "hit":
            frames = []
            for dx in (-3, -5, -3):
                back = Image.new("RGBA", image.size)
                back.paste(image, (dx, 0), image)
                frames.append(back)
        elif kind == "lying":
            frames = [image.rotate(angle, resample=Image.NEAREST, expand=True) for angle in (25, 60, 90)]
        else:
            frames = [image]
        loaded[name] = frames
    ref_name = manifest.get("reference", "idle")
    ref_mask = alpha(loaded[ref_name][0])
    ref_anchor = feet_center(ref_mask)

    report = {}
    # Les animations fabriquées passent en dernier : elles reprennent l'ancrage de leur source.
    order = [n for n in loaded if n not in derived] + [n for n in loaded if n in derived]
    for name in order:
        frames = loaded[name]
        # Animation dessinée plus petite par SpriteLab : on cherche l'agrandissement
        # qui la superpose le mieux à la référence, puis on l'applique à toutes ses images.
        if name in manifest.get("rescale", []):
            ref_ground = lowest_opaque(loaded[ref_name])
            best = (1.0, -1.0)
            for step in range(0, 11):
                factor = 1.0 + step * 0.05
                big = frames[0].resize((round(frames[0].width * factor), round(frames[0].height * factor)), Image.NEAREST)
                mask = alpha(big)
                # Mêmes pieds que la référence avant de comparer.
                shift = ref_ground - int(np.where(mask.any(axis=1))[0].max())
                padded = np.zeros((max(mask.shape[0], ref_mask.shape[0]) + 40, mask.shape[1]), np.float32)
                top = max(0, shift + 20)
                padded[top:top + mask.shape[0]] = mask[: padded.shape[0] - top]
                score = best_shift(padded[: ref_mask.shape[0]], ref_mask, ref_anchor)[1]
                if score > best[1]:
                    best = (factor, score)
            factor = best[0]
            frames = [f.resize((round(f.width * factor), round(f.height * factor)), Image.NEAREST) for f in frames]
            loaded[name] = frames
            print(f"{name:14s} agrandie x{factor:.2f}")
        if manifest.get("effect_only", {}).get(name):
            # Un effet seul (projectile) : réduit encore de moitié (un projectile est
            # plus petit qu'un personnage), centré, sans recalage sur le personnage.
            frames = [f.resize((f.width // 2, f.height // 2), Image.NEAREST) for f in frames]
            anchor, score, ground = frames[0].width // 2, 1.0, frames[0].height // 2
        elif name in derived and derived[name].get("kind", "still") == "lying":
            # À terre : le corps est couché, centré sur son milieu.
            box = frames[-1].getbbox()
            anchor, score, ground = (box[0] + box[2]) // 2, 1.0, lowest_opaque(frames)
        elif name in derived:
            source_report = report[derived[name]["from"]]
            anchor, score, ground = source_report["anchor"], 1.0, source_report["ground"]
        else:
            # Le personnage est au même endroit dans toutes les images d'une animation :
            # on cherche où il est en comparant la première ou la dernière image à la référence.
            candidates = [best_shift(alpha(frames[0]), ref_mask, ref_anchor),
                          best_shift(alpha(frames[-1]), ref_mask, ref_anchor)]
            anchor, score = max(candidates, key=lambda c: c[1])
            if name == ref_name:
                anchor, score = ref_anchor, 1.0
            ground = lowest_opaque(frames) if name not in manifest.get("airborne", []) else lowest_opaque(loaded[ref_name])
        folder = out_root / name
        folder.mkdir(parents=True, exist_ok=True)
        for old in folder.glob("frame_*.png"):
            old.unlink()
        base_y = CANVAS_H // 2 if manifest.get("effect_only", {}).get(name) else BASELINE_Y
        if manifest.get("effect_only", {}).get(name):
            # Effet : recadré au plus juste (même cadre pour toutes ses images), pour
            # que son centre soit le centre de sa zone de frappe dans le jeu.
            boxes = [f.getbbox() for f in frames if f.getbbox()]
            box = (min(b[0] for b in boxes), min(b[1] for b in boxes), max(b[2] for b in boxes), max(b[3] for b in boxes))
            for i, image in enumerate(frames):
                image.crop(box).save(folder / f"frame_{i + 1:02d}.png")
            report[name] = {"frames": len(frames), "size": [box[2] - box[0], box[3] - box[1]]}
            print(f"{name:14s} {len(frames):2d} images  effet recadré {box[2] - box[0]} x {box[3] - box[1]}")
            continue
        for i, image in enumerate(frames):
            canvas = Image.new("RGBA", (CANVAS_W, CANVAS_H), (0, 0, 0, 0))
            # paste accepte une position négative (ce qui dépasse est coupé).
            canvas.paste(image, (CANVAS_W // 2 - anchor, base_y - ground), image)
            canvas.save(folder / f"frame_{i + 1:02d}.png")
        report[name] = {"frames": len(frames), "anchor": anchor, "match": round(float(score), 2), "ground": ground}
        flag = "  <- à vérifier" if score < 0.45 else ""
        print(f"{name:14s} {len(frames):2d} images  ancrage x {anchor:3d}  ressemblance {score:.2f}{flag}")
    (out_root / "import_report.json").write_text(json.dumps(report, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()
