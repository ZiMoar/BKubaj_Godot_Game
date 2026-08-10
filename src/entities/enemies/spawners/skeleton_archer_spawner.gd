class_name SkeletonArcherSpawner
extends SkeletonSpawner

# Spawns a group of archers; difficulty scales the group size, not the frequency.
@export var group_size: int = 3


func _ready() -> void:
	# Barely more common than the brute (7.5s) — slightly shorter interval.
	spawn_interval = 6.5
	max_active_enemies = 9999
	difficulty_spawn_ratio = 0.25
	elite_chance_per_difficulty = 0.0
	elite_base_chance = 0.0
	if enemy_scene == null:
		enemy_scene = preload("res://src/entities/enemies/skeleton_archer/skeleton_archer.tscn")
	super._ready()


func get_spawn_count() -> int:
	# Base group size, +1 archer per ~15 difficulty. Frequency stays fixed.
	# Cap the group so a stationary player can't be overwhelmed by screen-wide archer volleys.
	var difficulty: float = get_run_difficulty()
	var extra: int = int(floor(difficulty / maxf(0.1, difficulty_spawn_ratio)))
	return clampi(group_size + extra, 1, MAX_ARCHERS_PER_BATCH)


const MAX_ARCHERS_PER_BATCH: int = 6