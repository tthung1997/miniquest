class_name TargetSensor
extends Area2D
## Finds the enemies around whoever owns it, out to a radius it is told.
##
## It only looks; what to do about them is up to the owner. Put it on the
## enemy layer's mask and nothing else. A body counts as near by the distance
## to its position, which is its feet, not by whether its shape overlaps the
## circle, so the radius means the same thing for tall and short enemies.

## Overlap is judged on shapes, which reach past an enemy's feet, so the circle
## is drawn a little wider than asked to be sure nobody in range is missed.
const MARGIN: float = 8.0

var _circle: CircleShape2D = CircleShape2D.new()

@onready var _shape: CollisionShape2D = $Shape


func _ready() -> void:
	_shape.shape = _circle
	set_radius(0.0)


## Look out to `radius`; zero or less switches the sensor off.
func set_radius(radius: float) -> void:
	_circle.radius = maxf(radius, 0.0) + MARGIN
	set_deferred(&"monitoring", radius > 0.0)


## The closest live enemy within `max_distance` of `origin`, or null.
func nearest_enemy(origin: Vector2, max_distance: float) -> Enemy:
	var best: Enemy = null
	var best_distance: float = max_distance
	for enemy: Enemy in enemies_within(origin, max_distance):
		var distance: float = origin.distance_to(enemy.global_position)
		if distance <= best_distance:
			best = enemy
			best_distance = distance
	return best


## Every live enemy within `max_distance` of `origin`.
func enemies_within(origin: Vector2, max_distance: float) -> Array[Enemy]:
	var found: Array[Enemy] = []
	# Switched off, or not yet switched on: Godot refuses to list overlaps.
	if not monitoring:
		return found
	for body: Node2D in get_overlapping_bodies():
		if body is not Enemy:
			continue
		var enemy: Enemy = body
		if enemy.is_dead() or origin.distance_to(enemy.global_position) > max_distance:
			continue
		found.append(enemy)
	return found
