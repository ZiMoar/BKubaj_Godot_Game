class_name PoisonSprayEffect
extends Node2D

## Poison Spray emitter. Once fired, the player's weapon releases a continuous
## stream of narrow cone "puffs" for the attack's duration — each puff flies
## forward from the player toward the nearest enemy, re-applying the POISON
## ailment as it sweeps. This simulates a spraying motion rather than a single
## static field. Deals NO direct damage — it only inflicts poison, guaranteed.

const PuffScript: Script = preload("res://src/entities/projectiles/poison_puff/poison_puff.gd")

var source_weapon: Node = null
var duration: float = 2.0
var release_interval: float = 0.18
var range_px: float = 190.0
var half_angle: float = 0.22
var hit_value: int = 20

var _age: float = 0.0
var _release_timer: float = 0.0


func setup(weapon: Node, val: int, dur: float, interval: float, rng_px: float, angle: float) -> void:
	source_weapon = weapon
	hit_value = val
	duration = dur
	release_interval = interval
	range_px = rng_px
	half_angle = angle
	_release_timer = 0.0


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= duration:
		queue_free()
		return
	_release_timer -= delta
	if _release_timer <= 0.0:
		_release_timer = release_interval
		_release_puff()


func _release_puff() -> void:
	var dir: Vector2 = _nearest_enemy_dir()
	var puff: Node2D = PuffScript.new()
	puff.name = "PoisonPuff"
	puff.global_position = global_position
	if puff.has_method("setup"):
		puff.setup(source_weapon, dir, hit_value, half_angle, range_px)
	get_tree().current_scene.add_child(puff)


func _nearest_enemy_dir() -> Vector2:
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var best_d: float = INF
	for e: Node in enemies:
		if not is_instance_valid(e):
			continue
		var en: Node2D = e as Node2D
		var d: float = global_position.distance_squared_to(en.global_position)
		if d < best_d:
			best_d = d
			nearest = en
	if nearest != null:
		return (nearest.global_position - global_position).normalized()
	return Vector2.RIGHT
