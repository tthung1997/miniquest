class_name Enemy
extends CharacterBody2D
## An enemy that walks straight at its target and hurts it on contact.
##
## What kind of enemy it is comes entirely from its EnemyData, so one scene
## serves every enemy. The art is drawn facing right and mirrored to face left.
## Spawners set `data` before adding it to the tree, and `target` whenever they
## like. Shots aim at its middle and its feet are its position, so distances
## measured to an enemy are measured to where it stands.

## Its health ran out. Emitted once, before the body fades away.
signal died(enemy: Enemy)

## From the feet to the middle of the body.
const BODY_CENTER: Vector2 = Vector2(0.0, -12.0)
## Closer than this to the target it stops, rather than shuddering on top of it.
const STOP_DISTANCE: float = 2.0
const HIT_FLASH: Color = Color(3.0, 3.0, 3.0)
const HIT_FLASH_TIME: float = 0.08
const FADE_TIME: float = 0.25

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

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _contact: Area2D = $ContactArea


func _ready() -> void:
	if data == null:
		push_error("Enemy '%s' has no EnemyData." % name)
		set_physics_process(false)
		return
	health = Health.new(data.max_health * health_scale)
	health.died.connect(_on_health_died)
	_sprite.sprite_frames = data.frames
	_sprite.play(&"walk")


func _physics_process(delta: float) -> void:
	_contact_cooldown = maxf(_contact_cooldown - delta, 0.0)
	_slow_left = maxf(_slow_left - delta, 0.0)
	if is_zero_approx(_slow_left):
		_slow_amount = 0.0
	if target == null or not is_instance_valid(target):
		velocity = Vector2.ZERO
		return

	var to_target: Vector2 = target.global_position - global_position
	if to_target.length() > STOP_DISTANCE:
		velocity = to_target.normalized() * data.speed * (1.0 - _slow_amount)
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	if absf(velocity.x) > 0.1:
		_sprite.flip_h = velocity.x < 0.0
	_hit_touching_target()


## Where shots should aim, in global space.
func center() -> Vector2:
	return global_position + BODY_CENTER


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
	# Out of reach of every shot and scan from here on, while it fades.
	set_deferred(&"collision_layer", 0)
	_contact.set_deferred(&"monitoring", false)
	died.emit(self)

	if _flash != null:
		_flash.kill()
	var fade: Tween = create_tween()
	fade.tween_property(_sprite, "modulate", Color(1.0, 1.0, 1.0, 0.0), FADE_TIME)
	fade.tween_callback(queue_free)
