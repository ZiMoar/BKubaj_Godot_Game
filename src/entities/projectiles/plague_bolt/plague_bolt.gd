class_name PlagueBolt
extends Area2D

## Bursting Plague's projectile. A slow necrotic bolt that homes to an enemy and,
## on impact, inflicts the ramping plague DoT (spawning a PlagueEffect on the
## target) plus a small direct necrotic hit.

var speed: float = 240.0
var damage: int = 10
var is_critical: bool = false
var source_player: Player = null
var source_weapon: Node = null
var dir: Vector2 = Vector2.RIGHT
var plague_base: int = 8
var plague_interval: float = 0.8
var plague_ramp: float = 1.4
var plague_lifetime: float = 6.0
var spread_count: int = 1
var spread_range: float = 150.0

var _age: float = 0.0
var _lifetime: float = 3.0
var _homing_strength: float = 2.2
var _hit: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func setup(start_pos: Vector2, aim_dir: Vector2, proj_speed: float, proj_damage: int, crit: bool, player: Player, weapon: Node,
		pbase: int, pinterval: float, pramp: float, plife: float, sc: int, sr: float) -> void:
	global_position = start_pos
	dir = aim_dir.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	speed = proj_speed
	damage = proj_damage
	is_critical = crit
	source_player = player
	source_weapon = weapon
	plague_base = pbase
	plague_interval = pinterval
	plague_ramp = pramp
	plague_lifetime = plife
	spread_count = sc
	spread_range = sr
	rotation = dir.angle()


func _physics_process(delta: float) -> void:
	_age += delta
	if _lifetime <= 0.0:
		queue_free()
		return
	_lifetime -= delta
	var tgt := _find_nearest_enemy()
	if is_instance_valid(tgt):
		var to_t: Vector2 = tgt.global_position - global_position
		var dist: float = to_t.length()
		if dist > 1.0:
			dir = dir.slerp((to_t / dist), minf(1.0, _homing_strength * delta)).normalized()
			rotation = dir.angle()
	global_position += dir * speed * delta


func _find_nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_d: float = INF
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var en: Node2D = e as Node2D
		var d: float = global_position.distance_squared_to(en.global_position)
		if d < best_d:
			best_d = d
			best = en
	return best


func _on_body_entered(body: Node2D) -> void:
	_resolve_hit(body)


func _on_area_entered(area: Area2D) -> void:
	_resolve_hit(area.get_parent())


func _resolve_hit(node: Node) -> void:
	if _hit or node == null:
		return
	if not (node.is_in_group("enemies") or node.is_in_group("destructibles")) or not node.has_method("take_damage"):
		return
	_hit = true
	node.take_damage(damage, false, DamageType.Type.NECROTIC, false, source_weapon.get_ailment_effect_multiplier() if source_weapon else 1.0)
	if source_weapon and node.has_method("has_died") and node.has_died():
		source_weapon.apply_explosion_on_kill(node.global_position, damage)
	if source_player and source_player.has_method("apply_lifesteal"):
		source_player.apply_lifesteal()
	# Inflict the plague DoT on enemies (not destructibles).
	if node.is_in_group("enemies"):
		_spawn_plague(node as Node2D)
	queue_free()


func _spawn_plague(tgt: Node2D) -> void:
	# Only Contagion may re-infect an enemy already carrying plague. Without it, a
	# second bolt on a plagued target is skipped so plagues never stack.
	if source_weapon and source_weapon.has_method("_has_plague") and source_weapon._has_plague(tgt):
		var can_stack: bool = "contagion" in source_weapon and bool(source_weapon.get("contagion"))
		if not can_stack:
			return
	var scene: PackedScene = preload("res://src/entities/projectiles/plague_bolt/plague_effect.tscn")
	var pe: Node = scene.instantiate()
	pe.global_position = tgt.global_position
	if pe.has_method("setup"):
		pe.setup(tgt, source_weapon, plague_base, plague_interval, plague_ramp, plague_lifetime, spread_count, spread_range)
	get_tree().current_scene.add_child(pe)
	var net: Node = get_node_or_null("/root/Net")
	if net and net.has_method("sync_player_effect"):
		net.sync_player_effect(pe, scene, {"life": plague_lifetime})
