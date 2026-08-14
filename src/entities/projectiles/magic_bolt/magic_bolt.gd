class_name MagicBolt
extends Area2D

var speed: float = 300.0
var damage: int = 12
var is_critical: bool = false
var source_player: Player = null
var source_weapon: Node = null
var dir: Vector2 = Vector2.RIGHT
var _homing_strength: float = 1.8   # base curve; scales up with age
var _retarget_range_sq: float = 40000.0  # squared; only home within ~200px

## Homing ramps up over time: multiply homing_strength up to `homing_ramp`
## after `homing_ramp_time` seconds (so early flight is straight-ish, later
## bolts curve harder toward a target).
@export var homing_ramp: float = 3.5
@export var homing_ramp_time: float = 1.2

var _age: float = 0.0
var _lifetime: float = 3.0
var _hit_enemy: bool = false  # guards against body+area double-hit on the same overlap


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func setup(start_pos: Vector2, aim_dir: Vector2, bolt_speed: float, bolt_damage: int, crit: bool, player: Player, weapon: Node = null) -> void:
	global_position = start_pos
	dir = aim_dir.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	speed = bolt_speed
	damage = bolt_damage
	is_critical = crit
	source_player = player
	source_weapon = weapon
	rotation = dir.angle()


func _physics_process(delta: float) -> void:
	_lifetime -= delta
	_age += delta
	if _lifetime <= 0.0:
		queue_free()
		return

	var current_dir: Vector2 = dir

	# Homing ramps up with age: weakest right after launch, strongest later.
	var ramp_t: float = clampf(_age / homing_ramp_time, 0.0, 1.0)
	var homing: float = _homing_strength * lerpf(1.0, homing_ramp, ramp_t)

	# Gentle curve toward a nearby enemy (within retarget range), not auto-aim.
	var target: Node2D = _find_nearest_enemy()
	if is_instance_valid(target):
		var to_target: Vector2 = target.global_position - global_position
		var dist: float = to_target.length()
		if dist > 1.0:
			var desired_dir: Vector2 = to_target / dist
			# Turn rate grows with age + homing. Slow further when very close so
			# the bolt doesn't wobble around an already-reached target.
			var turn: float = homing * delta
			if dist < 40.0:
				turn *= 0.15
			dir = current_dir.slerp(desired_dir, minf(1.0, turn)).normalized()
			rotation = dir.angle()

	global_position += current_dir * speed * delta


func _find_nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_d: float = _retarget_range_sq
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
	_hit(body)


func _on_area_entered(area: Area2D) -> void:
	_hit(area.get_parent())


func _hit(node: Node) -> void:
	if _hit_enemy:
		return
	if node and (node.is_in_group("enemies") or node.is_in_group("destructibles")) and node.has_method("take_damage"):
		_hit_enemy = true
		var dealt: int = damage
		if source_weapon and (source_weapon.close_range_damage_bonus > 0.0 or source_weapon.far_range_damage_bonus > 0.0) and node is Node2D:
			dealt = maxi(1, int(round(float(dealt) * source_weapon.get_range_damage_multiplier((source_weapon.global_position - (node as Node2D).global_position).length()))))
		node.take_damage(dealt, false, source_weapon.damage_type if source_weapon != null else DamageType.Type.ARCANE)
		if source_player and source_player.has_method("apply_lifesteal"):
			source_player.apply_lifesteal()
		if node.has_method("apply_knockback"):
			node.apply_knockback(global_position, 120.0)
		if source_weapon and node.is_in_group("enemies"):
			source_weapon.apply_status_on_hit(node, dealt)
			if node.has_method("has_died") and node.has_died():
				source_weapon.apply_explosion_on_kill(global_position, dealt)
	queue_free()
