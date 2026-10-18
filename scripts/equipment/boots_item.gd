class_name BootsItem
extends EquipmentItem
## One Boots item: which pair it is.
##
## Saves store only the template id, so a pair's name, art and numbers can
## change in its BootsData without touching any save.

@export var boots_id: StringName = &""

var _data: BootsData = null


## A new item of the pair `boots_id`, or null with an error if there is no such
## pair.
static func create(boots_id: StringName) -> BootsItem:
	if BootsData.find(boots_id) == null:
		return null
	var item: BootsItem = BootsItem.new()
	item.boots_id = boots_id
	return item


## A new item of a random pair. Null, with an error, when there are none.
static func roll(rng: RandomNumberGenerator = null) -> BootsItem:
	var ids: Array[StringName] = BootsData.all_ids()
	if ids.is_empty():
		push_error("BootsItem: there are no boots to roll from.")
		return null
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	return create(ids[rng.randi_range(0, ids.size() - 1)])


## This item's template, or null with an error if it no longer exists.
func data() -> BootsData:
	if _data == null or _data.id != boots_id:
		_data = BootsData.find(boots_id)
	return _data


func get_slot() -> EquipmentItem.Slot:
	return EquipmentItem.Slot.BOOTS


func get_display_name() -> String:
	var boots: BootsData = data()
	return boots.display_name if boots != null else String(boots_id).capitalize()


func get_icon_layers() -> Array[Texture2D]:
	var layers: Array[Texture2D] = []
	var boots: BootsData = data()
	if boots != null and boots.icon != null:
		layers.append(boots.icon)
	return layers


func get_stat_bonuses() -> Dictionary[StringName, int]:
	var boots: BootsData = data()
	if boots == null:
		return {}
	var rarity_data: RarityData = get_rarity()
	var scaled: Dictionary[StringName, int] = {}
	for stat_name: StringName in boots.stat_bonuses:
		scaled[stat_name] = rarity_data.scale_points(boots.stat_bonuses[stat_name])
	return scaled


func get_move_speed_bonus() -> float:
	var boots: BootsData = data()
	return get_rarity().scale_value(boots.move_speed) if boots != null else 0.0


## The frames to draw over the feet, or null when the template has none.
func frames() -> SpriteFrames:
	var boots: BootsData = data()
	return boots.frames if boots != null else null
