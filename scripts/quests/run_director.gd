class_name RunDirector
extends Node
## Runs a quest's clock and feeds the arena enemies along its ramp.
##
## Call start() with the hero's level. From then on it counts the run's time,
## spawns enemies just beyond the screen as fast as the ramp allows, scales
## their health and damage with it, and announces when the hero has survived
## the whole duration. Everything it needs is wired in the editor; it does not
## reach up the tree. It owns no rewards, results or scene changes: it reports
## kills and survival and leaves the rest to whoever runs the quest.

## An enemy it spawned died.
signal enemy_killed(enemy: Enemy)
## The quest's elite has arrived.
signal elite_spawned(elite: Enemy)
## The run's clock crossed into a new whole second; `elapsed` is the run's time
## so far, in seconds. Also sent with 0 when the run starts.
signal second_passed(elapsed: float)
## The run's full duration passed with the hero alive. Spawning has stopped.
signal survived

## How far from the hero enemies appear: past the screen's half-width of 320.
const SPAWN_DISTANCE: float = 360.0

@export var quest: QuestData
@export var enemy_scene: PackedScene
## Whom the enemies chase, and around whom they appear.
@export var hero: Hero
## Enemies appear inside its playable_rect.
@export var arena: ArenaMap
## What spawned enemies are added to. Make it the y-sorted level node so they
## pass in front of and behind the hero and the trees.
@export var enemy_parent: Node2D

## Seconds of this run so far, up to the quest's duration.
var elapsed: float = 0.0
## Where on the ramp the run began, from the hero's level.
var ramp_start: float = 0.0
## Enemies it spawned that are still alive, elite included.
var enemies: Array[Enemy] = []

var _running: bool = false
var _spawn_cooldown: float = 0.0
var _elite_spawned: bool = false
var _last_second: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


## Begin a run for a hero of `level`, starting the clock from zero.
func start(hero_level: int) -> void:
	if quest == null or enemy_scene == null or quest.spawn_entries.is_empty():
		push_error("RunDirector: quest (with spawn entries) and enemy_scene must be set.")
		return
	if hero == null or arena == null or enemy_parent == null:
		push_error("RunDirector: hero, arena and enemy_parent must be set.")
		return
	_rng.randomize()
	elapsed = 0.0
	_last_second = 0
	ramp_start = quest.start_for(hero_level)
	_spawn_cooldown = 0.0
	enemies.clear()
	_elite_spawned = false
	_running = true
	second_passed.emit(0.0)


## Stop spawning and counting, as when the hero dies. Enemies already out stay.
func stop() -> void:
	_running = false


func is_running() -> bool:
	return _running


## Where on the ramp the run is now, in seconds.
func ramp_time() -> float:
	return ramp_start + elapsed


func time_left() -> float:
	return maxf(quest.duration - elapsed, 0.0) if quest != null else 0.0


func _process(delta: float) -> void:
	if not _running:
		return

	elapsed = minf(elapsed + delta, quest.duration)
	if floori(elapsed) > _last_second:
		_last_second = floori(elapsed)
		second_passed.emit(elapsed)
	var progress: float = quest.progress_at(ramp_time())
	_spawn_cooldown = maxf(_spawn_cooldown - delta, 0.0)
	if is_zero_approx(_spawn_cooldown) and _regular_alive() < quest.max_alive_at(progress):
		var data: EnemyData = quest.roll_enemy(progress, _rng)
		if data != null:
			_spawn(data, quest.health_scale_at(progress), quest.damage_scale_at(progress))
		_spawn_cooldown = quest.spawn_interval_at(progress)

	if not _elite_spawned and quest.elite != null and elapsed >= quest.elite_spawn_time:
		_elite_spawned = true
		var elite: Enemy = _spawn(quest.elite, quest.elite_health_scale, quest.elite_damage_scale)
		if elite != null:
			elite_spawned.emit(elite)

	if elapsed >= quest.duration:
		_running = false
		survived.emit()


## Enemies out that count against the quest's cap: the elite does not.
func _regular_alive() -> int:
	var count: int = 0
	for enemy: Enemy in enemies:
		if not enemy.data.is_elite:
			count += 1
	return count


## Bring one enemy in from a random direction, inside the arena's walls.
func _spawn(data: EnemyData, health_scale: float, damage_scale: float) -> Enemy:
	var node: Node = enemy_scene.instantiate()
	if node is not Enemy:
		push_error("RunDirector: enemy_scene must have an Enemy root.")
		node.free()
		return null

	var enemy: Enemy = node
	enemy.data = data
	enemy.target = hero
	enemy.health_scale = health_scale
	enemy.damage_scale = damage_scale
	var playable: Rect2 = arena.playable_rect
	playable.position += arena.global_position
	var angle: float = _rng.randf() * TAU
	var spot: Vector2 = hero.global_position + Vector2.from_angle(angle) * SPAWN_DISTANCE
	enemy.position = enemy_parent.to_local(spot.clamp(playable.position, playable.end))
	enemy.died.connect(_on_enemy_died)
	enemies.append(enemy)
	enemy_parent.add_child(enemy)
	return enemy


func _on_enemy_died(enemy: Enemy) -> void:
	enemies.erase(enemy)
	enemy_killed.emit(enemy)

