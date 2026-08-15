class_name ChromaticOrb
extends Node2D

## Orb thrown by the Chromatic Bolt weapon. It decelerates over time; once its
## speed reaches 0 (or it stops) it lingers in place until its lifetime ends.
## The orb itself deals NO damage and does not break on touching enemies — it
## only periodically launches bolts of RANDOM damage type at nearby enemies.

var source_weapon: Node = null
var source_player: Node = null

var dir: Vector2 = Vector2.RIGHT
var speed: float = 0.0
var deceleration: float = 0.0
var lifetime: float = 4.0
var bolt_interval: float = 0.5
var bolt_count: int = 3
var bolt_damage: int = 14
var bolt_range: float = 300.0
var bolt_speed: float = 340.0

var _age: float = 0.0
var _bolt_timer: float = 0.0
var _stopped: bool = false

# Projectile scene preloaded to stay decoupled from the global class cache.
const BoltScript: Script = preload("res://src/entities/projectiles/chromatic_bolt/chromatic_bolt.gd")


func setup(weapon: Node, player: Node, start_dir: Vector2, dmg: int, count: int) -> void:
	source_weapon = weapon
	source_player = player
	dir = start_dir.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	bolt_damage = dmg
	bolt_count = count


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return

	# Decelerate until stopped; once stopped, linger in place.
	if not _stopped:
		speed = maxf(0.0, speed - deceleration * delta)
		if speed <= 0.0:
			_stopped = true
		else:
			global_position += dir * speed * delta

	# Fire bolts periodically.
	_bolt_timer -= delta
	if _bolt_timer <= 0.0:
		_bolt_timer = bolt_interval
		_fire_volley()


func _fire_volley() -> void:
	if not is_instance_valid(source_weapon):
		return
	var player := source_player as Node
	if player == null:
		player = get_tree().get_first_node_in_group("player")

	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return

	for i in range(maxi(1, bolt_count)):
		var target: Node2D = _nearest_enemy(enemies)
		if target == null:
			return
		var to_target: Vector2 = target.global_position - global_position
		var dist_ok: bool = to_target.length() <= bolt_range
		if not dist_ok:
			target = null
		if target == null:
			return

		var bolt: Node2D = BoltScript.new()
		bolt.name = "ChromaticBolt"
		bolt.global_position = global_position

		# Each bolt carries a RANDOM damage type.
		var rnd_type: DamageType.Type = _random_damage_type()
		var dmg: int = bolt_damage
		var crit: bool = false
		if is_instance_valid(source_weapon):
			dmg = source_weapon.get_attack_damage(bolt_damage)
			if source_weapon.has_method("roll_critical_hit") and source_weapon.roll_critical_hit():
				crit = true
				dmg = int(round(float(dmg) * source_weapon.get_critical_multiplier()))
		if bolt.has_method("setup"):
			bolt.setup(global_position, to_target.normalized(), bolt_speed, dmg, crit, player, source_weapon, rnd_type)
		get_tree().current_scene.add_child(bolt)


func _nearest_enemy(enemies: Array) -> Node2D:
	var best: Node2D = null
	var best_d: float = bolt_range * bolt_range
	for e: Node in enemies:
		if not is_instance_valid(e):
			continue
		var en: Node2D = e as Node2D
		var d: float = global_position.distance_squared_to(en.global_position)
		if d < best_d:
			best_d = d
			best = en
	return best


func _random_damage_type() -> DamageType.Type:
	var choices: Array[DamageType.Type] = [
		DamageType.Type.FIRE,
		DamageType.Type.LIGHTNING,
		DamageType.Type.COLD,
		DamageType.Type.ARCANE,
		DamageType.Type.NECROTIC,
		DamageType.Type.HOLY,
		DamageType.Type.POISON,
	]
	return choices[randi() % choices.size()]


func _draw() -> void:
	# Soft glowing orb.
	draw_circle(Vector2.ZERO, 10.0, Color(0.75, 0.75, 0.95, 0.25))
	draw_circle(Vector2.ZERO, 6.0, Color(0.9, 0.9, 1.0, 0.85))
	draw_circle(Vector2.ZERO, 3.0, Color.WHITE)
