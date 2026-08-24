class_name BlackHole
extends Node2D

## Black Hole — a ground effect that sucks enemies toward its centre (applying a
## constant pull via their knockback_velocity) and deals ARCANE damage to those
## inside every half-second. Lasts for its duration, then collapses.
##
## Signatures:
##  - Singularity: pull strengthens with age; near-core enemies take bonus damage.
##  - Gravitational Lens: wider pull that also drags enemy projectiles off course.
##  - Collapse: on expiry the hole implodes in a big arcane burst.

var radius: float = 110.0
var tick_interval: float = 0.5
var tick_damage: int = 12
var duration: float = 5.0
var pull_speed: float = 70.0
var source_weapon: Node = null

var _age: float = 0.0
var _tick_timer: float = 0.5
var _visual_only: bool = false


func _ready() -> void:
	z_index = 10
	_tick_timer = tick_interval
	queue_redraw()


func setup(r: float, interval: float, dmg: int, dur: float, pull: float, w: Node) -> void:
	radius = r
	tick_interval = interval
	tick_damage = dmg
	duration = dur
	pull_speed = pull
	source_weapon = w
	_tick_timer = interval


func setup_visual(data: Dictionary) -> void:
	_visual_only = true
	radius = float(data.get("radius", radius))
	duration = float(data.get("dur", duration))
	queue_redraw()


func _process(delta: float) -> void:
	if _visual_only:
		_age += delta
		queue_redraw()
		if _age >= duration:
			queue_free()
		return

	_age += delta
	if _age >= duration:
		# Collapse signature: implode on expiry instead of quietly vanishing.
		if source_weapon and source_weapon.collapse:
			_implode()
		queue_free()
		return

	var center: Vector2 = global_position
	var lens: bool = source_weapon != null and source_weapon.gravitational_lens
	var eff_radius: float = radius * (1.4 if lens else 1.0)

	# Suck enemies toward the centre. Singularity makes the pull grow over time.
	var pull: float = pull_speed
	if source_weapon and source_weapon.singularity:
		pull = pull_speed * (1.0 + 2.0 * clampf(_age / duration, 0.0, 1.0))
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var en: Node2D = e as Node2D
		if en == null:
			continue
		var to_c: Vector2 = center - en.global_position
		var dist: float = to_c.length()
		if dist > eff_radius or dist < 1.0:
			continue
		if "knockback_velocity" in en:
			en.set("knockback_velocity", (to_c / dist) * pull)

	# Gravitational Lens: steer enemy projectiles toward the core.
	if lens:
		_drag_projectiles(center, eff_radius)

	# Arcane damage pulse.
	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer = tick_interval
		for e: Node in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(e):
				continue
			var en: Node2D = e as Node2D
			if en == null:
				continue
			if center.distance_to(en.global_position) <= eff_radius and en.has_method("take_damage"):
				var dmg: int = tick_damage
				# Singularity: enemies hugging the core take bonus damage.
				if source_weapon and source_weapon.singularity and center.distance_to(en.global_position) <= radius * 0.35:
					dmg = maxi(1, int(round(float(dmg) * 2.0)))
				en.take_damage(dmg, false, DamageType.Type.ARCANE, false)
				if source_weapon and en.has_method("has_died") and en.has_died():
					source_weapon.apply_explosion_on_kill(en.global_position, dmg)
	queue_redraw()


func _drag_projectiles(center: Vector2, eff_radius: float) -> void:
	for p: Node in get_tree().get_nodes_in_group("enemy_projectile"):
		if not is_instance_valid(p):
			continue
		var proj: Node2D = p as Node2D
		if proj == null or not ("direction" in proj):
			continue
		var to_c: Vector2 = center - proj.global_position
		var dist: float = to_c.length()
		if dist > eff_radius or dist < 1.0:
			continue
		var dir: Vector2 = proj.get("direction")
		var steer: Vector2 = dir.lerp((to_c / dist), 0.06).normalized()
		proj.set("direction", steer)
		if "speed" in proj:
			proj.set("speed", float(proj.get("speed")) * 0.985)


## Collapse: a violent arcane implosion bursting outward at the moment the hole
## dies. Uses a larger radius and multiplied damage.
func _implode() -> void:
	var center: Vector2 = global_position
	var blast_radius: float = radius * (source_weapon.COLLAPSE_RADIUS_MULT if source_weapon else 1.6)
	var dmg: int = maxi(1, int(round(float(tick_damage) * (source_weapon.COLLAPSE_DAMAGE_MULT if source_weapon else 5.0))))
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var en: Node2D = e as Node2D
		if en == null:
			continue
		if center.distance_to(en.global_position) <= blast_radius and en.has_method("take_damage"):
			en.take_damage(dmg, false, DamageType.Type.ARCANE, false)
			if source_weapon and en.has_method("has_died") and en.has_died():
				source_weapon.apply_explosion_on_kill(en.global_position, dmg)
	_spawn_collapse_visual(center, blast_radius)


func _spawn_collapse_visual(center: Vector2, blast_radius: float) -> void:
	var fx: Node2D = preload("res://src/effects/explosion_effect/explosion_effect.gd").new()
	fx.name = "BlackHoleCollapse"
	fx.global_position = center
	fx.set("max_radius", blast_radius)
	fx.set("color", Color(0.7, 0.4, 1.0))
	get_tree().current_scene.add_child(fx)


func _draw() -> void:
	var fade: float = clampf(1.0 - _age / duration, 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius, Color(0.15, 0.05, 0.25, 0.5 * fade))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(0.6, 0.3, 1.0, 0.8 * fade), 3.0)
	draw_circle(Vector2.ZERO, radius * 0.25, Color(0.0, 0.0, 0.0, 0.9 * fade))
