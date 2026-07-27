---
name: godot-headless-workflow
description: Running Godot 4 from the command line to validate scripts and scenes, run a project, execute one-off tool scripts, edit project settings safely, and export builds. Use to verify changes before claiming they work, or when a task needs a project setting or input action changed.
---

# Godot from the command line

The editor is not the only way to drive Godot, and for an assistant the CLI is
the *only* way to actually check its own work. Nothing should be reported as
working until it has passed the validation step below.

Executable on this machine:

```
S:\Godot\Godot_v4.7.1-stable_win64_console.exe
```

Use the `_console` build. The plain `.exe` detaches from the terminal on Windows
and you will see none of the output.

## Validate — run this after every change

```powershell
cd S:\Codes\miniquest
& "S:\Godot\Godot_v4.7.1-stable_win64_console.exe" --headless --path . --quit
```

This boots the project, parses every `.gd`, loads every autoload and resolves the
main scene, then exits. What to look for:

| Output | Meaning |
| --- | --- |
| `SCRIPT ERROR:` / `Parse Error:` | GDScript syntax or type error |
| `ERROR: Failed loading scene` | malformed `.tscn`, bad ExtResource id |
| `ERROR: Cannot load resource` | wrong `res://` path, or file not imported |
| `Condition "..." is true` | engine-level misuse, read the file:line it prints |

A clean run prints the version banner and little else. Warnings about a missing
display or audio driver in headless mode are expected and harmless.

## Import assets

After adding art, audio or fonts, Godot must generate `.import` sidecars:

```powershell
& "S:\Godot\Godot_v4.7.1-stable_win64_console.exe" --headless --path . --import
```

Commit the generated `.import` files — they carry the import settings. Never
commit the `.godot/` cache.

## Run the game

```powershell
& "S:\Godot\Godot_v4.7.1-stable_win64_console.exe" --path .
```

Useful flags: `--debug-collisions`, `--debug-navigation`, `--resolution 1280x720`,
`--position 100,100`, and `res://path/to/scene.tscn` as a positional argument to
run a single scene (the CLI equivalent of F6).

## One-off tool scripts

To do something that would be tedious or unsafe to hand-edit — bulk asset
renames, generating resources, **writing project settings** — write a script
that extends `SceneTree` and run it:

```gdscript
extends SceneTree

func _init() -> void:
	# ... do the work ...
	quit()
```

```powershell
& "S:\Godot\Godot_v4.7.1-stable_win64_console.exe" --headless --path . --script res://tools/my_task.gd
```

Keep these under `tools/`. They are not shipped game code.

### Editing project settings — do it this way

Hand-writing the `[input]` section of `project.godot` is a trap: input actions
are serialised `InputEventKey` objects with a dozen properties, and a malformed
entry silently drops the action. Let the engine serialise them instead:

```gdscript
extends SceneTree

func _init() -> void:
	var events: Array[InputEvent] = []
	for keycode in [KEY_A, KEY_LEFT]:
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		events.append(event)
	ProjectSettings.set_setting("input/move_left", {"deadzone": 0.2, "events": events})
	ProjectSettings.save()
	quit()
```

`tools/setup_input.gd` in this repo is exactly that, and is safe to re-run.

Use **`physical_keycode`**, not `keycode`, so bindings follow the physical key
position and work on AZERTY and other layouts.

## Export a build

Presets are defined in the editor (Project → Export) and stored in
`export_presets.cfg`, which is gitignored because it can hold signing keys.

```powershell
& "S:\Godot\Godot_v4.7.1-stable_win64_console.exe" --headless --path . --export-release "Windows Desktop" build/miniquest.exe
& "S:\Godot\Godot_v4.7.1-stable_win64_console.exe" --headless --path . --export-release "Web" build/web/index.html
```

Export templates for 4.7.1 must be installed first (Editor → Manage Export
Templates), or the command fails with `No export template found`.

Web builds need cross-origin isolation headers to run; `godot --headless` cannot
serve them. Test with a local server that sets `Cross-Origin-Opener-Policy:
same-origin` and `Cross-Origin-Embedder-Policy: require-corp`.

## What the CLI cannot tell you

It verifies that code *parses and loads*. It does not verify that a jump feels
right, that a spawn rate is fair, or that a UI is readable. Never assert those
from a clean headless run — describe what to look for and let the human play it.
