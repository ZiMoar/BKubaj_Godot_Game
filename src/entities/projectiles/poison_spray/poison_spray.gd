class_name PoisonSprayEffect
extends Node2D

## Poison Spray emitter. Once fired, the player's weapon releases a continuous
## stream of narrow cone "puffs" for the attack's duration — each puff flies
## forward from the player toward the nearest enemy, re-applying the POISON
## ailment as it sweeps. This simulates a spraying motion rather than a single
## static field. Deals NO direct damage — it only inflicts poison, guaranteed.
## The emitter follows the player so the spray always originates from the player's
## current position even while they move.

const PuffScript: Script = preload("res://src/entities/projectiles/poison_puff/poison_puff.gd")

var source_weapon: Node = null
var duration: float = 2.0
var release_interval: float = 0.18
var range_px: float = 190.0
var half_angle: float = 0.22
var hit_value: int = 20
## Name of the player this visual copy follows (a teammate's replica on this
## machine). Empty for the real, weapon-driven copy.
var _visual_player_name: String = ""

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


## Follow the living player. If the weapon reports a player, snap to it every
## frame so newly released puffs burst from the player, not from the fixed spot
## where the emitter was first created. On a remote visual copy (no weapon ref),
## follow the firing player's replica by name instead of the first local player.
func _follow_player() -> void:
	if get_meta("visual_copy", false):
		var vis: Node = NetworkManager.find_player_by_name(_visual_player_name)
		if vis is Node2D:
			global_position = (vis as Node2D).global_position
			return
	var player: Node = null
	if source_weapon and source_weapon.has_method("get_player"):
		player = source_weapon.get_player()
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	if player is Node2D:
		global_position = (player as Node2D).global_position


## Co-op: configure a remote visual-only copy from broadcast data (no weapon ref
## on this machine). It follows the firing player's replica and keeps releasing
## visual puffs, but nothing applies poison.
func setup_visual(data: Dictionary) -> void:
	duration = float(data.get("dur", 2.0))
	release_interval = float(data.get("interval", 0.18))
	range_px = float(data.get("rng", 190.0))
	half_angle = float(data.get("half_angle", 0.22))
	hit_value = int(data.get("val", 20))
	_visual_player_name = str(data.get("player_name", ""))


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= duration:
		queue_free()
		return
	_follow_player()
	_release_timer -= delta
	if _release_timer <= 0.0:
		_release_timer = release_interval
		_release_puff()


func _release_puff() -> void:
	# Twin Spray: also spray in the opposite direction.
	var twin: bool = source_weapon != null and source_weapon.has_method("has_signature") and source_weapon.has_signature("twin_spray")
	var dir: Vector2 = _nearest_enemy_dir()
	_spawn_puff(dir)
	if twin:
		_spawn_puff(-dir)


func _spawn_puff(dir: Vector2) -> void:
	var puff: Node2D = PuffScript.new()
	puff.name = "PoisonPuff"
	puff.global_position = global_position
	# A visual copy's own puffs must also be visual-only (render, no poison).
	if get_meta("visual_copy", false):
		puff.set_meta("visual_copy", true)
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
