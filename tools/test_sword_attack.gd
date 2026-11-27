## Run from the repo root:
##   godot --headless --path . --fixed-fps 60 --script res://tools/test_sword_attack.gd
extends SceneTree

const PANDA: EnemyData = preload("res://resources/enemies/panda.tres")
const BEAR: EnemyData = preload("res://resources/enemies/bear.tres")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/enemy.tscn")
const HERO_SCENE: PackedScene = preload("res://scenes/hero.tscn")

var _failures: int = 0
var _arena: Node2D


func _initialize() -> void:
	await process_frame
	await _check_sword_retreat()
	await _check_forward_lunge()
	await _check_lunge_can_be_cancelled()
	quit(0 if _failures == 0 else 1)


func _check_sword_retreat() -> void:
	var hero: Hero = _spawn_hero()
	var doll: PaperDoll = hero.get_node("PaperDoll")
	doll.attack_released.connect(_check_slash_effects.bind(doll))
	hero.facing_changed.connect(_check_retreat_facing)

	var reach: float = hero.weapon.data().attack_range
	var rear: Enemy = _spawn_enemy(Vector2(-32.0, 0.0))
	var front: Enemy = _spawn_enemy(Vector2(23.0, 36.0))
	var elite: Enemy = _spawn_enemy(Vector2(0.0, -36.0), BEAR)
	var outside: Enemy = _spawn_enemy(Vector2(0.0, reach + 2.0))
	Input.action_press(&"move_right")
	for _tick: int in range(ceili(Engine.physics_ticks_per_second * 0.5)):
		await physics_frame
		if front.health.current < front.health.maximum:
			break
	Input.action_release(&"move_right")
	for _tick: int in range(ceili(Engine.physics_ticks_per_second * 0.15)):
		await physics_frame

	var damage: float = hero.weapon.base_damage()
	_expect(is_equal_approx(front.health.current, front.health.maximum - damage),
		"The sword must hit the enemy ahead once.")
	_expect(is_equal_approx(rear.health.current, rear.health.maximum - damage),
		"The same swing must hit the enemy behind once.")
	_expect(outside.health.current == outside.health.maximum,
		"The sword must not hit beyond its range.")
	_expect(rear.position.x < -39.0 and front.position.y > 43.0,
		"The swing must push both regular enemies away from the hero.")
	_expect(elite.health.current < elite.health.maximum
		and elite.position.y < -38.0 and elite.position.y > -41.0,
		"The elite must take damage but recoil less than regular enemies.")
	_expect(hero.global_position.x > 0.0 and hero.is_facing_right(),
		"The hero must keep retreating without turning.")
	_arena.free()


func _check_forward_lunge() -> void:
	var hero: Hero = _spawn_hero()
	var reach: float = hero.weapon.data().attack_range
	var pursuer: Enemy = _spawn_enemy(Vector2(-40.0, 0.0))
	var ahead: Enemy = _spawn_enemy(Vector2(reach + 38.0, 0.0))
	_spawn_enemy(Vector2(reach + 29.0, 42.0))
	_spawn_enemy(Vector2(0.0, reach + 3.0))

	Input.action_press(&"move_right")
	var dashed: bool = false
	for _tick: int in range(ceili(Engine.physics_ticks_per_second * 0.5)):
		await physics_frame
		dashed = dashed or hero.velocity.x > hero.speed
		if ahead.health.current < ahead.health.maximum:
			break
	Input.action_release(&"move_right")

	_expect(dashed and is_zero_approx(hero.position.y),
		"The sword must lunge toward the nearest enemy ahead, not a closer enemy to the side.")
	_expect(ahead.health.current < ahead.health.maximum,
		"The lunge must close enough distance for the swing to hit.")
	_expect(is_equal_approx(pursuer.health.current, pursuer.health.maximum),
		"The lunge must take priority over an ordinary swing at the nearby pursuer.")
	_arena.free()


func _check_lunge_can_be_cancelled() -> void:
	var hero: Hero = _spawn_hero()
	var ahead: Enemy = _spawn_enemy(Vector2(101.0, 0.0))
	Input.action_press(&"move_right")
	var trigger_distance: float = 0.0
	for _tick: int in range(ceili(Engine.physics_ticks_per_second * 0.2)):
		var previous_distance: float = hero.position.distance_to(ahead.position)
		await physics_frame
		if hero.velocity.x > hero.speed:
			trigger_distance = previous_distance
			break
	var walk_step: float = hero.speed / Engine.physics_ticks_per_second
	_expect(trigger_distance <= 96.0 and trigger_distance >= 96.0 - walk_step,
		"The starter Sword must begin lunging as soon as the target enters its 96 px reach.")
	var turn_at: float = hero.position.x
	Input.action_release(&"move_right")
	Input.action_press(&"move_left")
	await physics_frame
	_expect(hero.position.x < turn_at, "Reversing input must immediately cancel the lunge.")
	for _tick: int in range(ceili(Engine.physics_ticks_per_second * 0.2)):
		await physics_frame
	Input.action_release(&"move_left")
	_expect(ahead.health.current == ahead.health.maximum,
		"A cancelled lunge must not release a delayed swing.")
	_arena.free()


func _check_retreat_facing(facing_right: bool) -> void:
	_expect(facing_right, "The sword must not turn the hero toward the nearest enemy behind them.")


func _check_slash_effects(doll: PaperDoll) -> void:
	var left: bool = false
	var right: bool = false
	for child: Node in doll.get_children():
		if child is OneShotEffect:
			left = left or (child.position.x < 0.0 and child.scale.x < 0.0)
			right = right or (child.position.x > 0.0 and child.scale.x > 0.0)
	_expect(left and right, "A sword swing must show a slash on both sides.")


func _spawn_hero() -> Hero:
	_arena = Node2D.new()
	root.add_child(_arena)
	var hero: Hero = HERO_SCENE.instantiate()
	hero.weapon = WeaponItem.create(&"sword")
	hero.acceleration = 0.0
	_arena.add_child(hero)
	return hero


func _spawn_enemy(at: Vector2, data: EnemyData = PANDA) -> Enemy:
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	enemy.data = data
	enemy.position = at
	_arena.add_child(enemy)
	return enemy


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
