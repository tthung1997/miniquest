class_name TitleScreen
extends Control

signal start_pressed

@onready var _start_button: Button = %StartButton


func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	_start_button.grab_focus()


func _on_start_pressed() -> void:
	start_pressed.emit()
