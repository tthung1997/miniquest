class_name AdvanceOption
extends PanelContainer
## One class a hero can advance into, shown as a card in the advance dialog:
## its name, what each level will grow, what it is like, and what the hero
## still lacks for it.
##
## Shows what it is told and reports a choice; the dialog decides what a
## choice does.

signal chosen(class_id: StringName)

const MISSING_PREFIX: String = "Needs "

var _class_id: StringName = &""

@onready var _badge: ClassBadge = %Badge
@onready var _name_label: Label = %NameLabel
@onready var _growth_label: Label = %GrowthLabel
@onready var _description_label: Label = %DescriptionLabel
@onready var _requirement_label: Label = %RequirementLabel
@onready var _choose_button: Button = %ChooseButton


func _ready() -> void:
	_choose_button.pressed.connect(_on_choose_pressed)


## Show `target` as `hero` sees it. Can be called before ready.
func show_option(hero: HeroData, target: ClassData) -> void:
	_class_id = target.id
	var missing: PackedStringArray = hero.unmet_requirements(target)
	if not is_node_ready():
		await ready
	_badge.show_class(target)
	_name_label.text = target.display_name
	_growth_label.text = _growth_text(target)
	_description_label.text = target.description
	_choose_button.disabled = not missing.is_empty()
	if missing.is_empty():
		_requirement_label.text = "Ready"
		_requirement_label.theme_type_variation = &"AccentLabel"
	else:
		_requirement_label.text = MISSING_PREFIX + ", ".join(missing)
		_requirement_label.theme_type_variation = &"MutedLabel"


## The button that picks this class, for the dialog to focus.
func choose_button() -> Button:
	return _choose_button


func _growth_text(target: ClassData) -> String:
	var parts: PackedStringArray = []
	for stat_name: StringName in HeroData.STATS:
		if target.stat_growth.has(stat_name):
			var amount: String = String.num(target.stat_growth[stat_name], 1).trim_suffix(".0")
			parts.append("+%s %s" % [amount, String(stat_name).left(3).to_upper()])
	return "  ".join(parts) + " a level"


func _on_choose_pressed() -> void:
	chosen.emit(_class_id)
