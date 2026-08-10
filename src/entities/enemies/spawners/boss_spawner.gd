class_name BossSpawner
extends Event

## Spawns a boss once at trigger_time, and suppresses regular spawner rates
## while the boss is alive. Extends Event so it fires exactly one time per stage.

@export var boss_scene: PackedScene
@export var suppression_factor: float = 5.0
@export var spawn_offset: Vector2 = Vector2(0, -320)
@export var arena_bounds: Rect2 = Rect2(40, 40, 1840, 1000)

var _active_boss: Node2D = null
var _suppress_active: bool = false


func _trigger() -> void:
	if boss_scene == null:
		return

	_active_boss = boss_scene.instantiate() as Node2D
	if _active_boss == null:
		return

	get_tree().current_scene.add_child(_active_boss)
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player:
		_active_boss.global_position = player.global_position + spawn_offset
	else:
		_active_boss.global_position = Vector2(960, 300)
	# Keep the boss inside the arena walls, even if the player is hugging a edge.
	_active_boss.global_position = clamp_position_to_arena(_active_boss.global_position)

	_active_boss.tree_exited.connect(_on_boss_exited.bind(_active_boss))
	_set_spawner_suppression(true)


func _on_boss_exited(boss: Node2D) -> void:
	if boss == _active_boss:
		_active_boss = null
	_set_spawner_suppression(false)


func _set_spawner_suppression(suppress: bool) -> void:
	if suppress == _suppress_active:
		return
	_suppress_active = suppress
	# Guard against the tree being torn down (e.g. scene reload after death)
	# when the boss's tree_exited fires: at that point the group is no longer
	# reachable, and a fresh BossSpawner on the next run starts un-suppressed anyway.
	var tree := get_tree()
	if tree == null:
		return
	for spawner in tree.get_nodes_in_group("regular_spawner"):
		if spawner.has_method("set_suppressed"):
			spawner.set_suppressed(suppress, suppression_factor)


func clamp_position_to_arena(pos: Vector2) -> Vector2:
	return Vector2(
		clamp(pos.x, arena_bounds.position.x, arena_bounds.position.x + arena_bounds.size.x),
		clamp(pos.y, arena_bounds.position.y, arena_bounds.position.y + arena_bounds.size.y)
	)
