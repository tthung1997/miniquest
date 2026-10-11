class_name Playground
extends Node2D
## Walkable test area for driving the hero around with the keyboard.
##
## The hero walks the meadow arena, which is larger than the 640x360 viewport,
## so the camera follows and its limits are exercised at the tree line. Not
## shipped game code; it exists to check movement, facing, animation switching,
## auto-attack, combat and the run's ramp by hand. The hero attacks on its own,
## a RunDirector sends enemies in from beyond the screen along the quest's ramp,
## and Q cycles the weapon.

## Raised when the player asks to leave, so whatever opened this scene can
## return to the hub. Nothing listens when the scene is run on its own.
signal back_requested

const WEAPON_IDS: Array[StringName] = [&"sword", &"crossbow", &"wand"]

var _hero_name: String = ""
var _kills: int = 0
var _survived: bool = false
var _run_started: bool = false

@onready var hero: Hero = $Hero
@onready var _arena: ArenaMap = $Meadow
@onready var _camera: Camera2D = $Hero/Camera
## Kept above the y-sorted hero and trees, so shots are never hidden.
@onready var _projectiles: Node2D = $Projectiles
@onready var _director: RunDirector = $RunDirector
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
	hero.died.connect(_director.stop)
	_director.enemy_killed.connect(_on_enemy_killed)
	_director.survived.connect(_on_run_survived)
	# A saved hero is shown right after this scene is added, which starts the
	# run at their level; this only covers the scene being run on its own.
	_start_standalone_run.call_deferred()
	_refresh()


## Dress the hero as `data`, name them in the readout, and start the run at
## their level.
func show_hero(data: HeroData) -> void:
	_hero_name = data.hero_name
	hero.apply(data)
	_start_run(data.level)
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


func _start_standalone_run() -> void:
	if not _run_started:
		_start_run(1)


func _start_run(level: int) -> void:
	_run_started = true
	_director.start(level)


func _on_enemy_killed(_enemy: Enemy) -> void:
	_kills += 1


func _on_run_survived() -> void:
	_survived = true


func _on_hero_projectile_released(projectile: Projectile) -> void:
	_projectiles.add_child(projectile)


func _refresh() -> void:
	var status: String = "HP %d/%d" % [ceili(hero.health.current), roundi(hero.health.maximum)]
	if hero.is_dead():
		status = "DEFEATED"
	elif _survived:
		status = "SURVIVED"
	_readout.text = (
		"%s%s    kills %d    %s\n"
		% [
			"" if _hero_name.is_empty() else _hero_name + "    ",
			status,
			_kills,
			hero.weapon.get_display_name() if hero.weapon != null else "no weapon",
		]
		+ "time %s / %s    ramp %s\n"
		% [
			_clock(_director.elapsed),
			_clock(_director.quest.duration),
			_clock(_director.ramp_time()),
		]
		+ "WASD or arrows to move    attacks are automatic    Q weapon    Esc to go back"
	)


## `seconds` as minutes and seconds, such as 4:05.
func _clock(seconds: float) -> String:
	var whole: int = floori(seconds)
	return "%d:%02d" % [floori(whole / 60.0), whole % 60]
