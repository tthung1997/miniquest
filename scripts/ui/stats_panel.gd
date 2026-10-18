class_name StatsPanel
extends VBoxContainer
## The selected hero's stats and unspent points, shown under the hero in the
## hub: each stat with buttons to put free points into it, and what the hero's
## health and held weapon come to.
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

## One StatRow per stat in HeroData.STATS.
@export var stat_row_scene: PackedScene

var _hero: HeroData = null
var _pending: Dictionary[StringName, int] = {}
var _rows: Dictionary[StringName, StatRow] = {}

@onready var _free_points_label: Label = %FreePointsLabel
@onready var _reset_button: Button = %ResetButton
@onready var _apply_button: Button = %ApplyButton
@onready var _grid: GridContainer = %StatGrid
@onready var _health_label: Label = %HealthLabel
@onready var _damage_label: Label = %DamageLabel
@onready var _speed_label: Label = %SpeedLabel
@onready var _range_label: Label = %RangeLabel
@onready var _move_label: Label = %MoveLabel


func _ready() -> void:
	_reset_button.pressed.connect(discard)
	_apply_button.pressed.connect(apply)
	_build_rows()
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
		_free_points_label.text = "Free points: --"
		_free_points_label.theme_type_variation = NORMAL
		for row: StatRow in _rows.values():
			row.show_empty()
		_show_readout(_health_label, "HP", "--", "--")
		_show_readout(_damage_label, "DMG", "--", "--")
		_show_readout(_speed_label, "SPD", "--", "--")
		_show_readout(_range_label, "RNG", "--", "--")
		_show_readout(_move_label, "MOV", "--", "--")
		return

	var remaining: int = _remaining_points()
	_free_points_label.text = "Free points: %d" % remaining
	_free_points_label.theme_type_variation = ACCENT if remaining > 0 else NORMAL
	var current: Dictionary[StringName, int] = _hero.stats()
	for stat_name: StringName in _rows:
		var pending: int = _pending.get(stat_name, 0)
		_rows[stat_name].show_values(current[stat_name], pending, pending > 0, remaining > 0)
	_refresh_readouts(_hero.total_stats(), _preview_stats())


## `current` and `preview` count the stats gear adds; the rows above show only
## the points the hero has earned.
func _refresh_readouts(
	current: Dictionary[StringName, int], preview: Dictionary[StringName, int]
) -> void:
	_show_readout(
		_health_label,
		"HP",
		_format(_hero.max_health()),
		_format(_hero.max_health_with(preview[&"vitality"]))
	)
	var movement: String = "%d%%" % roundi(_hero.move_speed_multiplier() * 100.0)
	_show_readout(_move_label, "MOV", movement, movement)

	var weapon: WeaponData = null
	if _hero.weapon != null:
		weapon = _hero.weapon.data()
	if weapon == null:
		_show_readout(_damage_label, "DMG", "--", "--")
		_show_readout(_speed_label, "SPD", "--", "--")
		_show_readout(_range_label, "RNG", "--", "--")
		return
	var damage: String = _format(_hero.weapon.damage_with(current))
	_show_readout(_damage_label, "DMG", damage, _format(_hero.weapon.damage_with(preview)))
	var speed: String = _format(1.0 / weapon.attack_interval)
	_show_readout(_speed_label, "SPD", speed, speed)
	var reach: String = _format(weapon.attack_range)
	_show_readout(_range_label, "RNG", reach, reach)


## "NAME now", or "NAME now → after" in the accent colour when it will change.
func _show_readout(label: Label, readout_name: String, now: String, after: String) -> void:
	if now == after:
		label.text = "%s %s" % [readout_name, now]
		label.theme_type_variation = NORMAL
	else:
		label.text = "%s %s %s %s" % [readout_name, now, ARROW, after]
		label.theme_type_variation = ACCENT


## One decimal place, dropped when it is zero.
func _format(value: float) -> String:
	return String.num(value, 1).trim_suffix(".0")


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
