class_name BossSpawner
extends Event

func _ready() -> void:
	add_to_group("boss_spawner")

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

	_derive_arena_bounds()

	# Co-op: spawn ONE shared, host-authoritative boss. Route through EnemyNet so
	# the HOST spawns it on every machine with position/health synced and client
	# damage forwarded to the host (identical to regular enemies). On a client
	# request_spawn is a no-op (only the host may spawn), so a client never spawns
	# a second, un-synced local boss that would desync room progression.
	var net: Node = get_node_or_null("/root/Net")
	if net != null and net.active():
		var enemy_net: Node = get_tree().get_first_node_in_group("enemy_net")
		if enemy_net and enemy_net.has_method("request_spawn"):
			enemy_net.request_spawn(boss_scene.resource_path, _pick_spawn_position())
		_set_spawner_suppression(true)
		return

	_active_boss = boss_scene.instantiate() as Node2D
	if _active_boss == null:
		return

	get_tree().current_scene.add_child(_active_boss)
	_active_boss.global_position = _pick_spawn_position()

	_active_boss.tree_exited.connect(_on_boss_exited.bind(_active_boss))
	_set_spawner_suppression(true)


## Where the boss appears: near the current player (or arena top-center if none),
## clamped to the arena walls. Shared by the co-op and single-player paths.
func _pick_spawn_position() -> Vector2:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var pos: Vector2 = (player.global_position + spawn_offset) if player else Vector2(960, 300)
	return clamp_position_to_arena(pos)


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

# Derive the safe clamp region from the arena's Floor so the boss stays inside
# the walls on any map (narrow arena included), not just the wide test arena.
func _derive_arena_bounds() -> void:
	var floor_node := _find_floor_node()
	if floor_node == null:
		return
	var margin := 40.0
	arena_bounds = Rect2(
		floor_node.arena_center - floor_node.arena_size * 0.5 + Vector2(margin, margin),
		floor_node.arena_size - Vector2(margin * 2.0, margin * 2.0)
	)

# Walk up from this spawner to the arena root and look for a "Floor" (GridBackground).
func _find_floor_node() -> GridBackground:
	var node: Node = self
	while node != null:
		var floor_node := node.get_node_or_null("Floor") as GridBackground
		if floor_node != null:
			return floor_node
		node = node.get_parent()
	return null
