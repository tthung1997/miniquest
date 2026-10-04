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
## The in-hand layer drawn in front of the hero, built from the weapon's
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

@export_group("Attack visuals")
## Frame of the weapon's attack clip on which the effect and the projectile
## appear.
@export_range(0, 15) var release_frame: int = 0
## Where they appear, relative to the hero's feet with the hero facing right
## and in the body's idle pose. The doll adds the hand's offset on other body
## frames and mirrors the point when the hero faces left.
@export var release_point: Vector2 = Vector2.ZERO
## Drawn on the hero for the moment of the attack, such as the sword's slash.
## It follows the hero and should free itself when done.
@export var attack_effect: PackedScene
## Released into the world to fly ahead for attack_range, such as a crossbow
## bolt. Its root must be a Projectile.
@export var projectile: PackedScene


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
