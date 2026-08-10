class_name MagicBolt
extends Area2D

var speed: float = 300.0
var damage: int = 12
var is_critical: bool = false
var source_player: Player = null
var target: Node2D = null
var _homing_strength: float = 9.0
var _retarget_range_sq: float = 999999.0  # squared; effectively unlimited by default

var _lifetime: float = 3.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func setup(start_pos: Vector2, target_enemy: Node2D, bolt_speed: float, bolt_damage: int, crit: bool, player: Player) -> void:
	global_position = start_pos
	target = target_enemy
	speed = bolt_speed
	damage = bolt_damage
	is_critical = crit
	source_player = player
	# Face the target immediately so the bolt doesn't drift out of the player's
	# right side before homing kicks in — it flies toward its mark from frame 1.
	if is_instance_valid(target_enemy):
		rotation = (target_enemy.global_position - start_pos).angle()


func _physics_process(delta: float) -> void:
	_lifetime -= delta
	if _lifetime <= 0.0:
		queue_free()
		return

	# If the original target died, re-acquire the nearest enemy so the bolt
	# keeps being useful instead of flying off into the void.
	if not is_instance_valid(target):
		target = _find_nearest_enemy()

	var current_dir: Vector2 = Vector2.RIGHT.rotated(rotation)

	if is_instance_valid(target):
		var to_target: Vector2 = target.global_position - global_position
		var dist: float = to_target.length()
		if dist > 1.0:
			var desired_dir: Vector2 = to_target / dist
			# High turn rate homes quickly. When very close to the target we
			# stop turning and fly straight, which stops the "orbiting" wobble.
			var turn: float = _homing_strength * delta
			if dist < 40.0:
				turn *= 0.15
			var new_dir: Vector2 = current_dir.slerp(desired_dir, minf(1.0, turn)).normalized()
			rotation = new_dir.angle()

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
	if node and node.is_in_group("enemies") and node.has_method("take_damage"):
		node.take_damage(damage)
		if source_player and source_player.has_method("apply_lifesteal"):
			source_player.apply_lifesteal()
		if node.has_method("apply_knockback"):
			node.apply_knockback(global_position, 120.0)
	queue_free()
