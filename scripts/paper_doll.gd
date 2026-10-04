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

const IDLE_CLIP: StringName = &"idle"
const WALK_CLIP: StringName = &"walk"

var _facing_right: bool = true
var _layers: Array[AnimatedSprite2D] = []
var _armour: ArmourItem = null
var _weapon: WeaponItem = null

@onready var _body: AnimatedSprite2D = $Body
@onready var _equipment: Node2D = $Equipment
@onready var _hat: AnimatedSprite2D = $Equipment/Hat
@onready var _shirt: AnimatedSprite2D = $Equipment/Shirt
@onready var _pants: AnimatedSprite2D = $Equipment/Pants
@onready var _weapon_layer: AnimatedSprite2D = $Equipment/Weapon


func _ready() -> void:
	_collect_layers()
	_body.play(IDLE_CLIP)

	# Copy the body's frame on its own change signals rather than polling in
	# _process: a poll reads whatever the body had when this node last ran,
	# which lags by a frame whenever tree order puts the doll first.
	_body.frame_changed.connect(_sync_layers)
	_body.animation_changed.connect(_sync_layers)
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
func wield(item: WeaponItem) -> void:
	_weapon = item
	if is_node_ready():
		_apply_weapon()
		_sync_layers()


## Play `clip` on the body; the equipment layers follow it.
func play(clip: StringName) -> void:
	if _body.animation != clip or not _body.is_playing():
		_body.play(clip)


func set_facing_right(facing_right: bool) -> void:
	if facing_right == _facing_right:
		return
	_facing_right = facing_right
	_body.flip_h = not _facing_right
	for layer: AnimatedSprite2D in _layers:
		layer.flip_h = not _facing_right


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
		if not layer.sprite_frames.has_animation(_body.animation):
			push_warning(
				"PaperDoll: equipment layer '%s' has no clip '%s'."
				% [layer.name, _body.animation]
			)
			continue
		layer.animation = _body.animation
		layer.frame = _body.frame
