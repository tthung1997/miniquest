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
	var lines: String = (
		"Time    %s / %s\nKills    %d\nExperience    +%d"
		% [
			RunResult.clock(result.time_survived),
			RunResult.clock(result.duration),
			result.kills,
			result.experience,
		]
	)
	if result.level_after > result.level_before:
		lines += "\nLEVEL UP!    Lv %d to %d" % [result.level_before, result.level_after]
	_details.text = lines
	show()
	_continue_button.grab_focus()
