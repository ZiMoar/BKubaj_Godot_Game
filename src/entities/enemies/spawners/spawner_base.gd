class_name SpawnerBase
extends Node2D

@export var enemy_scene: PackedScene
@export var spawn_interval: float = 1.5
@export var is_spawning: bool = true
@export var max_active_enemies: int = 9999
@export var arena_bounds: Rect2 = Rect2(40, 40, 1840, 1000)
@export var difficulty_spawn_ratio: float = 0.4
@export var elite_chance_per_difficulty: float = 0.0
@export var elite_base_chance: float = 0.0
# Minimum run difficulty required before this enemy type can spawn.
@export var min_difficulty: int = 0

@onready var timer: Timer = get_node_or_null("Timer") as Timer

var player: Node2D = null
var _base_interval: float = 1.5
var _suppressed: bool = false

func _ready() -> void:
	if timer == null:
		timer = Timer.new()
		timer.name = "Timer"
		add_child(timer)

	_derive_arena_bounds()

	timer.wait_time = spawn_interval
	_base_interval = spawn_interval
	add_to_group("regular_spawner")
	timer.timeout.connect(_on_timer_timeout)
	if is_spawning:
		timer.start()

# Derive the safe spawn region from the arena's Floor (GridBackground) so the
# out-of-bounds protection matches whatever map this spawner runs in, instead of
# being hardcoded to the test arena's wide layout. Falls back to the exported
# arena_bounds if no Floor node is found.
func _derive_arena_bounds() -> void:
	var floor_node := _find_floor_node()
	if floor_node == null:
		return
	# Inset from the floor edge by a margin so enemies never spawn inside walls.
	var margin := 40.0
	arena_bounds = Rect2(floor_node.arena_center - floor_node.arena_size * 0.5 + Vector2(margin, margin), floor_node.arena_size - Vector2(margin * 2.0, margin * 2.0))

# Walk up from this spawner to the arena root and look for a "Floor" (GridBackground).
func _find_floor_node() -> GridBackground:
	var node: Node = self
	while node != null:
		var floor_node := node.get_node_or_null("Floor") as GridBackground
		if floor_node != null:
			return floor_node
		node = node.get_parent()
	return null

# Boss fights call this to slow down regular spawners. Suppression is
# multiplicative on the spawn interval and restored when the boss dies.
func set_suppressed(suppressed: bool, factor: float = 1.0) -> void:
	if suppressed == _suppressed:
		return
	_suppressed = suppressed
	if suppressed:
		spawn_interval = _base_interval * maxf(1.0, factor)
	else:
		spawn_interval = _base_interval
	if timer:
		timer.wait_time = spawn_interval

func _on_timer_timeout() -> void:
	if not is_spawning or enemy_scene == null:
		return
		
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D
		if player == null:
			return
			
	var active_enemy_count = get_tree().get_nodes_in_group("enemies").size()
	if active_enemy_count >= max_active_enemies:
		return

	if get_run_difficulty() < min_difficulty:
		return

	_spawn_pattern()

func get_run_difficulty() -> float:
	if player and is_instance_valid(player):
		if player.has_method("get_map_difficulty"):
			return maxf(0.0, float(player.get_map_difficulty()))
		if player.has_method("get"):
			return maxf(0.0, float(player.get("difficulty")))

	return 0.0

func get_spawn_count() -> int:
	return max(1, int(round(get_run_difficulty() / maxf(0.1, difficulty_spawn_ratio))))

func should_spawn_elite() -> bool:
	if elite_chance_per_difficulty <= 0.0:
		return randf() < clamp(elite_base_chance, 0.0, 1.0)

	var difficulty_chance = get_run_difficulty() / maxf(0.1, elite_chance_per_difficulty)
	return randf() < clamp(elite_base_chance + difficulty_chance, 0.0, 1.0)

# Virtual method to be overridden by child spawners
func _spawn_pattern() -> void:
	pass

func spawn_at_position(pos: Vector2) -> Node:
	if enemy_scene == null:
		return null
	var enemy = enemy_scene.instantiate()
	if enemy is Node2D:
		(enemy as Node2D).global_position = pos
	get_tree().current_scene.add_child(enemy)
	return enemy

func clamp_position_to_arena(pos: Vector2) -> Vector2:
	return Vector2(
		clamp(pos.x, arena_bounds.position.x, arena_bounds.position.x + arena_bounds.size.x),
		clamp(pos.y, arena_bounds.position.y, arena_bounds.position.y + arena_bounds.size.y)
	)
