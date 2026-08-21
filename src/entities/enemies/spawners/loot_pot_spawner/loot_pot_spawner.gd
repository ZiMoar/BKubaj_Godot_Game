class_name LootPotSpawner
extends SpawnerBase

## Spawns a Loot Pot (breakable loot container). Spawns as rarely as a
## necromancer (9s interval) but with NO minimum difficulty, so pots can appear
## from the very first room. Each pot spawns alone in a ring around the player.

@export var spawn_radius: float = 420.0


func _ready() -> void:
	spawn_interval = 9.0
	min_difficulty = 0
	max_active_enemies = 9999
	difficulty_spawn_ratio = 2.668
	elite_chance_per_difficulty = 0.0
	elite_base_chance = 0.0
	if enemy_scene == null:
		enemy_scene = preload("res://src/entities/enemies/pot/loot_pot/loot_pot.tscn")
	super._ready()


func _spawn_pattern() -> void:
	if player == null:
		return

	var spawn_pos: Vector2 = Vector2.ZERO
	var valid_found: bool = false
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

	spawn_at_position(spawn_pos)
