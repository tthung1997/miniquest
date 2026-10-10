class_name Health
extends RefCounted
## Hit points for anything that can be hurt, with no knowledge of its owner.
##
## The owner builds one, calls take_damage(), and listens for the signals; a
## hero and an enemy use it the same way.

## The hit points changed in either direction, for a health bar to follow.
signal changed(current: float, maximum: float)
## `amount` was actually lost, after clamping to what was left.
signal damaged(amount: float)
## The hit points reached zero. Emitted once.
signal died

var maximum: float = 1.0
var current: float = 1.0


func _init(max_health: float = 1.0) -> void:
	if max_health <= 0.0:
		push_error("Health: maximum must be above zero, got %s." % max_health)
		max_health = 1.0
	maximum = max_health
	current = max_health


func is_dead() -> bool:
	return current <= 0.0


## Fraction of the maximum left, from 0.0 to 1.0.
func ratio() -> float:
	return current / maximum


## Lose `amount`, never going below zero. Returns what was actually lost, which
## is zero once dead.
func take_damage(amount: float) -> float:
	if amount < 0.0:
		push_error("Health: damage must not be negative, got %s." % amount)
		return 0.0
	if is_dead() or is_zero_approx(amount):
		return 0.0

	var lost: float = minf(amount, current)
	current -= lost
	damaged.emit(lost)
	changed.emit(current, maximum)
	if is_dead():
		died.emit()
	return lost


## Gain `amount`, never going above the maximum. The dead stay dead. Returns
## what was actually gained.
func heal(amount: float) -> float:
	if amount < 0.0:
		push_error("Health: healing must not be negative, got %s." % amount)
		return 0.0
	if is_dead() or is_zero_approx(amount):
		return 0.0

	var gained: float = minf(amount, maximum - current)
	if is_zero_approx(gained):
		return 0.0
	current += gained
	changed.emit(current, maximum)
	return gained
