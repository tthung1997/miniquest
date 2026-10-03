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
