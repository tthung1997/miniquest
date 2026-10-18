class_name UpgradeOption
extends PanelContainer
## One choice on the level-up overlay, shown as a card: a ribbon saying what
## kind of upgrade it is, the icon on a soft glow, its name and what it does.
## The whole card is the button: click it, or focus it and press Enter or Space.
## It lifts a little under the mouse. It reports a pick; the overlay decides
## what a pick means.

signal chosen(offer: UpgradeOffer)

const HOVER_SCALE: float = 1.05
const HOVER_SECONDS: float = 0.08
const INTRO_SECONDS: float = 0.2
const INTRO_START_SCALE: float = 0.85

var _offer: UpgradeOffer = null
var _enabled: bool = false
var _hovered: bool = false
var _scale_tween: Tween = null

@onready var _frame: SkillFrame = %Frame
@onready var _tag_label: Label = %TagLabel
@onready var _name_label: Label = %NameLabel
@onready var _description_label: Label = %DescriptionLabel


func _ready() -> void:
	mouse_entered.connect(_on_hover_changed.bind(true))
	mouse_exited.connect(_on_hover_changed.bind(false))
	focus_entered.connect(_on_focus_changed)
	focus_exited.connect(_on_focus_changed)
	resized.connect(_centre_pivot)
	_centre_pivot()


func _gui_input(event: InputEvent) -> void:
	if not _enabled:
		return
	var clicked: bool = (
		event is InputEventMouseButton
		and event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT
	)
	if clicked or event.is_action_pressed(&"ui_accept"):
		accept_event()
		chosen.emit(_offer)


## The theme's own focus outline, so the card is lit the way a focused button is.
func _draw() -> void:
	if _enabled and (_hovered or has_focus()):
		draw_style_box(get_theme_stylebox(&"focus", &"Button"), Rect2(Vector2.ZERO, size))


## Show `offer`. Can be called before ready.
func show_offer(offer: UpgradeOffer) -> void:
	_offer = offer
	if not is_node_ready():
		await ready
	_frame.icon = offer.icon()
	_tag_label.text = offer.tag()
	_name_label.text = offer.title()
	_description_label.text = offer.description()


## Fade and grow in after `delay` seconds. Runs while the tree is paused.
func play_intro(delay: float) -> void:
	modulate.a = 0.0
	scale = Vector2.ONE * INTRO_START_SCALE
	var tween: Tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, INTRO_SECONDS).set_delay(delay)
	var grow: PropertyTweener = tween.tween_property(self, "scale", Vector2.ONE, INTRO_SECONDS)
	grow.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Whether the card answers clicks and keys. The overlay keeps the cards off
## for a moment after it opens.
func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND if enabled else Control.CURSOR_ARROW
	)
	queue_redraw()


func _centre_pivot() -> void:
	pivot_offset = size * 0.5


func _on_hover_changed(hovered: bool) -> void:
	_hovered = hovered
	queue_redraw()
	if not _enabled:
		return
	if _scale_tween != null:
		_scale_tween.kill()
	_scale_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var target: float = HOVER_SCALE if hovered else 1.0
	_scale_tween.tween_property(self, "scale", Vector2.ONE * target, HOVER_SECONDS)


func _on_focus_changed() -> void:
	queue_redraw()
