class_name HeldSkill
extends RefCounted
## One skill a hero is carrying through a run: the template, the level it is at
## for this run, and how long until it can be cast again. Runs are disposable,
## so none of this is saved; the permanent part is in HeroData.

var data: SkillData = null
## Permanent level plus whatever the run's offers added, up to the skill's max.
var level: int = 1
var cooldown_left: float = 0.0


func _init(skill: SkillData = null, start_level: int = 1) -> void:
	data = skill
	level = start_level


func is_ready() -> bool:
	return cooldown_left <= 0.0


## Seconds between casts at the current level.
func cooldown() -> float:
	return data.cooldown_at(level)


func is_maxed() -> bool:
	return level >= data.max_level


## Fraction of the cooldown still to run, from 0.0 (ready) to 1.0.
func cooldown_ratio() -> float:
	return clampf(cooldown_left / maxf(cooldown(), 0.01), 0.0, 1.0)
