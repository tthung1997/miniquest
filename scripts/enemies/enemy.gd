class_name Enemy
extends CharacterBody2D
## An enemy that chases its target and hurts it on contact.
##
## What kind of enemy it is comes entirely from its EnemyData, so one scene
## serves every enemy. The art is drawn facing right and mirrored to face left.
## Spawners set `data` before adding it to the tree, and `target` whenever they
## like. Shots aim at its middle and its feet are its position, so distances
## measured to an enemy are measured to where it stands.

## Its health ran out. Emitted once, before the body fades away.
signal died(enemy: Enemy)

enum ChargePhase { CHASE, WINDUP, DASH }

## From the feet to the middle of the body.
const BODY_CENTER: Vector2 = Vector2(0.0, -12.0)
## Closer than this to the target it stops, rather than shuddering on top of it.
const STOP_DISTANCE: float = 2.0
const HIT_FLASH: Color = Color(3.0, 3.0, 3.0)
const HIT_FLASH_TIME: float = 0.08
const FADE_TIME: float = 0.25
const WINDUP_TINT: Color = Color(1.0, 0.55, 0.3)

@export var data: EnemyData

## Multipliers on the template's health and contact damage, set by a spawner
## before the enemy is added to the tree.
var health_scale: float = 1.0
var damage_scale: float = 1.0

## Who it chases and hurts. Nothing is chased while it is null.
var target: Hero = null
var health: Health = null

var _contact_cooldown: float = 0.0
var _slow_amount: float = 0.0
var _slow_left: float = 0.0
var _flash: Tween = null
var _charge_phase: ChargePhase = ChargePhase.CHASE
var _charge_time_left: float = 0.0
var _charge_direction: Vector2 = Vector2.ZERO

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _body: CollisionShape2D = $Collision
@onready var _contact: Area2D = $ContactArea


func _ready() -> void:
	if data == null:
		push_error("Enemy '%s' has no EnemyData." % name)
		set_physics_process(false)
		return
	if (data.frames == null or not data.frames.has_animation(&"walk")
			or data.frames.get_frame_count(&"walk") == 0):
		push_error("Enemy '%s' has no walk animation." % name)
		set_physics_process(false)
		return
	var first_frame: Texture2D = data.frames.get_frame_texture(&"walk", 0)
	if first_frame == null:
		push_error("Enemy '%s' has no walk texture." % name)
		set_physics_process(false)
		return
	health = Health.new(data.max_health * health_scale)
	health.died.connect(_on_health_died)
	_sprite.sprite_frames = data.frames
	_sprite.position.y = -first_frame.get_height() * 0.5
	_sprite.play(&"walk")
	_charge_time_left = data.charge_cooldown
	if not is_equal_approx(data.body_scale, 1.0):
		_body.scale = Vector2.ONE * data.body_scale
		_contact.scale = Vector2.ONE * data.body_scale


func _physics_process(delta: float) -> void:
	_contact_cooldown = maxf(_contact_cooldown - delta, 0.0)
	_slow_left = maxf(_slow_left - delta, 0.0)
	if is_zero_approx(_slow_left):
		_slow_amount = 0.0
	if target == null or not is_instance_valid(target):
		if _charge_phase != ChargePhase.CHASE:
			_finish_charge()
		velocity = Vector2.ZERO
		return

	var to_target: Vector2 = target.global_position - global_position
	var direction: Vector2 = Vector2.ZERO
	if to_target.length_squared() > STOP_DISTANCE * STOP_DISTANCE:
		direction = to_target.normalized()
	velocity = _chase_or_charge(direction, delta) * (1.0 - _slow_amount)
	move_and_slide()
	var facing_x: float = to_target.x if _charge_phase == ChargePhase.WINDUP else velocity.x
	if absf(facing_x) > 0.1:
		_sprite.flip_h = facing_x < 0.0
	_hit_touching_target()


## Where shots should aim, in global space.
func center() -> Vector2:
	var scale_factor: float = data.body_scale if data != null else 1.0
	return global_position + BODY_CENTER * scale_factor


func is_dead() -> bool:
	return health != null and health.is_dead()


func take_damage(amount: float) -> void:
	if health == null or health.is_dead():
		return
	health.take_damage(amount)
	if not health.is_dead():
		_flash_white()


## Move at `1 - amount` of normal speed for `seconds`. A stronger or longer
## slow replaces a weaker one.
func slow(amount: float, seconds: float) -> void:
	_slow_amount = clampf(maxf(amount, _slow_amount), 0.0, 0.95)
	_slow_left = maxf(seconds, _slow_left)


func _chase_or_charge(direction: Vector2, delta: float) -> Vector2:
	if data.charge_speed <= 0.0:
		return direction * data.speed

	_charge_time_left = maxf(_charge_time_left - delta, 0.0)
	match _charge_phase:
		ChargePhase.CHASE:
			if _charge_time_left == 0.0 and _can_charge(direction):
				_charge_phase = ChargePhase.WINDUP
				_charge_time_left = data.charge_windup
				_sprite.pause()
				_sprite.self_modulate = WINDUP_TINT
				return Vector2.ZERO
		ChargePhase.WINDUP:
			if not _can_charge(direction):
				_finish_charge()
			elif _charge_time_left > 0.0:
				return Vector2.ZERO
			else:
				_clear_windup()
				# Aim at launch, then commit so a sidestep can dodge the rush.
				_charge_direction = direction
				_charge_phase = ChargePhase.DASH
				_charge_time_left = data.charge_duration
				return _charge_direction * data.charge_speed
		ChargePhase.DASH:
			if _charge_time_left > 0.0:
				return _charge_direction * data.charge_speed
			_finish_charge()
	return direction * data.speed


func _can_charge(direction: Vector2) -> bool:
	return direction != Vector2.ZERO and target.is_targetable() and not target.is_dead()


func _finish_charge() -> void:
	if _charge_phase == ChargePhase.WINDUP:
		_clear_windup()
	_charge_phase = ChargePhase.CHASE
	_charge_time_left = data.charge_cooldown


func _clear_windup() -> void:
	_sprite.self_modulate = Color.WHITE
	_sprite.play(&"walk")


func _hit_touching_target() -> void:
	if _contact_cooldown > 0.0:
		return
	for body: Node2D in _contact.get_overlapping_bodies():
		if body is Hero:
			var hero: Hero = body
			# A hero nobody can target is walked through, not hurt.
			if not hero.is_targetable():
				return
			hero.take_damage(data.contact_damage * damage_scale, self)
			_contact_cooldown = data.contact_interval
			return


func _flash_white() -> void:
	if _flash != null:
		_flash.kill()
	_sprite.modulate = HIT_FLASH
	_flash = create_tween()
	_flash.tween_property(_sprite, "modulate", Color.WHITE, HIT_FLASH_TIME)


func _on_health_died() -> void:
	set_physics_process(false)
	velocity = Vector2.ZERO
	if _charge_phase != ChargePhase.CHASE:
		_finish_charge()
	# Out of reach of every shot and scan from here on, while it fades.
	set_deferred(&"collision_layer", 0)
	_contact.set_deferred(&"monitoring", false)
	died.emit(self)

	if _flash != null:
		_flash.kill()
	var fade: Tween = create_tween()
	fade.tween_property(_sprite, "modulate", Color(1.0, 1.0, 1.0, 0.0), FADE_TIME)
	fade.tween_callback(queue_free)
