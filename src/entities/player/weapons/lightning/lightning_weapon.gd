extends Weapon

## Lightning — automatic. Strikes the nearest enemy, then arcs to up to a few
## nearby enemies in a chain. Hitscan, so it can't be dodged by obstacles.

@export var max_targets: int = 4
@export var base_damage: int = 45
@export var chain_range: float = 270.0
@export var lightning_scene: PackedScene


func _ready() -> void:
	weapon_name = "Lightning Bolt"
	trigger_type = TriggerType.AUTOMATIC
	cooldown = 2.0
	super._ready()
	call_deferred("try_fire")


func fire() -> void:
	if lightning_scene == null:
		return
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return

	var origin: Vector2 = global_position
	var eff_chain_range: float = chain_range * get_area_multiplier()
	var first: Node2D = null
	var first_dist: float = INF
	for e: Node in enemies:
		if not is_instance_valid(e):
			continue
		var d: float = origin.distance_squared_to((e as Node2D).global_position)
		if d < first_dist:
			first_dist = d
			first = e as Node2D
	if first == null:
		return

	# Greedily chain to the nearest enemy within chain_range of the previous hit.
	var seq: Array[Node2D] = [first]
	var hit_ids: Dictionary = { first.get_instance_id(): true }
	var last_pos: Vector2 = first.global_position
	for i in range(max_targets - 1):
		var next: Node2D = null
		var nd: float = INF
		for e: Node in enemies:
			if not is_instance_valid(e) or hit_ids.has(e.get_instance_id()):
				continue
			var d: float = last_pos.distance_squared_to((e as Node2D).global_position)
			if d <= eff_chain_range * eff_chain_range and d < nd:
				nd = d
				next = e as Node2D
		if next == null:
			break
		seq.append(next)
		hit_ids[next.get_instance_id()] = true
		last_pos = next.global_position

	var dmg: int = get_attack_damage(base_damage)
	var crit: bool = roll_critical_hit()
	if crit:
		dmg = int(round(float(dmg) * get_critical_multiplier()))

	var prev: Vector2 = origin
	var local_points := PackedVector2Array()
	local_points.append(Vector2.ZERO)
	for e: Node2D in seq:
		if not is_instance_valid(e):
			continue
		e.take_damage(dmg)
		apply_lifesteal()
		if e.has_method("apply_knockback"):
			e.apply_knockback(prev, 90.0)
		prev = e.global_position
		local_points.append(e.global_position - origin)

	_spawn_lightning(origin, local_points, crit)


func _spawn_lightning(origin: Vector2, local_points: PackedVector2Array, crit: bool) -> void:
	var bolt = lightning_scene.instantiate()
	if bolt == null or not bolt.has_method("setup"):
		return
	bolt.global_position = origin
	bolt.setup(local_points, Color(1.0, 0.85, 0.3, 1.0) if not crit else Color(1.0, 0.4, 0.9, 1.0))
	get_tree().current_scene.add_child(bolt)
