class_name SkillData
extends Resource
## One skill template. Instances live in resources/skills/, one file per skill,
## named after its id. They are generated from design/skills.json by
## tools/build_skills.gd; change the tool or the JSON and re-run it.
##
## A skill's strength is `power`, worked out from its level and the hero's stats
## (DESIGN.md section 5.5):
##
##   power = base_power + power_per_level * (level - 1) + sum(scaling[stat] * stat)
##
## What power means depends on the skill's kind: damage for an attack, health for
## a heal, a percentage or a number of tenths of a second for a buff. `kind` says
## how the skill is carried out; SkillCaster does it.

## What a skill aims at, and so when it is worth casting on its own.
enum Target { NEAREST_ENEMY, AROUND_HERO, SELF }
## How the skill is carried out.
enum Kind {
	## Hurts everything within `radius` of the hero, `hits` times over `duration`.
	AREA,
	## Hurts the nearest enemy `hits` times over `duration`, optionally teleporting
	## behind it first.
	STRIKE,
	## Releases `projectile_count` projectiles at the nearest enemy.
	PROJECTILE,
	## Marks the nearest enemy's spot and hurts everything within `radius` of it
	## after `delay`.
	DELAYED_AREA,
	## Restores health equal to power.
	HEAL,
	## Gives the hero the status named by `buff`.
	BUFF,
	## Leaves a rune on the ground that detonates when an enemy touches it.
	TRAP,
}

const DIRECTORY: String = "res://resources/skills"
const FILE_SUFFIX: String = ".tres"
## Cooldown reduction from levels never takes a skill below this.
const COOLDOWN_FLOOR: float = 0.2

## Every skill, filled in by all_skills() the first time it is asked for.
static var _everything: Array[SkillData] = []

@export var id: StringName = &""
@export var display_name: String = ""
## 16x16 icon, drawn by tools/build_skill_icons.gd. Shown in the skill tree, on
## the run's skill bar and on level-up cards.
@export var icon: Texture2D
## The class that grants it. A hero has every skill granted by a class in their
## lineage.
@export var class_id: StringName = &""
@export_multiline var description: String = ""
## Plain-language note on what the skill does beyond its description, as the
## design file words it.
@export_multiline var effect_note: String = ""
@export var target: Target = Target.NEAREST_ENEMY
@export var kind: Kind = Kind.AREA

@export_group("Power")
## Power per point of each stat, keyed by HeroData stat name. A map, so a hybrid
## skill can draw on two stats at once.
@export var scaling: Dictionary[StringName, float] = {}
@export_range(0.0, 1000.0, 0.5) var base_power: float = 0.0
@export_range(0.0, 1000.0, 0.5) var power_per_level: float = 0.0

@export_group("Cooldown")
@export_range(0.5, 120.0, 0.1, "suffix:s") var cooldown: float = 5.0
@export_range(0.0, 10.0, 0.05, "suffix:s") var cooldown_reduction_per_level: float = 0.0
@export_range(1, 10) var max_level: int = 5
## Whether the player may leave it to fire by itself. False for reactive skills.
@export var supports_auto_cast: bool = true

@export_group("Reach")
## How far away a target can be and still be cast on, for skills that aim.
## A self skill on auto-cast waits for an enemy this close.
@export_range(8.0, 400.0, 1.0, "suffix:px") var cast_range: float = 120.0
## Size of the area the skill hurts, where it has one.
@export_range(0.0, 200.0, 1.0, "suffix:px") var radius: float = 0.0
## Only hurt what is on the side the hero faces.
@export var frontal: bool = false

@export_group("Delivery")
## Total power is split evenly across this many hits.
@export_range(1, 20) var hits: int = 1
## Seconds the hits are spread over.
@export_range(0.0, 10.0, 0.05, "suffix:s") var duration: float = 0.0
## Seconds between the skill being marked and landing.
@export_range(0.0, 5.0, 0.05, "suffix:s") var delay: float = 0.0
## Released for a PROJECTILE skill. Its root must be a Projectile.
@export var projectile: PackedScene
@export_range(1, 9) var projectile_count: int = 1
## Angle between neighbouring projectiles of one cast.
@export_range(0.0, 1.0, 0.01, "suffix:rad") var spread: float = 0.2
## Keeps a projectile flying through every enemy it meets.
@export var pierces: bool = false
## Put the hero behind the target before the strike.
@export var teleports: bool = false
## Colour of the area marker the skill draws.
@export var tint: Color = Color(1.0, 1.0, 1.0, 0.5)

@export_group("Effects")
## Played once as the skill is cast, on the hero. Its root must be a OneShotEffect,
## drawn facing right; it is mirrored for a hero facing left. A skill with its own
## cast or target effect draws no flash ring.
@export var cast_effect: PackedScene
## Where the cast effect sits, from the hero's feet, before mirroring. Art drawn
## around the body wants (0, -12), the body's centre.
@export var cast_effect_offset: Vector2 = Vector2.ZERO
## Leave the cast effect where it was cast rather than carrying it with the hero.
@export var cast_effect_anchored: bool = false
## Played once at the target when the skill is cast: on the enemy a STRIKE hits,
## and on the spot a DELAYED_AREA marks. Its art must run for as long as the skill
## takes to land, and show the landing itself, since nothing else does.
@export var target_effect: PackedScene
## For BUFF: a looping scene kept on the hero, at the cast effect's offset, from the
## cast until the status ends, and flickering for its last second. A recast
## replaces it. Its art must loop.
@export var aura_effect: PackedScene

@export_group("Status")
## For BUFF: which status the hero gains (see HeroBuffs for what each means).
@export var buff: StringName = &""
## Seconds the status lasts. Vanish reads its length from power instead.
@export_range(0.0, 60.0, 0.1, "suffix:s") var buff_duration: float = 0.0
## Fraction of speed enemies hit lose, and for how long.
@export_range(0.0, 1.0, 0.05) var slow: float = 0.0
@export_range(0.0, 20.0, 0.1, "suffix:s") var slow_duration: float = 0.0


## Every skill's id, in alphabetical order.
static func all_ids() -> Array[StringName]:
	# Sorted as Strings: StringName comparison is not alphabetical.
	var names: PackedStringArray = []
	# ResourceLoader rather than DirAccess, so the listing still matches the
	# resources after export, where files are remapped.
	for file: String in ResourceLoader.list_directory(DIRECTORY):
		if file.ends_with(FILE_SUFFIX):
			names.append(file.trim_suffix(FILE_SUFFIX))
	names.sort()
	var ids: Array[StringName] = []
	for skill_name: String in names:
		ids.append(StringName(skill_name))
	return ids


## The skill with `skill_id`, or null with an error if there is none.
static func find(skill_id: StringName) -> SkillData:
	var path: String = DIRECTORY.path_join("%s%s" % [skill_id, FILE_SUFFIX])
	if not ResourceLoader.exists(path):
		push_error("SkillData: no skill '%s' at %s." % [skill_id, path])
		return null
	var data: SkillData = load(path) as SkillData
	if data == null:
		push_error("SkillData: %s is not a SkillData." % path)
	return data


## Every skill, loaded on first use and kept.
static func all_skills() -> Array[SkillData]:
	if _everything.is_empty():
		for skill_id: StringName in all_ids():
			var skill: SkillData = find(skill_id)
			if skill != null:
				_everything.append(skill)
	return _everything


## Every skill granted by a class in `class_ids`: the classes in the order given,
## and each class's skills by id.
static func granted_by(class_ids: Array[StringName]) -> Array[SkillData]:
	var found: Array[SkillData] = []
	for granting_class: StringName in class_ids:
		for skill: SkillData in all_skills():
			if skill.class_id == granting_class:
				found.append(skill)
	return found


## The skill a run begins with when none was chosen: the first that attacks, or
## failing that the first there is. Null for an empty list.
static func default_start(skills: Array[SkillData]) -> SkillData:
	for skill: SkillData in skills:
		if skill.target != Target.SELF:
			return skill
	return skills[0] if not skills.is_empty() else null


## Power at `level` for a hero with stat values `stats`, keyed like
## HeroData.STATS.
func power_at(level: int, stats: Dictionary[StringName, int]) -> float:
	var power: float = base_power + power_per_level * (maxi(level, 1) - 1)
	for stat_name: StringName in scaling:
		if not stats.has(stat_name):
			push_error("SkillData: %s scales off '%s', which is not a stat." % [id, stat_name])
			continue
		power += scaling[stat_name] * stats[stat_name]
	return power


## Seconds between casts at `level`, never below the floor.
func cooldown_at(level: int) -> float:
	return maxf(cooldown - cooldown_reduction_per_level * (maxi(level, 1) - 1), COOLDOWN_FLOOR)
