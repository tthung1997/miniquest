class_name ArenaRun
extends Node2D
## One playthrough of the arena quest: the meadow, the hero, and a RunDirector
## sending enemies in along the quest's ramp.
##
## A run ends three ways: the hero survives the quest's full duration (a win),
## the hero dies, or the player retreats from the pause menu. A death and a
## retreat are the same to the rewards (DESIGN.md section 6.5). Whichever it
## is, the tree is paused behind a results panel until the player continues,
## and then `finished` carries the RunResult to whoever banks it. The run
## itself saves nothing and changes no scene.
##
## Kills also feed the run's own levelling (RunProgress). Each in-run level
## pauses the run behind the upgrade overlay and applies the pick: a skill
## taken or raised, or a generic upgrade (DESIGN.md section 6.4). The hero
## starts with the one skill their hub screen chose, and carries at most four.

## The player pressed Continue on the results panel. The tree is no longer
## paused, so whatever listens can swap scenes.
signal finished(result: RunResult)

## Seconds between the hero falling and the results panel, so the death is seen.
const DEATH_DELAY: float = 0.75
## Weapon given to a hero when this scene is run on its own.
const STANDALONE_WEAPON: StringName = &"sword"
const RETREAT_WARNING: String = (
	"Retreating ends the run like a defeat: only the experience you earned is kept. "
	+ "Gold and items you picked up are lost."
)
## How far from where an enemy fell its drops land.
const DROP_SCATTER: float = 8.0

## Where the dropped gold and items appear.
@export var pickup_scene: PackedScene

var _kills: int = 0
var _experience: int = 0
var _gold: int = 0
var _items: Array[EquipmentItem] = []
## Items this run's kills have left on the ground, against the quest's cap.
var _item_drops: int = 0
var _hero_data: HeroData = null
var _ending: bool = false
var _result: RunResult = null
var _run_started: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _progress: RunProgress = null
## Every skill the hero can be offered, and the level they have trained each to.
var _unlocked: Array[SkillData] = []
var _permanent_levels: Dictionary[StringName, int] = {}
## Level-ups still waiting for their pick, and whether one is being picked now.
var _pending_picks: int = 0
var _choosing: bool = false

@onready var hero: Hero = $Hero
@onready var _arena: ArenaMap = $Meadow
@onready var _camera: Camera2D = $Hero/Camera
## Kept above the y-sorted hero and trees, so shots are never hidden.
@onready var _projectiles: Node2D = $Projectiles
@onready var _director: RunDirector = $RunDirector
@onready var _readout: Label = $HUD/Root/Readout
@onready var _skill_bar: SkillBar = %SkillBar
@onready var _pause_menu: PauseMenu = %PauseMenu
@onready var _retreat_dialog: ConfirmDialog = %RetreatDialog
@onready var _upgrade_overlay: UpgradeOverlay = %UpgradeOverlay
@onready var _end_panel: RunEndPanel = %EndPanel


func _ready() -> void:
	_rng.randomize()
	_progress = RunProgress.new(_director.quest)
	# Run on its own there is no saved hero to dress from, so start armed.
	if hero.weapon == null:
		hero.wield(WeaponItem.create(STANDALONE_WEAPON))
	hero.position = _arena.position + _arena.playable_rect.get_center()
	var limits: Rect2i = Rect2i(_arena.map_rect)
	limits.position += Vector2i(_arena.position)
	_camera.limit_left = limits.position.x
	_camera.limit_top = limits.position.y
	_camera.limit_right = limits.end.x
	_camera.limit_bottom = limits.end.y

	hero.projectile_released.connect(_on_hero_projectile_released)
	hero.effect_spawned.connect(_on_hero_effect_spawned)
	hero.pickup_reached.connect(_on_hero_pickup_reached)
	hero.died.connect(_on_hero_died)
	hero.skills.skills_changed.connect(_on_skills_changed)
	hero.skills.auto_cast_changed.connect(_skill_bar.show_auto_cast)
	_skill_bar.auto_cast_toggle_requested.connect(_on_auto_cast_toggle_requested)
	_skill_bar.show_auto_cast(hero.skills.auto_cast)
	_director.enemy_killed.connect(_on_enemy_killed)
	_director.survived.connect(_on_run_survived)
	_pause_menu.resume_requested.connect(_on_resume_requested)
	_pause_menu.retreat_requested.connect(_on_retreat_requested)
	_retreat_dialog.confirmed.connect(_end.bind(RunResult.Outcome.RETREATED))
	_retreat_dialog.cancelled.connect(_pause_menu.open)
	_upgrade_overlay.offer_chosen.connect(_on_offer_chosen)
	_end_panel.continue_pressed.connect(_on_continue_pressed)

	# A saved hero is shown right after this scene is added, which starts the
	# run at their level; this only covers the scene being run on its own.
	_start_standalone_run.call_deferred()
	_refresh()


func _exit_tree() -> void:
	# A pause left on would freeze whatever screen comes next.
	if get_tree() != null:
		get_tree().paused = false


## Dress the hero as `data` and start the run at their level.
func show_hero(data: HeroData) -> void:
	_hero_data = data
	hero.apply(data)
	_unlocked = data.unlocked_skills()
	_permanent_levels = data.skill_levels()
	var loadout: Array[HeldSkill] = []
	var start: SkillData = data.start_skill()
	if start != null:
		loadout.append(HeldSkill.new(start, _permanent_levels[start.id]))
	hero.skills.set_loadout(loadout)
	_start_run(data.level)
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") and not event.is_echo() and not _ending:
		if _choosing:
			return
		get_viewport().set_input_as_handled()
		get_tree().paused = true
		_pause_menu.open()


func _start_standalone_run() -> void:
	if _run_started:
		return
	# No saved hero to take skills from: play as a fresh Novice.
	_unlocked = SkillData.granted_by([HeroData.STARTING_CLASS])
	var loadout: Array[HeldSkill] = []
	var start: SkillData = SkillData.default_start(_unlocked)
	if start != null:
		loadout.append(HeldSkill.new(start))
	hero.skills.set_loadout(loadout)
	_start_run(1)


func _start_run(level: int) -> void:
	_run_started = true
	_director.start(level)


## Finish the run as `outcome`, once: whatever ends it first wins.
## Finish the run as `outcome`, once: whatever ends it first wins. A win banks
## what was picked up and adds the quest's win bonus; a death or retreat banks
## only experience and forfeits the rest.
func _end(outcome: RunResult.Outcome) -> void:
	if _result != null:
		return
	_ending = true
	_director.stop()
	_result = RunResult.new()
	_result.outcome = outcome
	_result.time_survived = _director.elapsed
	_result.duration = _director.quest.duration
	_result.kills = _kills
	_result.experience = _experience
	if outcome == RunResult.Outcome.WON:
		_add_win_bonus(_result)
	else:
		_result.gold_forfeited = _gold
		_result.items_forfeited = _items.size()

	if _hero_data != null:
		_result.level_before = _hero_data.level
		_result.level_after = _hero_data.level_after(_result.experience)
		var room: int = _hero_data.free_inventory_cells()
		_result.items_without_room = maxi(_result.items.size() - room, 0)
	get_tree().paused = true
	_end_panel.show_result(_result)


## Bank the pickups into `result` and add the win bonus on top.
func _add_win_bonus(result: RunResult) -> void:
	var quest: QuestData = _director.quest
	var bonus_items: Array[EquipmentItem] = Drops.win_bonus_items(
		quest, _director.ramp_start, _rng
	)
	result.bonus_experience = quest.win_bonus_experience
	result.bonus_gold = quest.win_bonus_gold
	result.bonus_items = bonus_items.size()
	result.experience += result.bonus_experience
	result.gold = _gold + result.bonus_gold
	result.items = _items.duplicate()
	result.items.append_array(bonus_items)


func _on_hero_died() -> void:
	if _ending:
		return
	_ending = true
	_director.stop()
	await get_tree().create_timer(DEATH_DELAY).timeout
	if is_inside_tree():
		_end(RunResult.Outcome.DIED)


func _on_run_survived() -> void:
	if not _ending:
		_end(RunResult.Outcome.WON)


func _on_enemy_killed(enemy: Enemy) -> void:
	_kills += 1
	_experience += enemy.data.experience
	_drop_loot(enemy)
	var gained: int = _progress.add_experience(enemy.data.experience)
	if gained > 0 and not _ending:
		_pending_picks += gained
		_offer_upgrades.call_deferred()


## Pause the run and offer the next waiting upgrade pick, if there is one and
## nothing else is in the way.
func _offer_upgrades() -> void:
	if _choosing or _pending_picks <= 0 or _ending:
		return
	if _pause_menu.visible or _retreat_dialog.visible:
		return
	var offers: Array[UpgradeOffer] = UpgradePool.roll(
		_unlocked,
		hero.skills.held,
		_permanent_levels,
		_director.quest.offer_count,
		_rng,
	)
	if offers.is_empty():
		_pending_picks = 0
		return
	_pending_picks -= 1
	_choosing = true
	get_tree().paused = true
	_upgrade_overlay.open(offers, _progress.level - _pending_picks)


func _on_offer_chosen(offer: UpgradeOffer) -> void:
	match offer.kind:
		UpgradeOffer.Kind.SKILL:
			if offer.raises_held:
				hero.skills.level_up(offer.skill.id)
			else:
				hero.skills.add_skill(HeldSkill.new(offer.skill, offer.skill_level))
		UpgradeOffer.Kind.GENERIC:
			hero.apply_upgrade(offer.upgrade)
	_upgrade_overlay.close()
	_choosing = false
	if _pending_picks > 0:
		_offer_upgrades()
	else:
		get_tree().paused = false


## Leave whatever `enemy` drops where it fell. Items stop once the quest's cap
## for the run is reached.
func _drop_loot(enemy: Enemy) -> void:
	var gold: int = Drops.gold_for(enemy.data, _rng)
	if gold > 0:
		var coins: Pickup = _new_pickup(enemy.global_position)
		if coins != null:
			coins.set_gold(gold)
	if _item_drops >= _director.quest.max_item_drops:
		return
	if Drops.item_dropped(enemy.data, _rng):
		var difficulty: float = _director.quest.start_difficulty(_director.ramp_start)
		var item: EquipmentItem = Drops.roll_item(_rng, difficulty)
		var loot: Pickup = _new_pickup(enemy.global_position) if item != null else null
		if loot != null:
			loot.set_item(item)
			_item_drops += 1


## A pickup near `at`, on its way into the world. Adding waits for the end of
## the frame because the kill that made it can come from inside a physics
## callback, where adding collision objects is not allowed.
func _new_pickup(at: Vector2) -> Pickup:
	if pickup_scene == null:
		push_error("ArenaRun: pickup_scene must be wired to show drops.")
		return null
	var node: Node = pickup_scene.instantiate()
	if node is not Pickup:
		push_error("ArenaRun: pickup_scene must have a Pickup root.")
		node.free()
		return null
	var pickup: Pickup = node
	var scatter: Vector2 = Vector2(
		_rng.randf_range(-DROP_SCATTER, DROP_SCATTER),
		_rng.randf_range(-DROP_SCATTER, DROP_SCATTER) * 0.5,
	)
	pickup.position = to_local(at + scatter)
	add_child.call_deferred(pickup)
	return pickup


func _on_hero_pickup_reached(pickup: Pickup) -> void:
	if pickup.is_collected():
		return
	if pickup.kind == Pickup.Kind.GOLD:
		_gold += pickup.gold
	elif pickup.item != null:
		_items.append(pickup.item)
	pickup.collect()


func _on_resume_requested() -> void:
	_pause_menu.close()
	get_tree().paused = false
	_offer_upgrades.call_deferred()


func _on_retreat_requested() -> void:
	_pause_menu.close()
	_retreat_dialog.open(RETREAT_WARNING, "RETREAT", "KEEP FIGHTING")


func _on_continue_pressed() -> void:
	get_tree().paused = false
	finished.emit(_result)


func _on_hero_projectile_released(projectile: Projectile) -> void:
	_projectiles.add_child(projectile)


func _on_hero_effect_spawned(effect: Node2D, at: Vector2) -> void:
	_projectiles.add_child(effect)
	effect.global_position = at


func _on_skills_changed() -> void:
	_skill_bar.show_skills(hero.skills.held)


func _on_auto_cast_toggle_requested() -> void:
	hero.skills.set_auto_cast(not hero.skills.auto_cast)


func _refresh() -> void:
	var level: Vector2i = _progress.progress() if _progress != null else Vector2i.ZERO
	_readout.text = (
		"HP %d/%d    Lv %d (%d/%d)    kills %d    exp +%d    gold %d    items %d\n"
		+ "time %s / %s    Esc to pause    1-4 cast skills    Tab auto-cast"
	) % [
		ceili(hero.health.current),
		roundi(hero.health.maximum),
		_progress.level if _progress != null else 1,
		level.x,
		level.y,
		_kills,
		_experience,
		_gold,
		_items.size(),
		RunResult.clock(_director.elapsed),
		RunResult.clock(_director.quest.duration),
	]
