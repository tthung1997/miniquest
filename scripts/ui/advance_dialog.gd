class_name AdvanceDialog
extends Control
## Lists the classes the hero can advance into and lets them pick one, drawn
## over the screen that opened it.
##
## Advancing is permanent, so a pick is confirmed first. Reports the confirmed
## class and nothing else: changing the hero and saving are the owner's
## business.

signal class_chosen(class_id: StringName)
signal closed

## Seconds between one card starting to appear and the next.
const INTRO_STAGGER: float = 0.08

## One AdvanceOption per class on offer.
@export var option_scene: PackedScene

var _options: Array[AdvanceOption] = []
var _picked: StringName = &""

@onready var _note_label: Label = %NoteLabel
@onready var _option_row: HBoxContainer = %OptionRow
@onready var _close_button: Button = %CloseButton
@onready var _confirm_dialog: ConfirmDialog = %ConfirmDialog


func _ready() -> void:
	_close_button.pressed.connect(close)
	_confirm_dialog.confirmed.connect(_on_confirmed)
	_confirm_dialog.cancelled.connect(_focus_first_choice)
	hide()


func _input(event: InputEvent) -> void:
	if visible and not _confirm_dialog.visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## Show what `hero` can advance into. `note` is a line of advice for the
## player, such as why a requirement may look unmet.
func open(hero: HeroData, note: String = "") -> void:
	if option_scene == null:
		push_error("AdvanceDialog: option_scene must be wired to show the classes.")
		return
	_clear_options()
	for target: ClassData in hero.advancement_options():
		var node: Node = option_scene.instantiate()
		if node is not AdvanceOption:
			push_error("AdvanceDialog: option_scene must have an AdvanceOption root.")
			node.free()
			return
		var option: AdvanceOption = node
		_option_row.add_child(option)
		option.show_option(hero, target)
		option.play_intro(_options.size() * INTRO_STAGGER)
		option.chosen.connect(_on_option_chosen)
		_options.append(option)
	_note_label.text = note
	_note_label.visible = not note.is_empty()
	show()
	_focus_first_choice()


func close() -> void:
	hide()
	closed.emit()


func _clear_options() -> void:
	for option: AdvanceOption in _options:
		option.queue_free()
	_options.clear()


## The first class the hero can take, or else the close button.
func _focus_first_choice() -> void:
	for option: AdvanceOption in _options:
		if option.is_available():
			option.grab_focus()
			return
	_close_button.grab_focus()


func _on_option_chosen(class_id: StringName) -> void:
	var target: ClassData = ClassData.find(class_id)
	if target == null:
		return
	_picked = class_id
	_confirm_dialog.open(
		"Become a %s? This cannot be undone." % target.display_name, "BECOME", "CANCEL"
	)


func _on_confirmed() -> void:
	var picked: StringName = _picked
	_picked = &""
	hide()
	class_chosen.emit(picked)
