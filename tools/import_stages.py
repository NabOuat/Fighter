"""Prépare les décors générés (ChatGPT) pour le jeu.

Pour chaque décor de assets/stages/<décor>/ (back.png, middle.png, ground.png) :
  1. met les trois couches à la même taille ;
  2. pose le bas des bâtiments ou des arbres (couche « milieu ») exactement sur le
     haut du sol, pour qu'aucune bande vide n'apparaisse entre les deux ;
  3. réduit à la densité de pixels des personnages (840 px pour les 480 unités de
     l'arène : 1 pixel du décor = 1 pixel de l'écran avec la caméra zoomée) ;
  4. limite la palette et rend les bords nets (vrai pixel art, comme les personnages) ;
  5. écrit le résultat dans assets/stages/<décor>/game/layer_<couche>.png.

Les originaux ne sont pas modifiés (ils ne partent pas dans l'APK).

    python tools/import_stages.py            (tous les décors)
    python tools/import_stages.py savane_itsa
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
STAGES = ROOT / "assets" / "stages"
# Taille de travail commune (les originaux font entre 2167 et 2172 de large).
WORK = (2170, 725)
# Taille dans le jeu : 480 unités x 1,75 (zoom de la caméra) = 840 pixels.
GAME_WIDTH = 840
# Nombre de couleurs par couche (assez pour la richesse, assez peu pour le style pixel art).
COLORS = {"back": 64, "middle": 64, "ground": 40}
# Recouvrement entre le bas du milieu et le haut du sol (en pixels de travail).
OVERLAP = 6


def column_edges(alpha: np.ndarray, bottom: bool) -> np.ndarray:
    """Pour chaque colonne : la ligne opaque la plus basse (bottom) ou la plus haute."""
    edges = []
    for x in range(0, alpha.shape[1], 4):
        ys = np.where(alpha[:, x] > 128)[0]
        if len(ys):
            edges.append(ys.max() if bottom else ys.min())
    return np.array(edges)


def pixelate(image: Image.Image, colors: int) -> Image.Image:
    """Réduit la palette et rend la transparence franche (tout ou rien)."""
    rgba = np.array(image)
    solid = rgba[..., 3] >= 128
    rgb = Image.fromarray(rgba[..., :3]).quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    out = np.dstack([np.array(rgb), np.where(solid, 255, 0).astype(np.uint8)])
    return Image.fromarray(out, "RGBA")


def prepare(stage: Path) -> dict:
    layers = {}
    for name in ("back", "middle", "ground"):
        path = stage / f"{name}.png"
        if path.exists():
            layers[name] = Image.open(path).convert("RGBA").resize(WORK, Image.LANCZOS)
    if "back" not in layers:
        return {"stage": stage.name, "status": "pas de fond : ignoré"}
    report = {"stage": stage.name, "layers": sorted(layers)}

    # Le milieu est posé sur le sol (décalé vers le bas ou le haut si besoin).
    if "middle" in layers and "ground" in layers:
        middle_bottom = int(np.median(column_edges(np.array(layers["middle"])[..., 3], bottom=True)))
        ground_top = int(np.median(column_edges(np.array(layers["ground"])[..., 3], bottom=False)))
        shift = ground_top + OVERLAP - middle_bottom
        if shift:
            moved = Image.new("RGBA", WORK)
            moved.paste(layers["middle"], (0, shift), layers["middle"])
            layers["middle"] = moved
        report["middle_shift"] = shift
        report["ground_top"] = ground_top

    out_dir = stage / "game"
    out_dir.mkdir(exist_ok=True)
    height = round(WORK[1] * GAME_WIDTH / WORK[0])
    for name, image in layers.items():
        small = image.resize((GAME_WIDTH, height), Image.LANCZOS)
        if name != "back":
            small = pixelate(small, COLORS[name])
        else:
            small = pixelate(small, COLORS[name]).convert("RGB").convert("RGBA")
        small.save(out_dir / f"layer_{name}.png")
    report["size"] = [GAME_WIDTH, height]
    if "ground_top" in report:
        # Hauteur du haut du sol dans l'image du jeu (sert à poser les combattants).
        report["ground_top_game"] = round(report["ground_top"] * height / WORK[1])
    (out_dir / "stage.json").write_text(json.dumps(report, indent=1), encoding="utf-8")
    return report


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    wanted = sys.argv[1:] or [p.name for p in sorted(STAGES.iterdir()) if p.is_dir()]
    for name in wanted:
        report = prepare(STAGES / name)
        print(json.dumps(report, ensure_ascii=False))


if __name__ == "__main__":
    main()
