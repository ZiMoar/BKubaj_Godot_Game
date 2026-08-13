class_name ArrowProj
extends Area2D

## Ranger's primary arrow. Fast, high single-target damage, pierces through
## several enemies before expiring (pierce_total => hits up to pierce_total).
var speed: float = 540.0
var damage: int = 18
var is_critical: bool = false
var source_player: Player = null
var dir: Vector2 = Vector2.RIGHT
var pierce_left: int = 0
var chain_left: int = 0
var chain_range: float = 200.0
var source_weapon: Node = null
var _lifetime: float = 2.0
var _already_hit: Dictionary = {}


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func setup(pos: Vector2, direction: Vector2, arrow_speed: float, dmg: int, crit: bool, player: Player, pierce_total: int = 1, chain_total: int = 0, chain_range_px: float = 200.0, weapon: Node = null) -> void:
	global_position = pos
	dir = direction.normalized()
	speed = arrow_speed
	damage = dmg
	is_critical = crit
	source_player = player
	source_weapon = weapon
	pierce_left = maxi(0, pierce_total - 1)
	chain_left = maxi(0, chain_total)
	chain_range = chain_range_px
	rotation = dir.angle()


func _physics_process(delta: float) -> void:
	_lifetime -= delta
	if _lifetime <= 0.0:
		queue_free()
		return
	global_position += dir * speed * delta


func _on_body_entered(body: Node2D) -> void:
	_hit(body)


func _on_area_entered(area: Area2D) -> void:
	_hit(area.get_parent())


func _hit(node: Node) -> void:
	if node and (node.is_in_group("enemies") or node.is_in_group("destructibles")) and node.has_method("take_damage"):
		var id: int = node.get_instance_id()
		if _already_hit.has(id):
			return
		_already_hit[id] = true

		var dealt: int = damage
		if source_weapon and (source_weapon.close_range_damage_bonus > 0.0 or source_weapon.far_range_damage_bonus > 0.0) and node is Node2D:
			dealt = maxi(1, int(round(float(dealt) * source_weapon.get_range_damage_multiplier((source_weapon.global_position - (node as Node2D).global_position).length()))))

		node.take_damage(dealt)
		if source_player and source_player.has_method("apply_lifesteal"):
			source_player.apply_lifesteal()
		if node.has_method("apply_knockback"):
			node.apply_knockback(global_position, 150.0)
		if source_weapon and node.is_in_group("enemies"):
			source_weapon.apply_status_on_hit(node, dealt)
			if node.has_method("has_died") and node.has_died():
				source_weapon.apply_explosion_on_kill(global_position, dealt)
		# Pierce first: keep flying through this enemy if pierce remains.
		if pierce_left > 0:
			pierce_left -= 1
			return
		# Once pierce is spent, chain-bounce to another enemy if a chain remains.
		if chain_left > 0:
			var next: Node2D = _find_chain_target()
			if next != null:
				chain_left -= 1
				dir = (next.global_position - global_position).normalized()
				rotation = dir.angle()
				_lifetime = maxf(_lifetime, 0.5)
				return
	queue_free()


# Find the nearest enemy not yet hit, within chain_range. Returns null if none.
func _find_chain_target() -> Node2D:
	var best: Node2D = null
	var best_d: float = INF
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var id: int = e.get_instance_id()
		if _already_hit.has(id):
			continue
		var d: float = global_position.distance_squared_to((e as Node2D).global_position)
		if d <= chain_range * chain_range and d < best_d:
			best_d = d
			best = e as Node2D
	return best
