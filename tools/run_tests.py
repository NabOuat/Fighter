"""Lance tous les tests automatiques du jeu (dossier tests/), sans fenêtre.

Utilisation (depuis le dossier du projet) :
    python tools/run_tests.py            # tous les tests
    python tools/run_tests.py combat     # seulement tests/test_combat.gd

Le chemin de Godot peut être changé avec la variable d'environnement GODOT.
"""

import os
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GODOT = os.environ.get(
    "GODOT",
    r"C:\Users\OUATTARA AFOR\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe",
)
# Messages internes de Godot à la fermeture, sans rapport avec les tests.
NOISE = ("Unreferenced static string", "at: unref", "RID allocations", "PagedAllocator",
         "Thread object", "wait_to_finish", "Godot Engine v")


def decode(raw: bytes) -> str:
    """Godot écrit en UTF-8, mais la console Windows peut utiliser une autre page de codes."""
    for encoding in ("utf-8", "cp1252", "cp850"):
        try:
            return raw.decode(encoding)
        except UnicodeDecodeError:
            continue
    return raw.decode("utf-8", errors="replace")


def run(test: Path) -> bool:
    started = time.time()
    result = subprocess.run(
        [GODOT, "--headless", "--fixed-fps", "60", "--path", str(ROOT), "--script", f"res://tests/{test.name}"],
        capture_output=True,
    )
    lines = [line for line in (decode(result.stdout) + decode(result.stderr)).splitlines()
             if line.strip() and not any(noise in line for noise in NOISE)]
    print(f"\n=== {test.stem} ({time.time() - started:.0f} s)")
    print("\n".join(lines))
    return result.returncode == 0


def main() -> int:
    wanted = sys.argv[1] if len(sys.argv) > 1 else ""
    tests = sorted(t for t in (ROOT / "tests").glob("test_*.gd") if t.name != "test_base.gd" and wanted in t.stem)
    results = {test.stem: run(test) for test in tests}
    print("\n=== Bilan")
    for name, ok in results.items():
        print(f"  {'OK    ' if ok else 'ÉCHEC '} {name}")
    return 0 if all(results.values()) else 1


if __name__ == "__main__":
    # Affiche correctement les accents dans la console Windows.
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    sys.exit(main())
