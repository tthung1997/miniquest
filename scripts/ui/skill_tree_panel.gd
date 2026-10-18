class_name SkillTreePanel
extends VBoxContainer
## The hub's Skills view, shown where the inventory is: the skill tree, and
## under it the details of the picked skill with the buttons to train it and
## to make it the skill a run starts with.
##
## Training is permanent, like advancing, and takes effect on the click. Every
## change goes through HeroData's own methods and is reported with hero_changed;
## the panel never saves, the screen owner does.

## The hero's skill points or starting skill changed and should be saved.
signal hero_changed
## The player asked to reset their skill points for `cost` gold. The screen
## owner confirms and then calls HeroData.reset_skill_points().
signal reset_requested(cost: int)

## The skill tree is never taller than this; more rows scroll.
const TREE_MAX_HEIGHT: float = 150.0

var _hero: HeroData = null
var _selected: SkillData = null

@onready var _points_label: Label = %PointsLabel
@onready var _tree_scroll: ScrollContainer = %TreeScroll
@onready var _skill_tree: SkillTreeView = %Tree
@onready var _frame: SkillFrame = %DetailFrame
@onready var _name_label: Label = %NameLabel
@onready var _level_label: Label = %LevelLabel
@onready var _description_label: Label = %DescriptionLabel
@onready var _numbers_label: Label = %NumbersLabel
@onready var _note_label: Label = %NoteLabel
@onready var _requirement_label: Label = %RequirementLabel
@onready var _train_button: Button = %TrainButton
@onready var _start_button: Button = %StartButton
@onready var _reset_button: Button = %ResetButton
@onready var _cost_row: HBoxContainer = %CostRow
@onready var _cost_label: Label = %CostLabel


func _ready() -> void:
	_skill_tree.skill_picked.connect(_on_skill_picked)
	_train_button.pressed.connect(_on_train_pressed)
	_start_button.pressed.connect(_on_start_pressed)
	_reset_button.pressed.connect(_on_reset_pressed)


## Show `hero`'s skills. The picked skill stays picked across calls for the same
## hero, and starts as the skill their runs begin with.
func show_hero(hero: HeroData) -> void:
	if hero != _hero:
		_selected = null
	_hero = hero
	if _hero == null:
		return
	if _selected == null or not _hero.lineage_skills().has(_selected):
		_selected = _hero.start_skill()
	_refresh()


## Put keyboard focus on the picked skill, so the arrow keys move around the tree.
func focus_selected() -> void:
	if _selected != null:
		var node: SkillNode = _skill_tree.node_for(_selected)
		if node != null:
			node.grab_focus()


## Take back the points once the player has confirmed the price, which the hub
## asked for when the panel reported reset_requested.
func reset_confirmed() -> void:
	if _hero != null and _hero.reset_skill_points():
		_after_edit()


func _refresh() -> void:
	var points: int = _hero.unspent_skill_points
	_points_label.text = "%d point%s" % [points, "" if points == 1 else "s"]
	_points_label.theme_type_variation = &"AccentLabel" if points > 0 else &"MutedLabel"
	_skill_tree.show_hero(_hero, _selected)
	# As tall as its rows need, up to a cap past which it scrolls, so the
	# details below get everything else.
	_tree_scroll.custom_minimum_size.y = minf(
		_skill_tree.custom_minimum_size.y, TREE_MAX_HEIGHT
	)
	_refresh_details()


func _refresh_details() -> void:
	if _selected == null:
		return
	var skill: SkillData = _selected
	var unlocked: bool = _hero.unlocked_skills().has(skill)
	var level: int = _hero.skill_level(skill)
	_frame.icon = skill.icon
	_frame.locked = not unlocked
	_name_label.text = skill.display_name
	_level_label.text = "Lv %d/%d" % [level, skill.max_level] if unlocked else ""
	_description_label.text = skill.description
	_numbers_label.text = _numbers_text(skill, level)
	_note_label.text = skill.effect_note
	_note_label.visible = not skill.effect_note.is_empty()
	_requirement_label.text = "" if unlocked else _requirement_text(skill)
	_requirement_label.visible = not unlocked

	_train_button.disabled = not _hero.can_raise_skill(skill)
	_train_button.text = "MAXED" if unlocked and level >= skill.max_level else "LEVEL UP"
	var starts: bool = _hero.start_skill() == skill
	_start_button.disabled = not unlocked or starts
	_start_button.text = "STARTS RUNS" if starts else "START WITH"
	var cost: int = _hero.skill_reset_cost()
	_cost_label.text = str(cost)
	# Kept in place, only hidden, so the buttons do not shift when there is no price.
	_cost_row.modulate.a = 1.0 if cost > 0 else 0.0
	_reset_button.disabled = not _hero.can_reset_skills()
	_reset_button.tooltip_text = (
		"Nothing to take back" if cost == 0
		else "Take back every skill point for %d gold" % cost if _hero.can_reset_skills()
		else "Needs %d gold" % cost
	)


func _numbers_text(skill: SkillData, level: int) -> String:
	var scales: PackedStringArray = []
	for stat_name: StringName in HeroData.STATS:
		if skill.scaling.has(stat_name):
			scales.append(String(stat_name).left(3).to_upper())
	var manual: String = "" if skill.supports_auto_cast else "    Manual only"
	return "Power %d    Cooldown %.1fs    %s%s" % [
		roundi(skill.power_at(level, _hero.total_stats())),
		skill.cooldown_at(level),
		" ".join(scales),
		manual,
	]


## Why a skill is not open yet: how many points the class before it still needs.
func _requirement_text(skill: SkillData) -> String:
	var gate: Vector2i = _hero.skill_gate(skill.class_id)
	var before: ClassData = ClassData.find(_hero.class_before(skill.class_id))
	var before_name: String = before.display_name if before != null else "earlier"
	return "Spend %d points on %s skills to open this (%d so far)" % [
		gate.y, before_name, gate.x
	]


func _on_skill_picked(skill: SkillData) -> void:
	if skill == _selected or _hero == null:
		return
	_selected = skill
	_refresh()


func _on_train_pressed() -> void:
	if _hero.raise_skill(_selected):
		_after_edit()


func _on_start_pressed() -> void:
	if _hero.set_start_skill(_selected):
		_after_edit()


func _on_reset_pressed() -> void:
	reset_requested.emit(_hero.skill_reset_cost())


func _after_edit() -> void:
	_refresh()
	hero_changed.emit()
	# A button that was just disabled would take keyboard focus with it.
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused is BaseButton and (focused as BaseButton).disabled:
		focus_selected()
