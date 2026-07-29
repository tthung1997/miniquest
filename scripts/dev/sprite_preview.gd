class_name SpritePreview
extends Node2D
## Dev harness for judging sprite art under real game conditions: the true
## 640x360 viewport, nearest-neighbour filtering and integer zoom.
##
## Assign a sheet in the inspector and run this scene on its own with F6. The
## left pane is the honest test — that is the size the art will actually be on
## screen. The right pane is for inspecting pixels, not for judging the art.
##
## Not shipped game code; nothing else should depend on this script.

const BACKDROPS: Array[Color] = [
	Color(0.11, 0.12, 0.15),
	Color(0.50, 0.50, 0.50),
	Color(0.88, 0.89, 0.91),
	Color(0.27, 0.42, 0.24),
	Color(1.0, 0.0, 1.0),
]
const GRID_STEP: int = 8
const GRID_COLOR: Color = Color(1.0, 1.0, 1.0, 0.16)
const BORDER_COLOR: Color = Color(1.0, 1.0, 1.0, 0.45)
const BASELINE_COLOR: Color = Color(1.0, 0.35, 0.35, 0.7)
const NECK_COLOR: Color = Color(0.35, 0.75, 1.0, 0.7)

@export var sheet: Texture2D:
	set(value):
		sheet = value
		if is_node_ready():
			_apply_sheet()
@export var frame_size: Vector2i = Vector2i(64, 64):
	set(value):
		frame_size = Vector2i(maxi(value.x, 1), maxi(value.y, 1))
		if is_node_ready():
			_layout()
			_apply_sheet()
@export_range(1, 64) var frame_count: int = 4
@export_range(0, 32) var row: int = 0
@export_range(1.0, 24.0, 0.5) var fps: float = 8.0
@export_range(1, 12) var zoom: int = 4:
	set(value):
		zoom = clampi(value, 1, 12)
		if is_node_ready():
			_zoomed.scale = Vector2(zoom, zoom)
			_zoom_caption.text = "%dx - inspection only" % zoom
			_layout()
@export var playing: bool = true
@export var show_grid: bool = true
@export_group("Layer anchors")
## Logical row the feet rest on, drawn in red. -1 hides it. Every layer of a
## paper-doll character must agree on this row or equipment will float.
@export var baseline_row: int = 56
## Logical row the head joins the body, drawn in blue. -1 hides it.
@export var neck_row: int = 34

var _frame: int = 0
var _elapsed: float = 0.0
var _backdrop: int = 0
var _columns: int = 1
var _rows: int = 1

@onready var _backdrop_rect: ColorRect = $Backdrop
@onready var _native: Sprite2D = $Native
@onready var _zoomed: Sprite2D = $Zoomed
@onready var _info: Label = $HUD/Root/Info
@onready var _hint: Label = $HUD/Root/Hint
@onready var _native_caption: Label = $HUD/Root/NativeCaption
@onready var _zoom_caption: Label = $HUD/Root/ZoomCaption


func _ready() -> void:
	_hint.text = "space play/pause    left/right frame    up/down row    b backdrop    g grid"
	_backdrop_rect.color = BACKDROPS[_backdrop]
	_zoomed.scale = Vector2(zoom, zoom)
	_zoom_caption.text = "%dx - inspection only" % zoom
	_layout()
	_apply_sheet()
	get_viewport().size_changed.connect(_layout)


func _process(delta: float) -> void:
	if not playing or frame_count <= 1 or sheet == null:
		return
	_elapsed += delta
	var step: float = 1.0 / fps
	while _elapsed >= step:
		_elapsed -= step
		_frame = (_frame + 1) % frame_count
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventKey:
		return
	var key: InputEventKey = event as InputEventKey
	if not key.pressed or key.echo:
		return

	match key.physical_keycode:
		KEY_SPACE:
			playing = not playing
		KEY_RIGHT:
			playing = false
			_step_frame(1)
		KEY_LEFT:
			playing = false
			_step_frame(-1)
		KEY_UP:
			_step_row(-1)
		KEY_DOWN:
			_step_row(1)
		KEY_B:
			_backdrop = (_backdrop + 1) % BACKDROPS.size()
			_backdrop_rect.color = BACKDROPS[_backdrop]
		KEY_G:
			show_grid = not show_grid
			queue_redraw()
		_:
			return
	_refresh()


func _draw() -> void:
	if sheet == null or not show_grid:
		return

	var extent: Vector2 = Vector2(frame_size) * float(zoom)
	var origin: Vector2 = _zoomed.position - extent * 0.5

	for x in range(GRID_STEP, frame_size.x, GRID_STEP):
		var at_x: float = origin.x + float(x * zoom)
		draw_line(Vector2(at_x, origin.y), Vector2(at_x, origin.y + extent.y), GRID_COLOR, 1.0)
	for y in range(GRID_STEP, frame_size.y, GRID_STEP):
		var at_y: float = origin.y + float(y * zoom)
		draw_line(Vector2(origin.x, at_y), Vector2(origin.x + extent.x, at_y), GRID_COLOR, 1.0)

	draw_rect(Rect2(origin, extent), BORDER_COLOR, false, 2.0)
	_draw_anchor(origin, extent, baseline_row, BASELINE_COLOR)
	_draw_anchor(origin, extent, neck_row, NECK_COLOR)


func _draw_anchor(origin: Vector2, extent: Vector2, anchor_row: int, color: Color) -> void:
	if anchor_row < 0 or anchor_row >= frame_size.y:
		return
	var at_y: float = origin.y + float((anchor_row + 1) * zoom)
	draw_line(Vector2(origin.x, at_y), Vector2(origin.x + extent.x, at_y), color, 2.0)


func _layout() -> void:
	# Backdrop is a Control parented to a Node2D, so anchors have no parent rect
	# to resolve against and leave it zero-sized; its size is set explicitly.
	var view: Vector2 = get_viewport_rect().size
	var frame: Vector2 = Vector2(frame_size)

	_backdrop_rect.size = view
	_native.position = Vector2(view.x * 0.22, view.y * 0.46)
	_zoomed.position = Vector2(view.x * 0.64, view.y * 0.46)

	_caption_under(_native_caption, _native.position, frame.y * 0.5)
	_caption_under(_zoom_caption, _zoomed.position, frame.y * float(zoom) * 0.5)
	_hint.position = Vector2(12.0, view.y - 32.0)
	queue_redraw()


func _caption_under(caption: Label, anchor: Vector2, half_height: float) -> void:
	caption.size = Vector2(240.0, 24.0)
	caption.position = Vector2(anchor.x - 120.0, anchor.y + half_height + 14.0)


func _apply_sheet() -> void:
	if sheet == null:
		push_warning("SpritePreview: no sheet assigned; assign one in the inspector.")
		_native.texture = null
		_zoomed.texture = null
		_refresh()
		return

	var texture_size: Vector2i = sheet.get_size()
	if texture_size.x % frame_size.x != 0 or texture_size.y % frame_size.y != 0:
		push_warning(
			"SpritePreview: %dx%d does not divide evenly into %dx%d frames; the sheet is "
			% [texture_size.x, texture_size.y, frame_size.x, frame_size.y]
			+ "either the wrong size or not on a clean grid."
		)

	_columns = maxi(texture_size.x / frame_size.x, 1)
	_rows = maxi(texture_size.y / frame_size.y, 1)

	for sprite: Sprite2D in [_native, _zoomed]:
		sprite.texture = sheet
		sprite.hframes = _columns
		sprite.vframes = _rows

	_frame = 0
	_elapsed = 0.0
	_refresh()


func _step_frame(delta: int) -> void:
	_frame = wrapi(_frame + delta, 0, maxi(frame_count, 1))


func _step_row(delta: int) -> void:
	row = wrapi(row + delta, 0, _rows)


func _refresh() -> void:
	if sheet == null:
		_info.text = "no sheet assigned"
		queue_redraw()
		return

	var column: int = mini(_frame, _columns - 1)
	var visible_row: int = mini(row, _rows - 1)
	var index: int = visible_row * _columns + column
	_native.frame = index
	_zoomed.frame = index

	var texture_size: Vector2i = sheet.get_size()
	_info.text = (
		"%dx%d sheet    %dx%d frames    grid %dx%d\nrow %d/%d    frame %d/%d    %s"
		% [
			texture_size.x,
			texture_size.y,
			frame_size.x,
			frame_size.y,
			_columns,
			_rows,
			visible_row + 1,
			_rows,
			column + 1,
			frame_count,
			"playing" if playing else "paused",
		]
	)
	queue_redraw()
