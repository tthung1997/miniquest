class_name SigilTrap
extends Node2D
## A rune left on the ground. It waits for an enemy to touch it, then bursts,
## hurting every enemy within its radius, or fades if nothing comes.
##
## Set `damage`, `radius` and `lifetime` before adding it to the tree.

## Damage dealt to each enemy caught in the burst.
var damage: float = 0.0
var radius: float = 28.0
var lifetime: float = 15.0
var tint: Color = Color(0.6, 0.4, 1.0, 0.6)

var _spent: bool = false
var _circle: CircleShape2D = CircleShape2D.new()

@onready var _trigger: Area2D = $Trigger
@onready var _shape: CollisionShape2D = $Trigger/Shape


func _ready() -> void:
	_circle.radius = radius
	_shape.shape = _circle
	_trigger.body_entered.connect(_on_trigger_body_entered)
	get_tree().create_timer(lifetime).timeout.connect(_on_lifetime_ended)
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(tint, 0.15))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, tint, 2.0)
	draw_arc(Vector2.ZERO, radius * 0.5, 0.0, TAU, 24, tint, 1.0)


func _on_trigger_body_entered(body: Node2D) -> void:
	if body is Enemy and not _spent:
		_spent = true
		_burst.call_deferred()


func _burst() -> void:
	for body: Node2D in _trigger.get_overlapping_bodies():
		if body is Enemy:
			(body as Enemy).take_damage(damage)
	var marker: AreaMarker = AreaMarker.new()
	marker.setup(radius, tint, 0.35)
	marker.position = position
	get_parent().add_child(marker)
	queue_free()


func _on_lifetime_ended() -> void:
	if is_instance_valid(self) and not _spent:
		queue_free()
