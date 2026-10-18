class_name UpgradePool
extends RefCounted
## Works out what a mid-run level-up offers (DESIGN.md section 6.4).
##
## The pool is the hero's unlocked skills plus the generic upgrades. A skill the
## hero is carrying can be raised a level for the run, until it is maxed. One
## they are not carrying can be taken while there is room for another, and
## joins at the hero's permanent level for it. Offers are drawn without
## repeats, so a choice never shows the same thing twice.


## `count` offers for a hero who has unlocked `unlocked` and carries `held`.
## `permanent_levels` maps a skill id to the level the hero has trained it to;
## a skill missing from it joins at level 1.
static func roll(
	unlocked: Array[SkillData],
	held: Array[HeldSkill],
	permanent_levels: Dictionary[StringName, int],
	count: int,
	rng: RandomNumberGenerator,
) -> Array[UpgradeOffer]:
	var pool: Array[UpgradeOffer] = _candidates(unlocked, held, permanent_levels)
	var offers: Array[UpgradeOffer] = []
	while offers.size() < count and not pool.is_empty():
		offers.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return offers


static func _candidates(
	unlocked: Array[SkillData],
	held: Array[HeldSkill],
	permanent_levels: Dictionary[StringName, int],
) -> Array[UpgradeOffer]:
	var pool: Array[UpgradeOffer] = []
	var carried: Dictionary[StringName, HeldSkill] = {}
	for skill: HeldSkill in held:
		carried[skill.data.id] = skill
		if not skill.is_maxed():
			pool.append(UpgradeOffer.for_skill(skill.data, skill.level + 1, true))
	if held.size() < SkillCaster.MAX_SKILLS:
		for data: SkillData in unlocked:
			if not carried.has(data.id):
				var level: int = permanent_levels.get(data.id, 1)
				pool.append(UpgradeOffer.for_skill(data, level, false))
	for upgrade: GenericUpgrade in GenericUpgrade.all():
		pool.append(UpgradeOffer.for_generic(upgrade))
	return pool
