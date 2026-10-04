class_name PaperDoll
extends Node2D
## A body with equipment layers drawn over it, all driven from one clock.
##
## The art is drawn in side view facing right; facing left flips every layer.
## Only the body plays its animation. Each equipment layer copies the body's
## clip and frame index, so no layer can drift out of step with the pose
## beneath it. The weapon layer is drawn last, in front of everything; its art
## redraws the near fist over the grip so the hand holds it. Has no input or
## physics of its own, so it can be shown anywhere a hero needs to be seen,
## from the arena to a menu portrait.
##
## The one exception to the single clock is an attack. The weapon then plays
## its own attack clip once, over whatever the body is doing, so the hero can
## attack mid-stride. That clip is drawn once at the idle pose's hand, and the
## layer is moved by the hand's offset on each body frame to keep it in the
## fist.

## The held weapon's attack reached its release frame: the moment its effect
## appears and any projectile should leave.
signal attack_released

const IDLE_CLIP: StringName = &"idle"
const WALK_CLIP: StringName = &"walk"
const ATTACK_CLIP: StringName = &"attack"

## Where the near hand is on each frame of each body clip, in pixels relative
## to the idle pose, facing right. Weapon idle and walk sheets already carry
## this placement; the attack clip relies on it to follow the hand.
@export var hand_offsets: Dictionary[StringName, PackedVector2Array] = {}

var _facing_right: bool = true
var _layers: Array[AnimatedSprite2D] = []
var _armour: ArmourItem = null
var _weapon: WeaponItem = null
var _attacking: bool = false
var _released: bool = false
var _weapon_base_offset: Vector2 = Vector2.ZERO

@onready var _body: AnimatedSprite2D = $Body
@onready var _equipment: Node2D = $Equipment
@onready var _hat: AnimatedSprite2D = $Equipment/Hat
@onready var _shirt: AnimatedSprite2D = $Equipment/Shirt
@onready var _pants: AnimatedSprite2D = $Equipment/Pants
@onready var _weapon_layer: AnimatedSprite2D = $Equipment/Weapon


func _ready() -> void:
	_collect_layers()
	_weapon_base_offset = _weapon_layer.offset
	_body.play(IDLE_CLIP)

	# Copy the body's frame on its own change signals rather than polling in
	# _process: a poll reads whatever the body had when this node last ran,
	# which lags by a frame whenever tree order puts the doll first.
	_body.frame_changed.connect(_sync_layers)
	_body.animation_changed.connect(_sync_layers)
	_weapon_layer.frame_changed.connect(_on_weapon_frame_changed)
	_weapon_layer.animation_finished.connect(_end_attack)
	_apply_armour()
	_apply_weapon()
	_sync_layers()


## Show `item`'s rolled pieces, or clear all three armour layers when null.
## Safe to call before the doll enters the tree; it is applied on ready.
func wear_armour(item: ArmourItem) -> void:
	_armour = item
	if is_node_ready():
		_apply_armour()
		_sync_layers()


## Hold `item`, or empty the hand when null. Safe to call before ready.
## Changing weapon cuts short any attack in progress.
func wield(item: WeaponItem) -> void:
	_weapon = item
	if is_node_ready():
		_end_attack()
		_apply_weapon()
		_sync_layers()


## Play `clip` on the body; the equipment layers follow it.
func play(clip: StringName) -> void:
	if _body.animation != clip or not _body.is_playing():
		_body.play(clip)


## Play the held weapon's attack once, from the start, over whatever the body
## is doing. Returns false and does nothing when no weapon is held or it has no
## attack clip.
func attack() -> bool:
	var weapon: WeaponData = _held_weapon()
	if weapon == null:
		return false
	var frames: SpriteFrames = _weapon_layer.sprite_frames
	if frames == null or not frames.has_animation(ATTACK_CLIP):
		push_warning("PaperDoll: weapon '%s' has no %s clip." % [weapon.id, ATTACK_CLIP])
		return false

	_attacking = true
	_released = false
	# stop() rewinds, so a new attack restarts even if the last one is running.
	_weapon_layer.stop()
	_weapon_layer.play(ATTACK_CLIP)
	_place_weapon()
	_check_release()
	return true


func is_attacking() -> bool:
	return _attacking


## Where the held weapon's attack effect or projectile appears, in this doll's
## space, for the current facing and body frame.
func get_release_position() -> Vector2:
	var weapon: WeaponData = _held_weapon()
	if weapon == null:
		return Vector2.ZERO
	return _mirror(weapon.release_point + _hand_offset())


func set_facing_right(facing_right: bool) -> void:
	if facing_right == _facing_right:
		return
	_facing_right = facing_right
	_body.flip_h = not _facing_right
	for layer: AnimatedSprite2D in _layers:
		layer.flip_h = not _facing_right
	if _attacking:
		_place_weapon()


func is_facing_right() -> bool:
	return _facing_right


## Equipment layers are whatever AnimatedSprite2D nodes sit under Equipment, so
## a slot can be added in the editor without touching this script.
func _collect_layers() -> void:
	_layers.clear()
	for child: Node in _equipment.get_children():
		if child is AnimatedSprite2D:
			var layer: AnimatedSprite2D = child
			# Layers must not run their own clock, or they drift against the body.
			layer.stop()
			layer.flip_h = not _facing_right
			_layers.append(layer)


func _apply_armour() -> void:
	if _armour == null:
		_hat.sprite_frames = null
		_shirt.sprite_frames = null
		_pants.sprite_frames = null
		return
	_hat.sprite_frames = _armour.frames_for(ArmourItem.Piece.HAT)
	_shirt.sprite_frames = _armour.frames_for(ArmourItem.Piece.SHIRT)
	_pants.sprite_frames = _armour.frames_for(ArmourItem.Piece.PANTS)


func _apply_weapon() -> void:
	_weapon_layer.sprite_frames = _weapon.frames() if _weapon != null else null


func _sync_layers() -> void:
	for layer: AnimatedSprite2D in _layers:
		if layer.sprite_frames == null:
			continue
		if _attacking and layer == _weapon_layer:
			continue
		if not layer.sprite_frames.has_animation(_body.animation):
			push_warning(
				"PaperDoll: equipment layer '%s' has no clip '%s'."
				% [layer.name, _body.animation]
			)
			continue
		layer.animation = _body.animation
		layer.frame = _body.frame
	if _attacking:
		_place_weapon()


func _held_weapon() -> WeaponData:
	return _weapon.data() if _weapon != null else null


## Keep the attack clip in the fist as the body's frame moves the hand.
func _place_weapon() -> void:
	_weapon_layer.offset = _weapon_base_offset + _mirror(_hand_offset())


func _hand_offset() -> Vector2:
	var offsets: PackedVector2Array = hand_offsets.get(_body.animation, PackedVector2Array())
	if _body.frame >= offsets.size():
		push_warning(
			"PaperDoll: no hand offset for %s frame %d." % [_body.animation, _body.frame]
		)
		return Vector2.ZERO
	return offsets[_body.frame]


## `point`, drawn facing right, as it appears for the current facing.
func _mirror(point: Vector2) -> Vector2:
	return point if _facing_right else Vector2(-point.x, point.y)


func _on_weapon_frame_changed() -> void:
	if _attacking:
		_check_release()


func _check_release() -> void:
	var weapon: WeaponData = _held_weapon()
	if _released or weapon == null or _weapon_layer.frame < weapon.release_frame:
		return
	_released = true

	if weapon.attack_effect != null:
		var effect: Node = weapon.attack_effect.instantiate()
		if effect is Node2D:
			var effect_2d: Node2D = effect
			effect_2d.position = get_release_position()
			if not _facing_right:
				effect_2d.scale.x = -1.0
			add_child(effect_2d)
		else:
			push_error("PaperDoll: attack effect of '%s' is not a Node2D." % weapon.id)
			effect.free()
	attack_released.emit()


## Hand the weapon layer back to the body's clock, whether the attack ran out
## or was cut short.
func _end_attack() -> void:
	if not _attacking:
		return
	_attacking = false
	_weapon_layer.stop()
	_weapon_layer.offset = _weapon_base_offset
	_sync_layers()
