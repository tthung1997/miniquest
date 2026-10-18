class_name SkillTreeView
extends Control
## The hero's skills: a coloured box for each class on their path, oldest at the
## top, holding the class's name and its pair of skills. Only skills the hero
## could learn are shown, so a class they did not take never appears.
##
## A box that is not open yet says how many skill points the hero has spent on
## the class above out of the number it needs. The rows follow the hero's
## lineage, so they are rebuilt only when the hero advances.

## A skill was picked, by click or by focusing it.
signal skill_picked(skill: SkillData)

const NODE_SIZE: int = 34
const PAIR_GAP: int = 8
const BOX_PADDING: int = 4
const BOX_CHAMFER: float = 3.0
const BOX_GAP: int = 6
const BOX_HEIGHT: int = NODE_SIZE + BOX_PADDING * 2
const ROW_HEIGHT: int = BOX_HEIGHT + BOX_GAP
## Width kept at the left of each box for the class's emblem, name and status.
const LABEL_WIDTH: int = 98
const EMBLEM_SIZE: int = 16
const FILL_ALPHA: float = 0.22
const NAME_LIGHTEN: float = 0.4
## Pixels between the class name and the line under it.
const LINE_GAP: float = 2.0
const NEEDED_COLOR: Color = Color("ffad55")

## One SkillNode per skill.
@export var node_scene: PackedScene

var _hero: HeroData = null
var _selected: SkillData = null
var _rows: Array[StringName] = []
var _nodes: Dictionary[StringName, SkillNode] = {}
var _emblems: Array[TextureRect] = []
var _skills_of: Dictionary[StringName, Array] = {}


func _ready() -> void:
	resized.connect(_place)


func _draw() -> void:
	if _hero == null:
		return
	var font: Font = get_theme_default_font()
	var font_size: int = get_theme_default_font_size()
	for row: int in _rows.size():
		var granting: ClassData = ClassData.find(_rows[row])
		if granting == null:
			continue
		var top: float = _row_top(row)
		_draw_box(top, granting.color)
		var text_x: float = BOX_PADDING + EMBLEM_SIZE + 6.0
		var text_width: float = LABEL_WIDTH - text_x
		var status: String = _status_text(row)
		var lines: int = 2 if not status.is_empty() else 1
		var line_height: float = font.get_height(font_size)
		var block: float = lines * line_height + (lines - 1) * LINE_GAP
		var baseline: float = (
			top + (BOX_HEIGHT - block) * 0.5 + font.get_ascent(font_size)
		)
		var name_color: Color = granting.color.lightened(NAME_LIGHTEN)
		draw_string(
			font, Vector2(text_x, roundf(baseline)), granting.display_name,
			HORIZONTAL_ALIGNMENT_LEFT, text_width, font_size, name_color,
		)
		if lines == 2:
			draw_string(
				font, Vector2(text_x, roundf(baseline + line_height + LINE_GAP)), status,
				HORIZONTAL_ALIGNMENT_LEFT, text_width, font_size, NEEDED_COLOR,
			)


## Show the tree as `hero` stands in it, with `selected` highlighted.
func show_hero(hero: HeroData, selected: SkillData) -> void:
	_hero = hero
	_selected = selected
	if hero.lineage() != _rows:
		_rebuild()
	_refresh()
	queue_redraw()


## The node showing `skill`, for focusing.
func node_for(skill: SkillData) -> SkillNode:
	return _nodes.get(skill.id)


func _rebuild() -> void:
	if node_scene == null:
		push_error("SkillTreeView: node_scene must be wired to show the skills.")
		return
	for node: SkillNode in _nodes.values():
		node.queue_free()
	for emblem: TextureRect in _emblems:
		emblem.queue_free()
	_nodes.clear()
	_emblems.clear()
	_skills_of.clear()
	_rows = _hero.lineage()
	for class_id: StringName in _rows:
		var granting: ClassData = ClassData.find(class_id)
		var emblem: TextureRect = TextureRect.new()
		emblem.texture = granting.icon if granting != null else null
		emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
		emblem.size = Vector2.ONE * EMBLEM_SIZE
		add_child(emblem)
		_emblems.append(emblem)
		var skills: Array[SkillData] = _attacks_first(SkillData.granted_by([class_id]))
		_skills_of[class_id] = skills
		for skill: SkillData in skills:
			var node: Node = node_scene.instantiate()
			if node is not SkillNode:
				push_error("SkillTreeView: node_scene must have a SkillNode root.")
				node.free()
				return
			var skill_node: SkillNode = node
			add_child(skill_node)
			skill_node.pressed.connect(skill_picked.emit)
			_nodes[skill.id] = skill_node
	custom_minimum_size.y = maxf(_rows.size() * ROW_HEIGHT - BOX_GAP, 0.0)
	_place()


## Attacking skills ahead of self ones, so each class's pair reads the same way.
func _attacks_first(skills: Array[SkillData]) -> Array[SkillData]:
	var ordered: Array[SkillData] = skills.duplicate()
	ordered.sort_custom(
		func(a: SkillData, b: SkillData) -> bool:
			return (a.target == SkillData.Target.SELF) < (b.target == SkillData.Target.SELF)
	)
	return ordered


func _place() -> void:
	for row: int in _rows.size():
		var top: float = _row_top(row)
		_emblems[row].position = Vector2(BOX_PADDING, top + (BOX_HEIGHT - EMBLEM_SIZE) * 0.5)
		var skills: Array[SkillData] = _skills_of[_rows[row]]
		var left: float = _pair_left(skills.size())
		for i: int in skills.size():
			_nodes[skills[i].id].position = Vector2(
				left + i * (NODE_SIZE + PAIR_GAP), top + BOX_PADDING
			)
	queue_redraw()


func _refresh() -> void:
	var open: Array[SkillData] = _hero.unlocked_skills()
	for class_id: StringName in _rows:
		for skill: SkillData in _skills_of[class_id]:
			var state: SkillNode.State = (
				SkillNode.State.UNLOCKED if open.has(skill) else SkillNode.State.LOCKED
			)
			_nodes[skill.id].show_skill(_hero, skill, state, skill == _selected)


func _row_top(row: int) -> float:
	return float(row * ROW_HEIGHT)


## Left edge of a row's skills: centred in the space beside the class label.
func _pair_left(count: int) -> float:
	var width: float = count * NODE_SIZE + (count - 1) * PAIR_GAP
	return roundf(LABEL_WIDTH + (size.x - LABEL_WIDTH - BOX_PADDING - width) * 0.5)


## A square tinted with the class's colour and edged in it, with cut corners
## like the skill frames.
func _draw_box(top: float, tint: Color) -> void:
	var left: float = 0.5
	var right: float = size.x - 0.5
	var upper: float = top + 0.5
	var lower: float = top + BOX_HEIGHT - 0.5
	var outline: PackedVector2Array = PackedVector2Array([
		Vector2(left + BOX_CHAMFER, upper), Vector2(right - BOX_CHAMFER, upper),
		Vector2(right, upper + BOX_CHAMFER), Vector2(right, lower - BOX_CHAMFER),
		Vector2(right - BOX_CHAMFER, lower), Vector2(left + BOX_CHAMFER, lower),
		Vector2(left, lower - BOX_CHAMFER), Vector2(left, upper + BOX_CHAMFER),
	])
	draw_colored_polygon(outline, Color(tint, FILL_ALPHA))
	outline.append(outline[0])
	draw_polyline(outline, Color(tint, 0.9), 1.0)


## Under a class's name: what it still takes to open its skills. Empty when
## there is nothing to take, which is how an open class reads.
func _status_text(row: int) -> String:
	if row == 0:
		return ""
	var gate: Vector2i = _hero.skill_gate(_rows[row])
	return "%d/%d points" % [gate.x, gate.y] if gate.x < gate.y else ""
