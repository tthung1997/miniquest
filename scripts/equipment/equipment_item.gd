@abstract
class_name EquipmentItem
extends Resource
## Anything a hero can wear in one of the four equipment slots (DESIGN.md
## section 5.6).
##
## Each slot holds at most one item, and an item only fits its own slot.
## Subclasses say which slot that is, what the item is called, and what its
## inventory icon looks like.

enum Slot { WEAPON, ARMOUR, BOOTS, ACCESSORY }

## Player-facing slot names, indexed by Slot.
const SLOT_NAMES: PackedStringArray = ["Weapon", "Armour", "Boots", "Accessory"]
## Every icon layer is drawn on a canvas this size, so layers stack by position.
const ICON_SIZE: Vector2i = Vector2i(16, 16)


static func slot_name(slot: Slot) -> String:
	return SLOT_NAMES[slot]


@abstract func get_slot() -> Slot


@abstract func get_display_name() -> String


## The item's icon as layers drawn in order, each ICON_SIZE. A single-image
## icon is one layer.
@abstract func get_icon_layers() -> Array[Texture2D]


## Points this item adds to its wearer's stats, keyed by HeroData stat name.
func get_stat_bonuses() -> Dictionary[StringName, int]:
	return {}


## Fraction of the hero's base move speed this item adds: 0.1 is 10% faster.
func get_move_speed_bonus() -> float:
	return 0.0


## What a cell shows on hover: the name, then whatever the item adds, with
## the stat points together on one line.
func get_tooltip_text() -> String:
	var lines: PackedStringArray = [get_display_name()]
	var speed: float = get_move_speed_bonus()
	if not is_zero_approx(speed):
		lines.append("Move speed %+d%%" % roundi(speed * 100.0))
	var bonuses: Dictionary[StringName, int] = get_stat_bonuses()
	var points: PackedStringArray = []
	for stat_name: StringName in bonuses:
		points.append("%s %+d" % [String(stat_name).left(3).to_upper(), bonuses[stat_name]])
	if not points.is_empty():
		lines.append("  ".join(points))
	return "\n".join(lines)
