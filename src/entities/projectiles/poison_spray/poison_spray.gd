class_name PoisonSprayEffect
extends Node2D

## Continuous poison stream. Sits at the player's position, oriented at the
## nearest enemy, and every tick applies a POISON stack to every enemy inside
## the cone. Deals NO direct damage — it only inflicts the poison ailment,
## guaranteed, using an "as-if" hit value that the player's ailment chance
## boosts (since the ailment is guaranteed, chance converts to damage).

var source_weapon: Node = null
var direction: Vector2 = Vector2.RIGHT
var duration: float = 2.0
var tick_interval: float = 0.25
var range_px: float = 180.0
var half_angle: float = 0.6  # radians (~34 deg each side)
var hit_value: int = 20

var _age: float = 0.0
var _tick_timer: float = 0.0


func setup(weapon: Node, aim_dir: Vector2, val: int, dur: float, tick: float, rng_px: float) -> void:
	source_weapon = weapon
	direction = aim_dir.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	hit_value = val
	duration = dur
	tick_interval = tick
	range_px = rng_px
	rotation = direction.angle()
	# First tick happens on the first physics frame (after being added to the
	# tree), so we don't touch the tree before the node is parented.
	_tick_timer = 0.0


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= duration:
		queue_free()
		return
	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer = tick_interval
		_apply_tick()


func _apply_tick() -> void:
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for e: Node in enemies:
		if not is_instance_valid(e):
			continue
		var en: Node2D = e as Node2D
		if not _in_cone(en.global_position):
			continue
		if en.has_method("apply_poison"):
			en.apply_poison(float(hit_value))
			if source_weapon and source_weapon.has_method("apply_lifesteal"):
				source_weapon.apply_lifesteal()
			# Track kills? Poison never kills directly through these this way, but
			# explosion-on-kill won't fire on a pure ailment. Keep it simple.


func _in_cone(target: Vector2) -> bool:
	var to: Vector2 = target - global_position
	var dist: float = to.length()
	if dist > range_px:
		return false
	var ang: float = to.angle() - direction.angle()
	ang = wrapf(ang, -PI, PI)
	return absf(ang) <= half_angle


func _draw() -> void:
	# Draw a translucent hazard cone facing `direction`.
	var pts := PackedVector2Array()
	pts.append(Vector2.ZERO)
	var steps := 24
	for i in range(steps + 1):
		var a: float = -half_angle + (2.0 * half_angle) * float(i) / float(steps)
		pts.append(Vector2(cos(a), sin(a)) * range_px)
	draw_colored_polygon(pts, Color(0.5, 0.85, 0.35, 0.18))
	# Hazard speckles.
	draw_arc(Vector2.ZERO, range_px, -half_angle, half_angle, steps, Color(0.6, 0.9, 0.4, 0.4), 2.0)
