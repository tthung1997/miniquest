# Miniquest — Copilot Instructions

**Miniquest** is a 2D game built with **Godot 4.7** and **GDScript**.

> The game design is not settled yet. Do not invent gameplay systems,
> architecture, or data models unless explicitly asked. When a request is
> ambiguous, ask rather than assume.

These instructions cover how to write Godot code in this repo, not what to build.

## Non-negotiables

- **Godot 4.7, GDScript, standard build (not .NET).** Do not add C# files or
  suggest `[Export]` / `GetNode<T>()`. If a hot path genuinely needs C#, say so
  and leave the GDScript in place.
- **Static typing everywhere.** `var speed: float = 0.0`,
  `func take(n: int) -> void:`. Untyped GDScript is slower and defeats
  autocompletion. `:=` is fine when the right-hand type is obvious.
- **Tabs, not spaces**, in `.gd` files. `snake_case` for files, variables and
  functions. `PascalCase` for `class_name` and node names.
  `SCREAMING_SNAKE_CASE` for constants. `_leading_underscore` for private members.
- **Every reusable script gets a `class_name`.** It is how other scripts and the
  editor's node/resource pickers find it, and it removes `preload` boilerplate.
- **Godot 4 API only.** The engine changed a lot in 4.0 — `yield` is now `await`,
  `instance()` is now `instantiate()`, `KinematicBody2D` is now
  `CharacterBody2D`, `export` is now `@export`, and
  `connect("sig", self, "_m")` is now `sig.connect(_m)`. Godot 3 snippets are a
  common failure mode; do not produce them.

## Engine idioms — get these right

These are the mistakes an assistant most often makes in Godot. Prefer the right
column, every time.

| Don't | Do |
| --- | --- |
| `get_node("../../Player")` | `@export var player: Node2D` wired in the editor |
| Polling a boolean in `_process` | `signal`, connected with `.connect()` |
| Movement or physics in `_process` | `_physics_process(delta)` |
| Deep inheritance chains | Composition: child nodes for discrete behaviours |
| Hardcoded tunable numbers | `@export` vars, or a custom `Resource` |
| `get_nodes_in_group()` every frame | Cache the reference once in `_ready()` |
| A `Timer` node for a one-off delay | `await get_tree().create_timer(0.5).timeout` |
| `queue_free()` then touching the node | Free last, or guard `is_instance_valid()` |
| `load()` at runtime in a hot path | `@export var scene: PackedScene` or `preload()` |

More specifics:

- **Signals go up, calls go down.** A parent may call methods on its children. A
  child must never reach up the tree — it emits a signal and lets the parent
  decide. This is the single most important structural rule.
- **`@onready` only for nodes inside the same scene**, e.g.
  `@onready var _sprite: Sprite2D = $Sprite2D`. For anything outside the scene,
  use `@export`.
- **`_physics_process` for anything that moves or collides**, `_process` for
  visuals and UI. Never split one system across both.
- **Use `move_and_slide()` on `CharacterBody2D`**; set `velocity`, then call it.
  Do not integrate `position` manually for physics bodies.
- **`Area2D` for detection** (pickups, hitboxes, triggers); `CharacterBody2D` for
  things that move under control; `StaticBody2D` for level geometry.
- **Set collision layers and masks in the editor**, not in code, and keep the
  layer names in Project Settings up to date.
- **`await` is a coroutine, not a thread.** `await some_signal` is the idiomatic
  way to sequence flow. Guard with `is_instance_valid(self)` after long awaits.
- **Prefer connecting signals in code** (`timer.timeout.connect(_on_timeout)`)
  over editor connections — it is checked at parse time and reviews better.

## Data belongs in Resources

When tunable data is needed, define a custom `Resource` subclass and save
instances as `.tres`. Do not write a JSON loader, and do not bury a dictionary of
magic numbers in a script — Godot's resource system already solves this and
gives you a free inspector UI. See
`.github/skills/godot-data-resources/SKILL.md`.

## Project layout

```
scenes/       .tscn files, mirroring scripts/
  ui/         menus, HUD, overlays
scripts/      .gd files
assets/       art, audio, fonts (imported, never hand-edited)
resources/    .tres data instances
addons/       third-party plugins (added deliberately, not casually)
tools/        one-shot editor/CLI scripts, not shipped game code
```

Keep a script and its scene at mirrored paths, e.g. `scenes/ui/main_menu.tscn`
pairs with `scripts/ui/main_menu.gd`.

## Autoloads

There are none yet, and each one added is global mutable state that makes the
project harder to reason about and test. Add one only when something genuinely
must outlive scene changes (save data, audio bus, scene transitions). Prefer
passing references or using signals first.

## Writing `.tscn` files by hand

You will often need to. The format is text but strict — a stale `ExtResource` id
or an invented `uid` produces a scene that fails to load, sometimes silently.
Read `.github/skills/tscn-authoring/SKILL.md` before generating one, and prefer
small scenes composed by instancing over one large scene.

## Before you claim something works

Run the headless check and confirm it is clean:

```powershell
S:\Godot\Godot_v4.7.1-stable_win64_console.exe --headless --path . --quit
```

This parses every script and scene. See
`.github/skills/godot-headless-workflow/SKILL.md` for the full CLI toolkit.

Never claim a gameplay *feel* change is correct — describe what to look for and
let the human play it. Feel is not verifiable from code.

## Things to avoid

- Adding addons or plugins without being asked. The dependency cost is real.
- `class_name` collisions — search before naming.
- Committing anything under `.godot/`.
- Bundling a large refactor with a feature. Separate them.
- `print()` left in committed code; use `print_debug()` or remove it.
- Inventing game systems. The design is still open — ask first.
