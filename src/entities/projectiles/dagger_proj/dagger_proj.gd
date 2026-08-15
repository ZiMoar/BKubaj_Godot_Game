class_name DaggerProj
extends Area2D

var damage: int = 12
var is_critical: bool = false
var source_player: Player = null
var dir: Vector2 = Vector2.RIGHT
var speed: float = 360.0
# Number of additional enemies this dagger can pass through before it's spent.
# pierce_left = 2 => hits up to 3 enemies total. Raisable via player pierce bonus.
var pierce_left: int = 0
var chain_left: int = 0
var chain_range: float = 180.0
var source_weapon: Node = null
var _lifetime: float = 1.6
var _already_hit: Dictionary = {}
## Returning Blades (boomerang) — dagger flies a bit then returns to the player.
var returning: bool = false
var _return_timer: float = 0.0
var _return_delay: float = 0.5
var _age: float = 0.0
var _has_returned: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func setup(pos: Vector2, direction: Vector2, dagger_speed: float, dmg: int, crit: bool, player: Player, pierce_total: int = 1, chain_total: int = 0, chain_range_px: float = 180.0, weapon: Node = null, do_return: bool = false) -> void:
	global_position = pos
	dir = direction.normalized()
	speed = dagger_speed
	damage = dmg
	is_critical = crit
	source_player = player
	source_weapon = weapon
	pierce_left = maxi(0, pierce_total - 1)
	chain_left = maxi(0, chain_total)
	chain_range = chain_range_px
	returning = do_return
	rotation = dir.angle()


func _physics_process(delta: float) -> void:
	_lifetime -= delta
	_age += delta
	if _lifetime <= 0.0:
		queue_free()
		return

	# Returning Blades: when the return delay elapses, boomerang back to the player.
	if returning and not _has_returned and _age >= _return_delay:
		_has_returned = true
		_already_hit.clear()

	if _has_returned:
		_return_timer += delta
		if _return_timer <= 1.0:
			var p: Node = source_player
			if p and is_instance_valid(p):
				var to_p: Vector2 = (p.global_position - global_position).normalized()
				if to_p != Vector2.ZERO:
					dir = to_p
					rotation = dir.angle()
				global_position += dir * speed * 1.3 * delta
				# Stop when it reaches the player.
				if global_position.distance_to(p.global_position) < 14.0:
					queue_free()
					return
			else:
				queue_free()
				return
		else:
			queue_free()
			return
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
		# Apply close/far range damage modifier if the source weapon has it.
		if source_weapon and (source_weapon.close_range_damage_bonus > 0.0 or source_weapon.far_range_damage_bonus > 0.0) and node is Node2D:
			var dist: float = (source_weapon.global_position - (node as Node2D).global_position).length()
			dealt = maxi(1, int(round(float(dealt) * source_weapon.get_range_damage_multiplier(dist))))

		node.take_damage(dealt, false, source_weapon.damage_type if source_weapon != null else DamageType.Type.PHYSICAL, false, source_weapon.get_ailment_effect_multiplier() if source_weapon != null else 1.0)
		if source_player and source_player.has_method("apply_lifesteal"):
			source_player.apply_lifesteal()

		# Possibly explode on kill.
		if source_weapon and node.is_in_group("enemies"):
			if node.has_method("has_died") and node.has_died():
				source_weapon.apply_explosion_on_kill(global_position, dealt)
		# Pierce first, then chain-bounce once pierce is spent.
		if pierce_left > 0:
			pierce_left -= 1
			return
		if chain_left > 0:
			var next: Node2D = _find_chain_target()
			if next != null:
				chain_left -= 1
				dir = (next.global_position - global_position).normalized()
				rotation = dir.angle()
				_lifetime = maxf(_lifetime, 0.5)
				return
	queue_free()


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
