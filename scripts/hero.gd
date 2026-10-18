class_name Hero
extends CharacterBody2D
## Player-controlled hero with free eight-way movement and an automatic attack.
##
## The art is drawn in side view facing right, so horizontal facing is shown by
## flipping the sprite and vertical movement reuses the same walk clip. Facing
## is only updated when there is horizontal input, so walking straight up or
## down keeps whichever way the hero last faced rather than snapping to a
## default. Drawing is the PaperDoll's job; this node only moves it.
##
## There is no attack button. Whenever the held weapon's interval is up and an
## enemy stands within its range, the hero turns to the nearest one and
## attacks. A melee weapon then hurts every enemy ahead of the hero within
## range; a ranged one releases a projectile aimed at the target.

signal facing_changed(facing_right: bool)
## An attack let go of `projectile`, already launched but not yet in the tree.
## The listener adds it to the world: the hero does not reach up into the
## level it stands in.
signal projectile_released(projectile: Projectile)
## A skill made something for the world, such as a ground marker or a trap, to
## be added at `at` in global space. The listener adds it, like a projectile.
signal effect_spawned(effect: Node2D, at: Vector2)
## The hero's pickup radius reached `pickup`. The listener decides what that
## means and calls its collect().
signal pickup_reached(pickup: Pickup)
## The hero's health reached zero. What that means for the run is up to whoever
## owns the hero.
signal died

## Health of a hero that has not been dressed from a saved HeroData, such as one
## placed in a scene run on its own.
const DEFAULT_MAX_HEALTH: float = 50.0
## How far behind the hero a melee swing still reaches, so an enemy standing on
## top of the hero is hit whichever side of their centre it is on.
const MELEE_REACH_BEHIND: float = 12.0

@export_group("Movement")
## Base speed, before any boots. A hero dressed by apply() moves at this times
## HeroData.move_speed_multiplier().
@export_range(10.0, 400.0, 5.0) var speed: float = 70.0
## How sharply the hero reaches full speed. Higher is snappier; 0 disables
## smoothing and applies input velocity directly.
@export_range(0.0, 40.0, 0.5) var acceleration: float = 14.0
@export_range(0.0, 40.0, 0.5) var friction: float = 18.0
## Vertical travel as a fraction of horizontal, so diagonal movement reads with
## the shallow perspective these side-view sprites imply. 1.0 is uniform.
@export_range(0.3, 1.0, 0.05) var vertical_ratio: float = 0.6

@export_group("Pickup")
## How close a drop must be for the hero to collect it.
@export_range(8.0, 200.0, 1.0, "suffix:px") var pickup_radius: float = 28.0:
	set(value):
		pickup_radius = value
		_pickup_circle.radius = value

@export_group("Appearance")
## What the hero wears and holds until apply() dresses it from a saved hero.
@export var armour: ArmourItem
@export var boots: BootsItem
@export var weapon: WeaponItem

var health: Health = null
## Timed statuses from skills, such as Bulwark.
var buffs: HeroBuffs = HeroBuffs.new()

var _stats: HeroData = null
var _move_multiplier: float = 1.0
## What this run's upgrades have added: fractions of running speed and of damage.
var _run_speed_bonus: float = 0.0
var _run_damage_bonus: float = 0.0
var _attack_cooldown: float = 0.0
var _aim_point: Vector2 = Vector2.INF
var _dead: bool = false
var _pickup_circle: CircleShape2D = CircleShape2D.new()

@onready var skills: SkillCaster = $SkillCaster
@onready var _doll: PaperDoll = $PaperDoll
@onready var _sensor: TargetSensor = $TargetSensor
@onready var _pickup_area: Area2D = $PickupArea
@onready var _pickup_shape: CollisionShape2D = $PickupArea/Shape


func _init() -> void:
	_set_health(DEFAULT_MAX_HEALTH)


func _ready() -> void:
	_doll.wear_armour(armour)
	_doll.wear_boots(boots)
	_doll.wield(weapon)
	_doll.attack_released.connect(_on_doll_attack_released)
	_update_sensor_range()
	_pickup_circle.radius = pickup_radius
	_pickup_shape.shape = _pickup_circle
	_pickup_area.area_entered.connect(_on_pickup_area_entered)
	skills.projectile_released.connect(_on_skill_projectile_released)
	skills.effect_spawned.connect(_on_skill_effect_spawned)


## Dress this hero as `data`, and give them full health for it. Their stats
## are what the held weapon's damage is worked out from, and their boots set
## how fast they run. Whatever a previous run gave them is forgotten.
func apply(data: HeroData) -> void:
	_stats = data
	armour = data.armour
	boots = data.boots
	weapon = data.weapon
	_move_multiplier = data.move_speed_multiplier()
	_run_speed_bonus = 0.0
	_run_damage_bonus = 0.0
	buffs.clear()
	_doll.wear_armour(armour)
	_doll.wear_boots(boots)
	_doll.wield(weapon)
	_update_sensor_range()
	_set_health(data.max_health())
	_pickup_area.set_deferred(&"monitoring", true)


## Lose `amount` of health, less whatever Bulwark takes off. `attacker`, when
## known, is who Riposte throws the blow back at. The died signal follows when
## no health is left.
func take_damage(amount: float, attacker: Enemy = null) -> void:
	if _dead:
		return
	if buffs.is_active(HeroBuffs.RIPOSTE):
		var reflected: float = buffs.consume(HeroBuffs.RIPOSTE)
		if attacker != null and is_instance_valid(attacker):
			attacker.take_damage(reflected * damage_multiplier())
		return
	var reduction: float = buffs.magnitude(HeroBuffs.BULWARK) / 100.0
	health.take_damage(amount * (1.0 - reduction))


## Recover up to `amount` health.
func heal(amount: float) -> void:
	health.heal(amount)


func is_dead() -> bool:
	return _dead


## Whether enemies can hurt the hero: not while Vanish is hiding them.
func is_targetable() -> bool:
	return not buffs.is_active(HeroBuffs.VANISH)


## Stat values skills scale off, keyed like HeroData.STATS. A hero with no saved
## stats, such as one placed in a scene run on its own, has the starting ones.
func skill_stats() -> Dictionary[StringName, int]:
	if _stats != null:
		return _stats.total_stats()
	var values: Dictionary[StringName, int] = {}
	for stat_name: StringName in HeroData.STATS:
		values[stat_name] = HeroData.STARTING_STAT
	return values


## What every hit the hero deals is multiplied by: 1.0 plus the run's damage
## upgrades.
func damage_multiplier() -> float:
	return 1.0 + _run_damage_bonus


## Whether a body of the hero's size fits at `point` in global space.
func can_stand_at(point: Vector2) -> bool:
	return not test_move(Transform2D(0.0, point), Vector2.ZERO)


## Put the hero at `point` in global space, as a blink does.
func teleport_to(point: Vector2) -> void:
	global_position = point


## Take an upgrade from the run's general pool, for the rest of the run.
func apply_upgrade(upgrade: GenericUpgrade) -> void:
	match upgrade.effect:
		GenericUpgrade.Effect.MOVE_SPEED:
			_run_speed_bonus += upgrade.amount
		GenericUpgrade.Effect.HEAL:
			heal(health.maximum * upgrade.amount)
		GenericUpgrade.Effect.DAMAGE:
			_run_damage_bonus += upgrade.amount
		GenericUpgrade.Effect.PICKUP_RADIUS:
			pickup_radius += upgrade.amount


## Hold `item`, or nothing when null.
func wield(item: WeaponItem) -> void:
	weapon = item
	_doll.wield(weapon)
	_attack_cooldown = 0.0
	_update_sensor_range()


## Play the held weapon's attack once and release its projectile, if any,
## turning to face `aim_at` (in global space) and aiming at it. With no aim the
## hero attacks straight ahead. Does not check attack_interval or range; pacing
## attacks is the caller's job. Returns false when there is nothing to attack
## with.
func attack(aim_at: Vector2 = Vector2.INF) -> bool:
	if aim_at.is_finite():
		_update_facing(aim_at.x - global_position.x)
	_aim_point = aim_at
	return _doll.attack()


func _physics_process(delta: float) -> void:
	if _dead:
		velocity = Vector2.ZERO
		_update_animation()
		return

	buffs.tick(delta)
	var input: Vector2 = Input.get_vector(
		&"move_left", &"move_right", &"move_up", &"move_down"
	)
	input.y *= vertical_ratio

	var speed_multiplier: float = (
		_move_multiplier
		+ _run_speed_bonus
		+ buffs.magnitude(HeroBuffs.SWIFT_STEP) / 100.0
	)
	var target: Vector2 = input * speed * speed_multiplier
	if acceleration <= 0.0:
		velocity = target
	elif target.is_zero_approx():
		velocity = velocity.lerp(Vector2.ZERO, minf(friction * delta, 1.0))
	else:
		velocity = velocity.lerp(target, minf(acceleration * delta, 1.0))

	move_and_slide()
	_update_facing(input.x)
	_update_animation()
	_auto_attack(delta)


## Attack the nearest enemy in range once the weapon is ready again.
func _auto_attack(delta: float) -> void:
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	var data: WeaponData = weapon.data() if weapon != null else null
	if data == null or _attack_cooldown > 0.0:
		return
	var enemy: Enemy = _sensor.nearest_enemy(global_position, data.attack_range)
	if enemy != null and attack(enemy.center()):
		_attack_cooldown = data.attack_interval / _attack_speed_multiplier()


## Blood Frenzy swings faster the more health is missing.
func _attack_speed_multiplier() -> float:
	var bonus: float = buffs.magnitude(HeroBuffs.BLOOD_FRENZY) / 100.0
	return 1.0 + bonus * (1.0 - health.ratio())


func _update_sensor_range() -> void:
	var data: WeaponData = weapon.data() if weapon != null else null
	_sensor.set_radius(data.attack_range if data != null else 0.0)


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


func _set_health(max_health: float) -> void:
	if health != null:
		health.died.disconnect(_on_health_died)
	_dead = false
	health = Health.new(max_health)
	health.died.connect(_on_health_died)


func _on_health_died() -> void:
	_dead = true
	# A fallen hero collects nothing.
	_pickup_area.set_deferred(&"monitoring", false)
	died.emit()


func _on_pickup_area_entered(area: Area2D) -> void:
	if area is Pickup and not _dead:
		pickup_reached.emit(area)


## Skills' projectiles go into the world the same way the weapon's do.
func _on_skill_projectile_released(projectile: Projectile) -> void:
	if projectile_released.get_connections().is_empty():
		projectile.free()
		return
	projectile_released.emit(projectile)


func _on_skill_effect_spawned(effect: Node2D, at: Vector2) -> void:
	if effect_spawned.get_connections().is_empty():
		effect.free()
		return
	effect_spawned.emit(effect, at)


## What one hit of `data` deals, from the hero's stats, plus Flame Brand's fire
## while it burns, times the run's damage upgrades. A hero with no saved stats,
## such as one placed in a scene run on its own, deals the base damage.
func _damage_of(data: WeaponData) -> float:
	var base: float = data.base_damage if _stats == null else data.damage_for(_stats)
	return (base + buffs.magnitude(HeroBuffs.FLAME_BRAND)) * damage_multiplier()


func _on_doll_attack_released() -> void:
	var data: WeaponData = weapon.data() if weapon != null else null
	if data == null:
		return
	match data.attack_style:
		WeaponData.AttackStyle.MELEE:
			_strike(data)
		WeaponData.AttackStyle.PROJECTILE:
			_shoot(data)


## Hurt every enemy within range on the side the hero faces.
func _strike(data: WeaponData) -> void:
	var damage: float = _damage_of(data)
	var facing: float = 1.0 if _doll.is_facing_right() else -1.0
	for enemy: Enemy in _sensor.enemies_within(global_position, data.attack_range):
		if (enemy.global_position.x - global_position.x) * facing >= -MELEE_REACH_BEHIND:
			enemy.take_damage(damage)


func _shoot(data: WeaponData) -> void:
	if data.projectile == null:
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
	var origin: Vector2 = _doll.to_global(_doll.get_release_position())
	projectile.damage = _damage_of(data)
	projectile.launch(origin, _aim_direction(origin), data.attack_range, velocity)
	projectile_released.emit(projectile)


## The way a shot from `origin` goes: at the aim point, or straight ahead when
## the attack had none or the aim point is on top of the origin.
func _aim_direction(origin: Vector2) -> Vector2:
	if _aim_point.is_finite() and origin.distance_to(_aim_point) > 1.0:
		return origin.direction_to(_aim_point)
	return Vector2.RIGHT if _doll.is_facing_right() else Vector2.LEFT