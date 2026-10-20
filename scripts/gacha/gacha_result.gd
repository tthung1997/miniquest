class_name GachaResult
extends RefCounted
## What one set of pulls gave, for the screen to show.

## Every item pulled, in pull order. They are already in the hero's inventory.
var items: Array[EquipmentItem] = []
## Gold the pulls cost.
var cost: int = 0
## Whether the pack's guarantee turned a pull into a Legendary.
var guarantee_triggered: bool = false
