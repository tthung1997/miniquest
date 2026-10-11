class_name Projectile
extends Node2D
## Something an attack releases to fly straight on, such as a crossbow bolt or
## a magic bolt. It travels until it has covered its range, then frees itself.
##
## It hurts enemies it touches. By default it stops at the first one; a
## piercing projectile flies on through every enemy in its line, and one with a
## splash radius instead bursts on the first enemy, or at the end of its range,
## hurting everything near where it stops. The art faces right and is turned to
## face the way it flies.

@export_range(10.0, 1000.0, 5.0, "suffix:px/s") var speed: float = 300.0
## Played where the projectile stops, such as the wand bolt's burst. The
## projectile hides its own art and frees itself once the effect has gone.
## It must free itself when done, as OneShotEffect does.
@export var end_effect: PackedScene

@export_group("Hit")
## Keeps flying after a hit, hurting each enemy it passes through once.
@export var pierces: bool = false
## When above zero the projectile bursts instead: it hurts every enemy within
## this radius of where it stops, and nothing else.
@export_range(0.0, 100.0, 1.0, "suffix:px") var splash_radius: float = 0.0

## Hurt dealt to each enemy hit. Set by whoever fires it, from the weapon and
## the shooter's stats, before adding it to the tree.
var damage: float = 0.0

var _origin: Vector2 = Vector2.ZERO
var _direction: Vector2 = Vector2.RIGHT
var _remaining: float = 0.0
var _carried_speed: float = 0.0
var _stopped: bool = false
var _spent: bool = false

@onready var _hitbox: Area2D = $Hitbox


func _ready() -> void:
	global_position = _origin
	rotation = _direction.angle()
	_hitbox.body_entered.connect(_on_hitbox_body_entered)


func _physics_process(delta: float) -> void:
	# Range is counted at the projectile's own speed, so a shot fired on the run
	# still lands attack_range ahead of a hero who keeps running.
	var step: float = minf(speed * delta, _remaining)
	var fraction: float = step / (speed * delta) if speed * delta > 0.0 else 1.0
	position += _direction * (step + _carried_speed * delta * fraction)
	_remaining -= step
	if _remaining <= 0.0:
		_stop()


## Fly from `origin`, in global space, along `direction` until `max_distance`
## has been covered. `carrier_velocity` is the shooter's velocity: the part of
## it along `direction` is added to the projectile's speed, so a slow shot
## fired while running forward is not overtaken by the shooter. Call before
## adding to the tree; the whole flight happens once it is in.
func launch(
	origin: Vector2,
	direction: Vector2,
	max_distance: float,
	carrier_velocity: Vector2 = Vector2.ZERO,
) -> void:
	assert(not direction.is_zero_approx(), "Projectile.launch needs a direction.")
	assert(not is_inside_tree(), "Projectile.launch must be called before adding it.")
	_origin = origin
	_direction = direction.normalized()
	_remaining = maxf(max_distance, 0.0)
	_carried_speed = maxf(carrier_velocity.dot(_direction), 0.0)


func _on_hitbox_body_entered(body: Node2D) -> void:
	if _stopped or _spent or body is not Enemy:
		return
	# Bursting queries the physics space, which is locked while this signal is
	# being delivered, so the stop waits for the end of the frame. Once spent, a
	# projectile ignores any other enemy it reaches before then.
	if splash_radius > 0.0:
		_spent = true
		_stop.call_deferred()
		return

	var enemy: Enemy = body
	enemy.take_damage(damage)
	if not pierces:
		_spent = true
		_stop.call_deferred()


## Hurt every enemy within splash_radius of here.
func _burst() -> void:
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = splash_radius
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = _hitbox.collision_mask
	for hit: Dictionary in get_world_2d().direct_space_state.intersect_shape(query):
		var collider: Object = hit["collider"]
		if collider is Enemy:
			var enemy: Enemy = collider
			enemy.take_damage(damage)


func _stop() -> void:
	if _stopped:
		return
	_stopped = true
	set_physics_process(false)
	_hitbox.set_deferred(&"monitoring", false)
	if splash_radius > 0.0:
		_burst()
	if end_effect == null:
		queue_free()
		return

	var node: Node = end_effect.instantiate()
	if node is not Node2D:
		push_error("Projectile '%s': end effect is not a Node2D." % name)
		node.free()
		queue_free()
		return
	for child: Node in get_children():
		if child is CanvasItem:
			(child as CanvasItem).hide()
	var effect: Node2D = node
	# Upright whichever way the projectile flew.
	effect.rotation = -rotation
	effect.tree_exited.connect(queue_free)
	add_child(effect)
