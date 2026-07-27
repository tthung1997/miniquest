# Miniquest — Copilot Instructions

Miniquest is a **2D game** built with **Godot 4.7** and **GDScript**, using the
**standard build, not .NET**. The repo is currently scaffolding: engine config,
conventions and tooling exist; no gameplay code has been written.

**The game design is not settled.** Do not invent gameplay systems, entities,
progression or data models. When a request is ambiguous, ask instead of assuming.
This file covers *how* to write code here, not *what* to build.

## Non-negotiables

- **Godot 4 API only.** Godot 3 snippets are the most common failure mode here,
  because most GDScript training material predates 4.0. The renames that matter:
  `yield` → `await`, `instance()` → `instantiate()`, `KinematicBody2D` →
  `CharacterBody2D`, `export` → `@export`, `onready` → `@onready`,
  `connect("sig", self, "_m")` → `sig.connect(_m)`, `emit_signal("sig")` →
  `sig.emit()`. `move_and_slide()` takes no arguments — set `velocity` first; it
  returns a `bool`.
- **No C#.** Never add `.cs` files or suggest `[Export]` / `GetNode<T>()`. If a hot
  path genuinely warrants C#, say so and leave the GDScript in place.
- **Static typing everywhere** — `var speed: float = 0.0`,
  `func take(n: int) -> void:`. Typed GDScript compiles to optimized opcodes, so
  this is a performance rule, not just a readability one. Use `:=` only when the
  type is unambiguous on the same line. Nested typed collections
  (`Array[Array[int]]`) are not supported — do not generate them.
- **Every reusable script gets a `class_name`**, so other scripts and the editor's
  pickers find it without `preload` boilerplate. Search for collisions before naming.
- Tabs, LF, lines ≤ 100 characters. `snake_case` files/functions/variables,
  `PascalCase` classes, nodes and enum *names*, `CONSTANT_CASE` constants and enum
  *members*, `_leading_underscore` for private members, signals in the past tense
  (`door_opened`). Prefer `and`/`or`/`not` over `&&`/`||`/`!`. `.editorconfig`
  enforces the whitespace; the rest is Godot's official style guide, which applies
  in full.

## Declaration order

Godot's official code order — do not substitute another convention:

```
@tool / @icon, @abstract, class_name, extends, ## doc comment
signals, enums, constants, static vars, @export vars, regular vars, @onready vars
_static_init, static methods
_init, _enter_tree, _ready, _process, _physics_process, other virtuals
remaining methods, inner classes
```

Two places this is commonly got wrong: **enums come before constants**, and
**`@onready` comes last** among the variables, after plain `var`s. Public before
private within each group. `@abstract` goes immediately before `class_name`.

## Engine idioms

The mistakes most often made in this engine. Prefer the right column every time.

| Don't | Do |
| --- | --- |
| `get_node("../../Player")` | `@export var player: Node2D`, wired in the editor, or `%UniqueName` |
| Polling a flag in `_process` | A `signal`, connected with `.connect()` |
| Movement or collision in `_process` | `_physics_process(delta)` |
| Input checks in `_process` | `_input()` / `_unhandled_input()` |
| Deep inheritance chains | Composition — child nodes for discrete behaviours |
| Hardcoded tunable numbers | `@export` vars, or a custom `Resource` |
| `get_nodes_in_group()` every frame | Cache the reference in `_ready()` |
| A `Timer` node for a one-off delay | `await get_tree().create_timer(0.5).timeout` |
| `queue_free()` then touching the node | Free last, or guard `is_instance_valid()` |
| `load()` in a hot path | `preload()`, or `@export var scene: PackedScene` |
| `String` keys in per-frame lookups | `StringName` (`&"key"`) |
| A dictionary of magic numbers | A `Resource` subclass with typed `@export`s |

Also:

- **`_physics_process` for anything that moves or collides; `_process` for visuals
  and UI.** Never split one system across both.
- **Set `velocity`, then call `move_and_slide()`** on a `CharacterBody2D`. Do not
  integrate `position` by hand on a physics body.
- **`Area2D`** for detection (pickups, hitboxes, triggers), **`CharacterBody2D`**
  for things that move under control, **`StaticBody2D`** for level geometry.
  `collision_layer` is what I am; `collision_mask` is what I scan for.
- **Collision layers and masks belong in the editor**, with layer names kept
  current in Project Settings — not assigned in code.
- **`await` is a coroutine, not a thread.** After a long await, guard with
  `is_instance_valid(self)` before touching anything. Never `await` inside
  `_physics_process`.
- **Connect signals in code** (`timer.timeout.connect(_on_timeout)`) rather than in
  the editor — it is checked at parse time and reviews far better. Disconnect
  capturing lambdas explicitly; Godot cannot clean those up for you.
- Use `is` / `is not` / `assert()` for type checks. `as` silently yields `null` on
  a mismatch, which hides the bug.

## Structure and communication

**Calls go down, signals come up.** A parent may call methods on its children. A
child must not reach up the tree; it emits a signal and lets the parent decide.
Design scenes to be self-contained — every scene should run standalone (F6)
without crashing. A scene that depends on its surroundings cannot be instanced
anywhere else.

**`@onready` only for nodes inside the same scene**
(`@onready var _sprite: Sprite2D = $Sprite2D`). For anything outside it, take an
`@export` reference and wire it in the editor.

**There are no autoloads, and adding one needs justification.** Each is global
mutable state, and the node tree plus signals already solve most of what a manager
singleton would. Add one only for something that must genuinely outlive scene
changes — save data, audio buses, scene transitions. `static var` covers some
cases without an autoload at all. Do not introduce a global event bus.

## Data belongs in Resources

Define a custom `Resource` subclass with a `class_name`, `@export` its fields, and
save instances as `.tres` under `resources/`. Do not write a JSON loader and do not
bury a dictionary of magic numbers in a script. Resources give you typed fields, an
inspector UI, version-control-friendly text files, and free serialisation.

Use `@export_range`, `@export_enum`, `@export_multiline` and `@export_group` — they
cost nothing and make the inspector usable. `StringName` (`&"..."`) for ids,
`String` for player-facing text.

**Resources are shared by default.** Two nodes exporting the same `.tres` hold the
*same object*, so mutating one writes through to every user and to disk. Call
`.duplicate()`, or tick **Local to Scene**, when something needs a per-instance
mutable copy.

Prefer `RefCounted` for transient logic objects, `Resource` for anything a designer
should edit or that must serialise, and `Node` only when it needs the scene tree or
a per-frame callback.

## Fail loudly

```gdscript
if not ResourceLoader.exists(path):
	push_error("Missing resource: %s" % path)
	return null
```

`push_error` for genuine faults, `push_warning` for recoverable ones. Returning a
silent `null` or a default-constructed value hides the bug until it surfaces
somewhere unrelated. Prefer guard clauses and early returns over nested
conditionals. Do not leave `print()` in committed code.

## Godot 4.7 specifics

Docs are at <https://docs.godotengine.org/en/4.7/>. Behaviour that changed in 4.7
and will not produce a compile error:

- **Input device IDs**: mouse and keyboard are `InputEvent.DEVICE_ID_MOUSE` and
  `InputEvent.DEVICE_ID_KEYBOARD`, no longer `0`. Never compare `event.device == 0`
  — some joypads use `0`. Dispatch on event type where possible.
- A method overriding one with a **typed return inherits that return type**, so the
  override needs an explicit `return` statement.
- Setting a single element of a packed array no longer fires the setter for the
  whole packed-array property.
- `CanvasItem` line drawing no longer adds an antialiasing feather, so lines render
  thinner than they did in 4.6. Widen the line rather than reinstating the feather.
- `AudioStreamPlayer.area_mask` now defaults to `0` (disabled). If you ever use
  `audio_bus_override` on an `Area2D`, tick layer 1 explicitly.
- `RichTextLabel.add_image` / `update_image` take `width_unit` / `height_unit`
  (`RichTextLabel.ImageUnit`), not the old `*_in_percent` booleans.
- Third-party content comes from the **Asset Store**; the Asset Library is gone.

## Project layout

```
scenes/       .tscn files, mirroring scripts/
  ui/         menus, HUD, overlays
scripts/      .gd files
assets/       art, audio, fonts (imported, never hand-edited)
resources/    .tres data instances
tools/        one-off CLI/editor scripts, not shipped game code
addons/       third-party plugins (added deliberately, not casually)
```

Keep a script and its scene at mirrored paths — `scenes/ui/main_menu.tscn` pairs
with `scripts/ui/main_menu.gd`.

Settings that shape the code: base resolution **640×360** (windowed at 1280×720)
with `canvas_items` stretch, **Nearest** default texture filter for crisp pixel
art, and the **`gl_compatibility`** renderer, which keeps web and low-end hardware
export viable. Existing input actions are `move_left/right/up/down` and `pause`,
all bound to *physical* keycodes.

## Files you must not hand-edit

- **`.uid` files.** Godot generates them and they **must** be committed; losing one
  breaks resource references on another clone. Move a `.uid` alongside its script
  when renaming or moving it. Never create, edit or delete one by hand.
- **`.import` sidecars.** Generated by the engine and committed. After adding art,
  audio or fonts, run the engine with `--headless --path . --import` and commit the
  sidecars it produces.
- **The `[input]` section of `project.godot`.** Hand-writing serialised
  `InputEvent` objects is a trap. Edit and re-run `tools/setup_input.gd`, which is
  safe to run repeatedly, and let the engine serialise it.
- **Anything under `.godot/`.** Generated, ignored, never committed.

## Writing `.tscn` / `.tres` files by hand

Where a human is available, building the scene in the editor is faster and always
right. Prefer several small scenes composed by instancing over one large one. When
hand-authoring is unavoidable:

- **Put `script = ExtResource(...)` before the exported properties it sets.** With
  `script` listed after them, exported properties can be silently discarded and the
  node loads with defaults — no error, no warning.
- **`ExtResource`/`SubResource` ids must be unique and match their references
  exactly.** A stale id is a hard parse error on load.
- **Omit `load_steps` and `uid`.** Godot recomputes both on save, so there is
  nothing to keep in sync. Never invent a `uid`; a fabricated one that collides
  breaks resource resolution across the project.
- **Write `format=3`.**
- The first `[node]` is the root and takes no `parent=`. Others use `parent="."` or
  a name path like `parent="Sprite/Shadow"`.

## Commands

Tooling resolves the engine from `$env:GODOT`, falling back to a local default. Use
a `_console` build; the plain `.exe` detaches from the terminal on Windows and you
will see no output.

```powershell
pwsh -File tools/check.ps1                                   # validate (see below)
& $env:GODOT --path .                                        # run the game
& $env:GODOT --headless --path . --import                    # import new assets
& $env:GODOT --headless --path . --script res://tools/x.gd   # run a tool script
```

Write one-off chores (bulk renames, generating resources, editing project settings)
as a script extending `SceneTree` under `tools/`.

## Before you claim something works

```powershell
pwsh -File tools/check.ps1
```

It parses every `.gd` file with `--check-only --script`, then boots the project to
exercise scene loading. Exit 0 means clean.

**Do not substitute `--headless --path . --quit`.** It fails in two ways that are
both silent:

- It only parses scripts reachable from the main scene and autoloads. A script
  nothing instances yet is never parsed, so a broken one passes unnoticed.
- It exits **0 even while printing a parse error**, so the exit code is meaningless.
  Output must be scanned for `SCRIPT ERROR` / `Parse Error`.

A clean check proves only that code parses and loads. It says nothing about whether
behaviour is right, and **nothing about feel**. Never claim a movement, timing or
game-feel change is correct — describe what to look for and let the human play it.

## Things to avoid

- Inventing game systems. The design is open — ask first.
- Adding addons or plugins unasked. The dependency cost is real.
- `class_name` collisions — search before naming.
- Hardcoding absolute machine paths into committed files.
- Bundling a large refactor with a feature. Separate them.
- Generating `.md` documentation files unless explicitly requested.

## Precedence

A broad third-party Godot skill may be loaded alongside this file; both reach the
model at once. Where they disagree, **this file wins** — it is repo-specific. In
particular such guidance tends to recommend autoloads and a global event bus as
routine tools, which this project does not use, and much of it covers 3D,
multiplayer and platform porting that do not apply to a 2D game.
