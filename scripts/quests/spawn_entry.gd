class_name SpawnEntry
extends Resource
## One enemy a quest can spawn, with when it joins the mix and how often it is
## picked. A quest holds a list of these (DESIGN.md section 4).

@export var enemy: EnemyData
## How likely this enemy is next to the others available at the same moment.
@export_range(0.0, 100.0, 0.1) var weight: float = 1.0
## Ramp progress, 0.0 to 1.0, from which this enemy can appear.
@export_range(0.0, 1.0, 0.01) var from_progress: float = 0.0
## Ramp progress after which it stops appearing.
@export_range(0.0, 1.0, 0.01) var until_progress: float = 1.0


func is_available_at(progress: float) -> bool:
	return (
		enemy != null
		and weight > 0.0
		and progress >= from_progress
		and progress <= until_progress
	)
