---
name: tscn-authoring
description: How to correctly hand-write or edit Godot 4 .tscn and .tres files as text, including the header, load_steps, ExtResource/SubResource ids, node paths, instanced scenes and signal connections. Use before generating or modifying any scene or resource file outside the Godot editor.
---

# Writing `.tscn` and `.tres` by hand

Godot's scene format is text, which is exactly why an assistant can work with
it — but it is strict. A wrong id or a stale header produces a scene that fails
to load with a terse error, or worse, loads with silently missing nodes.

## Anatomy

```
[gd_scene format=3]

[ext_resource type="Script" path="res://scripts/player.gd" id="1_script"]
[ext_resource type="Texture2D" path="res://assets/sprites/player.png" id="2_sprite"]

[sub_resource type="CircleShape2D" id="CircleShape2D_body"]
radius = 8.0

[node name="Player" type="CharacterBody2D"]
script = ExtResource("1_script")
move_speed = 120.0

[node name="Sprite" type="Sprite2D" parent="."]
texture = ExtResource("2_sprite")

[node name="Collision" type="CollisionShape2D" parent="."]
shape = SubResource("CircleShape2D_body")
```

### The rules that actually break things

- **Omit `load_steps` entirely.** It must equal the number of `ext_resource` +
  `sub_resource` blocks + 1, and getting it wrong is a common source of corrupt
  scenes. Godot recomputes and rewrites it on save, so leaving it out is safe
  and strictly better when hand-authoring.
- **`format=3`** for Godot 4. Never write `format=2`.
- **Ids are arbitrary strings but must be unique and must match** their
  `ExtResource("...")` / `SubResource("...")` references exactly. Use
  descriptive ids (`1_script`, `CircleShape2D_body`), not bare numbers.
- **`uid="uid://..."` is optional when hand-writing — omit it.** Godot generates
  and inserts a stable uid on first save. Never invent a uid value; a fabricated
  one that collides will break resource resolution across the project.
- **The first `[node]` is the root** and has no `parent=`. Every other node needs
  `parent="."` (child of root) or `parent="Sprite/Shadow"` (a path relative to
  the root, using node *names*, not types).
- **Property lines use Godot's variant syntax**: `position = Vector2(10, 20)`,
  `modulate = Color(1, 1, 1, 0.5)`, `text = "Hello"`, `visible = false`.
  Only write properties you are changing — defaults are omitted.
- **`script` must come before the exported properties it defines**, otherwise the
  parser does not know the property exists and silently drops it.

### Instancing another scene

```
[ext_resource type="PackedScene" path="res://scenes/player.tscn" id="1_player"]

[node name="Player" parent="." instance=ExtResource("1_player")]
position = Vector2(64, 120)
```

`instance=` replaces `type=`. You may override any exported property of the
instanced scene by listing it below.

### Connections

```
[connection signal="timeout" from="SpawnTimer" to="." method="_on_spawn_timer_timeout"]
```

`from` and `to` are node paths relative to the root. The `method` must exist on
the target's script or you get a *runtime* error, not a load error — easy to
miss. **Prefer connecting in code** (`_spawn_timer.timeout.connect(...)`) when
authoring by hand; it is checked at parse time and easier to review.

## `.tres` files

Same grammar, different header:

```
[gd_resource type="Resource" script_class="ExampleDef" format=3]

[ext_resource type="Script" path="res://scripts/example_def.gd" id="1_script"]

[resource]
script = ExtResource("1_script")
display_name = "Example"
power = 25.0
```

`script_class` must match the script's `class_name`, and `[resource]` holds the
property values.

## Workflow that avoids most pain

1. **Prefer building scenes in the editor** when the human is available — it is
   faster and always correct.
2. When generating by hand, **keep scenes small** and compose by instancing.
   A 200-line `.tscn` is a code smell in any engine.
3. **Always verify after writing:**
   ```powershell
   S:\Godot\Godot_v4.7.1-stable_win64_console.exe --headless --path . --quit
   ```
   Look for `ERROR: Failed loading scene` or `Parse Error`.
4. **Let Godot rewrite the file once** (open the project, touch the scene, save).
   It normalises ids, inserts uids and fixes `load_steps`. Commit that version.

## Merge conflicts

`.tscn` conflicts are readable but easy to botch. If node ids or `load_steps`
conflict, take one side wholesale and re-apply the other change in the editor
rather than hand-merging. Never resolve a conflict by mixing id blocks.
