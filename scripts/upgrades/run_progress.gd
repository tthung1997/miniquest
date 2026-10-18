class_name RunProgress
extends RefCounted
## A run's own levelling: the experience earned so far this run and the level it
## has reached (DESIGN.md section 6.3). Each level earns an upgrade pick. It
## starts at level 1 every run and is forgotten when the run ends; banked
## experience is a separate tally.

var level: int = 1
## Experience earned this run.
var experience: int = 0

var _quest: QuestData = null


func _init(quest: QuestData) -> void:
	_quest = quest


## Add `amount` experience. Returns how many levels it gained.
func add_experience(amount: int) -> int:
	experience += maxi(amount, 0)
	var gained: int = 0
	while experience >= _total_for(level + 1):
		level += 1
		gained += 1
	return gained


## How far through the current level: x is earned towards the next, y is what
## it needs.
func progress() -> Vector2i:
	var start: int = _total_for(level)
	return Vector2i(experience - start, _total_for(level + 1) - start)


func _total_for(target_level: int) -> int:
	var total: int = 0
	for step: int in target_level - 1:
		total += _quest.run_exp_to_leave(step + 1)
	return total
