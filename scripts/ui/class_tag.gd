class_name ClassTag
extends HBoxContainer
## A line of accent text with an optional class icon before it, such as the
## "Lv 5  Mage" under a hero's name. Shows what it is told.

@onready var _icon: TextureRect = %Icon
@onready var _label: Label = %Label


## Show `text`, with `icon` before it when there is one. Can be called before
## ready.
func show_text(text: String, icon: Texture2D = null) -> void:
	if not is_node_ready():
		await ready
	_label.text = text
	_icon.texture = icon
	_icon.visible = icon != null
