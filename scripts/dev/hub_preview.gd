class_name HubPreview
extends Node
## Opens the hub with a throwaway hero carrying rolled armour from every pool
## and every pair of boots, cycling through every rarity, so equipping and
## rarity can be tried before item drops are tuned. The hero wears gear of
## `worn_rarity`.
##
## The hero is never saved: hero_changed is left unconnected. Raise
## `spare_armours` to 25 to try a full inventory, and `unspent_points` to try
## the stats panel.
##
## Run this scene on its own with F6. Not shipped game code.

const POOLS: Array[StringName] = [&"novice", &"mage", &"ranger", &"warrior"]

@export_range(0, 25) var spare_armours: int = 8
@export_range(0, 60) var unspent_points: int = 10
## Level the hero starts at, with Novice growth. Raise it to 5 to try the
## class advance dialog, or to 15 with enough points spent for tier 2.
@export_range(1, 30) var hero_level: int = 5
@export var hero_name: String = "Tester"
## Rarity of the hero's worn weapon, armour and boots, by id: common, uncommon,
## rare, epic or legendary. Empty leaves the starting gear as it is.
@export var worn_rarity: StringName = &"epic"

@onready var _hub: Hub = $Hub


func _ready() -> void:
	var hero: HeroData = HeroData.create(hero_name)
	if hero == null:
		return
	hero.gain_experience(Levelling.total_exp_for(hero_level))
	hero.unspent_points = unspent_points
	if worn_rarity != &"":
		hero.boots = BootsItem.create(&"wind_walkers")
		for worn: EquipmentItem in [hero.weapon, hero.armour, hero.boots]:
			if worn != null:
				worn.rarity = worn_rarity
	var rarities: Array[RarityData] = RarityData.all()
	for i in mini(spare_armours, HeroData.INVENTORY_SIZE):
		var armour: ArmourItem = ArmourItem.roll(POOLS[i % POOLS.size()])
		if armour == null:
			return
		armour.rarity = rarities[i % rarities.size()].id
		if not hero.add_to_inventory(armour):
			return
	var next_rarity: int = 0
	for boots_id: StringName in BootsData.all_ids():
		var boots: BootsItem = BootsItem.create(boots_id)
		if boots == null:
			break
		boots.rarity = rarities[next_rarity % rarities.size()].id
		next_rarity += 1
		if not hero.add_to_inventory(boots):
			break
	_hub.show_hero(hero)
