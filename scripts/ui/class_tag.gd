class_name ClassTag
extends HBoxContainer
## A line of accent text with a class badge before it, such as the "Lv 5  Mage"
## under a hero's name. Shows what it is told.

## How the badge marks the class's tier: a plate around the icon, or gems
## under it.
@export var badge_style: ClassBadge.Style = ClassBadge.Style.PLATE:
	set(value):
		badge_style = value
		if is_node_ready():
			_badge.style = value

@onready var _badge: ClassBadge = %Badge
@onready var _label: Label = %Label


func _ready() -> void:
	_badge.style = badge_style


## Show `text`, with `target`'s badge before it when there is one. Can be
## called before ready.
func show_text(text: String, target: ClassData = null) -> void:
	if not is_node_ready():
		await ready
	_label.text = text
	_badge.show_class(target)
