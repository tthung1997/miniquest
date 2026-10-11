class_name RunResult
extends RefCounted
## How an arena run ended and what it earned, handed from the run to whoever
## banks it into the hero.
##
## Only experience is here so far. Gold and item drops arrive with pickups, and
## are banked only on a win (DESIGN.md section 6.5).

enum Outcome { WON, DIED, RETREATED }

var outcome: Outcome = Outcome.DIED
## Seconds survived, and the quest's full duration for comparison.
var time_survived: float = 0.0
var duration: float = 0.0
var kills: int = 0
## Experience from kills. Kept whichever way the run ended.
var experience: int = 0
## The hero's level when the run began and the level the experience will take
## them to, so the results can announce a level-up before it is banked.
var level_before: int = 1
var level_after: int = 1


func is_win() -> bool:
	return outcome == Outcome.WON


## `seconds` as minutes and seconds, such as 4:05.
static func clock(seconds: float) -> String:
	var whole: int = floori(seconds)
	return "%d:%02d" % [floori(whole / 60.0), whole % 60]
