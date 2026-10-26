class_name SkillCaster
extends Node2D
## Carries a hero's skills through a run: counts their cooldowns down, fires
## the ones set to auto-cast when there is something to fire at, and fires the
## ones the player asks for with the skill keys.
##
## It belongs to a Hero and is wired to it in the editor. It does the skills'
## damage and healing through the hero's own methods, and puts anything that has
## to live in the world, such as projectiles and markers, into signals for
## whoever runs the level to add. What each skill kind does is on SkillData.

## A skill was just cast.
signal skill_cast(skill: HeldSkill)
## A skill was added, or its level changed.
signal skills_changed
## Auto-cast was switched on or off for every skill at once.
signal auto_cast_changed(enabled: bool)
## A skill let go of `projectile`, launched but not yet in the tree.
signal projectile_released(projectile: Projectile)
## A skill made something for the world, to be added at `at` in global space.
signal effect_spawned(effect: Node2D, at: Vector2)

## The most skills a hero can carry in one run.
const MAX_SKILLS: int = 4
const CAST_ACTIONS: Array[StringName] = [&"skill_1", &"skill_2", &"skill_3", &"skill_4"]
## Collision layer 3, "enemy".
const ENEMY_MASK: int = 4
const MAX_QUERY_RESULTS: int = 64
## An enemy is within reach by where it stands; the query is made this much
## wider so a shape that overlaps the circle but stands outside is not missed.
const QUERY_MARGIN: float = 8.0
## How far behind a hero's side of the target they land after a blink.
const BLINK_OFFSET: float = 16.0
## A self-heal set to auto-cast waits for the hero to be hurt this badly.
const AUTO_HEAL_BELOW: float = 0.6
## Bulwark never takes off more than this percentage of the damage.
const BULWARK_CAP: float = 70.0
## Seconds a self skill's flash ring stays up, and how big it is.
const FLASH_SECONDS: float = 0.35
const SELF_FLASH_RADIUS: float = 20.0
## Vanish's power is tenths of a second.
const VANISH_UNIT: float = 0.1
## An aura flickers for this long before its buff ends, and fades out over
## AURA_FADE when it does.
const AURA_WARNING: float = 1.0
const AURA_FADE: float = 0.2

## Whose skills these are.
@export var hero: Hero
## Left on the ground by a trap skill.
@export var trap_scene: PackedScene

var held: Array[HeldSkill] = []
## Whether skills fire by themselves. One switch for all of them; a skill that
## refuses auto-cast (SkillData.supports_auto_cast) is always cast by hand.
var auto_cast: bool = true

var _query_circle: CircleShape2D = CircleShape2D.new()
## The aura of each running buff, by status id.
var _auras: Dictionary[StringName, Node2D] = {}


func _ready() -> void:
	if hero != null:
		hero.buffs.ended.connect(_on_buff_ended)


func _process(_delta: float) -> void:
	for id: StringName in _auras:
		var aura: Node2D = _auras[id]
		if not is_instance_valid(aura):
			continue
		var left: float = hero.buffs.remaining(id)
		var blink: bool = left < AURA_WARNING and int(left * 8.0) % 2 == 0
		aura.modulate.a = 0.35 if blink else 1.0


func _physics_process(delta: float) -> void:
	if hero == null or hero.is_dead():
		return
	var rate: float = 1.0 + hero.buffs.magnitude(HeroBuffs.ARCANE_SURGE) / 100.0
	for skill: HeldSkill in held:
		skill.cooldown_left = maxf(skill.cooldown_left - delta * rate, 0.0)
		if (
			auto_cast
			and skill.data.supports_auto_cast
			and skill.is_ready()
			and _can_cast(skill, false)
		):
			_cast(skill)


func _unhandled_input(event: InputEvent) -> void:
	if hero == null or hero.is_dead():
		return
	if event.is_action_pressed(&"toggle_auto_cast") and not event.is_echo():
		get_viewport().set_input_as_handled()
		set_auto_cast(not auto_cast)
		return
	for i: int in mini(held.size(), CAST_ACTIONS.size()):
		if event.is_action_pressed(CAST_ACTIONS[i]) and not event.is_echo():
			get_viewport().set_input_as_handled()
			var skill: HeldSkill = held[i]
			if skill.is_ready() and _can_cast(skill, true):
				_cast(skill)
			return


## Switch auto-cast on or off for every skill.
func set_auto_cast(enabled: bool) -> void:
	if enabled == auto_cast:
		return
	auto_cast = enabled
	auto_cast_changed.emit(enabled)


## Cast `skill` now, whether or not it is carried, ready, or has anything to hit.
## For previews and tests; play goes through the skill keys and auto-cast.
func cast_now(skill: HeldSkill) -> void:
	if hero == null or hero.is_dead():
		return
	_cast(skill)


## Carry exactly `skills`, replacing whatever was carried.
func set_loadout(skills: Array[HeldSkill]) -> void:
	held = skills.duplicate()
	skills_changed.emit()


func has_room() -> bool:
	return held.size() < MAX_SKILLS


## The carried skill with `skill_id`, or null.
func find_held(skill_id: StringName) -> HeldSkill:
	for skill: HeldSkill in held:
		if skill.data.id == skill_id:
			return skill
	return null


## Carry one more skill, if there is room and it is not already carried.
func add_skill(skill: HeldSkill) -> bool:
	if not has_room() or find_held(skill.data.id) != null:
		push_error("SkillCaster: cannot carry '%s'." % skill.data.id)
		return false
	held.append(skill)
	skills_changed.emit()
	return true


## Raise a carried skill by one level for the rest of the run, up to its max.
func level_up(skill_id: StringName) -> bool:
	var skill: HeldSkill = find_held(skill_id)
	if skill == null or skill.is_maxed():
		push_error("SkillCaster: cannot level up '%s'." % skill_id)
		return false
	skill.level += 1
	skills_changed.emit()
	return true


## Power of `skill` right now, with the hero's stats and the run's damage
## bonuses where they apply.
func power_of(skill: HeldSkill) -> float:
	var power: float = skill.data.power_at(skill.level, hero.skill_stats())
	if _is_damage(skill.data):
		power *= hero.damage_multiplier()
	return power


## Whether power is damage, and so grows with damage upgrades.
func _is_damage(data: SkillData) -> bool:
	match data.kind:
		SkillData.Kind.HEAL, SkillData.Kind.BUFF:
			return false
	return true


## Whether `skill` has anything to do right now. A manual cast is turned down
## only when it would do nothing at all, so a press never wastes a cooldown; an
## auto-cast also waits for a reason: an enemy in reach, or a hurt hero.
func _can_cast(skill: HeldSkill, manual: bool) -> bool:
	var data: SkillData = skill.data
	match data.target:
		SkillData.Target.AROUND_HERO:
			return not _enemies_near(hero.global_position, data.radius, data.frontal).is_empty()
		SkillData.Target.NEAREST_ENEMY:
			return _nearest_enemy(data.cast_range) != null
		SkillData.Target.SELF:
			if data.kind == SkillData.Kind.HEAL:
				var health_ratio: float = hero.health.ratio()
				return health_ratio < 1.0 and (manual or health_ratio < AUTO_HEAL_BELOW)
			if manual:
				return true
			return _nearest_enemy(data.cast_range) != null
	return false


func _cast(skill: HeldSkill) -> void:
	var data: SkillData = skill.data
	var power: float = power_of(skill)
	skill.cooldown_left = skill.cooldown()
	_play_cast_effect(data)
	match data.kind:
		SkillData.Kind.AREA:
			_cast_area(data, power)
		SkillData.Kind.STRIKE:
			_cast_strike(data, power)
		SkillData.Kind.PROJECTILE:
			_cast_projectiles(data, power)
		SkillData.Kind.DELAYED_AREA:
			_cast_delayed_area(data, power)
		SkillData.Kind.HEAL:
			hero.heal(power)
			_flash(data, hero.global_position, SELF_FLASH_RADIUS)
		SkillData.Kind.BUFF:
			_cast_buff(data, power)
		SkillData.Kind.TRAP:
			_cast_trap(data, power)
	skill_cast.emit(skill)


func _cast_area(data: SkillData, power: float) -> void:
	_flash(data, hero.global_position, data.radius)
	var per_hit: float = power / data.hits
	for i: int in data.hits:
		var wait: float = data.duration * i / data.hits
		if is_zero_approx(wait):
			_area_hit(data, per_hit)
		else:
			get_tree().create_timer(wait, false).timeout.connect(_area_hit.bind(data, per_hit))


func _area_hit(data: SkillData, damage: float) -> void:
	if hero.is_dead():
		return
	for enemy: Enemy in _enemies_near(hero.global_position, data.radius, data.frontal):
		enemy.take_damage(damage)
		if data.slow > 0.0:
			enemy.slow(data.slow, data.slow_duration)


func _cast_strike(data: SkillData, power: float) -> void:
	var enemy: Enemy = _nearest_enemy(data.cast_range)
	if enemy == null:
		return
	if data.teleports:
		_blink_behind(enemy)
	_play_target_effect(data, enemy.center())
	var per_hit: float = power / data.hits
	var enemy_id: int = enemy.get_instance_id()
	for i: int in data.hits:
		var wait: float = data.duration * i / data.hits
		if is_zero_approx(wait):
			_strike_hit(enemy_id, per_hit)
		else:
			var strike: Callable = _strike_hit.bind(enemy_id, per_hit)
			get_tree().create_timer(wait, false).timeout.connect(strike)


## The enemy is passed as an instance id because it may have been freed by the
## time a delayed hit lands, and a freed object cannot be bound to a callable.
func _strike_hit(enemy_id: int, damage: float) -> void:
	var target: Object = instance_from_id(enemy_id)
	if not is_instance_valid(target) or target is not Enemy or hero.is_dead():
		return
	var enemy: Enemy = target
	if not enemy.is_dead():
		enemy.take_damage(damage)


## Put the hero on the far side of `enemy`, if there is room to stand there.
func _blink_behind(enemy: Enemy) -> void:
	var away: Vector2 = hero.global_position.direction_to(enemy.global_position)
	if away.is_zero_approx():
		return
	var spot: Vector2 = enemy.global_position + away * BLINK_OFFSET
	if hero.can_stand_at(spot):
		hero.teleport_to(spot)


func _cast_projectiles(data: SkillData, power: float) -> void:
	if data.projectile == null:
		push_error("SkillCaster: skill '%s' has no projectile." % data.id)
		return
	var enemy: Enemy = _nearest_enemy(data.cast_range)
	if enemy == null:
		return
	var origin: Vector2 = hero.global_position + Enemy.BODY_CENTER
	var aim: Vector2 = origin.direction_to(enemy.center())
	if aim.is_zero_approx():
		aim = Vector2.RIGHT if hero.is_facing_right() else Vector2.LEFT
	for i: int in data.projectile_count:
		var node: Node = data.projectile.instantiate()
		if node is not Projectile:
			push_error("SkillCaster: projectile of skill '%s' is not a Projectile." % data.id)
			node.free()
			return
		var shot: Projectile = node
		shot.damage = power / data.projectile_count
		shot.pierces = data.pierces
		var angle: float = (i - (data.projectile_count - 1) * 0.5) * data.spread
		shot.launch(origin, aim.rotated(angle), data.cast_range, hero.velocity)
		projectile_released.emit(shot)


func _cast_delayed_area(data: SkillData, power: float) -> void:
	var enemy: Enemy = _nearest_enemy(data.cast_range)
	if enemy == null:
		return
	var spot: Vector2 = enemy.global_position
	_mark(data.tint, spot, data.radius, data.delay, true)
	_play_target_effect(data, spot)
	get_tree().create_timer(data.delay, false).timeout.connect(_land.bind(data, spot, power))


func _land(data: SkillData, spot: Vector2, damage: float) -> void:
	for enemy: Enemy in _enemies_near(spot, data.radius):
		enemy.take_damage(damage)
	_flash(data, spot, data.radius)


func _cast_buff(data: SkillData, power: float) -> void:
	var magnitude: float = power
	var seconds: float = data.buff_duration
	match data.buff:
		HeroBuffs.BULWARK:
			magnitude = minf(power, BULWARK_CAP)
		HeroBuffs.VANISH:
			magnitude = 1.0
			seconds = power * VANISH_UNIT
	hero.buffs.apply(data.buff, magnitude, seconds)
	if seconds > 0.0:
		_show_aura(data)
	_flash(data, hero.global_position, SELF_FLASH_RADIUS)


## Keep the skill's aura on the hero until its buff ends, replacing the last one.
func _show_aura(data: SkillData) -> void:
	_remove_aura(data.buff)
	var aura: Node2D = _make_effect(data.aura_effect, data)
	if aura == null:
		return
	aura.position = data.cast_effect_offset
	add_child(aura)
	_auras[data.buff] = aura


func _remove_aura(id: StringName) -> void:
	var aura: Node2D = _auras.get(id)
	if aura == null:
		return
	_auras.erase(id)
	if not is_instance_valid(aura):
		return
	aura.modulate.a = 1.0
	var fade: Tween = aura.create_tween()
	fade.tween_property(aura, "modulate:a", 0.0, AURA_FADE)
	fade.tween_callback(aura.queue_free)


func _on_buff_ended(id: StringName) -> void:
	_remove_aura(id)


func _cast_trap(data: SkillData, power: float) -> void:
	if trap_scene == null:
		push_error("SkillCaster: trap_scene must be wired to cast a trap.")
		return
	var node: Node = trap_scene.instantiate()
	if node is not SigilTrap:
		push_error("SkillCaster: trap_scene must have a SigilTrap root.")
		node.free()
		return
	var trap: SigilTrap = node
	trap.damage = power
	trap.radius = data.radius
	trap.tint = data.tint
	effect_spawned.emit(trap, hero.global_position)


## A ring that fades, to show a skill went off. A skill with art of its own has no
## need of it.
func _flash(data: SkillData, at: Vector2, ring_radius: float) -> void:
	if data.cast_effect != null or data.target_effect != null:
		return
	_mark(data.tint, at, maxf(ring_radius, SELF_FLASH_RADIUS), FLASH_SECONDS, false)


## Play the skill's cast effect on the hero, or where the hero stands if it is
## anchored.
func _play_cast_effect(data: SkillData) -> void:
	var effect: Node2D = _make_effect(data.cast_effect, data)
	if effect == null:
		return
	var offset: Vector2 = data.cast_effect_offset
	if not hero.is_facing_right():
		offset.x = -offset.x
		effect.scale.x = -1.0
	if data.cast_effect_anchored:
		effect_spawned.emit(effect, hero.global_position + offset)
		return
	effect.position = offset
	add_child(effect)


## Play the skill's target effect at `at`, in global space.
func _play_target_effect(data: SkillData, at: Vector2) -> void:
	var effect: Node2D = _make_effect(data.target_effect, data)
	if effect == null:
		return
	if not hero.is_facing_right():
		effect.scale.x = -1.0
	effect_spawned.emit(effect, at)


## A new instance of `scene`, or null if the skill has none or it is not a Node2D.
func _make_effect(scene: PackedScene, data: SkillData) -> Node2D:
	if scene == null:
		return null
	var node: Node = scene.instantiate()
	if node is not Node2D:
		push_error("SkillCaster: an effect of skill '%s' is not a Node2D." % data.id)
		node.free()
		return null
	var effect: Node2D = node
	# Above the y-sorted crowd, as the world's other effects are.
	effect.z_index = 1
	return effect


func _mark(tint: Color, at: Vector2, ring_radius: float, seconds: float, filling: bool) -> void:
	var marker: AreaMarker = AreaMarker.new()
	marker.setup(ring_radius, tint, seconds, filling)
	effect_spawned.emit(marker, at)


func _nearest_enemy(max_distance: float) -> Enemy:
	var best: Enemy = null
	var best_distance: float = max_distance
	for enemy: Enemy in _enemies_near(hero.global_position, max_distance):
		var distance: float = hero.global_position.distance_to(enemy.global_position)
		if distance <= best_distance:
			best = enemy
			best_distance = distance
	return best


## Every live enemy standing within `reach` of `point`. With `frontal`, only the
## ones on the side the hero faces.
func _enemies_near(point: Vector2, reach: float, frontal: bool = false) -> Array[Enemy]:
	var found: Array[Enemy] = []
	_query_circle.radius = reach + QUERY_MARGIN
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = _query_circle
	query.transform = Transform2D(0.0, point)
	query.collision_mask = ENEMY_MASK
	var facing: float = 1.0 if hero.is_facing_right() else -1.0
	for hit: Dictionary in get_world_2d().direct_space_state.intersect_shape(
		query, MAX_QUERY_RESULTS
	):
		var collider: Object = hit["collider"]
		if collider is not Enemy:
			continue
		var enemy: Enemy = collider
		if enemy.is_dead() or point.distance_to(enemy.global_position) > reach:
			continue
		if frontal and (enemy.global_position.x - hero.global_position.x) * facing < 0.0:
			continue
		found.append(enemy)
	return found
