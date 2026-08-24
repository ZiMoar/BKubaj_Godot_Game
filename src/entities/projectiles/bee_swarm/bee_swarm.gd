class_name BeeSwarm
extends Node2D

## A swarm of bees released by the Beehive. Flies to a target enemy, ATTACHES,
## and deals POISON damage in an area around the target on each tick until the
## target dies, then RETURNS to the hive and is consumed.

enum State { HOMING, ATTACHED, RETURNING }

var speed: float = 260.0
var damage: int = 8
var tick_interval: float = 0.5
var area_radius: float = 70.0
var target: Node2D = null
var hive_pos: Vector2 = Vector2.ZERO
var hive_node: Node = null
var source_player: Player = null
var source_weapon: Node = null

var _state: State = State.HOMING
var _tick_timer: float = 0.5
var _age: float = 0.0
var _lifetime: float = 12.0
var _visual_only: bool = false
var _kill_notified: bool = false


func _ready() -> void:
	z_index = 9
	_tick_timer = tick_interval


func setup(tgt: Node2D, hive: Vector2, spd: float, dmg: int, interval: float, area: float, player: Player, weapon: Node, hive_node_ref: Node = null) -> void:
	target = tgt
	hive_pos = hive
	hive_node = hive_node_ref
	speed = spd
	damage = dmg
	tick_interval = interval
	area_radius = area
	source_player = player
	source_weapon = weapon
	_tick_timer = interval
	_state = State.HOMING


func setup_visual(data: Dictionary) -> void:
	_visual_only = true
	area_radius = float(data.get("area", area_radius))
	_tick_timer = tick_interval


func _physics_process(delta: float) -> void:
	if _visual_only:
		_age += delta
		queue_redraw()
		if _age >= _lifetime:
			queue_free()
		return

	_age += delta
	if _age >= _lifetime:
		queue_free()
		return

	match _state:
		State.HOMING:
			_homing(delta)
		State.ATTACHED:
			_attached(delta)
		State.RETURNING:
			_returning(delta)
	queue_redraw()


func _homing(delta: float) -> void:
	if not is_instance_valid(target) or _is_dead(target):
		_on_target_lost()
		return
	var to_t: Vector2 = target.global_position - global_position
	if to_t.length() <= 18.0:
		_state = State.ATTACHED
		return
	global_position += (to_t / to_t.length()) * speed * delta
	rotation = to_t.angle()


func _attached(delta: float) -> void:
	if not is_instance_valid(target) or _is_dead(target):
		_on_target_lost()
		return
	global_position = target.global_position + Vector2(cos(_age * 6.0), sin(_age * 6.0)) * 10.0
	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer = tick_interval
		_poison_burst()


func _on_target_lost() -> void:
	_state = State.RETURNING
	# Hive Mind: a swarm that KILLED its target banks an extra swarm for the hive.
	if not _kill_notified and source_weapon and source_weapon.hive_mind and hive_node != null:
		_kill_notified = true
		if hive_node.has_method("_notify_swarm_kill"):
			hive_node._notify_swarm_kill()


func _returning(delta: float) -> void:
	var to_h: Vector2 = hive_pos - global_position
	if to_h.length() <= 24.0:
		_drop_sweet_gift()
		queue_free()
		return
	global_position += (to_h / to_h.length()) * speed * delta
	rotation = to_h.angle()


func _poison_burst() -> void:
	var center: Vector2 = global_position
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var en: Node2D = e as Node2D
		if en == null:
			continue
		if center.distance_to(en.global_position) <= area_radius and en.has_method("take_damage"):
			en.take_damage(damage, false, DamageType.Type.POISON, false, source_weapon.get_ailment_effect_multiplier() if source_weapon else 1.0)
			if source_weapon and en.has_method("has_died") and en.has_died():
				source_weapon.apply_explosion_on_kill(en.global_position, damage)
			# Sticky Honey: stung enemies are slowed by honey.
			if source_weapon and source_weapon.sticky_honey and en.has_method("apply_slow"):
				en.apply_slow(1.0, 0.6)


## Sweet Gift: when a swarm makes it home, it may drop a small heal at the hive.
func _drop_sweet_gift() -> void:
	if not source_weapon or not source_weapon.sweet_gift or _visual_only:
		return
	if randf() >= float(source_weapon.SWEET_GIFT_CHANCE):
		return
	var scene: PackedScene = preload("res://src/pickups/heal_pickup/heal_25.tscn")
	var heal: Node = scene.instantiate()
	heal.name = "HoneyHeal"
	heal.global_position = hive_pos + Vector2(randf_range(-8, 8), randf_range(-8, 8))
	get_tree().current_scene.add_child(heal)


func _is_dead(n: Node2D) -> bool:
	if n.has_method("has_died") and n.has_died():
		return true
	if "current_health" in n:
		return int(n.get("current_health")) <= 0
	return false


func _draw() -> void:
	# A small fuzzy swarm: several dots clustered together.
	var c: Color = Color(0.9, 0.8, 0.2)
	for i in range(5):
		var a: float = TAU * float(i) / 5.0 + _age * 4.0
		var off: Vector2 = Vector2(cos(a), sin(a)) * 4.0
		draw_circle(off, 3.0, c)
	draw_circle(Vector2.ZERO, 3.0, Color(0.95, 0.85, 0.3))
