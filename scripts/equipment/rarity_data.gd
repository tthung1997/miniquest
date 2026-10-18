class_name RarityData
extends Resource
## One rarity of equipment. Instances live in resources/rarities/, one file per
## rarity, named after its id (DESIGN.md section 5.6).
##
## A higher rarity is strictly better: it scales what the item gives, turns up
## less often, and is marked with a frame in menus and a recolour on the
## item's art. Every number is a placeholder until the gear can be played.

const DIRECTORY: String = "res://resources/rarities"
const FILE_SUFFIX: String = ".tres"
const COMMON: StringName = &"common"
const SHADER: Shader = preload("res://shaders/item_rarity.gdshader")

@export var id: StringName = &""
@export var display_name: String = ""
## Lowest first. Sorts rarities from worst to best.
@export_range(0, 9) var order: int = 0
## The frame's colour, and the colour the item's art is shifted towards.
@export var color: Color = Color.WHITE

@export_group("Stats")
## What the item's numbers are multiplied by: 1.25 is a quarter more.
@export_range(1.0, 5.0, 0.05) var stat_multiplier: float = 1.0

@export_group("Drops")
## This rarity's share of drops. Only the ratio to the other rarities counts.
@export_range(0.0, 100.0, 0.5) var drop_weight: float = 1.0

@export_group("Look")
## How far the item's art is recoloured towards `color`; 0 leaves it as drawn.
@export_range(0.0, 1.0, 0.05) var tint_strength: float = 0.0
## Whether menus draw a frame around the item. Off for the plain rarity, so a
## full inventory is not a wall of borders.
@export var framed: bool = true

var _material: ShaderMaterial = null


## Every rarity, worst first.
static func all() -> Array[RarityData]:
	var found: Array[RarityData] = []
	# ResourceLoader rather than DirAccess, so the listing still matches the
	# resources after export, where files are remapped.
	for file: String in ResourceLoader.list_directory(DIRECTORY):
		if not file.ends_with(FILE_SUFFIX):
			continue
		var rarity: RarityData = find(StringName(file.trim_suffix(FILE_SUFFIX)))
		if rarity != null:
			found.append(rarity)
	found.sort_custom(RarityData._by_order)
	return found


## The rarity with `rarity_id`, or null with an error if there is none.
static func find(rarity_id: StringName) -> RarityData:
	var path: String = DIRECTORY.path_join("%s%s" % [rarity_id, FILE_SUFFIX])
	if not ResourceLoader.exists(path):
		push_error("RarityData: no rarity '%s' at %s." % [rarity_id, path])
		return null
	var data: RarityData = load(path) as RarityData
	if data == null:
		push_error("RarityData: %s is not a RarityData." % path)
	return data


## Pick a rarity at random, weighted by each one's `drop_weight`. Null, with an
## error, when no rarity can drop.
static func roll(rng: RandomNumberGenerator) -> RarityData:
	var rarities: Array[RarityData] = all()
	var total: float = 0.0
	for rarity: RarityData in rarities:
		total += rarity.drop_weight
	if total <= 0.0:
		push_error("RarityData: no rarity has a drop weight, so none can drop.")
		return null

	var pick: float = rng.randf() * total
	for rarity: RarityData in rarities:
		pick -= rarity.drop_weight
		if pick < 0.0 and rarity.drop_weight > 0.0:
			return rarity
	# Rounding can leave the pick just past the end; the last that can drop wins.
	for i: int in range(rarities.size() - 1, -1, -1):
		if rarities[i].drop_weight > 0.0:
			return rarities[i]
	return null


## `points` scaled by this rarity, rounded up so that any higher rarity is
## strictly better even for a bonus of one or two points.
func scale_points(points: int) -> int:
	if points <= 0 or is_equal_approx(stat_multiplier, 1.0):
		return points
	# The small subtraction stops 5 x 1.8 = 9.000000000000002 rounding up to 10.
	return ceili(points * stat_multiplier - 0.0001)


## `value` scaled by this rarity.
func scale_value(value: float) -> float:
	return value * stat_multiplier


## The material that recolours an item's art, or null when this rarity leaves
## it as drawn. Shared by everything of this rarity.
func get_tint_material() -> ShaderMaterial:
	if tint_strength <= 0.0:
		return null
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
		_material.set_shader_parameter(&"rarity_color", color)
		_material.set_shader_parameter(&"strength", tint_strength)
	return _material


static func _by_order(a: RarityData, b: RarityData) -> bool:
	return a.order < b.order
