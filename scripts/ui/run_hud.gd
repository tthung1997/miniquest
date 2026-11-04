class_name RunHud
extends Control
## The arena run's heads-up display: the hero's health, the run's level and
## experience, the clock with the elite's arrival marked on it, gold and item
## counters, and a controls hint.
##
## It only shows what it is handed. Whoever owns the run calls the show_*
## methods when a value changes, so nothing here polls and nothing reaches up
## the tree. Lives in the top corners and bottom-left, clear of the skill bar,
## the elite bar and the threat arrows.

@onready var _health_bar: ProgressBar = %HealthBar
@onready var _health_label: Label = %HealthLabel
@onready var _level_label: Label = %LevelLabel
@onready var _exp_bar: ProgressBar = %ExpBar
@onready var _exp_label: Label = %ExpLabel
@onready var _clock_label: Label = %ClockLabel
@onready var _clock_bar: ProgressBar = %ClockBar
@onready var _elite_marker: ColorRect = %EliteMarker
@onready var _gold_label: Label = %GoldLabel
@onready var _items_label: Label = %ItemsLabel
@onready var _kills_label: Label = %KillsLabel

var _duration: float = 0.0


## Set the run's length and when the elite arrives, both in seconds. The elite's
## time is marked on the clock bar; leave it out of range for no mark.
func configure(duration: float, elite_time: float) -> void:
	_duration = duration
	_clock_bar.max_value = maxf(duration, 1.0)
	var marked: bool = duration > 0.0 and elite_time > 0.0 and elite_time < duration
	_elite_marker.visible = marked
	if marked:
		var at: float = elite_time / duration
		_elite_marker.anchor_left = at
		_elite_marker.anchor_right = at
	show_time(0.0)


func show_health(current: float, maximum: float) -> void:
	_health_bar.max_value = maxf(maximum, 1.0)
	_health_bar.value = current
	_health_label.text = "%d / %d" % [ceili(current), roundi(maximum)]


## `progress` is the experience earned towards the next level (x) and what that
## level needs (y).
func show_progress(level: int, progress: Vector2i) -> void:
	_level_label.text = "Lv %d" % level
	_exp_bar.max_value = maxf(progress.y, 1.0)
	_exp_bar.value = progress.x
	_exp_label.text = "%d / %d" % [progress.x, progress.y]


func show_time(elapsed: float) -> void:
	_clock_bar.value = elapsed
	_clock_label.text = "%s / %s" % [RunResult.clock(elapsed), RunResult.clock(_duration)]


func show_gold(gold: int) -> void:
	_gold_label.text = str(gold)


func show_items(count: int) -> void:
	_items_label.text = str(count)


func show_kills(kills: int) -> void:
	_kills_label.text = "KILLS %d" % kills
