class_name Hub
extends Control
## The selected hero's home screen: a portrait, readouts and build-layer actions.
##
## Displays the supplied hero without loading, saving or changing their data.
## Feature screens are not built yet; Start Quest and Change Hero report choices
## to the screen owner. Runs standalone with an unselected portrait.

signal quest_requested
signal change_hero_requested

const DOLL_FEET_MARGIN: float = 18.0
const DOLL_HEIGHT: float = 48.0
const FRAME_SIZE: float = 64.0

@export_range(1, 4) var doll_scale: int = 3

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
	_portrait.custom_minimum_size = Vector2(
		FRAME_SIZE * doll_scale, DOLL_HEIGHT * doll_scale + DOLL_FEET_MARGIN + 6.0
	)
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
		_gold_label.text = "Gold --"
		_exp_label.text = "EXP --"
		_change_hero_button.grab_focus()
		return

	var hero_class: ClassData = _hero.class_data()
	var class_text: String = (
		hero_class.display_name if hero_class != null else String(_hero.class_id)
	)
	_name_label.text = _hero.hero_name
	_info_label.text = "Lv %d  %s" % [_hero.level, class_text]
	_gold_label.text = "Gold %d" % _hero.gold
	_exp_label.text = "EXP %d" % _hero.experience
	_doll.wear_armour(_hero.armour)
	_quest_button.grab_focus()


func _place_doll() -> void:
	_doll_anchor.position = Vector2(
		roundf(_portrait.size.x * 0.5), roundf(_portrait.size.y - DOLL_FEET_MARGIN)
	)


func _on_quest_pressed() -> void:
	quest_requested.emit()


func _on_change_hero_pressed() -> void:
	change_hero_requested.emit()
