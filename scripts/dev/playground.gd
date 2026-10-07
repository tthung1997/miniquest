class_name Playground
extends Node2D
## Walkable test area for driving the hero around with the keyboard.
##
## The hero walks the meadow arena, which is larger than the 640x360 viewport,
## so the camera follows and its limits are exercised at the tree line. Not
## shipped game code; it exists to check movement, facing, animation switching
## and attack animations by hand. Space attacks, repeating at the weapon's
## attack_interval while held, and Q cycles the weapon.

## Raised when the player asks to leave, so whatever opened this scene can
## return to the hub. Nothing listens when the scene is run on its own.
signal back_requested

const WEAPON_IDS: Array[StringName] = [&"sword", &"crossbow", &"wand"]

var _hero_name: String = ""
var _attack_held: bool = false
var _attack_cooldown: float = 0.0

@onready var hero: Hero = $Hero
@onready var _arena: ArenaMap = $Meadow
@onready var _camera: Camera2D = $Hero/Camera
## Kept above the y-sorted hero and trees, so shots are never hidden.
@onready var _projectiles: Node2D = $Projectiles
@onready var _readout: Label = $HUD/Root/Readout


func _ready() -> void:
	hero.position = _arena.position + _arena.playable_rect.get_center()
	var limits: Rect2i = Rect2i(_arena.map_rect)
	limits.position += Vector2i(_arena.position)
	_camera.limit_left = limits.position.x
	_camera.limit_top = limits.position.y
	_camera.limit_right = limits.end.x
	_camera.limit_bottom = limits.end.y
	hero.facing_changed.connect(_on_hero_facing_changed)
	hero.projectile_released.connect(_on_hero_projectile_released)
	_refresh()


## Dress the hero as `data` and name them in the readout.
func show_hero(data: HeroData) -> void:
	_hero_name = data.hero_name
	hero.apply(data)
	_refresh()


func _process(delta: float) -> void:
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	if _attack_held and is_zero_approx(_attack_cooldown):
		_attack()
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		back_requested.emit()
		return

	if event is not InputEventKey or event.is_echo():
		return
	var key: InputEventKey = event as InputEventKey
	match key.physical_keycode:
		KEY_SPACE:
			_attack_held = key.pressed
		KEY_Q:
			if key.pressed:
				_cycle_weapon()
		_:
			return
	get_viewport().set_input_as_handled()


func _attack() -> void:
	if not hero.attack():
		return
	var data: WeaponData = hero.weapon.data()
	_attack_cooldown = data.attack_interval if data != null else 0.0


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
	_attack_cooldown = 0.0
	_refresh()


func _on_hero_facing_changed(_facing_right: bool) -> void:
	_refresh()


func _on_hero_projectile_released(projectile: Projectile) -> void:
	_projectiles.add_child(projectile)


func _refresh() -> void:
	_readout.text = (
		"%spos %d, %d    speed %d    facing %s    %s\n"
		% [
			"" if _hero_name.is_empty() else _hero_name + "    ",
			roundi(hero.position.x),
			roundi(hero.position.y),
			roundi(hero.velocity.length()),
			"right" if hero.is_facing_right() else "left",
			hero.weapon.get_display_name() if hero.weapon != null else "no weapon",
		]
		+ "WASD or arrows to move    Space attack    Q weapon    Esc to go back"
	)
