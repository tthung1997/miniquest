class_name AccessoryItem
extends EquipmentItem
## One Accessory item: which accessory it is.
##
## Saves store only the template id, so an accessory's name, icon and numbers
## can change in its AccessoryData without touching any save.

@export var accessory_id: StringName = &""

var _data: AccessoryData = null


## A new item of `accessory_id`, or null with an error if there is no such
## accessory.
static func create(accessory_id: StringName) -> AccessoryItem:
	if AccessoryData.find(accessory_id) == null:
		return null
	var item: AccessoryItem = AccessoryItem.new()
	item.accessory_id = accessory_id
	return item


## A new item of a random accessory. Null, with an error, when there are none.
static func roll(rng: RandomNumberGenerator = null) -> AccessoryItem:
	var ids: Array[StringName] = AccessoryData.all_ids()
	if ids.is_empty():
		push_error("AccessoryItem: there are no accessories to roll from.")
		return null
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	return create(ids[rng.randi_range(0, ids.size() - 1)])


## This item's template, or null with an error if it no longer exists.
func data() -> AccessoryData:
	if _data == null or _data.id != accessory_id:
		_data = AccessoryData.find(accessory_id)
	return _data


func get_slot() -> EquipmentItem.Slot:
	return EquipmentItem.Slot.ACCESSORY


func get_display_name() -> String:
	var accessory: AccessoryData = data()
	return accessory.display_name if accessory != null else String(accessory_id).capitalize()


func get_icon_layers() -> Array[Texture2D]:
	var layers: Array[Texture2D] = []
	var accessory: AccessoryData = data()
	if accessory != null and accessory.icon != null:
		layers.append(accessory.icon)
	return layers


func get_stat_bonuses() -> Dictionary[StringName, int]:
	var accessory: AccessoryData = data()
	if accessory == null:
		return {}
	var rarity_data: RarityData = get_rarity()
	var scaled: Dictionary[StringName, int] = {}
	for stat_name: StringName in accessory.stat_bonuses:
		scaled[stat_name] = rarity_data.scale_points(accessory.stat_bonuses[stat_name])
	return scaled


func get_crit_chance() -> float:
	var accessory: AccessoryData = data()
	return get_rarity().scale_value(accessory.crit_chance) if accessory != null else 0.0


func get_cooldown_reduction() -> float:
	var accessory: AccessoryData = data()
	return get_rarity().scale_value(accessory.cooldown_reduction) if accessory != null else 0.0


func get_pickup_radius_bonus() -> float:
	var accessory: AccessoryData = data()
	return get_rarity().scale_value(accessory.pickup_radius) if accessory != null else 0.0


## What the tooltip adds beneath the name: this accessory's effects, then the
## stat points.
func get_tooltip_text() -> String:
	var lines: PackedStringArray = get_header_lines()
	var crit: float = get_crit_chance()
	if crit > 0.0:
		lines.append("Crit chance +%d%%" % roundi(crit * 100.0))
	var cooldown: float = get_cooldown_reduction()
	if cooldown > 0.0:
		lines.append("Cooldowns -%d%%" % roundi(cooldown * 100.0))
	var pickup: float = get_pickup_radius_bonus()
	if pickup > 0.0:
		lines.append("Pickup radius +%d px" % roundi(pickup))
	var bonuses: Dictionary[StringName, int] = get_stat_bonuses()
	var points: PackedStringArray = []
	for stat_name: StringName in bonuses:
		points.append("%s %+d" % [String(stat_name).left(3).to_upper(), bonuses[stat_name]])
	if not points.is_empty():
		lines.append("  ".join(points))
	return "\n".join(lines)
