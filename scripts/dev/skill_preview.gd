class_name SkillPreview
extends Node2D
## A sandbox for trying every skill: the meadow, a hero, and a few training
## dummies that stand still and take hits without dying.
##
## Click a skill in the list to cast it. Q and E step to the previous or next
## skill and cast it, Space casts the selected one again, R puts the hero and
## the dummies back and clears what is left on the ground, and T cycles the
## game speed so an animation can be watched slowly. Casts ignore cooldowns,
## and the hero is carrying no skills of their own, so nothing fires by itself.
##
## Aimed skills (projectiles and Meteor) switch the dummies to a far line so the
## shot has somewhere to fly; every other skill switches them to a close cluster
## inside its reach. The Targets box overrides either. Dummies can be made to
## chase the hero, which does them no harm, to try a slow or a strike on a
## moving target. Walk with the usual keys to try a skill facing left.
##
## Run this scene on its own with F6. Not shipped game code.

enum Layout { NEAR, FAR }

const WEAPON: StringName = &"sword"
## So a dummy outlasts anything the skills throw at it.
const DUMMY_HEALTH_SCALE: float = 1000.0
const SPEEDS: Array[float] = [1.0, 0.5, 0.25]
## Where the dummies stand, from the hero: close enough for a radius skill to
## reach, and far enough for a shot or a falling rock to be seen.
const NEAR_SPOTS: Array[Vector2] = [
	Vector2(30.0, 0.0), Vector2(-34.0, 10.0), Vector2(56.0, -26.0),
	Vector2(-60.0, -22.0), Vector2(26.0, 34.0),
]
const FAR_SPOTS: Array[Vector2] = [
	Vector2(110.0, 0.0), Vector2(155.0, 2.0), Vector2(135.0, -30.0), Vector2(-130.0, 8.0),
]
## Physics frames a new dummy needs before a skill's scan can find it.
const SETTLE_FRAMES: int = 2

@export var enemy_scene: PackedScene
@export var enemy_data: EnemyData

var _skills: Array[SkillData] = []
var _selected: int = -1
var _layout: Layout = Layout.NEAR
var _speed_index: int = 0
var _dummies: Array[Enemy] = []
var _start: Vector2 = Vector2.ZERO

@onready var _arena: ArenaMap = $Meadow
@onready var _hero: Hero = $Hero
@onready var _camera: Camera2D = $Hero/Camera
## Kept above the y-sorted hero and dummies, as the arena does.
@onready var _projectiles: Node2D = $Projectiles
@onready var _list: ItemList = %SkillList
@onready var _info: Label = %Info
@onready var _layout_button: OptionButton = %LayoutButton
@onready var _chase_check: CheckBox = %ChaseCheck
@onready var _speed_button: Button = %SpeedButton
@onready var _reset_button: Button = %ResetButton


func _ready() -> void:
	if enemy_scene == null or enemy_data == null:
		push_error("SkillPreview: enemy_scene and enemy_data must be wired.")
		return
	_hero.wield(WeaponItem.create(WEAPON))
	_start = _arena.position + _arena.playable_rect.get_center()
	_hero.position = _start
	var limits: Rect2i = Rect2i(_arena.map_rect)
	limits.position += Vector2i(_arena.position)
	_camera.limit_left = limits.position.x
	_camera.limit_top = limits.position.y
	_camera.limit_right = limits.end.x
	_camera.limit_bottom = limits.end.y

	_hero.projectile_released.connect(_on_hero_projectile_released)
	_hero.effect_spawned.connect(_on_hero_effect_spawned)
	_hero.skills.set_auto_cast(false)

	_skills = SkillData.all_skills()
	for skill: SkillData in _skills:
		var index: int = _list.add_item(skill.display_name, skill.icon)
		_list.set_item_tooltip(index, "%s: %s" % [skill.class_id, skill.description])
	_layout_button.add_item("Near", Layout.NEAR)
	_layout_button.add_item("Far", Layout.FAR)
	_list.item_clicked.connect(_on_skill_clicked)
	_layout_button.item_selected.connect(_on_layout_selected)
	_chase_check.toggled.connect(_on_chase_toggled)
	_speed_button.pressed.connect(_cycle_speed)
	_reset_button.pressed.connect(_reset)
	_show_speed()
	_spawn_dummies()


func _exit_tree() -> void:
	# A slowed game left on would carry into whatever scene runs next.
	Engine.time_scale = 1.0


func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventKey:
		return
	var key: InputEventKey = event
	if not key.pressed or key.echo or _skills.is_empty():
		return
	match key.physical_keycode:
		KEY_SPACE:
			_cast(maxi(_selected, 0))
		KEY_E:
			_cast(wrapi(_selected + 1, 0, _skills.size()))
		KEY_Q:
			_cast(wrapi(_selected - 1, 0, _skills.size()))
		KEY_R:
			_reset()
		KEY_T:
			_cycle_speed()
		_:
			return
	get_viewport().set_input_as_handled()


## Select and cast the skill at `index`, moving the dummies first if it wants
## them somewhere else.
func _cast(index: int) -> void:
	if index < 0 or index >= _skills.size():
		return
	_selected = index
	_list.select(index)
	var skill: SkillData = _skills[index]
	_info.text = "%s (%s)" % [skill.display_name, SkillData.Kind.keys()[skill.kind]]

	var aimed: bool = skill.kind in [SkillData.Kind.PROJECTILE, SkillData.Kind.DELAYED_AREA]
	var wanted: Layout = Layout.FAR if aimed else Layout.NEAR
	if wanted != _layout:
		_set_layout(wanted)
		for i: int in SETTLE_FRAMES:
			await get_tree().physics_frame
		if not is_instance_valid(self):
			return
	_hero.skills.cast_now(HeldSkill.new(skill))


func _set_layout(layout: Layout) -> void:
	_layout = layout
	_layout_button.select(_layout_button.get_item_index(layout))
	_spawn_dummies()


## Stand the dummies in the current layout around where the hero is.
func _spawn_dummies() -> void:
	for dummy: Enemy in _dummies:
		if is_instance_valid(dummy):
			dummy.queue_free()
	_dummies.clear()
	var spots: Array[Vector2] = NEAR_SPOTS if _layout == Layout.NEAR else FAR_SPOTS
	for spot: Vector2 in spots:
		var node: Node = enemy_scene.instantiate()
		if node is not Enemy:
			push_error("SkillPreview: enemy_scene must have an Enemy root.")
			node.free()
			return
		var dummy: Enemy = node
		dummy.data = enemy_data
		dummy.health_scale = DUMMY_HEALTH_SCALE
		dummy.damage_scale = 0.0
		dummy.target = _hero if _chase_check.button_pressed else null
		dummy.position = _hero.position + spot
		add_child(dummy)
		_dummies.append(dummy)


func _reset() -> void:
	for effect: Node in _projectiles.get_children():
		effect.queue_free()
	# What follows the hero is a child of their skill caster.
	for effect: Node in _hero.skills.get_children():
		if effect is OneShotEffect:
			effect.queue_free()
	_hero.buffs.clear()
	_hero.teleport_to(_start)
	_spawn_dummies()


func _cycle_speed() -> void:
	_speed_index = (_speed_index + 1) % SPEEDS.size()
	_show_speed()


func _show_speed() -> void:
	Engine.time_scale = SPEEDS[_speed_index]
	_speed_button.text = "Speed %sx" % SPEEDS[_speed_index]


func _on_skill_clicked(index: int, _at: Vector2, mouse_button: int) -> void:
	if mouse_button == MOUSE_BUTTON_LEFT:
		_cast(index)


func _on_layout_selected(item: int) -> void:
	_set_layout(_layout_button.get_item_id(item) as Layout)


func _on_chase_toggled(enabled: bool) -> void:
	for dummy: Enemy in _dummies:
		if is_instance_valid(dummy):
			dummy.target = _hero if enabled else null


func _on_hero_projectile_released(projectile: Projectile) -> void:
	_projectiles.add_child(projectile)


func _on_hero_effect_spawned(effect: Node2D, at: Vector2) -> void:
	_projectiles.add_child(effect)
	effect.global_position = at
