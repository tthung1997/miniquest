class_name UpgradeOffer
extends RefCounted
## One choice on the level-up overlay: a skill to take or raise, or a generic
## upgrade. Built by UpgradePool and applied by whoever runs the level.

enum Kind { SKILL, GENERIC }

var kind: Kind = Kind.GENERIC
var skill: SkillData = null
## For a skill: the level it will be at once taken.
var skill_level: int = 1
## For a skill: whether it is already carried, so taking it raises it.
var raises_held: bool = false
var upgrade: GenericUpgrade = null


static func for_skill(data: SkillData, level_after: int, held: bool) -> UpgradeOffer:
	var offer: UpgradeOffer = UpgradeOffer.new()
	offer.kind = Kind.SKILL
	offer.skill = data
	offer.skill_level = level_after
	offer.raises_held = held
	return offer


static func for_generic(data: GenericUpgrade) -> UpgradeOffer:
	var offer: UpgradeOffer = UpgradeOffer.new()
	offer.kind = Kind.GENERIC
	offer.upgrade = data
	return offer


func title() -> String:
	if kind == Kind.GENERIC:
		return upgrade.display_name
	return skill.display_name


func icon() -> Texture2D:
	return upgrade.icon if kind == Kind.GENERIC else skill.icon


## A short line above the description: what taking it does to the hero.
func tag() -> String:
	if kind == Kind.GENERIC:
		return "UPGRADE"
	if raises_held:
		return "SKILL  LV %d → %d" % [skill_level - 1, skill_level]
	return "NEW SKILL  LV %d" % skill_level


func description() -> String:
	return upgrade.description if kind == Kind.GENERIC else skill.description
