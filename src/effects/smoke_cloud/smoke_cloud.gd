class_name SmokeCloud
extends Node2D

## The Rogue's Smoke Bomb visual: a drifting grey cloud around the player for the
## buff's duration, showing the dodge-bonus area.

var duration: float = 4.0
var _t: float = 0.0
## "Toxic Cloud" signature: when true, poisons enemies inside the cloud.
var poison: bool = false
var _poison_tick: float = 0.0
const CLOUD_RADIUS: float = 58.0
const POISON_TICK_INTERVAL: float = 0.8


func setup(dur: float, poison_active: bool = false) -> void:
	duration = maxf(0.1, dur)
	poison = poison_active


func _process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		queue_free()
		return
	if poison:
		_poison_tick -= delta
		if _poison_tick <= 0.0:
			_poison_tick = POISON_TICK_INTERVAL
			_apply_poison()
	queue_redraw()


## Poisons every enemy inside the cloud (Toxic Cloud signature).
func _apply_poison() -> void:
	var pos: Vector2 = global_position
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var en: Node2D = e as Node2D
		if pos.distance_to(en.global_position) <= CLOUD_RADIUS and en.has_method("apply_poison"):
			en.apply_poison(30.0)


func _draw() -> void:
	var fade: float = clampf(1.0 - _t / duration, 0.0, 1.0)
	var r: float = 58.0
	draw_circle(Vector2.ZERO, r, Color(0.75, 0.75, 0.8, 0.22 * fade))
	for i in range(7):
		var a: float = TAU * float(i) / 7.0 + _t * 0.6
		var p: Vector2 = Vector2(cos(a), sin(a)) * r * 0.45
		var puff: float = r * (0.3 + 0.12 * sin(_t * 2.0 + float(i)))
		draw_circle(p, puff, Color(0.85, 0.85, 0.9, 0.28 * fade))
