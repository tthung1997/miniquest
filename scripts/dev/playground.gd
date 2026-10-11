class_name Playground
extends Node2D
## Walkable test area for driving the hero around with the keyboard.
##
## The hero walks the meadow arena, which is larger than the 640x360 viewport,
## so the camera follows and its limits are exercised at the tree line. Not
## shipped game code; it exists to check movement, facing, animation switching,
## auto-attack and combat by hand. The hero attacks on its own, enemies keep
## arriving from beyond the screen, and Q cycles the weapon.

## Raised when the player asks to leave, so whatever opened this scene can
## return to the hub. Nothing listens when the scene is run on its own.
signal back_requested

const WEAPON_IDS: Array[StringName] = [&"sword", &"crossbow", &"wand"]
## How far from the hero enemies appear: past the screen's half-width of 320.
const SPAWN_DISTANCE: float = 360.0
const MAX_ENEMIES: int = 12

@export var enemy_scene: PackedScene
@export var enemy_data: EnemyData

var _hero_name: String = ""
var _enemy_count: int = 0
var _kills: int = 0

@onready var hero: Hero = $Hero
@onready var _arena: ArenaMap = $Meadow
@onready var _camera: Camera2D = $Hero/Camera
## Kept above the y-sorted hero and trees, so shots are never hidden.
@onready var _projectiles: Node2D = $Projectiles
@onready var _spawn_timer: Timer = $SpawnTimer
@onready var _readout: Label = $HUD/Root/Readout


func _ready() -> void:
	# Run on its own there is no saved hero to dress from, so start armed.
	if hero.weapon == null:
		hero.wield(WeaponItem.create(WEAPON_IDS[0]))
	hero.position = _arena.position + _arena.playable_rect.get_center()
	var limits: Rect2i = Rect2i(_arena.map_rect)
	limits.position += Vector2i(_arena.position)
	_camera.limit_left = limits.position.x
	_camera.limit_top = limits.position.y
	_camera.limit_right = limits.end.x
	_camera.limit_bottom = limits.end.y
	hero.projectile_released.connect(_on_hero_projectile_released)
	hero.died.connect(_on_hero_died)
	_spawn_timer.timeout.connect(_spawn_enemy)
	_refresh()


## Dress the hero as `data` and name them in the readout.
func show_hero(data: HeroData) -> void:
	_hero_name = data.hero_name
	hero.apply(data)
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		back_requested.emit()
		return

	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var key: InputEventKey = event
		if key.physical_keycode == KEY_Q:
			get_viewport().set_input_as_handled()
			_cycle_weapon()


## Step to the next weapon in WEAPON_IDS, starting from the sword when the
## hero holds nothing or something not in the list.
func _cycle_weapon() -> void:
	var index: int = -1
	if hero.weapon != null:
		index = WEAPON_IDS.find(hero.weapon.weapon_id)
	var item: WeaponItem = WeaponItem.create(WEAPON_IDS[(index + 1) % WEAPON_IDS.size()])
	if item == null:
		return
	hero.wield(item)
	_refresh()


## Bring one enemy in from a random direction, just beyond the screen and
## inside the arena's walls.
func _spawn_enemy() -> void:
	if _enemy_count >= MAX_ENEMIES or enemy_scene == null or enemy_data == null:
		return
	var node: Node = enemy_scene.instantiate()
	if node is not Enemy:
		push_error("Playground: enemy_scene must have an Enemy root.")
		node.free()
		return

	var enemy: Enemy = node
	enemy.data = enemy_data
	enemy.target = hero
	var playable: Rect2 = _arena.playable_rect
	playable.position += _arena.position
	var spot: Vector2 = hero.position + Vector2.from_angle(randf() * TAU) * SPAWN_DISTANCE
	enemy.position = spot.clamp(playable.position, playable.end)
	enemy.died.connect(_on_enemy_died)
	_enemy_count += 1
	add_child(enemy)


func _on_enemy_died(_enemy: Enemy) -> void:
	_enemy_count -= 1
	_kills += 1


func _on_hero_died() -> void:
	_spawn_timer.stop()


func _on_hero_projectile_released(projectile: Projectile) -> void:
	_projectiles.add_child(projectile)


func _refresh() -> void:
	var status: String = "DEFEATED" if hero.is_dead() else "HP %d/%d" % [
		ceili(hero.health.current), roundi(hero.health.maximum)
	]
	_readout.text = (
		"%s%s    kills %d    %s\n"
		% [
			"" if _hero_name.is_empty() else _hero_name + "    ",
			status,
			_kills,
			hero.weapon.get_display_name() if hero.weapon != null else "no weapon",
		]
		+ "WASD or arrows to move    attacks are automatic    Q weapon    Esc to go back"
	)
