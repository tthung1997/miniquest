class_name StatRow
extends HBoxContainer
## One stat in the stats panel: its name and value, the points waiting to be
## spent on it, and buttons to add or take back a waiting point (shown as
## "+n" beside the value).
##
## Shows what it is told and asks for changes through signals; the panel
## decides whether a request is allowed.

signal increase_requested(stat_name: StringName)
signal decrease_requested(stat_name: StringName)

## The HeroData stat this row shows, such as &"strength". Set before the row
## enters the tree.
var stat_name: StringName = &""

@onready var _name_label: Label = %NameLabel
@onready var _value_label: Label = %ValueLabel
@onready var _pending_label: Label = %PendingLabel
@onready var _decrease_button: Button = %DecreaseButton
@onready var _increase_button: Button = %IncreaseButton


func _ready() -> void:
	_name_label.text = String(stat_name).left(3).to_upper()
	tooltip_text = String(stat_name).capitalize()
	_decrease_button.pressed.connect(_on_decrease_pressed)
	_increase_button.pressed.connect(_on_increase_pressed)
	show_empty()


## Show `value`, with `pending` waiting points on top of it.
func show_values(
	value: int, pending: int, can_decrease: bool, can_increase: bool
) -> void:
	_value_label.text = str(value)
	_pending_label.text = "+%d" % pending if pending > 0 else ""
	_decrease_button.disabled = not can_decrease
	_increase_button.disabled = not can_increase


## For a screen with no hero to show.
func show_empty() -> void:
	_value_label.text = "--"
	_pending_label.text = ""
	_decrease_button.disabled = true
	_increase_button.disabled = true


func _on_decrease_pressed() -> void:
	decrease_requested.emit(stat_name)


func _on_increase_pressed() -> void:
	increase_requested.emit(stat_name)
