class_name BomberSkeletonSpawner
extends SpawnerBase

## Spawns a single Bomber Skeleton. The bomber is a fast, kamikaze threat, so
## only ONE is ever alive at a time — the spawner skips its turn while a bomber
## is still on the field. Requires min_difficulty 3.

@export var spawn_radius: float = 420.0


func _ready() -> void:
	spawn_interval = 12.0
	min_difficulty = 3
	max_active_enemies = 9999
	difficulty_spawn_ratio = 2.668
	elite_chance_per_difficulty = 0.0
	elite_base_chance = 0.0
	if enemy_scene == null:
		enemy_scene = preload("res://src/entities/enemies/bomb/bomber_skeleton/bomber_skeleton.tscn")
	super._ready()


func _spawn_pattern() -> void:
	if player == null:
		return

	# Only one bomber alive at a time.
	if not get_tree().get_nodes_in_group("bombers").is_empty():
		return

	var spawn_pos: Vector2 = _find_spawn_position()
	if spawn_pos == Vector2.ZERO:
		return
	spawn_at_position(spawn_pos)


func _find_spawn_position() -> Vector2:
	var valid_found: bool = false
	var spawn_pos: Vector2 = Vector2.ZERO
	for i in range(10):
		var random_angle: float = randf() * TAU
		var candidate: Vector2 = player.global_position + Vector2(cos(random_angle), sin(random_angle)) * spawn_radius
		if arena_bounds.has_point(candidate):
			spawn_pos = candidate
			valid_found = true
			break
	if not valid_found:
		var random_angle: float = randf() * TAU
		spawn_pos = clamp_position_to_arena(player.global_position + Vector2(cos(random_angle), sin(random_angle)) * spawn_radius)
	return spawn_pos