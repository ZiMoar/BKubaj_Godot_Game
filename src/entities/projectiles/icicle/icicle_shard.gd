class_name IcicleShard
extends Area2D

## A small shard of ice launched by the Icicle's "Splintering" signature when the
## main icicle shatters. It homes to the nearest enemy and deals a small COLD hit
## on impact, then is consumed.

var speed: float = 320.0
var damage: int = 8
var source_player: Player = null
var source_weapon: Node = null
var dir: Vector2 = Vector2.RIGHT

var _age: float = 0.0
var _lifetime: float = 1.6
var _homing_strength: float = 3.0
var _hit: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	z_index = 9


func setup(start_pos: Vector2, aim_dir: Vector2, spd: float, dmg: int, player: Player, weapon: Node) -> void:
	global_position = start_pos
	dir = aim_dir.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	speed = spd
	damage = dmg
	source_player = player
	source_weapon = weapon
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
	node.take_damage(damage, false, DamageType.Type.COLD, false, source_weapon.get_ailment_effect_multiplier() if source_weapon else 1.0)
	if source_weapon and node.has_method("has_died") and node.has_died():
		source_weapon.apply_explosion_on_kill(node.global_position, damage)
	if source_player and source_player.has_method("apply_lifesteal"):
		source_player.apply_lifesteal()
	queue_free()


func _draw() -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(4, 0), Vector2(-3, -3), Vector2(-1, 0), Vector2(-3, 3),
	]), Color(0.75, 0.92, 1.0))
