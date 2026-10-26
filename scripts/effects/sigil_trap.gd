class_name SigilTrap
extends Node2D
## A rune left on the ground. It waits for an enemy to touch it, then bursts,
## hurting every enemy within its radius, or fades if nothing comes.
##
## The rune is its own looping art and the burst an effect scene, both drawn for the
## radius Sigil Trap is built with. Set `damage`, `radius` and `lifetime` before
## adding it to the tree.

## Played where the rune bursts. Its root must be a OneShotEffect. Without one the
## burst is a fading ring in `tint`.
@export var burst_effect: PackedScene

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


func _on_trigger_body_entered(body: Node2D) -> void:
	if body is Enemy and not _spent:
		_spent = true
		_burst.call_deferred()


func _burst() -> void:
	for body: Node2D in _trigger.get_overlapping_bodies():
		if body is Enemy:
			(body as Enemy).take_damage(damage)
	var shown: Node2D = _make_burst()
	if shown != null:
		shown.position = position
		get_parent().add_child(shown)
	queue_free()


func _make_burst() -> Node2D:
	if burst_effect == null:
		var marker: AreaMarker = AreaMarker.new()
		marker.setup(radius, tint, 0.35)
		return marker
	var node: Node = burst_effect.instantiate()
	if node is not Node2D:
		push_error("SigilTrap: burst effect is not a Node2D.")
		node.free()
		return null
	return node


func _on_lifetime_ended() -> void:
	if is_instance_valid(self) and not _spent:
		queue_free()
