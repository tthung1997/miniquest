class_name HeroData
extends Resource
## Everything that makes up one hero, and the contents of one save slot.
##
## The hero is the save (DESIGN.md section 2): runs are disposable, this is
## not. Saved and loaded by HeroSaves.

## Bumped whenever a saved field changes meaning, so a loader can migrate.
const FORMAT_VERSION: int = 1
const STARTING_CLASS: StringName = &"novice"
## Every stat's value at level 1 (design/classes.json, starting_stats).
const STARTING_STAT: int = 5
const NAME_MAX_LENGTH: int = 12

## Zero (the default) means the file predates versioning. Left at a non-default
## on purpose: Godot omits default-valued fields when saving, which would drop
## the version line from every file.
@export var format_version: int = 0
@export var hero_name: String = ""
@export_range(1, 999) var level: int = 1
@export var experience: int = 0
@export var gold: int = 0
@export var class_id: StringName = STARTING_CLASS

@export_group("Stats")
@export var strength: int = STARTING_STAT
@export var dexterity: int = STARTING_STAT
@export var intelligence: int = STARTING_STAT
@export var vitality: int = STARTING_STAT
@export var unspent_points: int = 0

@export_group("Equipment")
@export var armour: ArmourItem


## A new level 1 Novice called `raw_name`, wearing freshly rolled Novice
## armour. Returns null with an error if the name is empty once cleaned.
static func create(raw_name: String) -> HeroData:
	var cleaned: String = clean_name(raw_name)
	if cleaned.is_empty():
		push_error("HeroData: a hero needs a name.")
		return null

	var starting_class: ClassData = ClassData.find(STARTING_CLASS)
	if starting_class == null:
		return null

	var hero: HeroData = HeroData.new()
	hero.format_version = FORMAT_VERSION
	hero.hero_name = cleaned
	hero.class_id = STARTING_CLASS
	hero.armour = ArmourItem.roll(starting_class.armour_pool)
	if hero.armour == null:
		return null
	return hero


## Trim surrounding whitespace, collapse inner runs of it, and cap the length.
static func clean_name(raw_name: String) -> String:
	var words: PackedStringArray = raw_name.strip_edges().split(" ", false)
	return " ".join(words).left(NAME_MAX_LENGTH).strip_edges()


func class_data() -> ClassData:
	return ClassData.find(class_id)
