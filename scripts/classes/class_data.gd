class_name ClassData
extends Resource
## One class in the class tree. Instances live in resources/classes/, one file
## per class, named after its id.
##
## Only the fields something reads today are here. The rest of a class's
## definition (stat growth, health per vitality, skills, advancement
## requirements) is in design/classes.json and moves here when levelling and
## combat need it.

const DIRECTORY: String = "res://resources/classes"

@export var id: StringName = &""
@export var display_name: String = ""
@export_range(0, 3) var tier: int = 0
## Base class whose armour art this class wears. Advanced classes wear their
## base class's pool, so a Berserker's is &"warrior".
@export var armour_pool: StringName = &""


## The class with `class_id`, or null with an error if there is none.
static func find(class_id: StringName) -> ClassData:
	var path: String = DIRECTORY.path_join("%s.tres" % class_id)
	if not ResourceLoader.exists(path):
		push_error("ClassData: no class '%s' at %s." % [class_id, path])
		return null
	var data: ClassData = load(path) as ClassData
	if data == null:
		push_error("ClassData: %s is not a ClassData." % path)
	return data
