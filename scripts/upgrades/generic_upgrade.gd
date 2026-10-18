class_name GenericUpgrade
extends Resource
## One upgrade from the run's general pool, offered alongside skills when the
## hero levels up mid-run (DESIGN.md section 6.4). Instances live in
## resources/upgrades/, one file per upgrade, named after its id.
##
## Taking one lasts until the run ends, and the same one can be taken again.
## The numbers are placeholders.

enum Effect {
	## Adds `amount` (a fraction) to how fast the hero runs.
	MOVE_SPEED,
	## Heals `amount` (a fraction) of the hero's maximum health.
	HEAL,
	## Adds `amount` (a fraction) to all damage the hero deals.
	DAMAGE,
	## Adds `amount` pixels to the hero's pickup radius.
	PICKUP_RADIUS,
}

const DIRECTORY: String = "res://resources/upgrades"
const FILE_SUFFIX: String = ".tres"

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
## 16x16 icon, drawn by tools/build_skill_icons.gd.
@export var icon: Texture2D
@export var effect: Effect = Effect.DAMAGE
@export_range(0.0, 1000.0, 0.01) var amount: float = 0.0


## Every generic upgrade, in alphabetical order of id.
static func all() -> Array[GenericUpgrade]:
	# Sorted as Strings: StringName comparison is not alphabetical.
	var names: PackedStringArray = []
	# ResourceLoader rather than DirAccess, so the listing still matches the
	# resources after export, where files are remapped.
	for file: String in ResourceLoader.list_directory(DIRECTORY):
		if file.ends_with(FILE_SUFFIX):
			names.append(file.trim_suffix(FILE_SUFFIX))
	names.sort()
	var found: Array[GenericUpgrade] = []
	for upgrade_name: String in names:
		var path: String = DIRECTORY.path_join(upgrade_name + FILE_SUFFIX)
		var upgrade: GenericUpgrade = load(path) as GenericUpgrade
		if upgrade == null:
			push_error("GenericUpgrade: %s is not a GenericUpgrade." % path)
			continue
		found.append(upgrade)
	return found
