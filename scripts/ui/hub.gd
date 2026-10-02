class_name Hub
extends Control
## The selected hero's home screen: the hero on a stage, flanked by feature slots.
##
## Displays the supplied hero without loading, saving or changing their data.
## Feature screens are not built yet, so their slots are locked. Start Quest and
## Change Hero report choices to the screen owner. Runs standalone with an
## unselected portrait.

signal quest_requested
signal change_hero_requested

## Portrait size in unscaled doll pixels: the 64px frame plus a little air, and
## the 48px body plus headroom and the dais below its feet.
const PORTRAIT_SIZE: Vector2 = Vector2(72.0, 66.0)
## Distance from the portrait's bottom edge to the hero's feet, in doll pixels.
const FEET_MARGIN: float = 13.0

## Whole-number scale keeps the pixel art crisp. 4x does not fit 360 lines
## alongside the nameplate, top bar and Start Quest.
@export_range(1, 3) var doll_scale: int = 3

var _hero: HeroData = null

@onready var _portrait: NinePatchRect = %Portrait
@onready var _doll_anchor: Node2D = %DollAnchor
@onready var _doll: PaperDoll = %PaperDoll
@onready var _name_label: Label = %NameLabel
@onready var _info_label: Label = %InfoLabel
@onready var _gold_label: Label = %GoldLabel
@onready var _exp_label: Label = %ExpLabel
@onready var _quest_button: Button = %QuestButton
@onready var _change_hero_button: Button = %ChangeHeroButton


func _ready() -> void:
	_doll_anchor.scale = Vector2.ONE * doll_scale
	_portrait.custom_minimum_size = PORTRAIT_SIZE * doll_scale
	_portrait.resized.connect(_place_doll)
	_quest_button.pressed.connect(_on_quest_pressed)
	_change_hero_button.pressed.connect(_on_change_hero_pressed)
	_place_doll()
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		change_hero_requested.emit()


## Can be called before ready, or when updating the visible hero.
func show_hero(hero: HeroData) -> void:
	if hero == null:
		push_error("Hub: cannot display an empty hero.")
		return
	_hero = hero
	if is_node_ready():
		_refresh()


func _refresh() -> void:
	_quest_button.disabled = _hero == null
	if _hero == null:
		_name_label.text = "No hero selected"
		_info_label.text = "Choose a hero to start"
		_gold_label.text = "--"
		_exp_label.text = "--"
		_change_hero_button.grab_focus()
		return

	var hero_class: ClassData = _hero.class_data()
	var class_text: String = (
		hero_class.display_name if hero_class != null else String(_hero.class_id)
	)
	_name_label.text = _hero.hero_name
	_info_label.text = "Lv %d  %s" % [_hero.level, class_text]
	_gold_label.text = str(_hero.gold)
	_exp_label.text = str(_hero.experience)
	_doll.wear_armour(_hero.armour)
	_quest_button.grab_focus()


func _place_doll() -> void:
	_doll_anchor.position = Vector2(
		roundf(_portrait.size.x * 0.5), roundf(_portrait.size.y - FEET_MARGIN * doll_scale)
	)


func _on_quest_pressed() -> void:
	quest_requested.emit()


func _on_change_hero_pressed() -> void:
	change_hero_requested.emit()
