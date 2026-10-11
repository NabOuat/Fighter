# Legendz Fighting

2D pixel-art fighting game for mobile (Android first) featuring African historical figures. Godot 4.7.2 Standard, GDScript only (no C#).

The user is a beginner with Godot and works step by step: explain each change in French (what the file does, where to see it in the editor). Code comments are in French.

## Conventions
- Base resolution 480x270, stretch mode `viewport`, aspect `keep_height`, nearest texture filter. Landscape only.
- Renderer: `gl_compatibility` (low-end Android support). Keep it.
- Scripts live next to their scene (`scenes/<feature>/<name>.tscn` + `.gd`). Files and folders in snake_case, `class_name` in PascalCase. Indent with tabs.
- Never hardcode player-facing text: add a key to `localization/translations.csv` (columns `keys,fr,en`) and use the key or `tr()`.
- Fighter stats and texts live in `FighterData` resources (`data/fighters/*.tres`), registered in `GameState.roster` (`autoload/game_state.gd`).
- Input actions: `move_left`, `move_right`, `jump`, `crouch`, `punch`, `kick`, `special`, `pause`.
- Historical accuracy matters: check facts (dates, kingdoms) before writing bios.

## Checking work
Godot is at `C:/Users/OUATTARA AFOR/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe`.
- Import after adding files: `--headless --path . --import`
- Run and catch script errors: `--headless --path . --quit-after 120`
Close the Godot editor (or ask the user to) before editing `project.godot` directly.
