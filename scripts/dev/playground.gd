class_name Playground
extends Node2D
## Walkable test area for driving the hero around with the keyboard.
##
## The room is deliberately larger than the 640x360 viewport so the camera has
## something to follow and its limits are actually exercised. Not shipped game
## code; it exists to check movement, facing, animation switching and attack
## animations by hand. Space attacks, repeating at the weapon's
## attack_interval while held, and Q cycles the weapon.

## Raised when the player asks to leave, so whatever opened this scene can
## return to the hub. Nothing listens when the scene is run on its own.
signal back_requested

const ROOM: Rect2i = Rect2i(0, 0, 1120, 630)
const WALL: int = 16
const FLOOR_COLOR: Color = Color(0.16, 0.18, 0.22)
const WALL_COLOR: Color = Color(0.28, 0.31, 0.38)
const GRID_COLOR: Color = Color(1.0, 1.0, 1.0, 0.05)
const GRID_STEP: int = 64
const WEAPON_IDS: Array[StringName] = [&"sword", &"crossbow", &"wand"]

var _hero_name: String = ""
var _attack_held: bool = false
var _attack_cooldown: float = 0.0

@onready var hero: Hero = $Hero
@onready var _readout: Label = $HUD/Root/Readout


func _ready() -> void:
	_build_walls()
	hero.position = Vector2(ROOM.size) * 0.5
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


func _draw() -> void:
	draw_rect(Rect2(ROOM), FLOOR_COLOR, true)

	for x in range(GRID_STEP, ROOM.size.x, GRID_STEP):
		draw_line(Vector2(x, 0), Vector2(x, ROOM.size.y), GRID_COLOR, 1.0)
	for y in range(GRID_STEP, ROOM.size.y, GRID_STEP):
		draw_line(Vector2(0, y), Vector2(ROOM.size.x, y), GRID_COLOR, 1.0)

	var w: float = float(WALL)
	var sx: float = float(ROOM.size.x)
	var sy: float = float(ROOM.size.y)
	draw_rect(Rect2(0.0, 0.0, sx, w), WALL_COLOR, true)
	draw_rect(Rect2(0.0, sy - w, sx, w), WALL_COLOR, true)
	draw_rect(Rect2(0.0, 0.0, w, sy), WALL_COLOR, true)
	draw_rect(Rect2(sx - w, 0.0, w, sy), WALL_COLOR, true)


func _build_walls() -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.name = &"Walls"
	add_child(body)

	var w: float = float(WALL)
	var sx: float = float(ROOM.size.x)
	var sy: float = float(ROOM.size.y)
	var spans: Array[Rect2] = [
		Rect2(0.0, 0.0, sx, w),
		Rect2(0.0, sy - w, sx, w),
		Rect2(0.0, 0.0, w, sy),
		Rect2(sx - w, 0.0, w, sy),
	]

	for span: Rect2 in spans:
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = span.size
		var collider: CollisionShape2D = CollisionShape2D.new()
		collider.shape = shape
		collider.position = span.position + span.size * 0.5
		body.add_child(collider)


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
	add_child(projectile)


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
