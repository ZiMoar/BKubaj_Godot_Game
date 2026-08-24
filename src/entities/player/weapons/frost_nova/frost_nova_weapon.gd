extends Weapon

## Frost Nova — automatic. Every cooldown, blasts everything in a radius around
## the player, damaging it and briefly slowing it. A drawn ring shows the effect.

@export var nova_radius: float = 105.0
@export var base_damage: int = 46
@export var slow_duration: float = 2.0
@export var slow_factor: float = 0.45
@export var frost_scene: PackedScene


func _ready() -> void:
	weapon_name = "Frost Nova"
	trigger_type = TriggerType.AUTOMATIC
	cooldown = 3.0
	damage_type = DamageType.Type.COLD
	super._ready()
	call_deferred("try_fire")

func supports_range_damage() -> bool:
	return true


## Frost Nova's signature upgrades (granted by the rare golden anvil).
func get_signature_pool() -> Array[Dictionary]:
	return [
		{
			"id": "deep_freeze",
			"title": "Deep Freeze",
			"description": "Slowed enemies may become frozen, stopping them and doubling damage taken.",
			"value": 35,
			"apply": func(_w: Weapon) -> void: pass,
		},
		{
			"id": "procession",
			"title": "Procession",
			"description": "Your nova repeats twice more, 100px and 200px away in a line toward the nearest enemy.",
			"value": 1,
			"apply": func(_w: Weapon) -> void: pass,
		},
		{
			"id": "swift",
			"title": "Swift",
			"description": "Your nova deals more damage the faster you are than the enemy.",
			"value": 1,
			"apply": func(_w: Weapon) -> void: pass,
		},
	]


func fire() -> void:
	var origin: Vector2 = global_position
	_cast_nova_at(origin)
	# Procession: two more novas 100px and 200px ahead in a line toward the
	# nearest enemy.
	if has_signature("procession"):
		var dir: Vector2 = _aim_direction()
		_cast_nova_at(origin + dir * 100.0)
		_cast_nova_at(origin + dir * 200.0)


func _cast_nova_at(origin: Vector2) -> void:
	var eff_radius: float = nova_radius * get_area_multiplier()
	var dmg: int = get_attack_damage(base_damage)
	var crit: bool = roll_critical_hit()
	if crit:
		dmg = int(round(float(dmg) * get_critical_multiplier()))

	# Swift: bonus damage the faster you are than the enemy.
	var swift: bool = has_signature("swift")
	var player_speed: float = 0.0
	if swift:
		var p: Node = get_player()
		if p != null and p.has_method("current_move_speed"):
			player_speed = float(p.current_move_speed())

	var targets: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for d: Node in get_tree().get_nodes_in_group("destructibles"):
		targets.append(d)
	# Deep Freeze: an enemy that was ALREADY slowed has a chance to be frozen solid.
	var deep_freeze_owned: bool = has_signature("deep_freeze")
	for e: Node in targets:
		if not is_instance_valid(e):
			continue
		var en: Node2D = e as Node2D
		if origin.distance_to(en.global_position) <= eff_radius:
			# Whether the target was already slowed BEFORE this nova's slow hits.
			var was_slowed: bool = en.get("slow_timer") != null and float(en.get("slow_timer")) > 0.0
			var dealt: int = dmg
			# Swift: damage scales with how much faster you are than the enemy.
			# Enemy speed is guarded to a floor so 0-speed foes (e.g. pots) never
			# cause a divide-by-zero or a runaway multiplier.
			if swift:
				var es: float = maxf(0.0, float(en.get("speed")))
				var ratio: float = (player_speed - es) / maxf(1.0, es)
				dealt = int(round(float(dealt) * (1.0 + clampf(ratio, 0.0, 2.0) * 0.5)))
			dealt = apply_range_damage_multiplier(dealt, origin.distance_to(en.global_position))
			en.take_damage(dealt, false, damage_type, false, get_ailment_effect_multiplier())
			apply_lifesteal()
			if en.has_method("apply_slow"):
				en.apply_slow(slow_duration, slow_factor)
			# Freeze only if it was already slowed (so the first slow never
			# freezes), and only at the signature's chance.
			if deep_freeze_owned and was_slowed and en.has_method("apply_freeze") and randf() < 0.35:
				en.apply_freeze()
			if en.is_in_group("enemies"):
				if en.has_method("has_died") and en.has_died():
					apply_explosion_on_kill(en.global_position, dealt)

	if frost_scene:
		var ring = frost_scene.instantiate()
		if ring != null and ring.has_method("setup"):
			ring.global_position = origin
			ring.setup(eff_radius)
			get_tree().current_scene.add_child(ring)
			sync_effect(ring, frost_scene, {"radius": eff_radius})


## Nearest-enemy direction for the Procession line (else a random direction).
func _aim_direction() -> Vector2:
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
	if best == null:
		return Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	var dir: Vector2 = best.global_position - global_position
	if dir.length_squared() < 1.0:
		return Vector2.RIGHT
	return dir.normalized()
