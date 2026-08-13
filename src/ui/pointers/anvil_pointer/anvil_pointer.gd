class_name AnvilPointer
extends TargetPointer

## Points toward the currently active anvil.

@export var anvil_spawner: AnvilSpawner = null


func _ready() -> void:
	if anvil_spawner == null or not is_instance_valid(anvil_spawner):
		anvil_spawner = get_tree().get_first_node_in_group("anvil_spawner") as AnvilSpawner
	pointer_color = Color(0.75, 0.6, 0.95)  # purple, distinct from the gold chest arrow


func _get_target_world_pos() -> Vector2:
	if anvil_spawner == null or not is_instance_valid(anvil_spawner):
		return Vector2.INF
	var anvil: Node2D = anvil_spawner.get_active_anvil()
	if anvil == null or not is_instance_valid(anvil):
		return Vector2.INF
	return anvil.global_position
