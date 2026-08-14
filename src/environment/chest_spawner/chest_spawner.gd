class_name ChestSpawner
extends Node2D

signal chest_spawned

## Weapon boxes spawn exactly once per room, 10 seconds into the fight.
@export var chest_scene: PackedScene
@export var spawn_delay: float = 10.0
@export var arena_bounds: Rect2 = Rect2(80, 80, 1760, 920)

var _timer: float = 10.0
var _player: Node2D = null
var _active_chests: Array[Node] = []
var _spawned_once: bool = false
## Set false by the StageController once the room is cleared, so a weapon box
## doesn't spawn after the boss dies (matches the enemy/anvil spawners).
var is_active: bool = true


func _ready() -> void:
	add_to_group("chest_spawner")
	if chest_scene == null:
		chest_scene = preload("res://src/environment/treasure_chest/treasure_chest.tscn")
	_timer = spawn_delay
	_derive_arena_bounds()


# Derive the chest placement region from the arena's Floor so chests spawn inside
# the walls on any map (narrow arena included), not just the wide test arena.
func _derive_arena_bounds() -> void:
	var floor_node := _find_floor_node()
	if floor_node == null:
		return
	var margin := 80.0
	arena_bounds = Rect2(
		floor_node.arena_center - floor_node.arena_size * 0.5 + Vector2(margin, margin),
		floor_node.arena_size - Vector2(margin * 2.0, margin * 2.0)
	)

# Walk up from this node to the arena root and look for a "Floor" (GridBackground).
func _find_floor_node() -> GridBackground:
	var node: Node = self
	while node != null:
		var floor_node := node.get_node_or_null("Floor") as GridBackground
		if floor_node != null:
			return floor_node
		node = node.get_parent()
	return null


func _physics_process(delta: float) -> void:
	if not is_active:
		return  # Room cleared; don't spawn another box after the boss dies.
	if _spawned_once:
		return  # Weapon boxes spawn once per room.

	_timer -= delta
	if _timer <= 0.0:
		_spawned_once = true
		# Don't waste a chest if the player already has max weapons
		if _player_at_weapon_cap():
			chest_spawned.emit()
			return
		_spawn_chest()
		chest_spawned.emit()


func _player_at_weapon_cap() -> bool:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player == null:
		return false
	var weapons_container: Node = _player.get_node_or_null("Weapons")
	if weapons_container == null:
		return false
	var auto_count: int = 0
	for w: Node in weapons_container.get_children():
		if w is Weapon and w.trigger_type == Weapon.TriggerType.AUTOMATIC:
			auto_count += 1
	return auto_count >= Player.MAX_AUTO_WEAPONS


func get_active_chest() -> Node2D:
	# Return the currently active chest, if any (used by the chest pointer).
	for chest: Node in _active_chests:
		if is_instance_valid(chest):
			return chest as Node2D
	return null


func _on_chest_exited(chest: Node) -> void:
	# Remove the chest as soon as it leaves the tree (collected / freed).
	# This fires even while the game is paused, unlike _physics_process.
	_active_chests.erase(chest)


func _spawn_chest() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return

	var chest: Node2D = chest_scene.instantiate() as Node2D
	var spawn_pos: Vector2 = _random_arena_position()
	chest.global_position = spawn_pos
	get_tree().current_scene.add_child(chest)
	_active_chests.append(chest)
	chest.tree_exited.connect(_on_chest_exited.bind(chest))


func _random_arena_position() -> Vector2:
	return Vector2(
		randf_range(arena_bounds.position.x, arena_bounds.position.x + arena_bounds.size.x),
		randf_range(arena_bounds.position.y, arena_bounds.position.y + arena_bounds.size.y),
	)
