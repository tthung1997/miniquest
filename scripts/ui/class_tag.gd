class_name ClassTag
extends HBoxContainer
## A line of accent text with a class badge before it, such as the "Lv 5  Mage"
## under a hero's name. Shows what it is told.
##
## It can also act as a button: show_action() makes it clickable and focusable,
## with a cue after the text, and it reports activation with pressed.

signal pressed

## How far the hover and focus frames reach past the tag's edges.
const FRAME_GROW: float = 3.0

## How the badge marks the class's tier: a plate around the icon, or gems
## under it.
@export var badge_style: ClassBadge.Style = ClassBadge.Style.PLATE:
	set(value):
		badge_style = value
		if is_node_ready():
			_badge.style = value

var _actionable: bool = false
var _action_ready: bool = false
var _hovered: bool = false

@onready var _badge: ClassBadge = %Badge
@onready var _label: Label = %Label
@onready var _cue: Label = %Cue


func _ready() -> void:
	_badge.style = badge_style
	mouse_entered.connect(_on_hover_changed.bind(true))
	mouse_exited.connect(_on_hover_changed.bind(false))
	_refresh_action()


func _notification(what: int) -> void:
	if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not _actionable:
		return
	if event.is_action_pressed(&"ui_accept") and not event.is_echo():
		accept_event()
		pressed.emit()
	elif event is InputEventMouseButton:
		var click: InputEventMouseButton = event
		if click.button_index == MOUSE_BUTTON_LEFT and click.pressed:
			accept_event()
			pressed.emit()


func _draw() -> void:
	if not _actionable:
		return
	var frame: Rect2 = Rect2(Vector2.ONE * -FRAME_GROW, size + Vector2.ONE * FRAME_GROW * 2.0)
	if _hovered:
		draw_style_box(get_theme_stylebox(&"hover", &"QuietButton"), frame)
	if has_focus():
		draw_style_box(get_theme_stylebox(&"focus", &"Button"), frame)


## Show `text`, with `target`'s badge before it when there is one. Can be
## called before ready.
func show_text(text: String, target: ClassData = null) -> void:
	if not is_node_ready():
		await ready
	_label.text = text
	_badge.show_class(target)


## Make the tag a button, or plain text again. `highlighted` swaps the quiet
## cue for an exclamation mark. Can be called before ready.
func show_action(actionable: bool, highlighted: bool = false, tip: String = "") -> void:
	_actionable = actionable
	_action_ready = highlighted
	tooltip_text = tip if actionable else ""
	if is_node_ready():
		_refresh_action()


func _refresh_action() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if _actionable else Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_ALL if _actionable else Control.FOCUS_NONE
	mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND if _actionable else Control.CURSOR_ARROW
	)
	_cue.visible = _actionable
	_cue.text = "!" if _action_ready else ">"
	_cue.theme_type_variation = &"AccentLabel" if _action_ready else &"MutedLabel"
	if not _actionable:
		_hovered = false
	queue_redraw()


func _on_hover_changed(hovered: bool) -> void:
	_hovered = hovered and _actionable
	queue_redraw()
