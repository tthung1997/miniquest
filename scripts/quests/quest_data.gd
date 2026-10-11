class_name QuestData
extends Resource
## One quest's clock and difficulty ramp. Instances live in resources/quests/.
##
## There is one ramp per quest, shared by every hero (DESIGN.md section 4). A
## hero's level only decides where on it the run starts, so a run covers the
## ramp from start_for(level) for `duration` seconds. The ramp itself is a
## handful of values that rise from their `_start` to their `_end` as the ramp
## time goes from zero to ramp_length(), bent by `ramp_exponent`.
##
## All the numbers are placeholders, to be tuned by play.

@export var id: StringName = &""
@export var display_name: String = ""

@export_group("Run")
## How long a run lasts, for every hero. Surviving this long wins it.
@export_range(30.0, 1800.0, 1.0, "suffix:s") var duration: float = 300.0

@export_group("Level shift")
## Seconds of ramp a hero skips for each level above 1.
@export_range(0.0, 60.0, 0.5, "suffix:s") var start_per_level: float = 5.0
## The most ramp a hero can skip, however high their level.
@export_range(0.0, 600.0, 1.0, "suffix:s") var start_cap: float = 120.0

@export_group("Ramp")
## Above 1 the ramp stays gentle for longer and bites late; below 1 it bites
## early and levels off.
@export_range(0.25, 4.0, 0.05) var ramp_exponent: float = 1.0
## Seconds between one enemy arriving and the next.
@export_range(0.05, 10.0, 0.05, "suffix:s") var spawn_interval_start: float = 1.5
@export_range(0.05, 10.0, 0.05, "suffix:s") var spawn_interval_end: float = 0.3
## Most enemies alive at once.
@export_range(1, 500) var max_alive_start: int = 8
@export_range(1, 500) var max_alive_end: int = 50
## Multipliers on every enemy's health and contact damage.
@export_range(0.1, 50.0, 0.1) var health_scale_start: float = 1.0
@export_range(0.1, 50.0, 0.1) var health_scale_end: float = 4.0
@export_range(0.1, 50.0, 0.1) var damage_scale_start: float = 1.0
@export_range(0.1, 50.0, 0.1) var damage_scale_end: float = 2.0


## Where on the ramp, in seconds, a hero of `level` begins.
func start_for(level: int) -> float:
	return minf(start_cap, start_per_level * maxi(level - 1, 0))


## The whole ramp, in seconds: everything a run can reach.
func ramp_length() -> float:
	return start_cap + duration


## How far along the ramp `ramp_time` is, from 0.0 to 1.0, after bending.
func progress_at(ramp_time: float) -> float:
	return pow(clampf(ramp_time / ramp_length(), 0.0, 1.0), ramp_exponent)


func spawn_interval_at(progress: float) -> float:
	return lerpf(spawn_interval_start, spawn_interval_end, progress)


func max_alive_at(progress: float) -> int:
	return roundi(lerpf(max_alive_start, max_alive_end, progress))


func health_scale_at(progress: float) -> float:
	return lerpf(health_scale_start, health_scale_end, progress)


func damage_scale_at(progress: float) -> float:
	return lerpf(damage_scale_start, damage_scale_end, progress)
