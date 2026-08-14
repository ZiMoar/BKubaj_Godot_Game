class_name ChestPointer
extends TargetPointer

## Points toward the currently active treasure chest.

@export var chest_spawner: ChestSpawner = null


func _ready() -> void:
	pointer_color = Color(1.0, 0.85, 0.3)
	# NOTE: not resolving the chest_spawner here. This pointer is instanced
	# directly in the arena scene, so it readies before the ChestSpawner has
	# joined the "chest_spawner" group. Resolve lazily in _get_target_world_pos
	# instead, so we find the spawner no matter the scene-load order.


func _get_target_world_pos() -> Vector2:
	if chest_spawner == null or not is_instance_valid(chest_spawner):
		chest_spawner = get_tree().get_first_node_in_group("chest_spawner") as ChestSpawner
	if chest_spawner == null or not is_instance_valid(chest_spawner):
		return Vector2.INF
	var chest: Node2D = chest_spawner.get_active_chest()
	if chest == null or not is_instance_valid(chest):
		return Vector2.INF
	return chest.global_position