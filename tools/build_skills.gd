## One-shot tool: builds resources/skills/<id>.tres from design/skills.json.
## Run with:
##   & $env:GODOT --headless --path . --script res://tools/build_skills.gd
## The JSON holds the numbers; DELIVERY below holds how each skill is carried
## out in the arena, which the design file does not describe. Safe to re-run: it
## rewrites every skill, so change this file or the JSON rather than the .tres.
extends SceneTree

const JSON_PATH: String = "res://design/skills.json"
const OUTPUT: String = "res://resources/skills"
## Drawn by tools/build_skill_icons.gd; run that first.
const ICON_DIRECTORY: String = "res://assets/sprites/ui/skill_icons"
const MAGIC_BOLT: String = "res://scenes/effects/magic_bolt.tscn"
const CROSSBOW_BOLT: String = "res://scenes/effects/crossbow_bolt.tscn"

const WHITE: Color = Color(0.95, 0.95, 0.95, 0.7)
const GREEN: Color = Color(0.4, 1.0, 0.5, 0.7)
const ORANGE: Color = Color(1.0, 0.6, 0.2, 0.7)
const RED: Color = Color(1.0, 0.3, 0.25, 0.7)
const CYAN: Color = Color(0.5, 0.9, 1.0, 0.7)
const BLUE: Color = Color(0.4, 0.55, 1.0, 0.7)
const PURPLE: Color = Color(0.7, 0.45, 1.0, 0.7)
const YELLOW: Color = Color(1.0, 0.9, 0.4, 0.7)

## How each skill is carried out, keyed by skill id. `kind` is a SkillData.Kind
## name; everything else is a SkillData property.
const DELIVERY: Dictionary = {
	"whirl": {"kind": "AREA", "radius": 44.0, "tint": WHITE},
	"second_wind": {"kind": "HEAL", "tint": GREEN},
	"cleave": {"kind": "AREA", "radius": 52.0, "frontal": true, "tint": ORANGE},
	"bulwark": {"kind": "BUFF", "buff": "bulwark", "buff_duration": 4.0, "tint": BLUE},
	"firebolt": {
		"kind": "PROJECTILE", "projectile": MAGIC_BOLT, "cast_range": 180.0, "tint": ORANGE,
	},
	"frost_nova": {
		"kind": "AREA", "radius": 64.0, "slow": 0.5, "slow_duration": 3.0, "tint": CYAN,
	},
	"piercing_shot": {
		"kind": "PROJECTILE", "projectile": CROSSBOW_BOLT, "pierces": true,
		"cast_range": 200.0, "tint": YELLOW,
	},
	"swift_step": {"kind": "BUFF", "buff": "swift_step", "buff_duration": 3.0, "tint": YELLOW},
	"whirlwind": {"kind": "AREA", "radius": 56.0, "hits": 4, "duration": 2.0, "tint": RED},
	"blood_frenzy": {"kind": "BUFF", "buff": "blood_frenzy", "buff_duration": 6.0, "tint": RED},
	"meteor": {
		"kind": "DELAYED_AREA", "radius": 48.0, "delay": 1.0, "cast_range": 180.0,
		"tint": ORANGE,
	},
	"arcane_surge": {
		"kind": "BUFF", "buff": "arcane_surge", "buff_duration": 6.0, "tint": PURPLE,
	},
	"shadow_strike": {"kind": "STRIKE", "teleports": true, "cast_range": 140.0, "tint": PURPLE},
	"vanish": {"kind": "BUFF", "buff": "vanish", "tint": PURPLE},
	"flame_brand": {"kind": "BUFF", "buff": "flame_brand", "buff_duration": 8.0, "tint": ORANGE},
	"rune_slash": {"kind": "AREA", "radius": 56.0, "tint": ORANGE},
	"enchanted_volley": {
		"kind": "PROJECTILE", "projectile": MAGIC_BOLT, "projectile_count": 3, "spread": 0.22,
		"cast_range": 190.0, "tint": PURPLE,
	},
	"sigil_trap": {"kind": "TRAP", "radius": 32.0, "tint": PURPLE},
	"flurry": {
		"kind": "STRIKE", "hits": 5, "duration": 0.6, "cast_range": 48.0, "tint": WHITE,
	},
	"riposte": {"kind": "BUFF", "buff": "riposte", "buff_duration": 4.0, "tint": WHITE},
}

const TARGETS: Dictionary = {
	"nearest_enemy": SkillData.Target.NEAREST_ENEMY,
	"around_hero": SkillData.Target.AROUND_HERO,
	"self": SkillData.Target.SELF,
}


func _init() -> void:
	var text: String = FileAccess.get_file_as_string(JSON_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is not Dictionary:
		printerr("Could not read %s." % JSON_PATH)
		quit(1)
		return

	var failed: bool = false
	var seen: Array[String] = []
	for entry: Dictionary in (parsed as Dictionary)["skills"]:
		var skill: SkillData = _build(entry)
		if skill == null:
			failed = true
			continue
		var path: String = "%s/%s.tres" % [OUTPUT, skill.id]
		if ResourceSaver.save(skill, path) != OK:
			printerr("Could not save %s." % path)
			failed = true
			continue
		seen.append(String(skill.id))
		print("Wrote %s" % path)

	for id: StringName in SkillData.all_ids():
		if not seen.has(String(id)):
			printerr("%s/%s.tres has no entry in the JSON any more." % [OUTPUT, id])
			failed = true
	quit(1 if failed else 0)


func _build(entry: Dictionary) -> SkillData:
	var id: String = entry["id"]
	if not DELIVERY.has(id):
		printerr("No delivery described for skill '%s'." % id)
		return null
	var delivery: Dictionary = DELIVERY[id]

	var skill: SkillData = SkillData.new()
	skill.id = StringName(id)
	skill.display_name = entry["name"]
	skill.icon = load("%s/%s.png" % [ICON_DIRECTORY, id])
	skill.class_id = StringName(entry["class"])
	skill.description = entry["description"]
	skill.effect_note = entry.get("effect", "")
	skill.target = TARGETS[entry["target"]]
	for stat_name: String in entry["scaling"]:
		skill.scaling[StringName(stat_name)] = entry["scaling"][stat_name]
	skill.base_power = entry["base_power"]
	skill.power_per_level = entry["power_per_level"]
	skill.cooldown = entry["cooldown"]
	skill.cooldown_reduction_per_level = entry["cooldown_reduction_per_level"]
	skill.max_level = entry["max_level"]
	skill.supports_auto_cast = entry["supports_auto_cast"]

	for property: String in delivery:
		var value: Variant = delivery[property]
		match property:
			"kind":
				skill.kind = SkillData.Kind[value]
			"projectile":
				skill.projectile = load(value)
			"buff":
				skill.buff = StringName(value)
			_:
				skill.set(property, value)
	return skill
