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
	var rarity_data: RarityData = get_rarity()
	var scaling: PackedStringArray = []
	for stat_name: StringName in weapon.scaling:
		var stat_text: String = String(stat_name).left(3).to_upper()
		var factor: float = rarity_data.scale_value(weapon.scaling[stat_name])
		scaling.append("%s %s" % [_format(factor), stat_text])
	var damage: String = _format(rarity_data.scale_value(weapon.base_damage))
	if not scaling.is_empty():
		damage += " + " + " + ".join(scaling)
	var lines: PackedStringArray = get_header_lines()
	lines.append("Damage %s" % damage)
	lines.append("Attacks every %ss" % String.num(weapon.attack_interval))
	lines.append("Range %d" % roundi(weapon.attack_range))
	return "\n".join(lines)


## Damage of one hit when `wielder` swings this weapon: the template's damage
## times this item's rarity.
func damage_for(wielder: HeroData) -> float:
	return damage_with(wielder.total_stats())


## Damage of one hit for stat values `stats`, keyed like HeroData.STATS. Zero,
## with an error from data(), when the template is missing.
func damage_with(stats: Dictionary[StringName, int]) -> float:
	var weapon: WeaponData = data()
	if weapon == null:
		return 0.0
	return get_rarity().scale_value(weapon.damage_with(stats))


## Damage of one hit with no stats at all, for a hero that has none.
func base_damage() -> float:
	var weapon: WeaponData = data()
	return get_rarity().scale_value(weapon.base_damage) if weapon != null else 0.0


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


## Up to two decimals, dropping zeros: scaled numbers such as 0.3125 stay short.
static func _format(value: float) -> String:
	return String.num(snappedf(value, 0.01))
