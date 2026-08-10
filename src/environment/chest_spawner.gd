class_name ChestSpawner
extends Node2D

@export var chest_scene: PackedScene
@export var spawn_interval: float = 45.0
@export var arena_bounds: Rect2 = Rect2(80, 80, 1760, 920)

var _timer: float = 10.0  # First chest spawns quickly for testing
var _player: Node2D = null
var _active_chests: Array[Node] = []


func _ready() -> void:
	add_to_group("chest_spawner")
	if chest_scene == null:
		chest_scene = preload("res://src/environment/treasure_chest.tscn")


func _physics_process(delta: float) -> void:
	if _active_chests.size() > 0:
		return  # Only one chest at a time

	_timer -= delta
	if _timer <= 0.0:
		_timer = spawn_interval
		# Don't waste a chest if the player already has max weapons
		if _player_at_weapon_cap():
			return
		_spawn_chest()


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
