# Legendz Fighting

2D pixel-art fighting game for mobile (Android first) featuring African historical figures. Godot 4.7.2 Standard, GDScript only (no C#).

The user is a beginner with Godot and works step by step: explain each change in French (what the file does, where to see it in the editor). Code comments are in French.

## Conventions
- Base resolution 480x270, stretch mode `viewport`, aspect `keep_height`, nearest texture filter. Landscape only.
- Renderer: `gl_compatibility` (low-end Android support). Keep it.
- Scripts live next to their scene (`scenes/<feature>/<name>.tscn` + `.gd`). Files and folders in snake_case, `class_name` in PascalCase. Indent with tabs.
- Never hardcode player-facing text: add a key to `localization/translations.csv` (columns `keys,fr,en`) and use the key or `tr()`.
- Fighter stats and texts live in `FighterData` resources (`data/fighters/*.tres`), registered in `GameState.roster` (`autoload/game_state.gd`).
- Design spec (cahier des charges, Claude Doc): https://claude.ai/code/artifact/8224c575-a78f-4241-b6f7-cf007d9a7319 — read it before designing features. Current phase: Phase 1, combat prototype with rectangles, built in 7 validated steps.
- Fighter (`scenes/fighters/fighter.gd`, `class_name Fighter`) is an enum state machine driven by an `intent` dictionary (filled by player input or, later, AI). It has no `_physics_process`: the arena (`scenes/fight/fight.gd`) calls `poll_input()` then `tick()` on each fighter every physics frame, separates them, then resolves hits by intersecting `get_hitbox_rect()` / `get_hurtbox_rect()` (plain Rect2, no Area2D). Hitstop freezes ticks but not input polling.
- Health is the same for everyone (`Fighter.MAX_HEALTH = 1000`). Stats in `FighterData` are 1-5 (power, defense, speed) + reach. Attacks are `AttackData` resources (frames, damage, hitstun, pushback, knockdown, hitstop, hitbox Rect2 from the feet facing right): a `combo` array, `low_attack`, `air_attack`.
- Generate or restructure `.tres` files with a headless Godot script using `ResourceSaver.save` rather than hand-writing typed arrays.
- 2D physics layers: 1 decor, 2 fighters (fighters don't collide with each other; the arena pushes them apart).
- Input actions (simple control mode): `move_left`, `move_right`, `jump`, `crouch`, `attack` (J), `special` (K), `guard` (L), `assist` (I), `ultimate` (U), `pause`. Punch/kick will come back with the technical mode.
- Historical accuracy matters: check facts (dates, kingdoms) before writing bios.

## Checking work
Godot is at `C:/Users/OUATTARA AFOR/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe`.
- Import after adding files: `--headless --path . --import`
- Run and catch script errors: `--headless --path . --quit-after 120`
Close the Godot editor (or ask the user to) before editing `project.godot` directly.
