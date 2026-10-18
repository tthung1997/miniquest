class_name SkillBar
extends HBoxContainer
## The run's skill bar: the auto-cast switch, then one SkillSlot per skill the
## hero carries in the order of the keys that cast them. Slots are rebuilt
## whenever it is shown a new set. The switch only asks; whoever owns the skills
## decides, and tells the bar the result with show_auto_cast().
##
## The switch's AUTO state has its own pressed style in the scene. The theme's
## stretches the pack's top orange row into a fat band on a button this tall, so
## the scene's holds three rows fixed at the top and bottom instead.

## The player pressed the auto-cast switch.
signal auto_cast_toggle_requested

## One SkillSlot per carried skill.
@export var slot_scene: PackedScene

var _slots: Array[SkillSlot] = []

@onready var _auto_button: Button = %AutoButton


func _ready() -> void:
	_auto_button.pressed.connect(auto_cast_toggle_requested.emit)


## Show whether skills cast themselves.
func show_auto_cast(enabled: bool) -> void:
	_auto_button.text = "AUTO" if enabled else "MANUAL"
	_auto_button.set_pressed_no_signal(enabled)


## Show `skills`, replacing whatever was shown.
func show_skills(skills: Array[HeldSkill]) -> void:
	if slot_scene == null:
		push_error("SkillBar: slot_scene must be wired to show skills.")
		return
	for slot: SkillSlot in _slots:
		slot.queue_free()
	_slots.clear()
	for i: int in skills.size():
		var node: Node = slot_scene.instantiate()
		if node is not SkillSlot:
			push_error("SkillBar: slot_scene must have a SkillSlot root.")
			node.free()
			return
		var slot: SkillSlot = node
		add_child(slot)
		slot.show_skill(skills[i], i + 1)
		_slots.append(slot)
