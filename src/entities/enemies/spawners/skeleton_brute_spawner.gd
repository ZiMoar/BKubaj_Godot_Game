class_name SkeletonBruteSpawner
extends SkeletonSpawner

func _ready() -> void:
	spawn_interval = 7.5
	max_active_enemies = 9999
	difficulty_spawn_ratio = 2.668
	# Frequency is fixed (not scale by difficulty). Brutes scale via stats only.
	elite_chance_per_difficulty = 0.0
	elite_base_chance = 0.12
	if enemy_scene == null:
		enemy_scene = preload("res://src/entities/enemies/skeleton_brute/skeleton_brute.tscn")
	super._ready()

func _spawn_pattern() -> void:
	if player == null:
		return

	if not should_spawn_elite():
		return

	var spawn_pos: Vector2
	var valid_found: bool = false

	for i in range(10):
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
