class_name PoisonPuff
extends Node2D

## A single narrow cone "spurt" of poison released from the player during a
## Poison Spray attack. It travels forward for a short life while re-applying
## the POISON ailment to every enemy inside its narrow cone. Deals no direct
## damage — it only inflicts poison, guaranteed, using an "as-if" hit value that
## the player's ailment chance boosts (since infliction is guaranteed, chance
## converts into damage).

var source_weapon: Node = null
var direction: Vector2 = Vector2.RIGHT
var speed: float = 230.0
var life: float = 0.33
var hit_value: int = 20
var half_angle: float = 0.22  # radians (~12.6 deg each side)
var range_px: float = 170.0
var tick_interval: float = 0.1

var _age: float = 0.0
var _tick: float = 0.0


func setup(weapon: Node, aim_dir: Vector2, val: int, angle: float, rng_px: float) -> void:
	source_weapon = weapon
	direction = aim_dir.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	hit_value = val
	half_angle = angle
	range_px = rng_px
	rotation = direction.angle()


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= life:
		queue_free()
		return
	global_position += direction * speed * delta
	_tick -= delta
	if _tick <= 0.0:
		_tick = tick_interval
		_apply()


func _apply() -> void:
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


func _in_cone(target: Vector2) -> bool:
	var to: Vector2 = target - global_position
	var dist: float = to.length()
	if dist > range_px:
		return false
	var ang: float = to.angle() - direction.angle()
	ang = wrapf(ang, -PI, PI)
	return absf(ang) <= half_angle


func _draw() -> void:
	# Narrow hazard cone facing `direction` (moves with the puff).
	var pts := PackedVector2Array()
	pts.append(Vector2.ZERO)
	var steps := 16
	for i in range(steps + 1):
		var a: float = -half_angle + (2.0 * half_angle) * float(i) / float(steps)
		pts.append(Vector2(cos(a), sin(a)) * range_px)
	draw_colored_polygon(pts, Color(0.5, 0.85, 0.35, 0.20))
	draw_arc(Vector2.ZERO, range_px, -half_angle, half_angle, steps, Color(0.6, 0.9, 0.4, 0.4), 2.0)
