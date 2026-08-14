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
		_spawn_anvil()


func _spawn_anvil() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return

	var anvil: Node2D = anvil_scene.instantiate() as Node2D
	anvil.global_position = _random_arena_position()
	get_tree().current_scene.add_child(anvil)
	_active_anvils.append(anvil)
	anvil.tree_exited.connect(_on_anvil_exited.bind(anvil))


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