class_name TransitionPreview
extends Node2D
## Plays idle -> walk -> idle on a loop so the seam between the two clips can be
## judged in motion, which a static comparison cannot show.
##
## The two clips came from different source sheets whose characters differ
## slightly in proportion, so the risk is a vertical pop at the switch. The
## fixed head and feet guides exist for that: they do not move, so anything
## that shifts against them is a real discontinuity rather than an impression.
##
## Run this scene on its own with F6. Not shipped game code.

enum State { IDLE, WALK }

const BACKDROPS: Array[Color] = [
	Color(0.11, 0.12, 0.15),
	Color(0.50, 0.50, 0.50),
	Color(0.88, 0.89, 0.91),
	Color(0.27, 0.42, 0.24),
]
const GUIDE_HEAD: Color = Color(0.35, 0.75, 1.0, 0.75)
const GUIDE_FEET: Color = Color(1.0, 0.35, 0.35, 0.75)
const BORDER_COLOR: Color = Color(1.0, 1.0, 1.0, 0.35)

@export var idle_sheet: Texture2D
@export var walk_sheet: Texture2D
@export var frame_size: Vector2i = Vector2i(64, 64)
@export_range(1.0, 24.0, 0.5) var walk_fps: float = 8.0
## Seconds spent in each clip before the auto-cycle switches.
@export_range(0.2, 5.0, 0.1) var idle_hold: float = 1.2
@export_range(0.2, 5.0, 0.1) var walk_hold: float = 1.6
@export_range(1, 12) var zoom: int = 4
@export var auto_cycle: bool = true
@export_group("Guides")
## Row the head top is authored to sit on, drawn in blue.
@export var head_row: int = 9
## Row the feet are authored to rest on, drawn in red.
@export var feet_row: int = 56

var _state: State = State.IDLE
var _elapsed: float = 0.0
var _backdrop: int = 0
var _overlay: bool = false

@onready var _backdrop_rect: ColorRect = $Backdrop
@onready var _native: AnimatedSprite2D = $Native
@onready var _zoomed: AnimatedSprite2D = $Zoomed
@onready var _ghost: Sprite2D = $Ghost
@onready var _info: Label = $HUD/Root/Info
@onready var _hint: Label = $HUD/Root/Hint


func _ready() -> void:
	_hint.text = "space auto on/off    1 idle    2 walk    o overlay    b backdrop"
	_backdrop_rect.color = BACKDROPS[_backdrop]

	var frames: SpriteFrames = _build_frames()
	_native.sprite_frames = frames
	_zoomed.sprite_frames = frames
	_zoomed.scale = Vector2(zoom, zoom)

	_ghost.texture = walk_sheet
	_ghost.hframes = _frame_count(walk_sheet)
	_ghost.scale = Vector2(zoom, zoom)
	_ghost.modulate = Color(1.0, 1.0, 1.0, 0.5)
	_ghost.visible = false

	_layout()
	_enter(State.IDLE)
	get_viewport().size_changed.connect(_layout)


func _process(delta: float) -> void:
	if auto_cycle:
		_elapsed += delta
		var hold: float = idle_hold if _state == State.IDLE else walk_hold
		if _elapsed >= hold:
			_enter(State.WALK if _state == State.IDLE else State.IDLE)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventKey:
		return
	var key: InputEventKey = event as InputEventKey
	if not key.pressed or key.echo:
		return

	match key.physical_keycode:
		KEY_SPACE:
			auto_cycle = not auto_cycle
			_elapsed = 0.0
		KEY_1:
			auto_cycle = false
			_enter(State.IDLE)
		KEY_2:
			auto_cycle = false
			_enter(State.WALK)
		KEY_O:
			_overlay = not _overlay
			_ghost.visible = _overlay
		KEY_B:
			_backdrop = (_backdrop + 1) % BACKDROPS.size()
			_backdrop_rect.color = BACKDROPS[_backdrop]
		_:
			return
	_refresh()


func _draw() -> void:
	var extent: Vector2 = Vector2(frame_size) * float(zoom)
	var origin: Vector2 = _zoomed.position - extent * 0.5
	draw_rect(Rect2(origin, extent), BORDER_COLOR, false, 2.0)
	_guide(origin, extent, head_row, GUIDE_HEAD)
	_guide(origin, extent, feet_row, GUIDE_FEET)

	# The same guides at 1:1. A pop is easiest to see against the small view,
	# because that is the size the discontinuity will actually ship at.
	var small: Vector2 = Vector2(frame_size)
	var small_origin: Vector2 = _native.position - small * 0.5
	_guide_1to1(small_origin, small, head_row, GUIDE_HEAD)
	_guide_1to1(small_origin, small, feet_row, GUIDE_FEET)


func _guide(origin: Vector2, extent: Vector2, row: int, color: Color) -> void:
	if row < 0 or row >= frame_size.y:
		return
	var y: float = origin.y + float(row * zoom)
	draw_line(Vector2(origin.x, y), Vector2(origin.x + extent.x, y), color, 2.0)


func _guide_1to1(origin: Vector2, extent: Vector2, row: int, color: Color) -> void:
	if row < 0 or row >= frame_size.y:
		return
	var y: float = origin.y + float(row)
	draw_line(
		Vector2(origin.x - 8.0, y), Vector2(origin.x + extent.x + 8.0, y), color, 1.0
	)


func _build_frames() -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation(&"default")
	_add_clip(frames, &"idle", idle_sheet, 1.0)
	_add_clip(frames, &"walk", walk_sheet, walk_fps)
	return frames


func _add_clip(
	frames: SpriteFrames, clip: StringName, sheet: Texture2D, fps: float
) -> void:
	frames.add_animation(clip)
	frames.set_animation_speed(clip, fps)
	frames.set_animation_loop(clip, true)
	if sheet == null:
		push_error("TransitionPreview: no sheet assigned for clip '%s'." % clip)
		return
	for i in _frame_count(sheet):
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(
			float(i * frame_size.x), 0.0, float(frame_size.x), float(frame_size.y)
		)
		frames.add_frame(clip, atlas)


func _frame_count(sheet: Texture2D) -> int:
	if sheet == null:
		return 1
	return maxi(sheet.get_width() / frame_size.x, 1)


func _enter(state: State) -> void:
	_state = state
	_elapsed = 0.0
	var clip: StringName = &"idle" if state == State.IDLE else &"walk"
	_native.play(clip)
	_zoomed.play(clip)


func _layout() -> void:
	# Backdrop is a Control parented to a Node2D, so anchors have no parent rect
	# to resolve against and leave it zero-sized; its size is set explicitly.
	var view: Vector2 = get_viewport_rect().size
	_backdrop_rect.size = view
	_native.position = Vector2(view.x * 0.22, view.y * 0.46)
	_zoomed.position = Vector2(view.x * 0.64, view.y * 0.46)
	_ghost.position = _zoomed.position
	_hint.position = Vector2(12.0, view.y - 30.0)
	queue_redraw()


func _refresh() -> void:
	_info.text = (
		"%s    auto %s    overlay %s\nblue = head row %d, red = feet row %d"
		% [
			"IDLE" if _state == State.IDLE else "WALK",
			"on" if auto_cycle else "off",
			"on" if _overlay else "off",
			head_row,
			feet_row,
		]
	)
	queue_redraw()
