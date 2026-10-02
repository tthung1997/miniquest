class_name HeroSlotCard
extends PanelContainer
## One hero save slot on the character selection screen.
##
## Purely presentational: it shows a hero, an empty slot, or a slot whose save
## cannot be read, and reports button presses as signals. It never loads, saves
## or deletes anything; the screen that owns it decides what a press means.

signal play_pressed(slot: int)
signal delete_pressed(slot: int)
signal create_pressed(slot: int)

const DOLL_SCALE: float = 2.0
## Gap between the doll's feet and the bottom edge of the portrait frame.
const DOLL_FEET_MARGIN: float = 18.0

@export_range(0, 2) var slot: int = 0

@onready var _portrait: NinePatchRect = %Portrait
@onready var _doll_anchor: Node2D = %DollAnchor
@onready var _doll: PaperDoll = %PaperDoll
@onready var _name_label: Label = %NameLabel
@onready var _info_label: Label = %InfoLabel
@onready var _play_button: Button = %PlayButton
@onready var _delete_button: Button = %DeleteButton
@onready var _create_button: Button = %CreateButton


func _ready() -> void:
	_doll_anchor.scale = Vector2(DOLL_SCALE, DOLL_SCALE)
	_portrait.resized.connect(_place_doll)
	_play_button.pressed.connect(_on_play_pressed)
	_delete_button.pressed.connect(_on_delete_pressed)
	_create_button.pressed.connect(_on_create_pressed)
	_place_doll()
	show_empty()


func show_hero(hero: HeroData) -> void:
	var hero_class: ClassData = hero.class_data()
	var class_name_text: String = (
		hero_class.display_name if hero_class != null else String(hero.class_id)
	)
	_name_label.text = hero.hero_name
	_info_label.text = "Lv %d  %s" % [hero.level, class_name_text]
	_doll.wear_armour(hero.armour)
	_show_state(true, true, false)


func show_empty() -> void:
	_name_label.text = "Empty slot"
	_info_label.text = "Slot %d" % (slot + 1)
	_show_state(false, false, true)


func show_unreadable() -> void:
	_name_label.text = "Unreadable"
	_info_label.text = "Save can't be read"
	_show_state(false, true, false)


## Stop the card taking keyboard focus while a dialog is open over it. Mouse
## input is already blocked by the dialog's backdrop.
func set_interactive(interactive: bool) -> void:
	var mode: Control.FocusMode = Control.FOCUS_ALL if interactive else Control.FOCUS_NONE
	for button: Button in [_play_button, _delete_button, _create_button]:
		button.focus_mode = mode


## Focus the card's main action: Play, or New Hero for an empty slot.
func focus_primary() -> void:
	for button: Button in [_play_button, _create_button, _delete_button]:
		if button.is_visible_in_tree() and button.focus_mode != Control.FOCUS_NONE:
			button.grab_focus()
			return


func _show_state(has_doll: bool, can_delete: bool, can_create: bool) -> void:
	_doll_anchor.visible = has_doll
	_play_button.visible = has_doll
	_delete_button.visible = can_delete
	_create_button.visible = can_create


func _place_doll() -> void:
	_doll_anchor.position = Vector2(_portrait.size.x * 0.5, _portrait.size.y - DOLL_FEET_MARGIN)


func _on_play_pressed() -> void:
	play_pressed.emit(slot)


func _on_delete_pressed() -> void:
	delete_pressed.emit(slot)


func _on_create_pressed() -> void:
	create_pressed.emit(slot)
