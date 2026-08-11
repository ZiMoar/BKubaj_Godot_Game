class_name SkeletonArcherSpawner
extends SkeletonSpawner

# Spawns a group of archers; difficulty scales the group size, not the frequency.
@export var group_size: int = 2


func _ready() -> void:
	# Archers are rare ambushers: a long cooldown between volleys, and the
	# batch only grows slowly with difficulty.
	spawn_interval = 14.0
	min_difficulty = 1
	max_active_enemies = 9999
	elite_chance_per_difficulty = 0.0
	elite_base_chance = 0.0
	if enemy_scene == null:
		enemy_scene = preload("res://src/entities/enemies/trooper/skeleton_archer/skeleton_archer.tscn")
	super._ready()
	# Set AFTER super._ready() so SkeletonSpawner's 0.668 override doesn't
	# clobber this — otherwise batches explode with difficulty.
	difficulty_spawn_ratio = 4.0


func get_spawn_count() -> int:
	# Base group size, +1 archer per difficulty_spawn_ratio. Frequency stays fixed.
	# Cap the group so a stationary player can't be overwhelmed by archer volleys.
	var difficulty: float = get_run_difficulty()
	var extra: int = int(floor(difficulty / maxf(0.1, difficulty_spawn_ratio)))
	return clampi(group_size + extra, 1, MAX_ARCHERS_PER_BATCH)


const MAX_ARCHERS_PER_BATCH: int = 3