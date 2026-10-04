class_name OneShotEffect
extends AnimatedSprite2D
## A short effect that plays its clip once and then frees itself, such as the
## sword's slash. Its clip must not loop, or it would never finish.
##
## The art faces right. Whoever spawns it mirrors it for a hero facing left.


func _ready() -> void:
	if sprite_frames == null or not sprite_frames.has_animation(animation):
		push_error("OneShotEffect '%s' has no '%s' clip." % [name, animation])
		queue_free()
		return
	if sprite_frames.get_animation_loop(animation):
		push_error("OneShotEffect '%s': clip '%s' loops." % [name, animation])
		queue_free()
		return
	animation_finished.connect(queue_free)
	play(animation)
