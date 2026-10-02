class_name NameDialog
extends Control
## Asks for a new hero's name, drawn over the screen that opened it.
##
## Reports the result as a signal and does nothing else. The name it emits is
## already cleaned by HeroData.clean_name, so a blank or whitespace-only name
## can never be confirmed.

signal confirmed(hero_name: String)
signal cancelled

@onready var _edit: LineEdit = %NameEdit
@onready var _create_button: Button = %CreateButton
@onready var _cancel_button: Button = %CancelButton


func _ready() -> void:
	_edit.max_length = HeroData.NAME_MAX_LENGTH
	_edit.text_changed.connect(_on_text_changed)
	_edit.text_submitted.connect(_on_text_submitted)
	_create_button.pressed.connect(_submit)
	_cancel_button.pressed.connect(_cancel)
	hide()


func open() -> void:
	_edit.clear()
	_refresh()
	show()
	_edit.grab_focus()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_cancel()


func _submit() -> void:
	var cleaned: String = HeroData.clean_name(_edit.text)
	if cleaned.is_empty():
		return
	hide()
	confirmed.emit(cleaned)


func _cancel() -> void:
	hide()
	cancelled.emit()


func _refresh() -> void:
	_create_button.disabled = HeroData.clean_name(_edit.text).is_empty()


func _on_text_changed(_text: String) -> void:
	_refresh()


func _on_text_submitted(_text: String) -> void:
	_submit()
