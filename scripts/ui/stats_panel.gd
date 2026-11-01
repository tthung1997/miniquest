class_name StatsPanel
extends VBoxContainer
## The selected hero's stats and unspent points, shown under the hero in the
## hub, on two tabs. POINTS has each stat with buttons to put free points into
## it. STATS lists everything the hero's stats and gear come to, previewing the
## change waiting points would make, and the stat points the gear adds.
##
## Points are staged: the buttons only change a pending allocation, previewed
## in the numbers, until apply() commits it through HeroData.spend_points().
## There is no respec, so nothing permanent happens on a stray click. The panel
## never saves; it reports points_applied and the screen owner saves.

signal pending_changed
signal points_applied

const ARROW: String = "→"
const ACCENT: StringName = &"AccentLabel"
const NORMAL: StringName = &""
## The STATS tab turns this colour while waiting points would change its numbers.
const PENDING_TAB_COLOR: Color = Color(1.0, 0.678, 0.333)
## What the STATS tab lists, in order: its key, the short name on the tab and
## the full name shown on hover.
const SUMMARY_KEYS: Array[StringName] = [
	&"health", &"damage", &"speed", &"range", &"crit", &"cooldown", &"move", &"pickup", &"gear"
]
const SUMMARY_SHORT: PackedStringArray = [
	"HP", "DMG", "SPD", "RNG", "CRIT", "CDR", "MOV", "PICK", "GEAR"
]
const SUMMARY_TIPS: PackedStringArray = [
	"Maximum health",
	"Damage per hit with the held weapon",
	"Attacks per second with the held weapon",
	"Attack range of the held weapon",
	"Chance that a hit is critical",
	"Share taken off every skill's cooldown",
	"Move speed, compared with a hero wearing no boots",
	"How close a drop must be to be collected",
	"Stat points worn equipment adds",
]
const NO_VALUE: String = "--"

## One StatRow per stat in HeroData.STATS.
@export var stat_row_scene: PackedScene

var _hero: HeroData = null
var _pending: Dictionary[StringName, int] = {}
var _rows: Dictionary[StringName, StatRow] = {}
var _summary_values: Dictionary[StringName, Label] = {}
## What each STATS cell reads when nothing is changing, to say "NAME value".
var _summary_names: Dictionary[StringName, String] = {}

@onready var _points_tab: Button = %PointsTab
@onready var _stats_tab: Button = %StatsTab
@onready var _views: TabContainer = %Views
@onready var _free_points_label: Label = %FreePointsLabel
@onready var _reset_button: Button = %ResetButton
@onready var _apply_button: Button = %ApplyButton
@onready var _grid: GridContainer = %StatGrid
@onready var _summary_grid: GridContainer = %StatsGrid


func _ready() -> void:
	_reset_button.pressed.connect(discard)
	_apply_button.pressed.connect(apply)
	_points_tab.toggled.connect(_on_tab_toggled.bind(0))
	_stats_tab.toggled.connect(_on_tab_toggled.bind(1))
	_build_rows()
	_build_summary()
	_refresh()


## Show `hero`, or nothing for null. Safe to call again for the same hero after
## its equipment changed: waiting points are kept. A different hero starts with
## none waiting.
func show_hero(hero: HeroData) -> void:
	if hero != _hero:
		_pending.clear()
	_hero = hero
	if is_node_ready():
		_refresh()


## Points waiting to be applied.
func pending_total() -> int:
	var total: int = 0
	for amount: int in _pending.values():
		total += amount
	return total


func has_pending() -> bool:
	return pending_total() > 0


## Spend the waiting points. Returns whether it worked; with nothing waiting it
## does nothing and returns false.
func apply() -> bool:
	if _hero == null or not has_pending():
		return false
	if not _hero.spend_points(_pending):
		return false
	_pending.clear()
	_refresh()
	points_applied.emit()
	pending_changed.emit()
	return true


## Drop the waiting points without spending them.
func discard() -> void:
	if _pending.is_empty():
		return
	_pending.clear()
	_refresh()
	pending_changed.emit()


func _build_rows() -> void:
	if stat_row_scene == null:
		push_error("StatsPanel: stat_row_scene must be wired to show the stats.")
		return
	for stat_name: StringName in HeroData.STATS:
		var node: Node = stat_row_scene.instantiate()
		if node is not StatRow:
			push_error("StatsPanel: stat_row_scene must have a StatRow root.")
			node.free()
			return
		var row: StatRow = node
		row.stat_name = stat_name
		row.increase_requested.connect(_on_increase_requested)
		row.decrease_requested.connect(_on_decrease_requested)
		_grid.add_child(row)
		_rows[stat_name] = row


func _remaining_points() -> int:
	return _hero.unspent_points - pending_total() if _hero != null else 0


## The hero's stats, gear included, with the waiting points added.
func _preview_stats() -> Dictionary[StringName, int]:
	var stats: Dictionary[StringName, int] = _hero.total_stats()
	for stat_name: StringName in _pending:
		stats[stat_name] += _pending[stat_name]
	return stats


func _refresh() -> void:
	_reset_button.disabled = not has_pending()
	_apply_button.disabled = not has_pending()
	if _hero == null:
		_free_points_label.text = "Free: --"
		_free_points_label.theme_type_variation = NORMAL
		for row: StatRow in _rows.values():
			row.show_empty()
		for key: StringName in _summary_values:
			_show_summary(key, NO_VALUE)
		_stats_tab.remove_theme_color_override(&"font_color")
		return

	var remaining: int = _remaining_points()
	_free_points_label.text = "Free: %d" % remaining
	_free_points_label.theme_type_variation = ACCENT if remaining > 0 else NORMAL
	var current: Dictionary[StringName, int] = _hero.stats()
	for stat_name: StringName in _rows:
		var pending: int = _pending.get(stat_name, 0)
		_rows[stat_name].show_values(current[stat_name], pending, pending > 0, remaining > 0)
	_refresh_readouts(_hero.total_stats(), _preview_stats())
	if has_pending():
		_stats_tab.add_theme_color_override(&"font_color", PENDING_TAB_COLOR)
	else:
		_stats_tab.remove_theme_color_override(&"font_color")


## `current` and `preview` count the stats gear adds; the rows above show only
## the points the hero has earned.
func _refresh_readouts(
	current: Dictionary[StringName, int], preview: Dictionary[StringName, int]
) -> void:
	var health: String = _format(_hero.max_health())
	var health_after: String = _format(_hero.max_health_with(preview[&"vitality"]))
	_show_summary(&"health", health, health_after)
	_show_summary(&"crit", "%d%%" % roundi(_hero.crit_chance() * 100.0))
	_show_summary(&"cooldown", "%d%%" % roundi(_hero.cooldown_reduction() * 100.0))
	_show_summary(&"move", "%d%%" % roundi(_hero.move_speed_multiplier() * 100.0))
	_show_summary(&"pickup", "%d" % roundi(HeroData.BASE_PICKUP_RADIUS + _hero.pickup_radius_bonus()))
	_refresh_gear_points(current)

	var weapon: WeaponData = null
	if _hero.weapon != null:
		weapon = _hero.weapon.data()
	if weapon == null:
		for key: StringName in [&"damage", &"speed", &"range"]:
			_show_summary(key, NO_VALUE)
		return
	var damage: String = _format(_hero.weapon.damage_with(current))
	var damage_after: String = _format(_hero.weapon.damage_with(preview))
	_show_summary(&"damage", damage, damage_after)
	_show_summary(&"speed", "%s/s" % _format(1.0 / weapon.attack_interval, 2))
	_show_summary(&"range", _format(weapon.attack_range))


## The stat points worn equipment adds, in total, with the detail on hover.
func _refresh_gear_points(total: Dictionary[StringName, int]) -> void:
	var earned: Dictionary[StringName, int] = _hero.stats()
	var parts: PackedStringArray = []
	var points: int = 0
	for stat_name: StringName in HeroData.STATS:
		var extra: int = total[stat_name] - earned[stat_name]
		points += extra
		if extra != 0:
			parts.append("%s %+d" % [String(stat_name).left(3).to_upper(), extra])
	_show_summary(&"gear", "%+d" % points)
	var detail: String = "  ".join(parts) if not parts.is_empty() else "none"
	_summary_values[&"gear"].tooltip_text = "%s: %s" % [SUMMARY_TIPS[SUMMARY_KEYS.size() - 1], detail]


func _build_summary() -> void:
	for i: int in SUMMARY_KEYS.size():
		var cell: Label = Label.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.tooltip_text = SUMMARY_TIPS[i]
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		cell.custom_minimum_size = Vector2(0, 12)
		_summary_grid.add_child(cell)
		_summary_values[SUMMARY_KEYS[i]] = cell
		_summary_names[SUMMARY_KEYS[i]] = SUMMARY_SHORT[i]
		_show_summary(SUMMARY_KEYS[i], NO_VALUE)


## Show a STATS cell as "NAME now", or "NAME now → after" in the accent colour
## when `after` is given and differs.
func _show_summary(key: StringName, now: String, after: String = "") -> void:
	var label: Label = _summary_values.get(key)
	if label == null:
		return
	var short_name: String = _summary_names[key]
	if after.is_empty() or now == after:
		label.text = "%s %s" % [short_name, now]
		label.theme_type_variation = NORMAL
	else:
		label.text = "%s %s %s %s" % [short_name, now, ARROW, after]
		label.theme_type_variation = ACCENT


func _on_tab_toggled(pressed: bool, index: int) -> void:
	if pressed:
		_views.current_tab = index


## `decimals` places, trailing zeros dropped.
func _format(value: float, decimals: int = 1) -> String:
	var text: String = String.num(value, decimals)
	if text.contains("."):
		text = text.rstrip("0").trim_suffix(".")
	return text


func _on_increase_requested(stat_name: StringName) -> void:
	if _remaining_points() <= 0:
		return
	_pending[stat_name] = _pending.get(stat_name, 0) + 1
	_refresh()
	pending_changed.emit()


func _on_decrease_requested(stat_name: StringName) -> void:
	var waiting: int = _pending.get(stat_name, 0)
	if waiting <= 0:
		return
	if waiting == 1:
		_pending.erase(stat_name)
	else:
		_pending[stat_name] = waiting - 1
	_refresh()
	pending_changed.emit()
