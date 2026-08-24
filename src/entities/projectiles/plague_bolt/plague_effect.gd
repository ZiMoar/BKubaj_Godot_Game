class_name PlagueEffect
extends Node2D

## Bursting Plague's ramping necrotic damage-over-time. Attaches to a target
## enemy, deals a necrotic tick that ramps up over the plague's lifetime, and
## when the host enemy dies it SPREADS to `spread_count` random enemies in range
## (each fresh plague resets its ramp). Lifetime = the plague's duration; if the
## host survives that long the plague simply expires.
##
## Signatures:
##  - Pestilence: ticks start strong and DECAY over time instead of ramping up.
##  - Black Death: the host periodically leaks plague to a nearby enemy.
##  - Contagion: spread may re-infect already-plagued enemies (stacking).

var target: Node2D = null
var weapon: Node = null
var base_tick_damage: int = 8
var tick_interval: float = 0.8
var ramp_mult: float = 1.4        # per-tick damage multiplier
var lifetime: float = 6.0
var spread_count: int = 1
var spread_range: float = 150.0

var _tick_timer: float = 0.8
var _ramp: float = 1.0
var _pest_mult: float = 1.0
var _emit_timer: float = 0.0
var _age: float = 0.0
var _spread_done: bool = false
var _visual_only: bool = false    # co-op remote copy: no damage/follow/spread


func _ready() -> void:
	z_index = 12
	_tick_timer = tick_interval
	if weapon:
		_pest_mult = weapon.PESTILENCE_START
		_emit_timer = weapon.BLACK_DEATH_EMIT
	_register_host()
	queue_redraw()


func _exit_tree() -> void:
	_unregister_host()


func setup(tgt: Node2D, w: Node, bd: int, interval: float, rm: float, life: float, sc: int, sr: float) -> void:
	target = tgt
	weapon = w
	base_tick_damage = bd
	tick_interval = interval
	ramp_mult = rm
	lifetime = life
	spread_count = sc
	spread_range = sr
	_tick_timer = interval
	if weapon:
		_pest_mult = weapon.PESTILENCE_START
		_emit_timer = weapon.BLACK_DEATH_EMIT
	_register_host()


## Co-op: render an inert visual-only copy for the lifetime at a fixed spot.
func setup_visual(data: Dictionary) -> void:
	_visual_only = true
	lifetime = float(data.get("life", lifetime))
	_tick_timer = tick_interval
	queue_redraw()


func _process(delta: float) -> void:
	if _visual_only:
		_age += delta
		queue_redraw()
		if _age >= lifetime:
			queue_free()
		return

	if not is_instance_valid(target):
		queue_free()
		return
	global_position = target.global_position
	queue_redraw()

	_age += delta
	if _age >= lifetime:
		queue_free()
		return

	# Black Death: periodically leak plague to a nearby enemy.
	if weapon and weapon.black_death:
		_emit_timer -= delta
		if _emit_timer <= 0.0:
			_emit_timer = weapon.BLACK_DEATH_EMIT
			_leak_once()

	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer = tick_interval
		if is_instance_valid(target) and target.has_method("take_damage"):
			var dmg: int
			if weapon and weapon.pestilence:
				# Decaying: strong start, fades out.
				dmg = maxi(1, int(round(float(base_tick_damage) * _pest_mult)))
				_pest_mult = maxf(weapon.PESTILENCE_FLOOR, _pest_mult * weapon.PESTILENCE_DECAY)
			else:
				dmg = maxi(1, int(round(float(base_tick_damage) * _ramp)))
				_ramp *= ramp_mult
			target.take_damage(dmg, false, DamageType.Type.NECROTIC, true)
			if weapon and target.has_method("has_died") and target.has_died():
				weapon.apply_explosion_on_kill(target.global_position, dmg)

	if _target_dead():
		_spread()
		queue_free()


## Black Death: emit a single new plague to a random neighbour (fresh or, with
## Contagion, an already-plagued one).
func _leak_once() -> void:
	var origin: Vector2 = global_position
	var pool: Array[Node2D] = []
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var en: Node2D = e as Node2D
		if en == null or en == target:
			continue
		if origin.distance_to(en.global_position) <= spread_range:
			pool.append(en)
	if pool.is_empty():
		return
	_spawn_plague_on(pool[randi() % pool.size()])


func _target_dead() -> bool:
	if not is_instance_valid(target):
		return true
	if target.is_queued_for_deletion():
		return true
	if target.has_method("has_died") and target.has_died():
		return true
	if "current_health" in target:
		return int(target.get("current_health")) <= 0
	return false


func _spread() -> void:
	if _spread_done:
		return
	_spread_done = true
	var origin: Vector2 = global_position
	var fresh_pool: Array[Node2D] = []
	var all_pool: Array[Node2D] = []
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var en: Node2D = e as Node2D
		if en == null or en == target:
			continue
		if origin.distance_to(en.global_position) <= spread_range:
			all_pool.append(en)
			if not (weapon and weapon._has_plague(en)):
				fresh_pool.append(en)

	# Contagion: may target already-plagued enemies (stacking). Without it, spread
	# only ever hits fresh hosts — re-infecting a plagued enemy is Contagion's
	# exclusive mechanic (a skipped spread simply lets the plague die off).
	var pool: Array[Node2D]
	if weapon and weapon.contagion:
		pool = all_pool
	else:
		pool = fresh_pool

	pool.shuffle()
	var n: int = mini(spread_count, pool.size())
	for i in range(n):
		_spawn_plague_on(pool[i])


func _spawn_plague_on(enemy: Node2D) -> void:
	# Safety choke point: never stack on a plagued host unless Contagion is active
	# (covers the Black Death leak path, which bypasses _spread's fresh-only pool).
	if weapon and weapon.has_method("_has_plague") and weapon._has_plague(enemy):
		var can_stack: bool = "contagion" in weapon and bool(weapon.get("contagion"))
		if not can_stack:
			return
	var pe: Node = preload("res://src/entities/projectiles/plague_bolt/plague_effect.tscn").instantiate()
	pe.global_position = enemy.global_position
	if pe.has_method("setup"):
		pe.setup(enemy, weapon, base_tick_damage, tick_interval, ramp_mult, lifetime, spread_count, spread_range)
	get_tree().current_scene.add_child(pe)
	sync_effect(pe, preload("res://src/entities/projectiles/plague_bolt/plague_effect.tscn"), {"life": lifetime})


func _register_host() -> void:
	if target and is_instance_valid(target):
		var c: int = int(target.get_meta("plague_hosts", 0)) + 1
		target.set_meta("plague_hosts", c)


func _unregister_host() -> void:
	if target and is_instance_valid(target) and not target.is_queued_for_deletion():
		var c: int = int(target.get_meta("plague_hosts", 0)) - 1
		if c <= 0:
			target.remove_meta("plague_hosts")
		else:
			target.set_meta("plague_hosts", c)


func sync_effect(effect: Node, scene: PackedScene, extra: Dictionary) -> void:
	var net: Node = get_node_or_null("/root/Net")
	if net and net.has_method("sync_player_effect"):
		net.sync_player_effect(effect, scene, extra)


func _draw() -> void:
	var alpha: float = 1.0
	if _visual_only:
		alpha = clampf(1.0 - _age / lifetime, 0.0, 1.0)
	var wobble: float = sin(_age * 8.0) * 2.0
	var r: float = 16.0 + wobble
	draw_circle(Vector2.ZERO, r, Color(0.4, 0.85, 0.5, 0.35 * alpha))
	draw_arc(Vector2.ZERO, r + 4.0, 0.0, TAU, 24, Color(0.3, 0.9, 0.4, 0.6 * alpha), 2.0)
