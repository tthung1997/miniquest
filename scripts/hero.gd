class_name Hero
extends CharacterBody2D
## Player-controlled hero with free eight-way movement.
##
## The art is drawn in side view facing right, so horizontal facing is shown by
## flipping the sprite and vertical movement reuses the same walk clip. Facing
## is only updated when there is horizontal input, so walking straight up or
## down keeps whichever way the hero last faced rather than snapping to a
## default. Drawing is the PaperDoll's job; this node only moves it.

signal facing_changed(facing_right: bool)
## An attack let go of `projectile`, already launched but not yet in the tree.
## The listener adds it to the world: the hero does not reach up into the
## level it stands in.
signal projectile_released(projectile: Projectile)

@export_group("Movement")
@export_range(10.0, 400.0, 5.0) var speed: float = 70.0
## How sharply the hero reaches full speed. Higher is snappier; 0 disables
## smoothing and applies input velocity directly.
@export_range(0.0, 40.0, 0.5) var acceleration: float = 14.0
@export_range(0.0, 40.0, 0.5) var friction: float = 18.0
## Vertical travel as a fraction of horizontal, so diagonal movement reads with
## the shallow perspective these side-view sprites imply. 1.0 is uniform.
@export_range(0.3, 1.0, 0.05) var vertical_ratio: float = 0.6

@export_group("Appearance")
## What the hero wears and holds until apply() dresses it from a saved hero.
@export var armour: ArmourItem
@export var weapon: WeaponItem

@onready var _doll: PaperDoll = $PaperDoll


func _ready() -> void:
	_doll.wear_armour(armour)
	_doll.wield(weapon)
	_doll.attack_released.connect(_on_doll_attack_released)


## Dress this hero as `data`.
func apply(data: HeroData) -> void:
	armour = data.armour
	weapon = data.weapon
	_doll.wear_armour(armour)
	_doll.wield(weapon)


## Hold `item`, or nothing when null.
func wield(item: WeaponItem) -> void:
	weapon = item
	_doll.wield(weapon)


## Play the held weapon's attack once and release its projectile, if any.
## Does not check attack_interval; pacing attacks is the caller's job.
## Returns false when there is nothing to attack with.
func attack() -> bool:
	return _doll.attack()


func _physics_process(delta: float) -> void:
	var input: Vector2 = Input.get_vector(
		&"move_left", &"move_right", &"move_up", &"move_down"
	)
	input.y *= vertical_ratio

	var target: Vector2 = input * speed
	if acceleration <= 0.0:
		velocity = target
	elif target.is_zero_approx():
		velocity = velocity.lerp(Vector2.ZERO, minf(friction * delta, 1.0))
	else:
		velocity = velocity.lerp(target, minf(acceleration * delta, 1.0))

	move_and_slide()
	_update_facing(input.x)
	_update_animation()


## Face the hero along `direction_x`, ignoring zero so vertical-only movement
## preserves the current facing.
func _update_facing(direction_x: float) -> void:
	if is_zero_approx(direction_x):
		return

	var should_face_right: bool = direction_x > 0.0
	if should_face_right == _doll.is_facing_right():
		return

	_doll.set_facing_right(should_face_right)
	facing_changed.emit(should_face_right)


func _update_animation() -> void:
	var moving: bool = velocity.length() > 1.0
	_doll.play(PaperDoll.WALK_CLIP if moving else PaperDoll.IDLE_CLIP)


func is_facing_right() -> bool:
	return _doll.is_facing_right()


func _on_doll_attack_released() -> void:
	var data: WeaponData = weapon.data() if weapon != null else null
	if data == null or data.projectile == null:
		return
	# Nobody to put it in the world, as in a menu: an unparented node would leak.
	if projectile_released.get_connections().is_empty():
		return

	var node: Node = data.projectile.instantiate()
	if node is not Projectile:
		push_error("Hero: projectile of weapon '%s' is not a Projectile." % data.id)
		node.free()
		return
	var projectile: Projectile = node
	var direction: Vector2 = Vector2.RIGHT if _doll.is_facing_right() else Vector2.LEFT
	projectile.launch(
		_doll.to_global(_doll.get_release_position()), direction, data.attack_range, velocity
	)
	projectile_released.emit(projectile)