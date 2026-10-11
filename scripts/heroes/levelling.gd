class_name Levelling
extends RefCounted
## The experience curve and level cap (DESIGN.md section 6.6). Pure numbers: a
## hero's own levelling is done by HeroData.
##
## A hero's `experience` is a running total, and their level follows from it.
## At MAX_LEVEL it stops growing, and picks up again if the cap is raised later,
## since nothing here changes except the cap.

const MAX_LEVEL: int = 30
## Free stat points a hero earns for each level gained.
const FREE_POINTS_PER_LEVEL: int = 2
## A placeholder curve to be tuned by play.
const EXP_BASE: float = 40.0
const EXP_EXPONENT: float = 1.25


## Experience needed to go from `level` to the next one; zero at the cap.
static func exp_to_leave(level: int) -> int:
	if level < 1:
		push_error("Levelling: levels start at 1, got %d." % level)
		return 0
	if level >= MAX_LEVEL:
		return 0
	return roundi(EXP_BASE * pow(level, EXP_EXPONENT))


## Total experience at which a hero reaches `level`.
static func total_exp_for(level: int) -> int:
	var total: int = 0
	for step: int in mini(level, MAX_LEVEL) - 1:
		total += exp_to_leave(step + 1)
	return total


## Total experience a hero cannot go beyond.
static func max_exp() -> int:
	return total_exp_for(MAX_LEVEL)


## The level that `total_exp` reaches.
static func level_for(total_exp: int) -> int:
	var level: int = 1
	while level < MAX_LEVEL and total_exp >= total_exp_for(level + 1):
		level += 1
	return level


## How far through their level a hero with `total_exp` is: x is what they have
## earned towards the next level, y what it needs. y is zero at the cap.
static func progress(total_exp: int) -> Vector2i:
	var level: int = level_for(total_exp)
	return Vector2i(total_exp - total_exp_for(level), exp_to_leave(level))
