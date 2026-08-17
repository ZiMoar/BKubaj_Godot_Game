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
# Reach of each secondary hit (initial zap from the orb, and every chain hop),
# scaled by the weapon's area multiplier and set from the weapon on spawn.
var bolt_range: float = 150.0
var bolt_speed: float = 340.0

var _age: float = 0.0
var _bolt_timer: float = 0.0
var _stopped: bool = false


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

	# Fire bolts periodically. The rate scales with the player's attack speed
	# (the same multiplier that shortens the throw cooldown), so stacking attack
	# speed genuinely speeds up the orb's secondary hits.
	_bolt_timer -= delta
	if _bolt_timer <= 0.0:
		_bolt_timer = _get_effective_bolt_interval()
		_fire_volley()


## The base bolt_interval shortened by the player's attack-speed multiplier
## (lower = faster). Ensures a sane minimum so it can never tick faster than 20Hz.
func _get_effective_bolt_interval() -> float:
	var interval: float = bolt_interval
	if is_instance_valid(source_weapon) and source_weapon.has_method("get_player"):
		var player: Node = source_weapon.get_player()
		if player != null and player.has_method("get_attack_speed_multiplier"):
			interval *= float(player.get_attack_speed_multiplier())
	return maxf(0.05, interval)


func _fire_volley() -> void:
	# Co-op: this is a visual-only copy of a teammate's orb (spawned so the other
	# player can see it). Its bolts are HITSCAN — they'd deal real damage here on
	# top of the firing player's already-forwarded hits — so a visual copy never
	# fires. It just renders the orb drifting/decelerating.
	if get_meta("visual_copy", false):
		return
	if not is_instance_valid(source_weapon):
		return
	var player := source_player as Node
	if player == null:
		player = get_tree().get_first_node_in_group("player")

	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return

	# Hitscan: each bolt slot instantly slaps the nearest enemy in reach — no
	# travel time, so it can't be dodged/missed like a projectile. If the weapon
	# has Chain (anvil) upgrades each strike also arcs to nearby additional
	# enemies; by default there are none.
	var chain_count: int = 0
	if source_weapon.has_method("get_effective_chain_count"):
		chain_count = int(source_weapon.get_effective_chain_count(0))

	for i in range(maxi(1, bolt_count)):
		var target: Node2D = _nearest_enemy(enemies)
		if target == null:
			continue
		_zap(global_position, target, player)
		if chain_count > 0:
			var hit: Dictionary = { target.get_instance_id(): true }
			var from: Vector2 = target.global_position
			for c in range(chain_count):
				var next: Node2D = _nearest_enemy_from(enemies, from, hit)
				if next == null:
					break
				_zap(from, next, player)
				hit[next.get_instance_id()] = true
				from = next.global_position


## Instantly strikes one enemy (hitscan) with a random-damage-type zap. Applies
## crit, ailment resonance, lifesteal, and explosion-on-kill just like the old
## bolt projectile did, but immediately and at the target's current position.
func _zap(origin: Vector2, target: Node2D, player: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	var rnd_type: DamageType.Type = _random_damage_type()
	# Visual tracer from the strike origin to the target, colored by element.
	_spawn_bolt_line(origin, target.global_position, DamageType.color_for(rnd_type))
	var dmg: int = bolt_damage
	var crit: bool = false
	if is_instance_valid(source_weapon):
		dmg = source_weapon.get_attack_damage(bolt_damage)
		if source_weapon.has_method("roll_critical_hit") and source_weapon.roll_critical_hit():
			crit = true
			dmg = int(round(float(dmg) * source_weapon.get_critical_multiplier()))
		# Ailment Resonance: extra damage per distinct ailment already on the enemy.
		if source_weapon.has_method("has_signature") and source_weapon.has_signature("ailment_resonance") \
				and target.has_method("count_active_ailments"):
			var ailments: int = target.count_active_ailments()
			if ailments > 0:
				dmg += int(round(float(dmg) * 0.20 * float(ailments)))
	var am: float = 1.0
	if source_weapon and source_weapon.has_method("get_ailment_effect_multiplier"):
		am = source_weapon.get_ailment_effect_multiplier()
	target.take_damage(dmg, crit, rnd_type, false, am)
	if player and player.has_method("apply_lifesteal"):
		player.apply_lifesteal()
	if source_weapon and target.is_in_group("enemies"):
		if target.has_method("has_died") and target.has_died():
			source_weapon.apply_explosion_on_kill(target.global_position, dmg)


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


## Nearest enemy to a given point (for chaining), skipping already-hit nodes,
## within bolt_range.
func _nearest_enemy_from(enemies: Array, from: Vector2, used: Dictionary) -> Node2D:
	var best: Node2D = null
	var best_d: float = bolt_range * bolt_range
	for e: Node in enemies:
		if not is_instance_valid(e):
			continue
		var en: Node2D = e as Node2D
		if used.has(en.get_instance_id()):
			continue
		var d: float = from.distance_squared_to(en.global_position)
		if d < best_d:
			best_d = d
			best = en
	return best


## Draws a brief tracer line from `from` to `to` in the strike's element color,
## letting the player actually see each secondary hit land. The line fades out
## over ~0.18s then frees itself.
func _spawn_bolt_line(from: Vector2, to: Vector2, color: Color) -> void:
	var line := Line2D.new()
	line.points = PackedVector2Array([from, to])
	line.default_color = color
	line.width = 2.5
	line.antialiased = true
	line.z_index = 20
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	scene.add_child(line)
	var tw := line.create_tween()
	tw.tween_property(line, "self_modulate:a", 0.0, 0.18)
	tw.tween_callback(line.queue_free)


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
