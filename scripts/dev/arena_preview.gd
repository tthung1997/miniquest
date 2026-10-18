class_name ArenaPreview
extends Node
## Runs the arena with a throwaway hero wearing a weapon, armour and boots of
## one rarity, so the rarity can be seen in play: the aura and the weapon
## outline on the hero, and the glow on dropped items. Kills drop items often,
## at that same rarity, so the ground glow can be seen too; the quest's cap
## still limits a run to a few.
##
## F1 to F5 switch the rarity, lowest first, and redress the hero at once. A
## finished run restarts the scene. Nothing is saved.
##
## Run this scene on its own with F6. Not shipped game code.

const RARITY_KEYS: Array[Key] = [KEY_F1, KEY_F2, KEY_F3, KEY_F4, KEY_F5]
const BOOTS_ID: StringName = &"wind_walkers"

## Rarity the hero starts in, by id: common, uncommon, rare, epic or legendary.
@export var start_rarity: StringName = &"legendary"
## Chance each kill leaves an item. The quest's per-run cap still applies, so
## this only decides how soon the few items arrive.
@export_range(0.0, 1.0, 0.05) var item_chance: float = 0.15
@export_range(1, 30) var hero_level: int = 5
@export var hero_name: String = "Tester"

var _hero: HeroData = null
var _rarities: Array[RarityData] = []
var _label: Label = null

@onready var _run: ArenaRun = $ArenaRun


func _ready() -> void:
	_rarities = RarityData.all()
	_hero = HeroData.create(hero_name)
	if _hero == null:
		return
	_hero.gain_experience(Levelling.total_exp_for(hero_level))
	_hero.boots = BootsItem.create(BOOTS_ID)
	Drops.item_chance_override = item_chance

	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 1
	_label = Label.new()
	_label.position = Vector2(8.0, 60.0)
	layer.add_child(_label)
	add_child(layer)

	_dress(start_rarity)
	_run.show_hero(_hero)
	_run.finished.connect(_on_run_finished)


func _unhandled_input(event: InputEvent) -> void:
	if _hero == null or event is not InputEventKey:
		return
	var key: InputEventKey = event
	if not key.pressed or key.echo:
		return
	var index: int = RARITY_KEYS.find(key.physical_keycode)
	if index >= 0 and index < _rarities.size():
		_dress(_rarities[index].id)
		_run.hero.apply(_hero)


## Give the hero's gear, and everything that drops from now on, `rarity_id`.
func _dress(rarity_id: StringName) -> void:
	for item: EquipmentItem in [_hero.weapon, _hero.armour, _hero.boots]:
		if item != null:
			item.rarity = rarity_id
	Drops.forced_rarity = rarity_id
	_label.text = "Rarity: %s    (F1-F5 to change)" % String(rarity_id).capitalize()


func _on_run_finished(_result: RunResult) -> void:
	get_tree().reload_current_scene()
