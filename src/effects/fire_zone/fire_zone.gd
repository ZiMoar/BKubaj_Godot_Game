class_name FireZone
extends Node2D

## Burning ground left behind by Demolitionist explosions (and any future fire
## patches). Deals periodic FIRE damage to enemies inside its radius for its
## short duration, then fades out.

var radius: float = 80.0
var duration: float = 2.5
var dps: float = 0.0
var source_weapon: Node = null
## Inherits the source weapon's element, so infusions show through on the ground.
var damage_type: DamageType.Type = DamageType.Type.FIRE

var _t: float = 0.0
var _tick: float = 0.0


func _physics_process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		queue_free()
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.25
	var pos: Vector2 = global_position
	var ailment: float = source_weapon.get_ailment_effect_multiplier() if source_weapon != null else 1.0
	var per_tick: int = maxi(1, int(round(dps * 0.25)))
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var en: Node2D = e as Node2D
		if pos.distance_to(en.global_position) <= radius:
			en.take_damage(per_tick, false, damage_type, false, ailment)


func _draw() -> void:
	var fade: float = clampf(1.0 - _t / duration, 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius, Color(1.0, 0.5, 0.15, 0.10 * fade))
	for i in range(6):
		var a: float = TAU * float(i) / 6.0 + _t * 0.8
		var p: Vector2 = Vector2(cos(a), sin(a)) * radius * 0.4
		var r: float = radius * (0.15 + 0.1 * sin(_t * 3.0 + float(i)))
		draw_circle(p, r, Color(1.0, 0.6, 0.2, 0.25 * fade))
