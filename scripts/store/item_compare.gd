class_name ItemCompare
extends RefCounted
## What an item gives, set beside what a hero wears in its slot, for the store
## to show before the player pays.
##
## Only describes: nothing here touches a hero or an item. Each row is one
## number, such as damage or move speed, with the change from what is worn.

enum Tone { NEUTRAL, BETTER, WORSE }

## Differences smaller than this count as no change.
const EPSILON: float = 0.005


## The rows for `item` as `hero` would find it, against what the hero wears in
## its slot. Empty for kinds with nothing to compare.
static func rows(item: EquipmentItem, hero: HeroData) -> Array[Row]:
	if item == null or hero == null:
		return []
	var worn: EquipmentItem = hero.equipped(item.get_slot())
	if item is WeaponItem:
		return _weapon_rows(item as WeaponItem, worn as WeaponItem, hero)
	if item is ArmourItem and (item as ArmourItem).stat_points.is_empty():
		return _unrolled_armour_rows(item as ArmourItem, worn)
	return _stat_rows(item, worn)


static func _weapon_rows(item: WeaponItem, worn: WeaponItem, hero: HeroData) -> Array[Row]:
	var data: WeaponData = item.data()
	if data == null:
		return []
	var worn_data: WeaponData = worn.data() if worn != null else null
	var found: Array[Row] = []
	var damage: float = item.damage_for(hero)
	var worn_damage: float = worn.damage_for(hero) if worn != null else 0.0
	found.append(_number_row("Damage", damage, worn_damage, "%.1f"))
	var speed: float = 1.0 / maxf(data.attack_interval, 0.01)
	var worn_speed: float = (
		1.0 / maxf(worn_data.attack_interval, 0.01) if worn_data != null else 0.0
	)
	found.append(_number_row("Speed", speed, worn_speed, "%.2f/s"))
	var reach: float = data.attack_range
	var worn_reach: float = worn_data.attack_range if worn_data != null else 0.0
	found.append(_number_row("Range", reach, worn_reach, "%d"))
	return found


## Move speed, then each stat point the item or the worn item gives.
static func _stat_rows(item: EquipmentItem, worn: EquipmentItem) -> Array[Row]:
	var found: Array[Row] = []
	var speed: float = item.get_move_speed_bonus() * 100.0
	var worn_speed: float = worn.get_move_speed_bonus() * 100.0 if worn != null else 0.0
	if absf(speed) > EPSILON or absf(worn_speed) > EPSILON:
		found.append(_number_row("Speed", speed, worn_speed, "%+d%%", true))
	var bonuses: Dictionary[StringName, int] = item.get_stat_bonuses()
	var worn_bonuses: Dictionary[StringName, int] = worn.get_stat_bonuses() if worn != null else {}
	for stat_name: StringName in HeroData.STATS:
		var points: int = bonuses.get(stat_name, 0)
		var worn_points: int = worn_bonuses.get(stat_name, 0)
		if points == 0 and worn_points == 0:
			continue
		found.append(_number_row(_stat_label(stat_name), points, worn_points, "%+d", true))
	return found


## Armour in the store has no points yet: they are rolled when it is bought, so
## show the range each can roll, and what the hero's worn armour has.
static func _unrolled_armour_rows(item: ArmourItem, worn: EquipmentItem) -> Array[Row]:
	var found: Array[Row] = []
	var worn_bonuses: Dictionary[StringName, int] = worn.get_stat_bonuses() if worn != null else {}
	var ranges: Dictionary[StringName, Vector2i] = {}
	if item.pool == ArmourItem.NOVICE_POOL:
		ranges[&"vitality"] = Vector2i.ONE * ArmourItem.NOVICE_VITALITY
	else:
		ranges[&"vitality"] = ArmourItem.VITALITY_ROLL
		var leaning: StringName = ArmourItem.POOL_LEANINGS.get(item.pool, &"")
		if leaning != &"":
			ranges[leaning] = ArmourItem.LEANING_ROLL
	for stat_name: StringName in HeroData.STATS:
		if not ranges.has(stat_name):
			continue
		var span: Vector2i = ranges[stat_name]
		var value: String = str(span.x) if span.x == span.y else "%d-%d" % [span.x, span.y]
		var note: String = "you %d" % worn_bonuses.get(stat_name, 0) if worn != null else ""
		found.append(Row.new(_stat_label(stat_name), "+" + value, note))
	return found


static func _number_row(
	label: String, value: float, worn_value: float, format: String, whole: bool = false
) -> Row:
	var difference: float = value - worn_value
	var value_text: String = format % (roundi(value) if whole else value)
	if absf(difference) < EPSILON:
		return Row.new(label, value_text)
	var tone: Tone = Tone.BETTER if difference > 0.0 else Tone.WORSE
	var delta_text: String = "%+.1f" % difference
	if whole or format == "%d":
		delta_text = "%+d" % roundi(difference)
	return Row.new(label, value_text, delta_text, tone)


static func _stat_label(stat_name: StringName) -> String:
	return String(stat_name).left(3).to_upper()


## One line of the comparison.
class Row:
	extends RefCounted

	var label: String = ""
	var value: String = ""
	## Change from the worn item, such as "+2.5", or a note. Empty for none.
	var delta: String = ""
	var tone: Tone = Tone.NEUTRAL


	func _init(
		label_text: String,
		value_text: String,
		delta_text: String = "",
		row_tone: Tone = Tone.NEUTRAL
	) -> void:
		label = label_text
		value = value_text
		delta = delta_text
		tone = row_tone
