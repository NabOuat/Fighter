"""Outil de découpe des images générées pour Legendz Fighting.

Pour chaque image brute listée dans le manifeste d'un personnage
(tools/sprite_manifests/<personnage>.json), l'outil :
  1. retire le fond (damier dessiné, noir, magenta...) sans toucher au personnage ;
  2. sépare chaque pose de la planche (et les rangées s'il y en a plusieurs) ;
  3. réduit chaque pose à la taille du jeu, en pixel art net (palette limitée) ;
  4. aligne les pieds de toutes les poses dans des cases de taille identique ;
  5. écrit la planche finale dans assets/characters/<personnage>/sprites/
     et une planche d'aperçu dans assets/characters/<personnage>/preview/.

Utilisation (depuis le dossier du projet) :
    python tools/sprite_cutter.py abla_pokou
    python tools/sprite_cutter.py abla_pokou --only combo_1
"""

import argparse
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = Path(__file__).resolve().parent.parent
CHARACTERS = ROOT / "assets" / "characters"
MANIFESTS = Path(__file__).resolve().parent / "sprite_manifests"

# Taille de référence du jeu (voir le cahier des charges).
SCREEN = (480, 270)
DEFAULT_SPRITE_HEIGHT = 72      # hauteur d'une pose debout, en pixels du jeu
MIN_CELL = 96                   # taille minimale d'une case
FEET_MARGIN = 8                 # les pieds sont posés 8 pixels au-dessus du bas de la case
SPRITE_COLORS = 48              # nombre de couleurs par planche de personnage
SCENE_COLORS = 48               # nombre de couleurs pour les scènes de l'ultime

# Fond : tolérance de couleur, et trous intérieurs du damier.
BG_TOLERANCE = 34
GAP_COLUMNS = 6                 # colonnes vides (en pixels d'origine) entre deux poses
GAP_ROWS = 24                   # lignes vides entre deux rangées
MIN_PART_SHARE = 0.03           # une « pose » plus petite que 3 % de la plus grande = débris
SMALL_PART_SHARE = 0.004        # morceau minuscule (lettre, numéro, gouttelette) : écarté


# --- Fond --------------------------------------------------------------------

def border_palette(rgb: np.ndarray, alpha: np.ndarray) -> list[np.ndarray]:
    """Les 1 à 3 couleurs dominantes du bord de l'image (celles du fond)."""
    border = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]])
    border_alpha = np.concatenate([alpha[0], alpha[-1], alpha[:, 0], alpha[:, -1]])
    border = border[border_alpha > 200]
    if len(border) == 0:
        return []
    quantized = (border // 8).astype(np.int32)
    keys, counts = np.unique(quantized[:, 0] * 1024 + quantized[:, 1] * 32 + quantized[:, 2], return_counts=True)
    order = np.argsort(counts)[::-1]
    palette = []
    for index in order[:3]:
        if counts[index] < 0.08 * len(border):
            break
        key = keys[index]
        color = np.array([(key // 1024) * 8 + 4, (key // 32 % 32) * 8 + 4, (key % 32) * 8 + 4])
        palette.append(color)
    return palette


def remove_background(image: Image.Image) -> Image.Image:
    """Rend transparent le fond relié aux bords, et les trous intérieurs de damier."""
    rgba = np.array(image.convert("RGBA")).astype(np.int32)
    rgb, alpha = rgba[:, :, :3], rgba[:, :, 3]
    palette = border_palette(rgb, alpha)
    if not palette:
        return image.convert("RGBA")

    close = np.zeros(alpha.shape, bool)
    per_color = []
    for color in palette:
        match = np.abs(rgb - color).max(axis=2) <= BG_TOLERANCE
        per_color.append(match)
        close |= match
    close |= alpha < 10

    # 1. Le fond relié aux bords de l'image.
    labels, _ = ndimage.label(close)
    edge_labels = np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))
    background = np.isin(labels, edge_labels[edge_labels > 0])

    # 2. Les trous fermés (entre un bras et le corps) : on ne les retire que s'ils
    #    contiennent vraiment le motif du fond (les deux couleurs d'un damier,
    #    ou une grande zone unie de la couleur du fond). Un vêtement blanc reste.
    holes = close & ~background
    hole_labels, count = ndimage.label(holes)
    for index in range(1, count + 1):
        region = hole_labels == index
        size = region.sum()
        if size < 40:
            continue
        shares = [(region & match).sum() / size for match in per_color]
        checker = len(shares) >= 2 and sorted(shares)[-2] > 0.2
        solid = len(palette) == 1 and shares[0] > 0.95 and size > 400
        if checker or solid:
            background |= region

    # Ronger 2 pixels de bord pour effacer le liseré de fond autour du personnage.
    keep = ~background
    keep = ndimage.binary_erosion(keep, iterations=2) | (keep & (alpha > 250) & ~close)
    rgba[:, :, 3] = np.where(keep, rgba[:, :, 3], 0)
    return Image.fromarray(rgba.astype(np.uint8), "RGBA")


# --- Découpe -----------------------------------------------------------------

def runs(profile: np.ndarray, min_gap: int) -> list[tuple[int, int]]:
    """Plages occupées d'un profil (colonnes ou lignes), séparées par au moins min_gap vides."""
    filled = np.flatnonzero(profile > 0)
    if len(filled) == 0:
        return []
    result = []
    start = previous = filled[0]
    for position in filled[1:]:
        if position - previous > min_gap:
            result.append((start, previous + 1))
            start = position
        previous = position
    result.append((start, previous + 1))
    return result


def split_parts(image: Image.Image, expected: int | None) -> list[list[Image.Image]]:
    """Découpe la planche en rangées, puis chaque rangée en poses.

    Chaque pose est repérée comme un tout (un des plus grands morceaux de la
    rangée), puis les effets qui la touchent (cercle sous les pieds, eau...)
    lui sont rattachés. Les petits éléments (lettres, numéros, gouttelettes
    isolées) sont écartés. expected = nombre total de poses attendues, réparties
    également entre les rangées.
    """
    data = np.array(image)
    alpha = data[:, :, 3] > 40
    labels, count = ndimage.label(alpha, np.ones((3, 3), bool))
    if count == 0:
        return []
    ids = range(1, count + 1)
    areas = ndimage.sum(alpha, labels, index=ids)
    luminance = data[:, :, :3].mean(axis=2)
    brightness = ndimage.mean(luminance, labels, index=ids)
    largest = areas.max()
    big = [i for i, area, light in zip(ids, areas, brightness)
           # Les cadres sombres des numéros : petits et presque noirs.
           if area >= SMALL_PART_SHARE * largest and not (area < 0.03 * largest and light < 60)]
    mask = np.isin(labels, big)
    rows = runs(mask.sum(axis=1), GAP_ROWS)
    tallest = max(b - a for a, b in rows)
    rows = [(a, b) for a, b in rows if b - a > 0.4 * tallest]
    per_row = expected // len(rows) if expected and expected % len(rows) == 0 else None
    result = []
    for top, bottom in rows:
        band = mask[top:bottom]
        pixels = data[top:bottom]
        keeps = find_poses(band, per_row)
        parts = []
        for keep in keeps:
            cut = pixels.copy()
            cut[:, :, 3] = np.where(keep, cut[:, :, 3], 0)
            part = Image.fromarray(cut, "RGBA")
            box = part.getbbox()
            if box:
                parts.append(part.crop(box))
        result.append(parts)
    return result


def find_poses(band: np.ndarray, per_row: int | None) -> list[np.ndarray]:
    """Les poses d'une rangée, de gauche à droite (un masque par pose)."""
    labels, count = ndimage.label(band, np.ones((3, 3), bool))
    if count == 0:
        return []
    areas = ndimage.sum(band, labels, index=range(1, count + 1))
    boxes = ndimage.find_objects(labels)
    order = list(np.argsort(areas)[::-1] + 1)
    if per_row:
        mains = order[:per_row]
    else:
        mains = [i for i in order if areas[i - 1] >= 0.2 * areas.max()]
    # Des effets relient plusieurs poses en un seul morceau : on coupe en parts égales.
    left = min(boxes[i - 1][1].start for i in mains)
    right = max(boxes[i - 1][1].stop for i in mains)
    if per_row:
        slot = (right - left) / per_row
        widest = max(boxes[i - 1][1].stop - boxes[i - 1][1].start for i in mains)
        if len(mains) < per_row or widest > 1.6 * slot:
            columns = [(round(left + k * slot), round(left + (k + 1) * slot)) for k in range(per_row)]
            keeps = []
            for a, b in columns:
                cell = np.zeros_like(band)
                cell[:, a:b] = band[:, a:b]
                keep = main_with_attachments(cell)
                if keep is not None:
                    keeps.append(keep)
            return keeps
    mains.sort(key=lambda i: boxes[i - 1][1].start)
    keeps = {i: labels == i for i in mains}
    for index in range(1, count + 1):
        if index in keeps:
            continue
        box = boxes[index - 1]
        best, best_overlap = None, 0
        for main in mains:
            main_box = boxes[main - 1]
            vertical = min(box[0].stop, main_box[0].stop) - max(box[0].start, main_box[0].start)
            horizontal = min(box[1].stop, main_box[1].stop) - max(box[1].start, main_box[1].start)
            if vertical > 0 and horizontal > best_overlap:
                best, best_overlap = main, horizontal
        if best is not None:
            keeps[best] |= labels == index
    return [keeps[i] for i in mains]


def main_with_attachments(cell: np.ndarray) -> np.ndarray | None:
    """Dans une case : la pose (le plus grand morceau) et ce qui la touche en hauteur.

    Ce qui est entièrement au-dessus ou au-dessous de la pose (titre, bandeau,
    légende, numéro) est écarté ; un effet au niveau du corps ou des pieds
    (vague, cercle de kaolin) est gardé.
    """
    labels, count = ndimage.label(cell, np.ones((3, 3), bool))
    if count == 0:
        return None
    areas = ndimage.sum(cell, labels, index=range(1, count + 1))
    main = int(np.argmax(areas)) + 1
    boxes = ndimage.find_objects(labels)
    main_top, main_bottom = boxes[main - 1][0].start, boxes[main - 1][0].stop
    keep = labels == main
    for index, box in enumerate(boxes, start=1):
        if index == main or box is None:
            continue
        if box[0].stop <= main_top + 2 or box[0].start >= main_bottom - 2:
            continue
        keep |= labels == index
    return keep


# --- Réduction et alignement -------------------------------------------------

def shrink(image: Image.Image, scale: float) -> Image.Image:
    """Réduit en gardant des bords nets (alpha prémultiplié, puis seuil)."""
    size = (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
    small = image.convert("RGBa").resize(size, Image.BOX).convert("RGBA")
    data = np.array(small)
    data[:, :, 3] = np.where(data[:, :, 3] >= 128, 255, 0)
    return Image.fromarray(data, "RGBA")


def limit_palette(image: Image.Image, colors: int) -> Image.Image:
    """Limite le nombre de couleurs (sans tramage) en gardant la transparence."""
    alpha = np.array(image)[:, :, 3]
    rgb = image.convert("RGB").quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    result = np.array(rgb.convert("RGBA"))
    result[:, :, 3] = alpha
    return Image.fromarray(result, "RGBA")


def feet_x(image: Image.Image) -> float:
    """Position horizontale des pieds : centre des pixels du bas de la pose."""
    alpha = np.array(image)[:, :, 3] > 0
    height = alpha.shape[0]
    bottom = alpha[int(height * 0.88):]
    columns = np.flatnonzero(bottom.any(axis=0))
    if len(columns) == 0:
        return image.width / 2
    return (columns[0] + columns[-1]) / 2


def round_up(value: int, step: int = 16) -> int:
    return int(math.ceil(value / step) * step)


def build_sheet(parts: list[Image.Image], height: int, colors: int, centered: bool) -> tuple[Image.Image, dict]:
    """Met les poses à l'échelle et les range dans des cases identiques, pieds alignés."""
    heights = sorted(p.height for p in parts)
    reference = heights[len(heights) // 2]
    scale = height / reference
    frames = [limit_palette(shrink(p, scale), colors) for p in parts]
    feet = [f.width / 2 if centered else feet_x(f) for f in frames]
    # La case doit contenir chaque pose, de part et d'autre du point des pieds.
    left = max(x for x in feet)
    right = max(f.width - x for f, x in zip(frames, feet))
    cell_w = max(MIN_CELL, round_up(int(2 * max(left, right)) + 4))
    cell_h = max(MIN_CELL, round_up(max(f.height for f in frames) + FEET_MARGIN + 4))
    sheet = Image.new("RGBA", (cell_w * len(frames), cell_h), (0, 0, 0, 0))
    anchor = (cell_w // 2, cell_h - FEET_MARGIN)
    for index, (frame, x) in enumerate(zip(frames, feet)):
        if centered:
            position = (index * cell_w + (cell_w - frame.width) // 2, (cell_h - frame.height) // 2)
        else:
            position = (index * cell_w + anchor[0] - round(x), anchor[1] - frame.height)
        sheet.alpha_composite(frame, position)
    info = {"frames": len(frames), "cell": [cell_w, cell_h], "anchor": list(anchor), "scale": round(scale, 4)}
    return sheet, info


def build_scene(image: Image.Image, layer: bool) -> tuple[Image.Image, dict]:
    """Scènes de l'ultime : plein écran (480 x 270), ou calque qui tient dans l'écran."""
    if layer:
        image = remove_background(image)
        box = image.getbbox()
        if box:
            image = image.crop(box)
        scale = min(SCREEN[0] / image.width, SCREEN[1] / image.height)
        result = limit_palette(shrink(image, scale), SCENE_COLORS)
    else:
        # Remplir l'écran en coupant ce qui dépasse, au centre.
        scale = max(SCREEN[0] / image.width, SCREEN[1] / image.height)
        small = image.convert("RGB").resize((round(image.width * scale), round(image.height * scale)), Image.BOX)
        left = (small.width - SCREEN[0]) // 2
        top = (small.height - SCREEN[1]) // 2
        small = small.crop((left, top, left + SCREEN[0], top + SCREEN[1]))
        result = small.quantize(colors=SCENE_COLORS, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGBA")
    return result, {"size": list(result.size), "scale": round(scale, 4)}


# --- Aperçu ------------------------------------------------------------------

def checker(size: tuple[int, int], step: int = 8) -> Image.Image:
    board = Image.new("RGBA", size, (58, 52, 66, 255))
    draw = ImageDraw.Draw(board)
    for y in range(0, size[1], step):
        for x in range((y // step % 2) * step, size[0], 2 * step):
            draw.rectangle([x, y, x + step - 1, y + step - 1], fill=(72, 66, 80, 255))
    return board


def preview(entries: list[tuple[str, Image.Image, dict]], path: Path, zoom: int = 3) -> None:
    """Une grande image avec chaque planche agrandie, son nom et ses cases."""
    blocks = []
    for name, sheet, info in entries:
        big = sheet.resize((sheet.width * zoom, sheet.height * zoom), Image.NEAREST)
        block = checker((max(big.width, 360), big.height + 22))
        block.alpha_composite(big, (0, 22))
        draw = ImageDraw.Draw(block)
        label = f"{name}  {info.get('frames', 1)} img  case {info.get('cell', info.get('size'))}"
        draw.text((4, 4), label, fill=(255, 220, 120, 255))
        if "cell" in info:
            cell_w = info["cell"][0] * zoom
            for i in range(1, info["frames"]):
                draw.line([(i * cell_w, 22), (i * cell_w, block.height)], fill=(255, 255, 255, 60))
            foot_y = 22 + info["anchor"][1] * zoom
            draw.line([(0, foot_y), (big.width, foot_y)], fill=(255, 90, 60, 120))
        blocks.append(block)
    width = max(b.width for b in blocks)
    height = sum(b.height + 6 for b in blocks)
    sheet = Image.new("RGBA", (width, height), (30, 24, 36, 255))
    y = 0
    for block in blocks:
        sheet.alpha_composite(block, (0, y))
        y += block.height + 6
    path.parent.mkdir(parents=True, exist_ok=True)
    (path.parent / ".gdignore").write_text("")
    sheet.convert("RGB").save(path)


# --- Programme principal -----------------------------------------------------

def process(character: str, only: str | None) -> None:
    manifest = json.loads((MANIFESTS / f"{character}.json").read_text(encoding="utf-8"))
    raw = CHARACTERS / character / "raw"
    out = CHARACTERS / character / "sprites"
    out.mkdir(parents=True, exist_ok=True)
    report = {}
    entries = []
    for source, settings in manifest.items():
        names = settings["names"] if "names" in settings else [settings["name"]]
        if only and only not in names:
            continue
        kind = settings.get("kind", "sprite")
        image = Image.open(raw / source)
        if kind in ("scene", "layer"):
            result, info = build_scene(image, kind == "layer")
            result.save(out / f"{names[0]}.png")
            report[names[0]] = {"source": source, "kind": kind, **info}
            entries.append((names[0], result, info))
            continue
        clean = remove_background(image)
        rows = split_parts(clean, settings.get("frames"))
        if len(names) == 1:
            rows = [sum(rows, [])]
        elif len(rows) == 1:
            # Plusieurs animations sur une seule rangée (ex : intro puis victoire) : on partage.
            per = len(rows[0]) // len(names)
            rows = [rows[0][i * per:(i + 1) * per] for i in range(len(names))]
        for name, parts in zip(names, rows):
            height = settings.get("height", DEFAULT_SPRITE_HEIGHT)
            sheet, info = build_sheet(parts, height, SPRITE_COLORS, kind == "fx")
            sheet.save(out / f"{name}.png")
            expected = settings.get("frames")
            if expected:
                expected //= len(names)
            info["expected_frames"] = expected
            report[name] = {"source": source, "kind": kind, **info}
            entries.append((name, sheet, info))
            warn = "" if not expected or expected == info["frames"] else f"  <- {expected} attendues"
            print(f"  {name:22s} {info['frames']:2d} images, case {info['cell']}{warn}")
    previous = {}
    report_path = out / "sprites.json"
    if report_path.exists() and only:
        previous = json.loads(report_path.read_text(encoding="utf-8"))
    previous.update(report)
    report_path.write_text(json.dumps(previous, indent=2, ensure_ascii=False), encoding="utf-8")
    suffix = f"_{only}" if only else ""
    preview(entries, CHARACTERS / character / "preview" / f"apercu{suffix}.png")
    print(f"-> {len(report)} planches dans {out}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("character", help="identifiant du personnage (ex : abla_pokou)")
    parser.add_argument("--only", help="ne traiter qu'une animation (ex : combo_1)")
    arguments = parser.parse_args()
    process(arguments.character, arguments.only)
