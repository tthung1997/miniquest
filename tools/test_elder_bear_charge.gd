## Run from the repo root:
##   godot --headless --path . --fixed-fps 60 --script res://tools/test_elder_bear_charge.gd
extends SceneTree

const QUEST: QuestData = preload("res://resources/quests/meadow_run.tres")
const PANDA: EnemyData = preload("res://resources/enemies/panda.tres")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/enemy.tscn")
const HERO_SCENE: PackedScene = preload("res://scenes/hero.tscn")

var _failures: int = 0


func _initialize() -> void:
	await process_frame
	await _check_straight_retreat()
	await _check_sidestep()
	quit(0 if _failures == 0 else 1)


func _check_straight_retreat() -> void:
	var hero: Hero = HERO_SCENE.instantiate()
	hero.speed = 95.0
	root.add_child(hero)
	var bear: Enemy = _spawn(QUEST.elite, hero, -RunDirector.SPAWN_DISTANCE)
	var panda: Enemy = _spawn(PANDA, hero, -RunDirector.SPAWN_DISTANCE)
	Input.action_press(&"move_right")
	var panda_charged: bool = false
	# Leave the route wide open so no wall can do the catching for the bear.
	for _tick: int in range(20 * Engine.physics_ticks_per_second):
		await physics_frame
		panda_charged = panda_charged or panda.velocity.x > PANDA.speed
		if hero.health.current < hero.health.maximum:
			break
	_expect(hero.health.current < hero.health.maximum, "The bear must catch a fleeing hero.")
	_expect(not panda_charged, "A regular enemy must not gain a charge.")
	Input.action_release(&"move_right")
	bear.queue_free()
	panda.queue_free()
	hero.queue_free()
	await process_frame


func _check_sidestep() -> void:
	var hero: Hero = HERO_SCENE.instantiate()
	hero.position.x = 250.0
	root.add_child(hero)
	var bear: Enemy = _spawn(QUEST.elite, hero, 0.0)
	var sprite: AnimatedSprite2D = bear.get_node("Sprite")
	var warned: bool = false
	var charged: bool = false
	for _tick: int in range(4 * Engine.physics_ticks_per_second):
		await physics_frame
		if not sprite.is_playing() and sprite.self_modulate != Color.WHITE:
			warned = true
			_expect(bear.velocity.is_zero_approx(), "The bear must stop during its windup.")
		elif bear.velocity.x > bear.data.speed:
			charged = true
			break
	_expect(warned and charged, "The bear must show a windup before charging.")
	if charged:
		var launch_y: float = bear.global_position.y
		var held_direction: bool = true
		var finished: bool = false
		Input.action_press(&"move_down")
		for _tick: int in range(Engine.physics_ticks_per_second):
			await physics_frame
			if bear.velocity.length() <= bear.data.speed:
				finished = true
				break
			held_direction = held_direction and is_equal_approx(bear.global_position.y, launch_y)
		Input.action_release(&"move_down")
		_expect(finished, "The bear must return to normal pursuit after the charge.")
		_expect(held_direction, "The charge must not track the hero's sidestep.")
		_expect(hero.health.current == hero.health.maximum, "A sidestep must avoid the charge.")
	bear.queue_free()
	hero.queue_free()


func _spawn(data: EnemyData, hero: Hero, at_x: float) -> Enemy:
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	enemy.data = data
	enemy.target = hero
	enemy.position.x = at_x
	root.add_child(enemy)
	return enemy


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
