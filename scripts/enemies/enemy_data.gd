class_name EnemyData
extends Resource
## One enemy template. Instances live in resources/enemies/, one file per
## enemy, named after its id.
##
## The numbers are placeholders. Like every combat number they cannot be
## balanced until the arena run can be played.

@export var id: StringName = &""
@export var display_name: String = ""
## Built from the monster's pack sheet by tools/build_enemy_frames.gd. Needs a
## looping `walk` clip drawn facing right.
@export var frames: SpriteFrames

@export_group("Combat")
@export_range(1.0, 10000.0, 1.0) var max_health: float = 10.0
@export_range(0.0, 400.0, 1.0, "suffix:px/s") var speed: float = 40.0
## Damage dealt to the hero each time it touches them.
@export_range(0.0, 1000.0, 0.5) var contact_damage: float = 5.0
## Seconds between one enemy's hits while it keeps touching the hero.
@export_range(0.1, 5.0, 0.05, "suffix:s") var contact_interval: float = 1.0

@export_group("Rewards")
## Experience the hero earns for killing one.
@export_range(0, 1000) var experience: int = 1
