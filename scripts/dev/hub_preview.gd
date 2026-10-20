class_name HubPreview
extends Node
## Opens the hub with a throwaway hero carrying rolled armour from every pool
## and some pairs of boots, cycling through every rarity, so equipping and
## rarity can be tried before item drops are tuned. The hero wears gear of
## `worn_rarity` and has `gold` to spend. The gold count opens the store, and the
## store's GACHA button opens the gacha, each going back a step, so buying,
## selling (right-click an item), pulling and merging can all be tried.
##
## The hero is never saved: hero_changed is left unconnected, and every change
## is lost when the scene stops. Raise `spare_armours` and `spare_boots` to
## fill the inventory (a ten-pull needs ten free cells), and `unspent_points`
## to try the stats panel.
##
## Run this scene on its own with F6. Not shipped game code.

const POOLS: Array[StringName] = [&"novice", &"mage", &"ranger", &"warrior"]

@export_range(0, 25) var spare_armours: int = 8
@export_range(0, 13) var spare_boots: int = 4
@export_range(0, 60) var unspent_points: int = 10
@export_range(0, 1000000, 100) var gold: int = 20000
## Level the hero starts at, with Novice growth. Raise it to 5 to try the
## class advance dialog, or to 15 with enough points spent for tier 2.
@export_range(1, 30) var hero_level: int = 5
@export var hero_name: String = "Tester"
## Rarity of the hero's worn weapon, armour and boots, by id: common, uncommon,
## rare, epic or legendary. Empty leaves the starting gear as it is.
@export var worn_rarity: StringName = &"epic"
@export var store_scene: PackedScene
@export var gacha_scene: PackedScene

var _hero: HeroData = null

@onready var _hub: Hub = $Hub


func _ready() -> void:
	_hero = HeroData.create(hero_name)
	if _hero == null:
		return
	var hero: HeroData = _hero
	hero.gain_experience(Levelling.total_exp_for(hero_level))
	hero.unspent_points = unspent_points
	hero.gold = gold
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
	for boots_id: StringName in BootsData.all_ids().slice(0, spare_boots):
		var boots: BootsItem = BootsItem.create(boots_id)
		if boots == null:
			break
		boots.rarity = rarities[next_rarity % rarities.size()].id
		next_rarity += 1
		if not hero.add_to_inventory(boots):
			break
	_hub.store_requested.connect(_open_screen.bind(store_scene))
	_hub.show_hero(hero)


## Swap what is on show for `scene`, a Store or Gacha. The store leads on to the
## gacha and the gacha back to the store; the store goes back to the hub.
func _open_screen(scene: PackedScene) -> void:
	if scene == null:
		push_error("HubPreview: store_scene and gacha_scene must be wired.")
		return
	var screen: Node = scene.instantiate()
	if screen is not Store and screen is not Gacha:
		push_error("HubPreview: the scene must have a Store or Gacha root.")
		screen.free()
		return
	screen.show_hero(_hero)
	screen.back_requested.connect(_close_screen.bind(screen))
	if screen is Store:
		screen.gacha_requested.connect(_replace_screen.bind(screen, gacha_scene))
	if _hub.is_inside_tree():
		remove_child(_hub)
	add_child(screen)


func _replace_screen(old: Node, scene: PackedScene) -> void:
	old.queue_free()
	remove_child(old)
	_open_screen(scene)


func _close_screen(screen: Node) -> void:
	screen.queue_free()
	remove_child(screen)
	if screen is Gacha:
		_open_screen(store_scene)
		return
	add_child(_hub)
	_hub.show_hero(_hero)
