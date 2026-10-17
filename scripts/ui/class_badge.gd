class_name ClassBadge
extends Control
## A class's icon with its tier marked on it: a bronze, silver or gold plate
## around the icon, or the icon alone with a gem under it for each tier.
##
## Shows what it is told. Tier 0 is bronze with no gems, tier 1 silver with one,
## tier 2 gold with two. A tier past the art reuses the highest plate, so a new
## tier shows up as gold until it gets its own.

enum Style { PLATE, PIPS }

const PLATES: Array[Texture2D] = [
	preload("res://assets/sprites/ui/tier/plate_bronze.png"),
	preload("res://assets/sprites/ui/tier/plate_silver.png"),
	preload("res://assets/sprites/ui/tier/plate_gold.png"),
]
const PIP: Texture2D = preload("res://assets/sprites/ui/tier/pip.png")
const ICON_SIZE: int = 16
## Frame width around the icon in a plate.
const PLATE_BORDER: int = 2
const PIP_SIZE: int = 5
## Gap between the icon and its gems.
const PIP_GAP: int = 1

@export var style: Style = Style.PLATE:
	set(value):
		style = value
		_layout()
## Whole-number scale keeps the pixel art crisp.
@export_range(1, 4) var badge_scale: int = 1:
	set(value):
		badge_scale = value
		_layout()

var _tier: int = 0

@onready var _frame: TextureRect = %Frame
@onready var _icon: TextureRect = %Icon
@onready var _pips: HBoxContainer = %Pips


func _ready() -> void:
	_layout()


## Show `target`'s icon and tier, or nothing for null. Can be called before
## ready.
func show_class(target: ClassData) -> void:
	if not is_node_ready():
		await ready
	visible = target != null
	if target == null:
		return
	_tier = target.tier
	_icon.texture = target.icon
	_frame.texture = PLATES[mini(_tier, PLATES.size() - 1)]
	_refresh_pips()


func _layout() -> void:
	if not is_node_ready():
		return
	var scaled: int = badge_scale
	_frame.visible = style == Style.PLATE
	_pips.visible = style == Style.PIPS
	if style == Style.PLATE:
		var side: int = (ICON_SIZE + PLATE_BORDER * 2) * scaled
		custom_minimum_size = Vector2(side, side)
		_frame.position = Vector2.ZERO
		_frame.size = Vector2(side, side)
		_icon.position = Vector2.ONE * PLATE_BORDER * scaled
	else:
		# Height is reserved even with no gems, so a row of badges stays level.
		var height: int = (ICON_SIZE + PIP_GAP + PIP_SIZE) * scaled
		custom_minimum_size = Vector2(ICON_SIZE * scaled, height)
		_icon.position = Vector2.ZERO
		_pips.position = Vector2(0, (ICON_SIZE + PIP_GAP) * scaled)
		_pips.size = Vector2(ICON_SIZE * scaled, PIP_SIZE * scaled)
		# Neighbouring gems share an outline pixel.
		_pips.add_theme_constant_override(&"separation", -scaled)
	_icon.size = Vector2.ONE * ICON_SIZE * scaled
	_refresh_pips()


func _refresh_pips() -> void:
	for pip: Node in _pips.get_children():
		pip.queue_free()
		_pips.remove_child(pip)
	if style != Style.PIPS:
		return
	for _i: int in _tier:
		var gem: TextureRect = TextureRect.new()
		gem.texture = PIP
		gem.custom_minimum_size = Vector2.ONE * PIP_SIZE * badge_scale
		gem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		gem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pips.add_child(gem)
