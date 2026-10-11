class_name PauseMenu
extends Control
## The pause overlay: resume the run, or give it up.
##
## It only reports the player's choice. Pausing the tree, and what retreating
## costs, are the run's business. Must keep processing while the tree is
## paused, so whoever instances it sets its process mode to Always.

signal resume_requested
signal retreat_requested

@onready var _resume_button: Button = %ResumeButton
@onready var _retreat_button: Button = %RetreatButton


func _ready() -> void:
	_resume_button.pressed.connect(resume_requested.emit)
	_retreat_button.pressed.connect(retreat_requested.emit)
	hide()


func open() -> void:
	show()
	_resume_button.grab_focus()


func close() -> void:
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"pause") and not event.is_echo():
		get_viewport().set_input_as_handled()
		resume_requested.emit()
