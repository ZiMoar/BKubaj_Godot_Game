class_name BatSpawner
extends SpawnerBase

## Spawns a SWARM of bats. As rare as a brute (min_difficulty 3, long interval),
## but when it does fire it releases a cluster of many bats at once.
##
## Clusters, not rings: the whole swarm is spawned clumped around a single
## anchor point far from the player (rather than a circle around them), so the
## player sees a tight cloud of bats approaching together.

@export var spawn_radius: float = 380.0
@export var cluster_radius: float = 45.0
@export var swarm_size: int = 6


func _ready() -> void:
	spawn_interval = 7.5
	min_difficulty = 3
	max_active_enemies = 9999
	difficulty_spawn_ratio = 2.668
	elite_chance_per_difficulty = 0.0
	elite_base_chance = 0.0
	if enemy_scene == null:
		enemy_scene = preload("res://src/entities/enemies/dasher/bat/bat_enemy.tscn")
	super._ready()


func _spawn_pattern() -> void:
	if player == null:
		return

	var anchor: Vector2 = _find_anchor_position()
	if anchor == Vector2.ZERO:
		return

	var count: int = max(1, swarm_size)
	for i in range(count):
		var offset: Vector2 = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() * randf_range(0.0, cluster_radius)
		spawn_at_position(anchor + offset)


func _find_anchor_position() -> Vector2:
	var valid_found: bool = false
	var anchor: Vector2 = Vector2.ZERO
	for i in range(12):
		var random_angle: float = randf() * TAU
		var candidate: Vector2 = player.global_position + Vector2(cos(random_angle), sin(random_angle)) * spawn_radius
		if arena_bounds.has_point(candidate):
			anchor = candidate
			valid_found = true
			break
	if not valid_found:
		var random_angle: float = randf() * TAU
		anchor = clamp_position_to_arena(player.global_position + Vector2(cos(random_angle), sin(random_angle)) * spawn_radius)
	return anchor