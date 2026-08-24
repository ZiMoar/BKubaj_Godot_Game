class_name StaticCharge
extends Node2D

## Ground patch left by Storm Conduit's "Static Charge" signature. Periodically
## zaps enemies standing on it with LIGHTNING damage for a few seconds.

var radius: float = 55.0
var tick_interval: float = 0.6
var damage: int = 10
var duration: float = 4.0
var source_weapon: Node = null

var _age: float = 0.0
var _tick: float = 0.6
var _visual_only: bool = false


func _ready() -> void:
	z_index = 8
	_tick = tick_interval
	queue_redraw()


func setup(r: float, interval: float, dmg: int, dur: float, w: Node) -> void:
	radius = r
	tick_interval = interval
	damage = dmg
	duration = dur
	source_weapon = w
	_tick = interval


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
		queue_free()
		return

	_tick -= delta
	if _tick <= 0.0:
		_tick = tick_interval
		var center: Vector2 = global_position
		for e: Node in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(e):
				continue
			var en: Node2D = e as Node2D
			if en == null:
				continue
			if center.distance_to(en.global_position) <= radius and en.has_method("take_damage"):
				en.take_damage(damage, false, DamageType.Type.LIGHTNING, false)
		_spawn_zap_visual()
	queue_redraw()


func _spawn_zap_visual() -> void:
	var fx: Node2D = preload("res://src/effects/explosion_effect/explosion_effect.gd").new()
	fx.name = "StaticZap"
	fx.global_position = global_position
	fx.set("max_radius", radius * 0.6)
	fx.set("color", Color(0.6, 0.85, 1.0))
	get_tree().current_scene.add_child(fx)


func _draw() -> void:
	var fade: float = clampf(1.0 - _age / duration, 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius, Color(0.6, 0.7, 0.9, 0.18 * fade))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, Color(0.7, 0.85, 1.0, 0.6 * fade), 1.5)
	draw_circle(Vector2.ZERO, 3.0, Color(0.9, 0.95, 1.0, 0.9 * fade))
