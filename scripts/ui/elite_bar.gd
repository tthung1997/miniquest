class_name EliteBar
extends Control
## The HUD's boss bar: a warning when the elite arrives, then its name and a
## bar that follows its health until it falls. Hidden until `show_elite()`.
## Knows nothing about the run; whoever owns it hands it the elite.

const WARNING_TIME: float = 2.5
const WARNING_COLOR: Color = Color(1.0, 0.35, 0.3)
const NAME_COLOR: Color = Color(1.0, 0.9, 0.7)

var _elite: Enemy = null
var _tween: Tween = null

@onready var _name_label: Label = %NameLabel
@onready var _back: ColorRect = %Back
@onready var _fill: ColorRect = %Fill


func _ready() -> void:
	hide()


## Warn of `elite` and follow its health from now on.
func show_elite(elite: Enemy) -> void:
	if elite == null or elite.health == null:
		push_error("EliteBar: needs a spawned elite with health.")
		return
	_elite = elite
	elite.health.changed.connect(_on_health_changed)
	elite.died.connect(_on_elite_died)
	_name_label.text = "%s approaches!" % elite.data.display_name.to_upper()
	_name_label.add_theme_color_override(&"font_color", WARNING_COLOR)
	_back.hide()
	_fill.hide()
	show()
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(WARNING_TIME)
	_tween.tween_callback(_show_health)


func _show_health() -> void:
	if _elite == null:
		return
	_name_label.text = _elite.data.display_name.to_upper()
	_name_label.add_theme_color_override(&"font_color", NAME_COLOR)
	_back.show()
	_fill.show()
	_on_health_changed(_elite.health.current, _elite.health.maximum)


func _on_health_changed(current: float, maximum: float) -> void:
	_fill.size.x = _back.size.x * clampf(current / maximum, 0.0, 1.0)


func _on_elite_died(_enemy: Enemy) -> void:
	_elite = null
	if _tween != null:
		_tween.kill()
	hide()
