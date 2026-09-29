class_name Hero
extends CharacterBody2D
## Player-controlled hero with free eight-way movement.
##
## The art is drawn in side view facing right, so horizontal facing is shown by
## flipping the sprite and vertical movement reuses the same walk clip. Facing
## is only updated when there is horizontal input, so walking straight up or
## down keeps whichever way the hero last faced rather than snapping to a
## default.

signal facing_changed(facing_right: bool)

const IDLE_CLIP: StringName = &"idle"
const WALK_CLIP: StringName = &"walk"

@export_group("Movement")
@export_range(10.0, 400.0, 5.0) var speed: float = 70.0
## How sharply the hero reaches full speed. Higher is snappier; 0 disables
## smoothing and applies input velocity directly.
@export_range(0.0, 40.0, 0.5) var acceleration: float = 14.0
@export_range(0.0, 40.0, 0.5) var friction: float = 18.0
## Vertical travel as a fraction of horizontal, so diagonal movement reads with
## the shallow perspective these side-view sprites imply. 1.0 is uniform.
@export_range(0.3, 1.0, 0.05) var vertical_ratio: float = 0.6

var _facing_right: bool = true
var _layers: Array[AnimatedSprite2D] = []

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _equipment: Node2D = $Equipment


func _ready() -> void:
	_collect_layers()
	_sprite.play(IDLE_CLIP)

	# Copy the body's frame on its own change signals rather than polling in
	# _process: a poll reads whatever the body had when this node last ran,
	# which lags by a frame whenever tree order puts the hero first.
	_sprite.frame_changed.connect(_sync_layers)
	_sprite.animation_changed.connect(_sync_layers)
	_sync_layers()


## Equipment layers are whatever AnimatedSprite2D nodes sit under Equipment, so
## a slot can be added in the editor without touching this script.
func _collect_layers() -> void:
	_layers.clear()
	for child: Node in _equipment.get_children():
		if child is AnimatedSprite2D:
			var layer: AnimatedSprite2D = child as AnimatedSprite2D
			# Layers must not run their own clock, or they drift against the body.
			layer.stop()
			layer.flip_h = not _facing_right
			_layers.append(layer)


func _sync_layers() -> void:
	for layer: AnimatedSprite2D in _layers:
		if layer.sprite_frames == null:
			continue
		if not layer.sprite_frames.has_animation(_sprite.animation):
			push_warning(
				"Hero: equipment layer '%s' has no clip '%s'."
				% [layer.name, _sprite.animation]
			)
			continue
		layer.animation = _sprite.animation
		layer.frame = _sprite.frame


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
	if should_face_right == _facing_right:
		return

	_facing_right = should_face_right
	_sprite.flip_h = not _facing_right
	for layer: AnimatedSprite2D in _layers:
		layer.flip_h = not _facing_right
	facing_changed.emit(_facing_right)


func _update_animation() -> void:
	var moving: bool = velocity.length() > 1.0
	var clip: StringName = WALK_CLIP if moving else IDLE_CLIP
	if _sprite.animation != clip:
		_sprite.play(clip)


func is_facing_right() -> bool:
	return _facing_right
