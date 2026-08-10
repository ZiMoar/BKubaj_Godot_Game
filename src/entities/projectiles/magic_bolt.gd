class_name MagicBolt
extends Area2D

var speed: float = 300.0
var damage: int = 12
var is_critical: bool = false
var source_player: Player = null
var target: Node2D = null
var homing_strength: float = 5.0

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


func _physics_process(delta: float) -> void:
	_lifetime -= delta
	if _lifetime <= 0.0:
		queue_free()
		return

	# Home toward target
	if is_instance_valid(target):
		var desired_dir: Vector2 = (target.global_position - global_position).normalized()
		var current_dir: Vector2 = Vector2.RIGHT.rotated(rotation)
		var new_dir: Vector2 = current_dir.lerp(desired_dir, homing_strength * delta).normalized()
		rotation = new_dir.angle()
		global_position += new_dir * speed * delta
	else:
		# Target lost, continue in current direction
		global_position += Vector2.RIGHT.rotated(rotation) * speed * delta


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
