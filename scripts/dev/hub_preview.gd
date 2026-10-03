class_name HubPreview
extends Node
## Opens the hub with a throwaway hero carrying rolled armour from every pool,
## so equipping can be tried before item drops exist.
##
## The hero is never saved: hero_changed is left unconnected. Raise
## `spare_armours` to 24 to try a full inventory.
##
## Run this scene on its own with F6. Not shipped game code.

const POOLS: Array[StringName] = [&"novice", &"mage", &"ranger", &"warrior"]

@export_range(0, 24) var spare_armours: int = 8
@export var hero_name: String = "Tester"

@onready var _hub: Hub = $Hub


func _ready() -> void:
	var hero: HeroData = HeroData.create(hero_name)
	if hero == null:
		return
	for i in mini(spare_armours, HeroData.INVENTORY_SIZE):
		var armour: ArmourItem = ArmourItem.roll(POOLS[i % POOLS.size()])
		if armour == null or not hero.add_to_inventory(armour):
			return
	_hub.show_hero(hero)
