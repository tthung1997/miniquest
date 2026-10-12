class_name WeaponItem
extends EquipmentItem
## One Weapon item: which weapon template it is.
##
## Saves store only the template id, so a weapon's name, art and numbers can
## change in its WeaponData without touching any save.

@export var weapon_id: StringName = &""

var _data: WeaponData = null


## A new item of the weapon `weapon_id`, or null with an error if no such
## weapon exists.
static func create(weapon_id: StringName) -> WeaponItem:
	if WeaponData.find(weapon_id) == null:
		return null
	var item: WeaponItem = WeaponItem.new()
	item.weapon_id = weapon_id
	return item


## This item's template, or null with an error if it no longer exists.
func data() -> WeaponData:
	if _data == null or _data.id != weapon_id:
		_data = WeaponData.find(weapon_id)
	return _data


func get_slot() -> EquipmentItem.Slot:
	return EquipmentItem.Slot.WEAPON


func get_display_name() -> String:
	var weapon: WeaponData = data()
	return weapon.display_name if weapon != null else String(weapon_id).capitalize()


func get_tooltip_text() -> String:
	var weapon: WeaponData = data()
	if weapon == null:
		return get_display_name()
	var scaling: PackedStringArray = []
	for stat_name: StringName in weapon.scaling:
		var stat_text: String = String(stat_name).left(3).to_upper()
		scaling.append("%s %s" % [String.num(weapon.scaling[stat_name]), stat_text])
	var damage: String = String.num(weapon.base_damage)
	if not scaling.is_empty():
		damage += " + " + " + ".join(scaling)
	return "%s\nDamage %s\nAttacks every %ss\nRange %d" % [
		get_display_name(), damage, String.num(weapon.attack_interval), roundi(weapon.attack_range)
	]


func get_icon_layers() -> Array[Texture2D]:
	var layers: Array[Texture2D] = []
	var weapon: WeaponData = data()
	if weapon != null and weapon.icon != null:
		layers.append(weapon.icon)
	return layers


## The in-hand frames to draw, or null when the template has none.
func frames() -> SpriteFrames:
	var weapon: WeaponData = data()
	return weapon.frames if weapon != null else null
