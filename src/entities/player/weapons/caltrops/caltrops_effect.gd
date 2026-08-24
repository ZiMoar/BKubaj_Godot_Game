class_name CaltropsPatch
extends Node2D

## Caltrops — a scattered patch of spikes that deal PHYSICAL damage to enemies
## that walk over them. It is DURATION-based (not consumed on a single hit):
## while it lasts, every enemy inside takes damage on each tick interval.
##
## Signatures:
##  - Wall of Spikes: the patch is an elongated barrier instead of a circle.
##  - Rusty Spikes: hits apply a stacking physical bleed (impale).
##  - Barbed Field: slows enemies while they stand on it (duration handled by weapon).

var radius: float = 60.0
var tick_interval: float = 0.5
var tick_damage: int = 14
var duration: float = 6.0
var source_weapon: Node = null
var is_wall: bool = false
var wall_angle: float = 0.0
var wall_length: float = 300.0

var _age: float = 0.0
var _tick_timer: float = 0.5
var _visual_only: bool = false


func _ready() -> void:
	z_index = 8
	_tick_timer = tick_interval
	queue_redraw()


func setup(r: float, interval: float, dmg: int, dur: float, w: Node, wall: bool, wangle: float, wlen: float) -> void:
	radius = r
	tick_interval = interval
	tick_damage = dmg
	duration = dur
	source_weapon = w
	is_wall = wall
	wall_angle = wangle
	wall_length = wlen
	_tick_timer = interval


func setup_visual(data: Dictionary) -> void:
	_visual_only = true
	radius = float(data.get("radius", radius))
	duration = float(data.get("dur", duration))
	is_wall = bool(data.get("wall", false))
	wall_angle = float(data.get("wall_angle", wall_angle))
	wall_length = float(data.get("wall_len", wall_length))
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
		queue_free()
		return

	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer = tick_interval
		for e: Node in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(e):
				continue
			var en: Node2D = e as Node2D
			if en == null or not en.has_method("take_damage"):
				continue
			if _inside(en.global_position):
				en.take_damage(tick_damage, false, DamageType.Type.PHYSICAL, true)
				if source_weapon and en.has_method("has_died") and en.has_died():
					source_weapon.apply_explosion_on_kill(en.global_position, tick_damage)
				if source_weapon and source_weapon.rusty_spikes and en.has_method("apply_impale"):
					en.apply_impale(float(tick_damage))
				if source_weapon and source_weapon.barbed_field and en.has_method("apply_slow"):
					en.apply_slow(source_weapon.BARBED_SLOW_DURATION, source_weapon.BARBED_SLOW_FACTOR)
	queue_redraw()


## Whether a world position sits inside this patch (circle, or the wall segment).
func _inside(world_pos: Vector2) -> bool:
	if not is_wall:
		return global_position.distance_to(world_pos) <= radius
	# Transform into patch-local space where the wall runs along the X axis.
	var local: Vector2 = (world_pos - global_position).rotated(-wall_angle)
	var half: float = wall_length * 0.5
	if absf(local.x) > half:
		return false
	return absf(local.y) <= radius * 0.5


func _draw() -> void:
	var fade: float = clampf(1.0 - _age / duration, 0.0, 1.0)
	if is_wall:
		# A row of spikes along the wall.
		var half: float = wall_length * 0.5
		var steps: int = maxi(2, int(wall_length / 22.0))
		for i in range(steps):
			var t: float = -1.0 + 2.0 * float(i) / float(steps - 1)
			var x: float = t * half
			draw_line(Vector2(x, -8), Vector2(x, 8), Color(0.75, 0.75, 0.8, fade), 2.0)
		draw_rect(Rect2(-half, -radius * 0.5, wall_length, radius), Color(0.6, 0.6, 0.65, 0.15 * fade))
		return
	# Ring of jagged spikes.
	var spikes: int = 10
	for i in range(spikes):
		var a: float = TAU * float(i) / float(spikes)
		var inner: Vector2 = Vector2.from_angle(a) * radius * 0.4
		var outer: Vector2 = Vector2.from_angle(a) * radius
		draw_line(inner, outer, Color(0.75, 0.75, 0.8, fade), 2.0)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, Color(0.55, 0.55, 0.6, 0.4 * fade), 1.5)
