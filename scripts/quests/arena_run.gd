class_name ArenaRun
extends Node2D
## One playthrough of the arena quest: the meadow, the hero, and a RunDirector
## sending enemies in along the quest's ramp.
##
## A run ends three ways: the hero survives the quest's full duration (a win),
## the hero dies, or the player retreats from the pause menu. A death and a
## retreat are the same to the rewards (DESIGN.md section 6.5). Whichever it
## is, the tree is paused behind a results panel until the player continues,
## and then `finished` carries the RunResult to whoever banks it. The run
## itself saves nothing and changes no scene.

## The player pressed Continue on the results panel. The tree is no longer
## paused, so whatever listens can swap scenes.
signal finished(result: RunResult)

## Seconds between the hero falling and the results panel, so the death is seen.
const DEATH_DELAY: float = 0.75
## Weapon given to a hero when this scene is run on its own.
const STANDALONE_WEAPON: StringName = &"sword"
const RETREAT_WARNING: String = (
	"Retreating ends the run like a defeat: only the experience you earned is kept."
)

var _kills: int = 0
var _experience: int = 0
var _ending: bool = false
var _result: RunResult = null
var _run_started: bool = false

@onready var hero: Hero = $Hero
@onready var _arena: ArenaMap = $Meadow
@onready var _camera: Camera2D = $Hero/Camera
## Kept above the y-sorted hero and trees, so shots are never hidden.
@onready var _projectiles: Node2D = $Projectiles
@onready var _director: RunDirector = $RunDirector
@onready var _readout: Label = $HUD/Root/Readout
@onready var _pause_menu: PauseMenu = %PauseMenu
@onready var _retreat_dialog: ConfirmDialog = %RetreatDialog
@onready var _end_panel: RunEndPanel = %EndPanel


func _ready() -> void:
	# Run on its own there is no saved hero to dress from, so start armed.
	if hero.weapon == null:
		hero.wield(WeaponItem.create(STANDALONE_WEAPON))
	hero.position = _arena.position + _arena.playable_rect.get_center()
	var limits: Rect2i = Rect2i(_arena.map_rect)
	limits.position += Vector2i(_arena.position)
	_camera.limit_left = limits.position.x
	_camera.limit_top = limits.position.y
	_camera.limit_right = limits.end.x
	_camera.limit_bottom = limits.end.y

	hero.projectile_released.connect(_on_hero_projectile_released)
	hero.died.connect(_on_hero_died)
	_director.enemy_killed.connect(_on_enemy_killed)
	_director.survived.connect(_on_run_survived)
	_pause_menu.resume_requested.connect(_on_resume_requested)
	_pause_menu.retreat_requested.connect(_on_retreat_requested)
	_retreat_dialog.confirmed.connect(_end.bind(RunResult.Outcome.RETREATED))
	_retreat_dialog.cancelled.connect(_pause_menu.open)
	_end_panel.continue_pressed.connect(_on_continue_pressed)

	# A saved hero is shown right after this scene is added, which starts the
	# run at their level; this only covers the scene being run on its own.
	_start_standalone_run.call_deferred()
	_refresh()


func _exit_tree() -> void:
	# A pause left on would freeze whatever screen comes next.
	if get_tree() != null:
		get_tree().paused = false


## Dress the hero as `data` and start the run at their level.
func show_hero(data: HeroData) -> void:
	hero.apply(data)
	_start_run(data.level)
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") and not event.is_echo() and not _ending:
		get_viewport().set_input_as_handled()
		get_tree().paused = true
		_pause_menu.open()


func _start_standalone_run() -> void:
	if not _run_started:
		_start_run(1)


func _start_run(level: int) -> void:
	_run_started = true
	_director.start(level)


## Finish the run as `outcome`, once: whatever ends it first wins.
func _end(outcome: RunResult.Outcome) -> void:
	if _result != null:
		return
	_ending = true
	_director.stop()
	_result = RunResult.new()
	_result.outcome = outcome
	_result.time_survived = _director.elapsed
	_result.duration = _director.quest.duration
	_result.kills = _kills
	_result.experience = _experience
	get_tree().paused = true
	_end_panel.show_result(_result)


func _on_hero_died() -> void:
	if _ending:
		return
	_ending = true
	_director.stop()
	await get_tree().create_timer(DEATH_DELAY).timeout
	if is_inside_tree():
		_end(RunResult.Outcome.DIED)


func _on_run_survived() -> void:
	if not _ending:
		_end(RunResult.Outcome.WON)


func _on_enemy_killed(enemy: Enemy) -> void:
	_kills += 1
	_experience += enemy.data.experience


func _on_resume_requested() -> void:
	_pause_menu.close()
	get_tree().paused = false


func _on_retreat_requested() -> void:
	_pause_menu.close()
	_retreat_dialog.open(RETREAT_WARNING, "RETREAT", "KEEP FIGHTING")


func _on_continue_pressed() -> void:
	get_tree().paused = false
	finished.emit(_result)


func _on_hero_projectile_released(projectile: Projectile) -> void:
	_projectiles.add_child(projectile)


func _refresh() -> void:
	_readout.text = (
		"HP %d/%d    kills %d    exp +%d    time %s / %s\nEsc to pause"
		% [
			ceili(hero.health.current),
			roundi(hero.health.maximum),
			_kills,
			_experience,
			RunResult.clock(_director.elapsed),
			RunResult.clock(_director.quest.duration),
		]
	)
