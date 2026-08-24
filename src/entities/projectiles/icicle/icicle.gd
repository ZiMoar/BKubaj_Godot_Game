class_name Icicle
extends Area2D

## Icicle projectile. Flies toward an enemy; on impact deals COLD damage to the
## struck target, then SHATTERS, releasing a cone of cold damage BEHIND the
## target (relative to the throw direction).

var speed: float = 420.0
var damage: int = 22
var is_critical: bool = false
var source_player: Player = null
var source_weapon: Node = null
var dir: Vector2 = Vector2.RIGHT
var cone_radius: float = 120.0
var cone_half_angle: float = 0.6   # radians each side of the centre line

var _age: float = 0.0
var _lifetime: float = 3.0
var _homing_strength: float = 2.6
var _hit: bool = false

const SHARD_COUNT: int = 3


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func setup(start_pos: Vector2, aim_dir: Vector2, proj_speed: float, proj_damage: int, crit: bool, player: Player, weapon: Node, cone_r: float, cone_half: float) -> void:
	global_position = start_pos
	dir = aim_dir.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	speed = proj_speed
	damage = proj_damage
	is_critical = crit
	source_player = player
	source_weapon = weapon
	cone_radius = cone_r
	cone_half_angle = cone_half
	rotation = dir.angle()


func _physics_process(delta: float) -> void:
	_age += delta
	if _lifetime <= 0.0:
		queue_free()
		return
	_lifetime -= delta

	# Gentle homing toward the nearest enemy.
	var target := _find_nearest_enemy()
	if is_instance_valid(target):
		var to_target: Vector2 = target.global_position - global_position
		var dist: float = to_target.length()
		if dist > 1.0:
			var desired: Vector2 = to_target / dist
			var turn: float = _homing_strength * delta
			if dist < 40.0:
				turn *= 0.15
			dir = dir.slerp(desired, minf(1.0, turn)).normalized()
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

	var target_pos: Vector2 = (node as Node2D).global_position
	var dealt: int = damage
	if source_weapon and (source_weapon.close_range_damage_bonus > 0.0 or source_weapon.far_range_damage_bonus > 0.0):
		dealt = maxi(1, int(round(float(dealt) * source_weapon.get_range_damage_multiplier((source_weapon.global_position - target_pos).length()))))
	node.take_damage(dealt, false, DamageType.Type.COLD, false, source_weapon.get_ailment_effect_multiplier() if source_weapon != null else 1.0)
	if source_player and source_player.has_method("apply_lifesteal"):
		source_player.apply_lifesteal()
	if source_weapon and node.is_in_group("enemies"):
		if node.has_method("has_died") and node.has_died():
			source_weapon.apply_explosion_on_kill(target_pos, dealt)

	# Hail signature: striking the same enemy twice quickly freezes it.
	if source_weapon and source_weapon.hail and node.is_in_group("enemies"):
		source_weapon._record_hail_hit(node as Node2D)

	# Shatter: cone of cold behind the struck target (away from the throw origin).
	_shatter_cone(target_pos)
	_spawn_shatter_visual(target_pos)
	queue_free()


## Damages enemies sitting BEHIND the struck target, within a cone whose centre
## line points away from the player (i.e. past the target). With the Refraction
## signature the burst instead expands in a full 360° at reduced per-hit damage.
func _shatter_cone(target_pos: Vector2) -> void:
	var origin: Vector2 = global_position  # approximate throw origin (near the icicle)
	var backward: Vector2 = (target_pos - origin).normalized()
	if backward == Vector2.ZERO:
		backward = dir
	var radius: float = cone_radius * (source_weapon.get_area_multiplier() if source_weapon else 1.0)
	var refraction: bool = source_weapon != null and source_weapon.refraction
	# Splintering damage ratio drops further under Refraction (many shards + 360).
	var cone_dmg_ratio: float = 0.40 if refraction else 0.55
	var dmg: int = maxi(1, int(round(float(damage) * cone_dmg_ratio)))

	var shard_dirs: Array[Vector2] = []
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for e: Node in enemies:
		if not is_instance_valid(e):
			continue
		var en: Node2D = e as Node2D
		if en == null:
			continue
		var to_e: Vector2 = en.global_position - target_pos
		var dist: float = to_e.length()
		if dist > radius or dist < 1.0:
			continue
		var dot: float = to_e.normalized().dot(backward)
		var in_cone: bool = refraction or dot >= cos(cone_half_angle)
		if in_cone and en.has_method("take_damage"):
			en.take_damage(dmg, false, DamageType.Type.COLD, false, source_weapon.get_ailment_effect_multiplier() if source_weapon else 1.0)
			if source_weapon and source_weapon.splintering:
				shard_dirs.append(to_e.normalized())

	# Splintering: launch small shards from the shatter point that hit again.
	if source_weapon and source_weapon.splintering:
		if shard_dirs.is_empty():
			var base: Vector2 = backward
			for i in range(SHARD_COUNT):
				shard_dirs.append(base.rotated(deg_to_rad(-18.0 + 18.0 * i)))
		_spawn_shards(target_pos, shard_dirs, dmg)


func _spawn_shards(origin: Vector2, dirs: Array[Vector2], shard_dmg: int) -> void:
	var scene: PackedScene = preload("res://src/entities/projectiles/icicle/icicle_shard.tscn")
	for i in range(mini(dirs.size(), SHARD_COUNT)):
		var shard: Node = scene.instantiate()
		shard.name = "IcicleShard_%d" % i
		shard.global_position = origin + dirs[i] * 6.0
		if shard.has_method("setup"):
			shard.setup(origin + dirs[i] * 6.0, dirs[i], 320.0, shard_dmg, source_player, source_weapon)
		get_tree().current_scene.add_child(shard)


func _spawn_shatter_visual(target_pos: Vector2) -> void:
	var fx: Node2D = preload("res://src/effects/explosion_effect/explosion_effect.gd").new()
	fx.name = "IcicleShatter"
	fx.global_position = target_pos
	fx.set("max_radius", cone_radius * (source_weapon.get_area_multiplier() if source_weapon else 1.0))
	fx.set("color", Color(0.55, 0.85, 1.0))
	get_tree().current_scene.add_child(fx)
