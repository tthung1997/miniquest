class_name SkillNode
extends Control
## One skill in the skill tree: its icon in a frame with its trained level
## underneath. Click it, or focus it and press Enter or Space, to pick it;
## focusing it with the arrow keys picks it too, so the details follow along.
##
## It shows what it is told and reports a pick. What a pick does is up to the
## tree.

## The player picked this skill.
signal pressed(skill: SkillData)

## Whether the hero can use a skill yet.
enum State {
	## Open: it can be trained, started with and offered in a run.
	UNLOCKED,
	## Its class is the hero's, but they have not spent enough points on the
	## skills before it.
	LOCKED,
}

const FOCUS_COLOR: Color = Color("fff3d6")
const CAN_TRAIN_COLOR: Color = Color("ffad55")

var skill: SkillData = null

@onready var _frame: SkillFrame = %Frame


func _ready() -> void:
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(queue_redraw)


func _gui_input(event: InputEvent) -> void:
	var clicked: bool = (
		event is InputEventMouseButton
		and event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT
	)
	if clicked or event.is_action_pressed(&"ui_accept"):
		accept_event()
		pressed.emit(skill)


func _draw() -> void:
	if has_focus():
		var frame_size: Vector2 = _frame.size
		draw_rect(Rect2(Vector2(-1, -1), frame_size + Vector2(2, 2)), FOCUS_COLOR, false, 1.0)


## Show `data` as `hero` has it. `selected` brightens the frame. The level
## shows in the frame's corner, in the accent colour while a point could go in.
func show_skill(hero: HeroData, data: SkillData, state: State, selected: bool) -> void:
	skill = data
	if not is_node_ready():
		await ready
	_frame.icon = data.icon
	_frame.locked = state == State.LOCKED
	_frame.selected = selected
	_frame.badge_color = (
		CAN_TRAIN_COLOR if state == State.UNLOCKED and hero.can_raise_skill(data) else Color.WHITE
	)
	match state:
		State.UNLOCKED:
			_frame.badge = "%d/%d" % [hero.skill_level(data), data.max_level]
		State.LOCKED:
			_frame.badge = ""
	tooltip_text = data.display_name
	queue_redraw()


func _on_focus_entered() -> void:
	queue_redraw()
	pressed.emit(skill)
