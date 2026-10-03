class_name WeaponData
extends Resource
## One weapon template. Instances live in resources/weapons/, one file per
## weapon, named after its id.
##
## A weapon's strength comes only from the stats it scales off (DESIGN.md
## section 5.3): a sword draws on STR, so it hits hardest for whoever has the
## most STR. No class is favoured or forbidden.
##
## The numbers are placeholders. Like design/skills.json they cannot be
## balanced until enemies exist.

enum AttackStyle { MELEE, PROJECTILE }

const DIRECTORY: String = "res://resources/weapons"

@export var id: StringName = &""
@export var display_name: String = ""
## 16x16 inventory icon.
@export var icon: Texture2D
## The in-hand layer drawn behind the hero's body, built from the weapon's
## sheets by tools/build_sprite_frames.gd.
@export var frames: SpriteFrames

@export_group("Attack")
@export var attack_style: AttackStyle = AttackStyle.MELEE
@export_range(0.0, 100.0, 0.5) var base_damage: float = 0.0
## Damage added per point of each stat, keyed by HeroData stat property name,
## such as &"strength".
@export var scaling: Dictionary[StringName, float] = {}
## Seconds between auto-attacks.
@export_range(0.1, 5.0, 0.05, "suffix:s") var attack_interval: float = 1.0
## How far away a target can be and still be attacked.
@export_range(8.0, 400.0, 1.0, "suffix:px") var attack_range: float = 32.0


## The weapon with `weapon_id`, or null with an error if there is none.
static func find(weapon_id: StringName) -> WeaponData:
	var path: String = DIRECTORY.path_join("%s.tres" % weapon_id)
	if not ResourceLoader.exists(path):
		push_error("WeaponData: no weapon '%s' at %s." % [weapon_id, path])
		return null
	var data: WeaponData = load(path) as WeaponData
	if data == null:
		push_error("WeaponData: %s is not a WeaponData." % path)
	return data
