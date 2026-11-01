class_name FloatingText
extends Node2D
## A short word that drifts up from where it appears and fades, such as the
## "CRIT!" over a critical hit. Frees itself when done. Built in code: it needs
## no scene.

const LIFETIME: float = 0.7
const DRIFT: float = 14.0

var _text: String = ""
var _color: Color = Color.WHITE


## A new floating text, not yet in the tree.
static func create(text: String, color: Color) -> FloatingText:
	var floating: FloatingText = FloatingText.new()
	floating._text = text
	floating._color = color
	return floating


func _ready() -> void:
	var label: Label = Label.new()
	label.text = _text
	label.modulate = _color
	label.add_theme_font_size_override(&"font_size", 12)
	label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	label.add_theme_constant_override(&"outline_size", 3)
	label.position = Vector2(-label.get_minimum_size().x * 0.5, -8.0)
	add_child(label)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", -DRIFT, LIFETIME).as_relative()
	tween.tween_property(self, "modulate:a", 0.0, LIFETIME).set_delay(LIFETIME * 0.4)
	tween.chain().tween_callback(queue_free)
