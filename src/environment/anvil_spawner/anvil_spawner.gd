class_name AnvilSpawner
extends Node2D

## Spawns anvils on the same rules as weapon boxes (periodic, one at a time,
## random arena position), but only starts after the first weapon box has
## spawned.

@export var anvil_scene: PackedScene
@export var spawn_interval: float = 60.0
@export var arena_bounds: Rect2 = Rect2(80, 80, 1760, 920)

var _timer: float = 0.0
var _enabled: bool = false
var _active_anvils: Array[Node] = []
var _player: Node2D = null
## Set false by the StageController once the room is cleared, so anvils stop
## respawning after the boss dies (matches the enemy spawners).
var is_active: bool = true


func _ready() -> void:
	add_to_group("anvil_spawner")
	if anvil_scene == null:
		anvil_scene = preload("res://src/environment/anvil/anvil.tscn")
	_derive_arena_bounds()


func _derive_arena_bounds() -> void:
	var floor_node := _find_floor_node()
	if floor_node == null:
		return
	var margin := 80.0
	arena_bounds = Rect2(
		floor_node.arena_center - floor_node.arena_size * 0.5 + Vector2(margin, margin),
		floor_node.arena_size - Vector2(margin * 2.0, margin * 2.0)
	)


func _find_floor_node() -> GridBackground:
	var node: Node = self
	while node != null:
		var floor_node := node.get_node_or_null("Floor") as GridBackground
		if floor_node != null:
			return floor_node
		node = node.get_parent()
	return null


func _physics_process(delta: float) -> void:
	# Stop spawning entirely once the room is cleared (boss dead).
	if not is_active:
		return
	if _is_network_client():
		return  # Co-op: the HOST decides when/where an anvil spawns.
	# Stay dormant until the first weapon box has spawned.
	if not _enabled:
		var chest: Node = get_tree().get_first_node_in_group("chest_spawner")
		if chest != null and chest.get("_spawned_once") == true:
			_enabled = true
			_timer = spawn_interval
		return

	if _active_anvils.size() > 0:
		return

	_timer -= delta
	if _timer <= 0.0:
		_timer = spawn_interval
		_do_spawn_anvil()


## Co-op: the host picks the position + golden flag (host-only RNG) and
## broadcasts them so every machine spawns the SAME anvil at the SAME spot.
## Single-player just spawns locally with no network round-trip.
func _do_spawn_anvil() -> void:
	var pos: Vector2 = _random_arena_position()
	var golden: bool = randf() < 0.05
	if _is_coop():
		spawn_anvil.rpc(pos, golden, 0)  # standard anvil kind 0; authority RPC
	else:
		_spawn_anvil_at(pos, golden, 0)


## Host -> every machine: place an anvil at the shared position. Each machine
## spawns its OWN interactive copy (like shared pickups) so its local player can
## use it; using it frees only that machine's copy.
@rpc("authority", "reliable", "call_local")
func spawn_anvil(pos: Vector2, golden: bool, kind: int) -> void:
	_spawn_anvil_at(pos, golden, kind)


func _spawn_anvil_at(pos: Vector2, golden: bool, kind: int) -> void:
	if get_tree().current_scene == null:
		return
	var anvil: Node2D = anvil_scene.instantiate() as Node2D
	anvil.set("is_golden", golden)
	anvil.set("anvil_kind", kind)
	anvil.global_position = pos
	get_tree().current_scene.add_child(anvil)
	_active_anvils.append(anvil)
	anvil.tree_exited.connect(_on_anvil_exited.bind(anvil))


## True when a live co-op session is active (host or client).
func _is_coop() -> bool:
	var net: Node = get_node_or_null("/root/Net")
	return net != null and net.active()


## True on a co-op CLIENT (not the host). Such a machine never spawns an anvil
## on its own — it only reacts to the host's spawn_anvil RPC.
func _is_network_client() -> bool:
	var net: Node = get_node_or_null("/root/Net")
	if net == null or not net.active():
		return false
	return not multiplayer.is_server()


func _on_anvil_exited(anvil: Node) -> void:
	_active_anvils.erase(anvil)


## Returns the currently active anvil, if any (used by the anvil pointer).
func get_active_anvil() -> Node2D:
	for anvil: Node in _active_anvils:
		if is_instance_valid(anvil):
			return anvil as Node2D
	return null


func _random_arena_position() -> Vector2:
	return Vector2(
		randf_range(arena_bounds.position.x, arena_bounds.position.x + arena_bounds.size.x),
		randf_range(arena_bounds.position.y, arena_bounds.position.y + arena_bounds.size.y),
	)