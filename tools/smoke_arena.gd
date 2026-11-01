## Plays one arena run headless and fast, then prints how it went. Not shipped.
## Exercises the roster, the elite, drops and the results panel without a human.
##
##   & $env:GODOT --headless --path . --script res://tools/smoke_arena.gd -- --level=10 --god
##
## Options after `--`:
##   --level=N   the hero's level (default 1)
##   --scale=N   time scale; the run's 3 minutes pass N times faster (default 8)
##   --god       the hero cannot die, so the whole run and the elite are seen
##   --kite      a simple bot plays the hero: it closes in on enemies, backs away
##               from crowds and returns to the middle; without it the hero
##               stands still and is swarmed
##   --skill=N   upgrade card to pick on each level-up, 1 to 3 (default 1)
##   --weapon=ID the weapon template the hero holds, such as wand or crossbow
##
## Exit code 1 when the run never ends or a script error is printed; the
## printed figures are for tuning and say nothing about how it feels to play.
extends SceneTree

const ARENA_SCENE: String = "res://scenes/quests/arena_run.tscn"
## Real seconds before giving up on a run that never ends.
const TIMEOUT: float = 240.0
## The bot backs away from enemies closer than this share of its weapon's reach,
## and from a wall closer than WALL_MARGIN pixels when enemies are about.
const DANGER_SHARE: float = 0.6
const WALL_MARGIN: float = 90.0

var _level: int = 1
var _scale: float = 8.0
var _god: bool = false
var _kite: bool = false
var _weapon: StringName = &""
var _card: int = 0
var _run: ArenaRun = null
var _director: RunDirector = null
var _end_panel: RunEndPanel = null
var _seen: Dictionary[StringName, int] = {}
var _killed: Dictionary[StringName, int] = {}
var _elite_at: float = -1.0
var _started_msec: int = 0
var _last_report: int = 0


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--level="):
			_level = clampi(arg.trim_prefix("--level=").to_int(), 1, Levelling.MAX_LEVEL)
		elif arg.begins_with("--scale="):
			_scale = clampf(arg.trim_prefix("--scale=").to_float(), 1.0, 50.0)
		elif arg.begins_with("--skill="):
			_card = clampi(arg.trim_prefix("--skill=").to_int() - 1, 0, 2)
		elif arg.begins_with("--weapon="):
			_weapon = StringName(arg.trim_prefix("--weapon="))
		elif arg == "--god":
			_god = true
		elif arg == "--kite":
			_kite = true

	var hero: HeroData = HeroData.create("Smoke")
	hero.gain_experience(Levelling.total_exp_for(_level))
	_build(hero)
	var scene: PackedScene = load(ARENA_SCENE)
	_run = scene.instantiate()
	root.add_child(_run)
	_start.call_deferred(hero)


## Play the hub as a sensible player would: advance class whenever one is open,
## split free points between strength and vitality, and spend skill points.
func _build(hero: HeroData) -> void:
	if _weapon != &"":
		var held: WeaponItem = WeaponItem.create(_weapon)
		if held != null:
			hero.weapon = held
	var advanced: bool = true
	while advanced:
		advanced = false
		for option: ClassData in hero.advancement_options():
			if hero.can_advance_to(option) and hero.advance_to(option.id):
				advanced = true
				break
	var to_strength: int = ceili(hero.unspent_points / 2.0)
	var allocation: Dictionary[StringName, int] = {
		&"strength": to_strength, &"vitality": hero.unspent_points - to_strength
	}
	hero.spend_points(allocation)
	var raised: bool = true
	while raised:
		raised = false
		for skill: SkillData in hero.unlocked_skills():
			if hero.can_raise_skill(skill) and hero.raise_skill(skill):
				raised = true


func _start(hero: HeroData) -> void:
	_run.show_hero(hero)
	_director = _run.get_node("RunDirector")
	_end_panel = _run.get_node("%EndPanel")
	_director.enemy_killed.connect(_on_enemy_killed)
	_director.elite_spawned.connect(_on_elite_spawned)
	if _god:
		_run.hero.health.changed.connect(_on_hero_health_changed)
	Engine.time_scale = _scale
	_started_msec = Time.get_ticks_msec()
	print("smoke: level %d, scale %.0f, god %s" % [_level, _scale, _god])


func _process(_delta: float) -> bool:
	if _director == null:
		return false
	if _end_panel.visible:
		_report()
		quit(0)
		return true
	if (Time.get_ticks_msec() - _started_msec) / 1000.0 > TIMEOUT:
		printerr("smoke: timed out at run time %.1f" % _director.elapsed)
		quit(1)
		return true

	for enemy: Enemy in _director.enemies:
		_seen[enemy.data.id] = _seen.get(enemy.data.id, 0) + 1
	_pick_upgrade()
	if _kite:
		_steer_away()
	var whole: int = floori(_director.elapsed / 30.0)
	if whole > _last_report:
		_last_report = whole
		print(
			"smoke: %s  hp %d  alive %d  kills %d"
			% [
				RunResult.clock(_director.elapsed),
				ceili(_run.hero.health.current),
				_director.enemies.size(),
				_kill_total(),
			]
		)
	return false


## Play like a cautious player: close in on the nearest enemy to fight it, back
## away from a crowd closing in, and drift to the arena's middle otherwise so
## the hero is not pinned against a wall.
func _steer_away() -> void:
	var hero_at: Vector2 = _run.hero.global_position
	var arena: ArenaMap = _run.get_node("Meadow")
	var middle: Vector2 = arena.global_position + arena.playable_rect.get_center()
	var weapon: WeaponData = _run.hero.weapon.data() if _run.hero.weapon != null else null
	var reach: float = weapon.attack_range if weapon != null else 40.0
	var push: Vector2 = Vector2.ZERO
	var close: int = 0
	var nearest: Enemy = null
	var nearest_distance: float = INF
	var danger: float = reach * DANGER_SHARE
	for enemy: Enemy in _director.enemies:
		var away: Vector2 = hero_at - enemy.global_position
		var distance: float = maxf(away.length(), 1.0)
		if distance < danger:
			close += 1
			push += away / distance * (danger / distance)
		if distance < nearest_distance:
			nearest = enemy
			nearest_distance = distance
	var edge: float = minf(
		minf(hero_at.x - arena.global_position.x - arena.playable_rect.position.x,
			arena.global_position.x + arena.playable_rect.end.x - hero_at.x),
		minf(hero_at.y - arena.global_position.y - arena.playable_rect.position.y,
			arena.global_position.y + arena.playable_rect.end.y - hero_at.y)
	)
	if close == 0:
		if nearest != null and nearest_distance > reach and nearest_distance < 250.0:
			push = (nearest.global_position - hero_at).normalized()
		elif nearest_distance >= 250.0:
			push = (middle - hero_at).normalized() * 0.4
	elif edge < WALL_MARGIN:
		push += (middle - hero_at).normalized() * 2.0
	push = push.normalized() if push.length() > 1.0 else push
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		Input.action_release(action)
	if push.x < -0.2:
		Input.action_press(&"move_left", -push.x)
	if push.x > 0.2:
		Input.action_press(&"move_right", push.x)
	if push.y < -0.2:
		Input.action_press(&"move_up", -push.y)
	if push.y > 0.2:
		Input.action_press(&"move_down", push.y)


## Choose a card whenever the level-up overlay is waiting.
func _pick_upgrade() -> void:
	var overlay: UpgradeOverlay = _run.get_node("%UpgradeOverlay")
	if not overlay.visible:
		return
	var press: InputEventAction = InputEventAction.new()
	press.action = SkillCaster.CAST_ACTIONS[_card]
	press.pressed = true
	Input.parse_input_event(press)


func _report() -> void:
	var title: Label = _end_panel.get_node("%Title")
	var details: Label = _end_panel.get_node("%Details")
	print("smoke: %s" % title.text)
	print(details.text)
	print("smoke: killed %s" % _killed)
	print("smoke: frames each enemy type was on screen %s" % _seen)
	print("smoke: elite spawned at %.1f" % _elite_at)


func _on_hero_health_changed(_current: float, _maximum: float) -> void:
	_run.hero.health.heal(_run.hero.health.maximum)


func _kill_total() -> int:
	var total: int = 0
	for count: int in _killed.values():
		total += count
	return total


func _on_enemy_killed(enemy: Enemy) -> void:
	_killed[enemy.data.id] = _killed.get(enemy.data.id, 0) + 1


func _on_elite_spawned(_elite: Enemy) -> void:
	_elite_at = _director.elapsed
