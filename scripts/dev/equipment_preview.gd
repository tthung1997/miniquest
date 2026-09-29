class_name EquipmentPreview
extends Node2D
## Stacks equipment layers over the hero body so paper-doll alignment can be
## judged in motion.
##
## Every layer is driven from one animation and frame index rather than each
## playing independently. Separate AnimatedSprite2D nodes started at slightly
## different times drift apart, and a drifting stack hides the very
## misalignment this scene exists to find.
##
## The equipment layer is the thing under test, so it can be isolated, hidden,
## or flashed against the body. A piece that only lines up on one frame shows
## up as a jitter against the fixed guides.
##
## Run this scene on its own with F6. Not shipped game code.

const IDLE_CLIP: StringName = &"idle"
const WALK_CLIP: StringName = &"walk"
const BACKDROPS: Array[Color] = [
	Color(0.11, 0.12, 0.15),
	Color(0.50, 0.50, 0.50),
	Color(0.88, 0.89, 0.91),
	Color(0.27, 0.42, 0.24),
]
const GUIDE_HEAD: Color = Color(0.35, 0.75, 1.0, 0.7)
const GUIDE_FEET: Color = Color(1.0, 0.35, 0.35, 0.7)
const BORDER_COLOR: Color = Color(1.0, 1.0, 1.0, 0.3)
const GHOST_TINT: Color = Color(1.0, 1.0, 1.0, 0.22)

@export var frame_size: Vector2i = Vector2i(64, 64)
@export_range(1, 12) var zoom: int = 4
@export var walking: bool = true
@export_group("Guides")
@export var head_row: int = 9
@export var feet_row: int = 56

var _backdrop: int = 0
var _show_equipment: bool = true
var _isolate: bool = false

@onready var _backdrop_rect: ColorRect = $Backdrop
@onready var _native_body: AnimatedSprite2D = $Native/Body
@onready var _native_hat: AnimatedSprite2D = $Native/Hat
@onready var _zoom_body: AnimatedSprite2D = $Zoomed/Body
@onready var _zoom_hat: AnimatedSprite2D = $Zoomed/Hat
@onready var _native_root: Node2D = $Native
@onready var _zoom_root: Node2D = $Zoomed
@onready var _info: Label = $HUD/Root/Info
@onready var _hint: Label = $HUD/Root/Hint


func _ready() -> void:
	_hint.text = "space idle/walk    e equipment    i isolate    b backdrop"
	_backdrop_rect.color = BACKDROPS[_backdrop]
	_zoom_root.scale = Vector2(zoom, zoom)
	_layout()
	_apply_clip()
	get_viewport().size_changed.connect(_layout)


func _process(_delta: float) -> void:
	# One clock for the whole stack: the body leads, everything else copies its
	# frame index, so no layer can slide out of step with the pose beneath it.
	for follower: AnimatedSprite2D in [_native_hat, _zoom_hat]:
		follower.animation = _native_body.animation
		follower.frame = _native_body.frame
	_zoom_body.frame = _native_body.frame
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventKey:
		return
	var key: InputEventKey = event as InputEventKey
	if not key.pressed or key.echo:
		return

	match key.physical_keycode:
		KEY_SPACE:
			walking = not walking
			_apply_clip()
		KEY_E:
			_show_equipment = not _show_equipment
		KEY_I:
			_isolate = not _isolate
		KEY_B:
			_backdrop = (_backdrop + 1) % BACKDROPS.size()
			_backdrop_rect.color = BACKDROPS[_backdrop]
		_:
			return
	_apply_visibility()
	_refresh()


func _draw() -> void:
	var extent: Vector2 = Vector2(frame_size) * float(zoom)
	var origin: Vector2 = _zoom_root.position - extent * 0.5
	draw_rect(Rect2(origin, extent), BORDER_COLOR, false, 2.0)
	_guide(origin, extent, head_row, GUIDE_HEAD)
	_guide(origin, extent, feet_row, GUIDE_FEET)


func _guide(origin: Vector2, extent: Vector2, row: int, color: Color) -> void:
	if row < 0 or row >= frame_size.y:
		return
	var y: float = origin.y + float(row * zoom)
	draw_line(Vector2(origin.x, y), Vector2(origin.x + extent.x, y), color, 2.0)


func _apply_clip() -> void:
	var clip: StringName = WALK_CLIP if walking else IDLE_CLIP
	_native_body.play(clip)
	_zoom_body.play(clip)


## Isolating dims the body rather than hiding it: a floating hat says nothing
## about whether it sits on the head correctly.
func _apply_visibility() -> void:
	_native_hat.visible = _show_equipment
	_zoom_hat.visible = _show_equipment
	var body_tint: Color = GHOST_TINT if _isolate else Color.WHITE
	_native_body.modulate = body_tint
	_zoom_body.modulate = body_tint


func _layout() -> void:
	var view: Vector2 = get_viewport_rect().size
	_backdrop_rect.size = view
	_native_root.position = Vector2(view.x * 0.22, view.y * 0.46)
	_zoom_root.position = Vector2(view.x * 0.64, view.y * 0.46)
	_hint.position = Vector2(12.0, view.y - 30.0)
	queue_redraw()


func _refresh() -> void:
	_info.text = (
		"%s  frame %d/%d    equipment %s    body %s"
		% [
			"WALK" if walking else "IDLE",
			_native_body.frame + 1,
			_native_body.sprite_frames.get_frame_count(_native_body.animation),
			"on" if _show_equipment else "off",
			"ghosted" if _isolate else "solid",
		]
	)
