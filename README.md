# Miniquest

A 2D game built with **Godot 4.7** and **GDScript**.

> **Status: scaffolding only.** The engine project, tooling and conventions are
> set up; the game design is still open. No gameplay code has been written yet.

## Getting started

1. Install [Godot 4.7](https://godotengine.org/download) — the **standard**
   build, not .NET. This project uses GDScript.
2. Open Godot, click **Import**, and select `project.godot` in this folder.
3. Press **F5** to run.

Command-line tooling finds the engine as `godot_console`, `godot` or `godot4` on
your `PATH`, or via the `GODOT` environment variable if you would rather point at
it directly:

```powershell
$env:GODOT = "C:\path\to\Godot_v4.7-stable_win64_console.exe"
```

Use a **console** build — the plain `.exe` detaches from the terminal on Windows,
so you see no output and `check.ps1` cannot tell a clean run from a broken one.

Godot's Windows downloads are versioned (`Godot_v4.7.1-stable_win64_console.exe`),
which no `PATH` lookup will match. Note that the console executable is only a
launcher: it locates the real engine by stripping `_console` from its own
filename, so it needs a matching pair of names. Hardlinks cost no disk space and
need no administrator rights:

```powershell
New-Item -ItemType HardLink -Path 'C:\Godot\godot.exe' `
         -Target 'C:\Godot\Godot_v4.7.1-stable_win64.exe'
New-Item -ItemType HardLink -Path 'C:\Godot\godot_console.exe' `
         -Target 'C:\Godot\Godot_v4.7.1-stable_win64_console.exe'
```

Then add that folder to `PATH`.

## Layout

```
scenes/       .tscn scene files, mirroring scripts/
  ui/         menus, HUD, overlays
scripts/      .gd source files
assets/       art, audio, fonts (imported by Godot, never hand-edited)
resources/    .tres data instances
tools/        one-off CLI/editor scripts, not shipped game code
.github/      Copilot instructions
```

Keep a script and its scene at mirrored paths, e.g. `scenes/ui/main_menu.tscn`
pairs with `scripts/ui/main_menu.gd`.

## Project settings worth knowing

- **Base resolution** 640×360, windowed at 1280×720, `canvas_items` stretch with
  aspect kept — a pixel-art-friendly setup that scales cleanly to 2×, 3×, 4×.
- **Renderer** is `gl_compatibility`, which keeps web and low-end hardware
  export viable. Switch to Forward+ only if you need its 2D lighting features.
- **Default texture filter** is Nearest, so pixel art stays crisp.
- **Input actions**: `move_left/right/up/down` and `pause`, bound to WASD +
  arrows and Esc/P. All use *physical* keycodes so they work on non-QWERTY
  layouts. Add game-specific actions as the design calls for them, in Project
  Settings → Input Map, or by editing and re-running `tools/setup_input.gd`.

## Verifying changes

```powershell
pwsh -File tools/check.ps1
```

Parses every `.gd` file individually, then boots the project to exercise scene
loading. Exits 0 when everything is clean, 1 otherwise.

Do not use `--headless --path . --quit` on its own as a check. It only parses
scripts reachable from the main scene, so a script nothing instances yet is
never looked at, and it exits 0 even when it prints a parse error. `check.ps1`
works around both by running `--check-only` per file and scanning boot output
for errors.

After adding art, audio or fonts, run the engine with `--headless --path .
--import` to generate their `.import` sidecars, and commit those.

## Conventions

Coding standards and Godot idioms live in
[`.github/copilot-instructions.md`](.github/copilot-instructions.md). The short
version: static typing everywhere, tabs in `.gd` files, `snake_case` files and
functions, `class_name` on every reusable script, signals up and calls down,
composition over inheritance, and tunable data in `Resource` subclasses rather
than dictionaries of magic numbers.

## Git notes

- `.godot/` is generated and ignored; `.import` sidecars are committed.
- `.gitattributes` forces LF endings on all Godot text formats — this prevents
  spurious `.tscn` diffs and merge conflicts.
- `export_presets.cfg` is ignored because it can contain signing keys and store
  credentials.
