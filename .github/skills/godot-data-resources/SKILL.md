---
name: godot-data-resources
description: The pattern for defining tunable game data as custom Godot Resource subclasses saved as .tres files. Use when adding configuration, stats, catalogues or any data-driven content in a Godot 4 project, or when tempted to write a JSON loader or a dictionary of magic numbers.
---

# Data as Resources

Godot has a first-class answer to "where do the numbers live", and it is
**custom `Resource` subclasses serialised as `.tres`**. Use it. Do not write a
JSON loader, do not put a `const CONFIG := {...}` dictionary in a script, and do
not build a spreadsheet importer until you have hundreds of rows.

Why it wins:

- The inspector renders an editing UI for free, including dropdowns for enums
  and drag-and-drop slots for textures and sub-resources.
- `.tres` is plain text — it diffs, merges, and code-reviews properly.
- Typed. A field declared as `MyType` can only hold a `MyType`; typos fail at load.
- References work: one resource can point at another without any id lookup.

## The pattern

Define the schema as a script with `class_name`:

```gdscript
## Example only — replace with whatever this project actually needs.
class_name ExampleDef
extends Resource

enum Category { ALPHA, BETA }

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var category: Category = Category.ALPHA
@export var icon: Texture2D

@export_group("Tuning")
@export_range(0.0, 100.0) var power: float = 10.0
@export_range(1, 99) var required_level: int = 1
```

Create instances in the editor: right-click in the target folder →
**New Resource** → pick the class → fill in the inspector → save as
`something.tres`. You can hand-write `.tres` too, but the editor route is less
error-prone and should be the default.

Load them where needed:

```gdscript
@export var config: ExampleDef                              # wired in the inspector — best
const DEFAULT := preload("res://resources/default.tres")    # fine for a known constant
```

## Rules

- **`@export` everything that should be tunable.** A field without `@export` is
  invisible in the inspector and cannot be set per-instance.
- **Use `@export_range`, `@export_enum`, `@export_multiline`, `@export_group`,
  `@export_file`.** They cost nothing and make the inspector usable.
- **`StringName` (`&"..."`) for ids**, `String` for player-facing text.
- **Resources are shared by default.** Two nodes exporting the same `.tres` get
  the *same object*. If something needs a per-instance mutable copy, call
  `.duplicate()` first — mutating a shared resource corrupts your data on disk.
- **Runtime state that must persist can be a Resource too**, so it can be written
  with `ResourceSaver.save()` and read with `ResourceLoader.load()`.
- **Keep pure math on the resource.** A method that derives values from a
  resource's own fields belongs on that resource, not scattered across callers.

## Loading a whole folder

For catalogues, scan the directory rather than maintaining a hardcoded list:

```gdscript
static func load_all(dir_path: String) -> Array[ExampleDef]:
	var out: Array[ExampleDef] = []
	for file_name in DirAccess.get_files_at(dir_path):
		# Exported builds rename .tres to .remap — strip it before loading.
		var clean := file_name.trim_suffix(".remap")
		if clean.ends_with(".tres"):
			var res := load(dir_path.path_join(clean))
			if res is ExampleDef:
				out.append(res)
	return out
```

The `.remap` detail is the one that bites people: it works in the editor and
breaks in the exported build. Handle it from the start.

## When *not* to use a Resource

- Data that changes every frame — use a plain object or a node.
- Very large tables (thousands of rows) — consider a CSV plus a build step.
- Anything a player edits at runtime and must be sandboxed — `.tres` can embed
  script paths, so never `load()` a `.tres` from an untrusted source. Use JSON
  with explicit parsing for user-generated content.
