class_name ClassData
extends Resource
## One class in the class tree. Instances live in resources/classes/, one file
## per class, named after its id.
##
## Only the fields something reads today are here. Skills live in SkillData: a
## hero's skills are those whose `class_id` is in their lineage.
##
## A class's stat growth is its own. A hero's growth each level is the sum over
## their whole lineage (HeroData.lineage()), so a Berserker also gains Novice
## and Warrior growth. Nothing here assumes a number of tiers: a new tier is
## more files in resources/classes/ whose prerequisites name the tier below.

const DIRECTORY: String = "res://resources/classes"
const FILE_SUFFIX: String = ".tres"

@export var id: StringName = &""
@export var display_name: String = ""
## Emblem shown beside the class name: a 16x16 icon.
@export var icon: Texture2D
## Colour of the class's box in the skill tree, to tell classes apart.
@export var color: Color = Color(0.7, 0.65, 0.55)
@export_multiline var description: String = ""
@export_range(0, 3) var tier: int = 0
## Skill points the hero must have spent on the skills of the class they
## advanced from before this class's own skills unlock. It stops a hero skipping
## the lower skills to pile points into the higher ones. A class's skills are
## always open when this is zero.
@export_range(0, 40) var skill_points_required: int = 0
## Classes a hero can advance into this one from, by being it right now. More
## than one makes this reachable from any of them, as the hybrids are. Empty
## for a class a hero starts as.
@export var prerequisites: Array[StringName] = []
## Level a hero must have reached to advance into this class.
@export_range(1, 999) var required_level: int = 1
## Stat points a hero must have earned to advance into this class, keyed by
## HeroData stat name. Gear does not count, so swapping it cannot unlock a
## class.
@export var stat_requirements: Dictionary[StringName, int] = {}
## Base class whose armour art this class wears, such as &"warrior". Empty
## inherits from the class before this one in the hero's lineage, so a hybrid
## wears the armour of whichever parent the hero came through.
@export var armour_pool: StringName = &""
## Stat points gained per level, keyed by HeroData stat name such as
## &"strength". Stats not listed do not grow.
@export var stat_growth: Dictionary[StringName, float] = {}
## Durability: how much maximum health each point of vitality is worth, as a
## multiplier. Warrior 1.2, Mage 0.8. Zero inherits from the class before this
## one in the hero's lineage.
@export_range(0.0, 3.0, 0.05) var health_per_vitality: float = 0.0


## Every class id, sorted.
static func all_ids() -> Array[StringName]:
	# Sorted as Strings: StringName comparison is not alphabetical.
	var names: PackedStringArray = []
	# ResourceLoader rather than DirAccess, so the listing still matches the
	# resources after export, where files are remapped.
	for file: String in ResourceLoader.list_directory(DIRECTORY):
		if file.ends_with(FILE_SUFFIX):
			names.append(file.trim_suffix(FILE_SUFFIX))
	names.sort()
	var ids: Array[StringName] = []
	for class_name_text: String in names:
		ids.append(StringName(class_name_text))
	return ids


## Every class a hero who is currently `class_id` can advance into, whether or
## not they meet its requirements yet. Ordered by tier, then by id.
static func advancements_from(class_id: StringName) -> Array[ClassData]:
	var options: Array[ClassData] = []
	for candidate_id: StringName in all_ids():
		var candidate: ClassData = find(candidate_id)
		if candidate != null and candidate.prerequisites.has(class_id):
			options.append(candidate)
	options.sort_custom(ClassData._by_tier_then_id)
	return options


static func _by_tier_then_id(a: ClassData, b: ClassData) -> bool:
	if a.tier != b.tier:
		return a.tier < b.tier
	return String(a.id) < String(b.id)


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
