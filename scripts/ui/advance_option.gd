class_name AdvanceOption
extends PanelContainer
## One class a hero can advance into, shown as a card in the advance dialog: a
## chip with its tier, its badge on a soft glow, its name, what each level will
## grow, what it is like, and what the hero still lacks for it.
##
## The whole card is the button when the hero can take the class: click it, or
## focus it and press Enter or Space. A class the hero cannot take yet is dimmed
## and does nothing, so only its requirements need reading. It lifts a little
## under the mouse. Shows what it is told and reports a choice; the dialog
## decides what a choice does.

signal chosen(class_id: StringName)

const MISSING_PREFIX: String = "Needs "
const HOVER_SCALE: float = 1.05
const HOVER_SECONDS: float = 0.08
const INTRO_SECONDS: float = 0.2
const INTRO_START_SCALE: float = 0.85
const LOCKED_TINT: float = 0.7
## How far the card's wood is pulled towards the class colour.
const PLATE_TINT: float = 0.4
## How much lighter than the class colour its text is drawn, to stay readable.
const TEXT_LIGHTEN: float = 0.35
## Brightness text never drops below, so a dark class colour stays readable.
const MIN_TEXT_VALUE: float = 0.85

var _class_id: StringName = &""
var _available: bool = false
var _hovered: bool = false
var _scale_tween: Tween = null

@onready var _plate: PanelContainer = %Plate
@onready var _tag_label: Label = %TagLabel
@onready var _glow: TextureRect = %Glow
@onready var _badge: ClassBadge = %Badge
@onready var _name_label: Label = %NameLabel
@onready var _divider: DividerOrnament = %Divider
@onready var _growth_label: Label = %GrowthLabel
@onready var _description_label: Label = %DescriptionLabel
@onready var _requirement_label: Label = %RequirementLabel


func _ready() -> void:
	mouse_entered.connect(_on_hover_changed.bind(true))
	mouse_exited.connect(_on_hover_changed.bind(false))
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	resized.connect(_centre_pivot)
	_centre_pivot()


func _gui_input(event: InputEvent) -> void:
	if not _available:
		return
	var clicked: bool = (
		event is InputEventMouseButton
		and event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT
	)
	if clicked or event.is_action_pressed(&"ui_accept"):
		accept_event()
		chosen.emit(_class_id)


## The theme's own focus outline, so the card is lit the way a focused button is.
func _draw() -> void:
	if _available and (_hovered or has_focus()):
		draw_style_box(get_theme_stylebox(&"focus", &"Button"), Rect2(Vector2.ZERO, size))


## Show `target` as `hero` sees it. Can be called before ready.
func show_option(hero: HeroData, target: ClassData) -> void:
	_class_id = target.id
	var missing: PackedStringArray = hero.unmet_requirements(target)
	if not is_node_ready():
		await ready
	_available = missing.is_empty()
	_tag_label.text = "TIER %d" % target.tier
	_badge.show_class(target)
	_name_label.text = target.display_name
	_growth_label.text = _growth_text(target)
	_description_label.text = target.description
	_apply_colour(target.color)
	if _available:
		_requirement_label.text = "Ready"
		_requirement_label.theme_type_variation = &"AccentLabel"
	else:
		_requirement_label.text = MISSING_PREFIX + ", ".join(missing)
		_requirement_label.theme_type_variation = &"MutedLabel"
	focus_mode = Control.FOCUS_ALL if _available else Control.FOCUS_NONE
	var tint: float = 1.0 if _available else LOCKED_TINT
	modulate = Color(tint, tint, tint, modulate.a)
	mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND if _available else Control.CURSOR_ARROW
	)
	queue_redraw()


## Whether the hero can take this class, so the dialog knows what to focus.
func is_available() -> bool:
	return _available


## Fade and grow in after `delay` seconds.
func play_intro(delay: float) -> void:
	modulate.a = 0.0
	scale = Vector2.ONE * INTRO_START_SCALE
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, INTRO_SECONDS).set_delay(delay)
	var grow: PropertyTweener = tween.tween_property(self, "scale", Vector2.ONE, INTRO_SECONDS)
	grow.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Tint the card with the class's colour: its wood, the glow behind the badge,
## the divider and the title text.
func _apply_colour(accent: Color) -> void:
	var plate: StyleBoxFlat = _plate.get_theme_stylebox(&"panel").duplicate()
	plate.bg_color = plate.bg_color.lerp(accent, PLATE_TINT)
	_plate.add_theme_stylebox_override(&"panel", plate)
	_glow.modulate = accent
	var text_colour: Color = accent.lightened(TEXT_LIGHTEN)
	text_colour.v = maxf(text_colour.v, MIN_TEXT_VALUE)
	_divider.color = Color(text_colour, _divider.color.a)
	_name_label.add_theme_color_override(&"font_color", text_colour)
	_tag_label.add_theme_color_override(&"font_color", text_colour)


func _growth_text(target: ClassData) -> String:
	var parts: PackedStringArray = []
	for stat_name: StringName in HeroData.STATS:
		if target.stat_growth.has(stat_name):
			var amount: String = String.num(target.stat_growth[stat_name], 1).trim_suffix(".0")
			parts.append("+%s %s" % [amount, String(stat_name).left(3).to_upper()])
	return "  ".join(parts) + " a level"


func _centre_pivot() -> void:
	pivot_offset = size * 0.5


func _on_hover_changed(hovered: bool) -> void:
	_hovered = hovered
	queue_redraw()
	if not _available:
		return
	if _scale_tween != null:
		_scale_tween.kill()
	_scale_tween = create_tween()
	var target: float = HOVER_SCALE if hovered else 1.0
	_scale_tween.tween_property(self, "scale", Vector2.ONE * target, HOVER_SECONDS)
