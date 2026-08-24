class_name Beehive
extends Node2D

## Beehive — a placed hive that periodically releases swarms of bees toward
## nearby enemies. Each swarm flies out, attaches to an enemy, chews it with
## POISON damage in an area around it, and returns to the hive once its target
## dies. The hive lasts for its duration.

var spawn_interval: float = 1.2
var swarm_count: int = 2
var swarm_damage: int = 8
var swarm_speed: float = 260.0
var swarm_area: float = 70.0
var home_range: float = 320.0
var duration: float = 8.0
var source_player: Player = null
var source_weapon: Node = null

var _age: float = 0.0
var _spawn_timer: float = 0.6
var _bonus_swarms: int = 0
var _visual_only: bool = false


## Hive Mind: a returning swarm that killed its target adds an extra swarm to the
## next volley (called by the swarm).
func _notify_swarm_kill() -> void:
	_bonus_swarms += 1


func _ready() -> void:
	z_index = 9
	_spawn_timer = 0.4
	queue_redraw()


func setup(interval: float, count: int, dmg: int, spd: float, area: float, hrange: float, dur: float, player: Player, weapon: Node) -> void:
	spawn_interval = interval
	swarm_count = count
	swarm_damage = dmg
	swarm_speed = spd
	swarm_area = area
	home_range = hrange
	duration = dur
	source_player = player
	source_weapon = weapon
	_spawn_timer = 0.4


func setup_visual(data: Dictionary) -> void:
	_visual_only = true
	duration = float(data.get("dur", duration))
	swarm_area = float(data.get("area", swarm_area))
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

	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = spawn_interval
		_release_swarms()
	queue_redraw()


func _release_swarms() -> void:
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return
	var in_range: Array[Node2D] = []
	for e: Node in enemies:
		if not is_instance_valid(e):
			continue
		var en: Node2D = e as Node2D
		if en == null:
			continue
		if global_position.distance_squared_to(en.global_position) <= home_range * home_range:
			in_range.append(en)
	if in_range.is_empty():
		return
	in_range.shuffle()
	var n: int = mini(swarm_count + _bonus_swarms, in_range.size())
	_bonus_swarms = 0
	for i in range(n):
		var swarm: Node = preload("res://src/entities/projectiles/bee_swarm/bee_swarm.tscn").instantiate()
		swarm.name = "BeeSwarm_%d" % i
		swarm.global_position = global_position
		if swarm.has_method("setup"):
			swarm.setup(in_range[i], global_position, swarm_speed, swarm_damage, 0.5, swarm_area, source_player, source_weapon, self)
		get_tree().current_scene.add_child(swarm)
		sync_effect(swarm, preload("res://src/entities/projectiles/bee_swarm/bee_swarm.tscn"), {"area": swarm_area})


func sync_effect(effect: Node, scene: PackedScene, extra: Dictionary) -> void:
	var net: Node = get_node_or_null("/root/Net")
	if net and net.has_method("sync_player_effect"):
		net.sync_player_effect(effect, scene, extra)


func _draw() -> void:
	var fade: float = clampf(1.0 - _age / duration, 0.0, 1.0)
	# Hive: rounded golden blob with a darker opening.
	draw_circle(Vector2.ZERO, 16.0, Color(0.85, 0.7, 0.25, fade))
	draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 24, Color(0.5, 0.4, 0.12, fade), 2.0)
	draw_circle(Vector2(0, -4), 6.0, Color(0.35, 0.28, 0.1, fade))
