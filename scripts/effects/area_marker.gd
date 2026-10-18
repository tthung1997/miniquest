class_name AreaMarker
extends Node2D
## A ring on the ground that shows where a skill reaches, and frees itself when
## its time is up.
##
## Two looks: a ring that fades out, for something that just happened, and a
## disc that fills up to the ring, for something about to land. It is only a
## picture; the damage is the caster's business.

## Seconds it lasts.
var lifetime: float = 0.4
var radius: float = 24.0
var tint: Color = Color(1.0, 1.0, 1.0, 0.5)
## Fill up to the ring over its lifetime instead of fading out.
var filling: bool = false

var _age: float = 0.0


## Show a ring of `ring_radius` for `seconds`. Call before adding to the tree.
func setup(ring_radius: float, ring_tint: Color, seconds: float, fill_up: bool = false) -> void:
	radius = ring_radius
	tint = ring_tint
	lifetime = maxf(seconds, 0.05)
	filling = fill_up


func _process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress: float = clampf(_age / lifetime, 0.0, 1.0)
	if filling:
		var disc: Color = tint
		disc.a *= 0.5
		draw_circle(Vector2.ZERO, radius * progress, disc)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, tint, 2.0)
		return
	var ring: Color = tint
	ring.a *= 1.0 - progress
	draw_arc(Vector2.ZERO, radius * (0.6 + 0.4 * progress), 0.0, TAU, 48, ring, 2.0)
