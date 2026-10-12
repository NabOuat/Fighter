"""Résumé du journal des combats d'Arcade (user://match_log.csv), par difficulté.

Sert à régler l'IA contre de vrais joueurs : si le joueur gagne presque tout en
Normal, l'IA est trop facile ; s'il perd presque tout en Facile, trop dure.

    python tools/summarize_match_log.py              (journal de l'ordinateur)
    python tools/summarize_match_log.py chemin.csv   (journal copié d'un téléphone)
"""
import csv
import os
import sys
from collections import defaultdict

DEFAULT = os.path.join(os.environ.get("APPDATA", ""), "Godot", "app_userdata", "Legendz Fighting", "match_log.csv")
# Repères : ce qu'on vise pour un joueur moyen (part de victoires).
TARGETS = {"EASY": "70-90 %", "NORMAL": "45-65 %", "HARD": "20-40 %"}


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT
    if not os.path.exists(path):
        print("Pas encore de journal :", path)
        print("Joue quelques combats d'Arcade, puis relance ce script.")
        return
    rows = list(csv.DictReader(open(path, encoding="utf-8")))
    groups = defaultdict(list)
    for row in rows:
        groups[row["difficulty"]].append(row)
    print(f"{len(rows)} combats dans {path}\n")
    for level in ["EASY", "NORMAL", "HARD"]:
        matches = groups.get(level, [])
        if not matches:
            continue
        n = len(matches)
        wins = sum(r["result"] == "win" for r in matches)
        total = lambda col: sum(int(r[col]) for r in matches)
        seconds = sum(float(r["seconds"]) for r in matches) / n
        player_attacks = total("player_hits") + total("player_blocked")
        ai_attacks = total("ai_hits") + total("ai_blocked")
        print(f"== {level} : {n} combats")
        print(f"   victoires du joueur : {100 * wins / n:.0f} %  (visé : {TARGETS[level]})")
        print(f"   durée moyenne       : {seconds:.0f} s")
        if player_attacks:
            print(f"   coups du joueur parés par l'IA : {100 * total('player_blocked') / player_attacks:.0f} %")
        if ai_attacks:
            print(f"   coups de l'IA parés par le joueur : {100 * total('ai_blocked') / ai_attacks:.0f} %")
        print(f"   projections du joueur : {total('player_throws')}, contres parfaits de l'IA : {total('ai_parries')}")
        print(f"   esquives : joueur {total('player_dodges')}, IA {total('ai_dodges')}\n")


if __name__ == "__main__":
    main()
