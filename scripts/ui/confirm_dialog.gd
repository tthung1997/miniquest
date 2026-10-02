class_name ConfirmDialog
extends Control
## Asks the player to confirm something, drawn over the screen that opened it.
##
## Focus starts on the cancel button, so a stray Enter keeps things as they are.
## Reports the answer as a signal and does nothing else.

signal confirmed
signal cancelled

@onready var _message: Label = %Message
@onready var _confirm_button: Button = %ConfirmButton
@onready var _cancel_button: Button = %CancelButton


func _ready() -> void:
	_confirm_button.pressed.connect(_confirm)
	_cancel_button.pressed.connect(_cancel)
	hide()


func open(message: String, confirm_text: String, cancel_text: String) -> void:
	_message.text = message
	_confirm_button.text = confirm_text
	_cancel_button.text = cancel_text
	show()
	_cancel_button.grab_focus()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_cancel()


func _confirm() -> void:
	hide()
	confirmed.emit()


func _cancel() -> void:
	hide()
	cancelled.emit()
