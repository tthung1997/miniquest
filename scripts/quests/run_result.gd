class_name RunResult
extends RefCounted
## How an arena run ended and what it earned, handed from the run to whoever
## banks it into the hero.
##
## Experience is banked whichever way the run ended. Gold and items are banked
## only on a win; a death or retreat forfeits them, and the result says how
## much (DESIGN.md section 6.5).

enum Outcome { WON, DIED, RETREATED }

var outcome: Outcome = Outcome.DIED
## Seconds survived, and the quest's full duration for comparison.
var time_survived: float = 0.0
var duration: float = 0.0
var kills: int = 0
## Experience from kills, plus the win bonus on a win. Always banked.
var experience: int = 0
## The hero's level when the run began and the level the experience will take
## them to, so the results can announce a level-up before it is banked.
var level_before: int = 1
var level_after: int = 1
## Gold to bank, and the items to bank. Both empty unless the run was won.
var gold: int = 0
var items: Array[EquipmentItem] = []
## How much of the above came from the win bonus rather than from pickups.
var bonus_experience: int = 0
var bonus_gold: int = 0
var bonus_items: int = 0
## What was picked up but lost because the run was not won.
var gold_forfeited: int = 0
var items_forfeited: int = 0
## Items that will not fit in the hero's inventory when banked.
var items_without_room: int = 0


func is_win() -> bool:
	return outcome == Outcome.WON


## `seconds` as minutes and seconds, such as 4:05.
static func clock(seconds: float) -> String:
	var whole: int = floori(seconds)
	return "%d:%02d" % [floori(whole / 60.0), whole % 60]
