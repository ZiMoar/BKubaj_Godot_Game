class_name SkeletonSpawner
extends SpawnerBase

@export var spawn_radius: float = 920.0

func _ready() -> void:
	if enemy_scene == null:
		enemy_scene = preload("res://src/entities/enemies/swarmer/skeleton/skeleton_enemy.tscn")
	difficulty_spawn_ratio = 2.2  # Gentler spawn-count ramp so heavy swarms wait for later stages
	super._ready()

func _spawn_pattern() -> void:
	if player == null:
		return

	var spawn_count := get_spawn_count()
		
	for i in range(spawn_count):
		var spawn_pos: Vector2
		var valid_found: bool = false
		
		# Try up to 10 random angles to find a spawn position inside the arena walls
		for j in range(10):
			var random_angle = randf() * TAU
			var spawn_offset = Vector2(cos(random_angle), sin(random_angle)) * spawn_radius
			var candidate = player.global_position + spawn_offset
			
			if arena_bounds.has_point(candidate):
				spawn_pos = candidate
				valid_found = true
				break
				
		if not valid_found:
			var random_angle = randf() * TAU
			var spawn_offset = Vector2(cos(random_angle), sin(random_angle)) * spawn_radius
			spawn_pos = clamp_position_to_arena(player.global_position + spawn_offset)
			
		spawn_at_position(spawn_pos)
