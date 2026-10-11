class_name RunEndPanel
extends Control
## The panel shown when a run ends: how it went and what it earned.
##
## It only displays a RunResult and reports Continue; banking the result and
## leaving the run are the owner's business. Must keep processing while the
## tree is paused, so whoever instances it sets its process mode to Always.

signal continue_pressed

const TITLES: Dictionary[RunResult.Outcome, String] = {
	RunResult.Outcome.WON: "QUEST COMPLETE",
	RunResult.Outcome.DIED: "DEFEATED",
	RunResult.Outcome.RETREATED: "RETREATED",
}

@onready var _title: Label = %Title
@onready var _details: Label = %Details
@onready var _continue_button: Button = %ContinueButton


func _ready() -> void:
	_continue_button.pressed.connect(continue_pressed.emit)
	hide()


func show_result(result: RunResult) -> void:
	_title.text = TITLES[result.outcome]
	var clock: String = "%s / %s" % [
		RunResult.clock(result.time_survived), RunResult.clock(result.duration)
	]
	var lines: PackedStringArray = [
		"Time    " + clock,
		"Kills    %d" % result.kills,
		"Experience    +%d" % result.experience,
	]
	if result.is_win():
		lines.append("Gold    +%d" % result.gold)
		var items: String = "Items    +%d" % result.items.size()
		if result.items_without_room > 0:
			items += " (%d without room)" % result.items_without_room
		lines.append(items)
		lines.append(
			"Win bonus    %d exp, %d gold, %d items"
			% [result.bonus_experience, result.bonus_gold, result.bonus_items]
		)
	elif result.gold_forfeited > 0 or result.items_forfeited > 0:
		lines.append(
			"Lost    %d gold, %d items" % [result.gold_forfeited, result.items_forfeited]
		)
	if result.level_after > result.level_before:
		lines.append("LEVEL UP!    Lv %d to %d" % [result.level_before, result.level_after])
	_details.text = "\n".join(lines)
	show()
	_continue_button.grab_focus()
