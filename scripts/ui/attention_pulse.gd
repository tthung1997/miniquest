class_name AttentionPulse
extends RefCounted
## A slow glow that draws the eye to a control that wants the player's attention,
## such as unspent stat or skill points. It loops on the control's modulate until
## switched off, which puts the modulate back to white.

const BRIGHT: Color = Color(1.6, 1.45, 1.05)
const HALF_SECONDS: float = 0.6

const _TWEEN_META: StringName = &"_attention_pulse_tween"
const _WANTED_META: StringName = &"_attention_pulse_wanted"


## Start or stop the glow on `target`. Safe to call every refresh with the same
## value, and before the control is in the tree: it starts once it enters.
static func set_active(target: CanvasItem, active: bool) -> void:
	if target == null:
		return
	target.set_meta(_WANTED_META, active)
	if not active:
		_stop(target)
		return
	if not target.is_inside_tree():
		if not target.tree_entered.is_connected(_on_tree_entered.bind(target)):
			target.tree_entered.connect(_on_tree_entered.bind(target), CONNECT_ONE_SHOT)
		return
	if is_active(target):
		return
	var tween: Tween = target.create_tween().set_loops()
	tween.tween_property(target, "modulate", BRIGHT, HALF_SECONDS) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(target, "modulate", Color.WHITE, HALF_SECONDS) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	target.set_meta(_TWEEN_META, tween)


static func is_active(target: CanvasItem) -> bool:
	if target == null or not target.has_meta(_TWEEN_META):
		return false
	var running: Tween = target.get_meta(_TWEEN_META)
	return running != null and running.is_valid()


static func _stop(target: CanvasItem) -> void:
	if target.has_meta(_TWEEN_META):
		var running: Tween = target.get_meta(_TWEEN_META)
		if running != null:
			running.kill()
		target.remove_meta(_TWEEN_META)
	target.modulate = Color.WHITE


static func _on_tree_entered(target: CanvasItem) -> void:
	if is_instance_valid(target) and target.get_meta(_WANTED_META, false):
		set_active(target, true)
