class_name BouncingAxe
extends Node2D

## Axe lobbed by the Berserker's Axe Throw. It flies at the nearest enemy, and on
## hitting one it bounces to the next nearest enemy, and so on — bouncing
## infinitely between enemies until its short lifetime expires.

var damage: int = 30
var is_critical: bool = false
var speed: float = 620.0
var lifetime: float = 3.0
var source_player: Node = null
var source_weapon: Node = null

var _time: float = 0.0
var _target: Node2D = null
## Recent enemy ids we've bounced off, so it doesn't instantly stick to one.
var _recent_hits: Array[int] = []
## Ricochet signature widens how many distinct enemies it chains through.
var _max_recency: int = 4


func setup(pos: Vector2, dmg: int, crit: bool, spd: float, player: Node, weapon: Node, dur: float) -> void:
	global_position = pos
	damage = dmg
	is_critical = crit
	speed = spd
	source_player = player
	source_weapon = weapon
	lifetime = dur
	# Ricochet signature: ricochet to one more enemy before revisiting.
	if weapon != null and weapon.has_signature("ricochet"):
		_max_recency = 6


func _physics_process(delta: float) -> void:
	_time += delta
	if _time >= lifetime:
		queue_free()
		return
	if _target == null or not is_instance_valid(_target):
		_target = _nearest_enemy(_recent_hits)
	if _target == null:
		queue_free()
		return
	global_position = global_position.move_toward(_target.global_position, speed * delta)
	rotation += delta * 14.0
	if global_position.distance_to(_target.global_position) < 9.0:
		_hit(_target)
		_recent_hits.append(_target.get_instance_id())
		if _recent_hits.size() > _max_recency:
			_recent_hits.pop_front()
		_target = null
	queue_redraw()


func _nearest_enemy(exclude: Array) -> Node2D:
	var best: Node2D = null
	var best_d: float = INF
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		if exclude.has(e.get_instance_id()):
			continue
		var en: Node2D = e as Node2D
		var d: float = global_position.distance_squared_to(en.global_position)
		if d < best_d:
			best_d = d
			best = en
	return best


func _hit(en: Node2D) -> void:
	en.take_damage(damage, is_critical, source_weapon.damage_type if source_weapon != null else DamageType.Type.PHYSICAL, false, source_weapon.get_ailment_effect_multiplier() if source_weapon != null else 1.0)
	if source_player and source_player.has_method("apply_lifesteal"):
		source_player.apply_lifesteal()
	if source_weapon and en.is_in_group("enemies"):
		if en.has_method("has_died") and en.has_died():
			source_weapon.apply_explosion_on_kill(en.global_position, damage)


func _draw() -> void:
	# A spinning axe: head + handle, rotated by `rotation`.
	draw_circle(Vector2(0, 0), 5.5, Color(0.5, 0.5, 0.55))
	draw_circle(Vector2(0, 0), 3.0, Color(0.3, 0.3, 0.34))
	draw_rect(Rect2(-8.0, -1.5, 16.0, 3.0), Color(0.35, 0.3, 0.28))
	# Blade edges.
	draw_arc(Vector2.ZERO, 6.5, 0.4, PI - 0.4, 8, Color(0.75, 0.75, 0.8), 1.5)
	draw_arc(Vector2.ZERO, 6.5, PI + 0.4, TAU - 0.4, 8, Color(0.75, 0.75, 0.8), 1.5)
