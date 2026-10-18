class_name SkillSlot
extends Control
## One skill on the run's skill bar: its icon in a frame that darkens while the
## skill cools down, the key that casts it and its level for this run. A small
## mark shows a skill that auto-cast can never fire.
##
## It shows what it is given and follows the skill's cooldown every frame; it
## casts nothing.

var _skill: HeldSkill = null

@onready var _frame: SkillFrame = %Frame
@onready var _key_label: Label = %KeyLabel
@onready var _level_label: Label = %LevelLabel
@onready var _manual_label: Label = %ManualLabel


func _process(_delta: float) -> void:
	if _skill == null:
		return
	_frame.cooldown = _skill.cooldown_ratio()
	_level_label.text = str(_skill.level)


## Show `skill` as the `number`th skill, counting from 1.
func show_skill(skill: HeldSkill, number: int) -> void:
	_skill = skill
	if not is_node_ready():
		await ready
	_frame.icon = skill.data.icon
	_key_label.text = str(number)
	_manual_label.visible = not skill.data.supports_auto_cast
	tooltip_text = "%s\n%s" % [skill.data.display_name, skill.data.description]
	_process(0.0)
