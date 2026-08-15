class_name ObstacleSpawner
extends Node2D

## Randomly populates an arena with obstacles on load, replacing the fixed
## preset placements that used to be hard-coded in the arena scenes.
##
## Rules (tuned so obstacles never spam or cluster):
##  - A bounded random count per arena (no flood of obstacles).
##  - A minimum center-to-center spacing so you never get two pillars hugging.
##  - A clear zone around the player spawn so you're never boxed in at start.
##  - A clear zone around the exit door so the path out is never blocked.
##  - Inset from the arena walls so obstacles never clip into them.
##
## The arena is fully ready before this runs (called via _ready), so the Floor
## node (GridBackground) is available to compute the true play bounds for
## whatever map this is placed in (landscape or portrait).

const PILLAR_SCENE: PackedScene = preload("res://src/environment/obstacles/pillar/pillar.tscn")
const CRUMBLE_SCENE: PackedScene = preload("res://src/environment/obstacles/crumbling_pillar/crumbling_pillar.tscn")
const SPIKES_SCENE: PackedScene = preload("res://src/environment/obstacles/spikes/spikes.tscn")

## How many obstacles to attempt placing, chosen per arena.
@export_range(0, 12) var min_obstacles: int = 3
@export_range(0, 12) var max_obstacles: int = 5

## When false, this spawner does nothing. Used to keep a given arena free of
## random obstacles (e.g. the dedicated test map, which holds hand-placed
## hazards instead). game_state.gd detects an existing "ObstacleSpawner" node and
## won't add a second live one.
@export var enabled: bool = true

## Center-to-center spacing so obstacles never touch or form a wall.
@export var min_spacing: float = 150.0
## How far in from the walls obstacles must stay.
@export var wall_inset: float = 90.0
## Keep this radius clear around the player spawn (center of the arena).
@export var player_clearance: float = 200.0
## Keep this radius clear around the exit door (top-center of the arena).
@export var door_clearance: float = 160.0


func _ready() -> void:
	if not enabled:
		return
	# Defer until this frame's tree is fully settled so the arena root, its walls
	# and Floor are all in place and registered.
	call_deferred("_populate")


## Removes any obstacles that were baked into the arena scene at authoring time
## (we now replace fixed presets with random placement), then places a fresh
## random set. Obstacles are identified by group so we clear every type
## (solid / destructible / hazard) without hard-coding their names.
func _populate() -> void:
	var arena: Node2D = get_parent() as Node2D
	if arena == null:
		return

	_clear_preset_obstacles(arena)

	var floor_node: GridBackground = _find_floor(arena)
	if floor_node == null:
		# No floor to measure against — don't scatter randomly.
		return

	var bounds := Rect2(
		floor_node.arena_center - floor_node.arena_size * 0.5,
		floor_node.arena_size
	).grow(-wall_inset)

	var player_spawn := floor_node.arena_center
	var door_pos := Vector2(floor_node.arena_center.x, bounds.position.y)

	var count := randi_range(min_obstacles, max_obstacles)
	var placed: Array[Vector2] = []
	for i in count:
		var pos := _find_valid_position(bounds, player_spawn, door_pos, placed)
		if pos == Vector2.INF:
			continue
		placed.append(pos)
		_spawn_one(arena, pos)


func _clear_preset_obstacles(arena: Node) -> void:
	for child in arena.get_children():
		if child.is_in_group("obstacles") or child.is_in_group("destructibles") or child.is_in_group("hazards"):
			child.queue_free()


func _find_valid_position(bounds: Rect2, player_spawn: Vector2, door_pos: Vector2, placed: Array) -> Vector2:
	# Rejection sampling: keep trying random points until one satisfies all rules.
	for _attempt in 200:
		var p := Vector2(
			randf_range(bounds.position.x, bounds.position.x + bounds.size.x),
			randf_range(bounds.position.y, bounds.position.y + bounds.size.y)
		)
		if p.distance_to(player_spawn) < player_clearance:
			continue
		if p.distance_to(door_pos) < door_clearance:
			continue
		var too_close := false
		for other: Vector2 in placed:
			if p.distance_to(other) < min_spacing:
				too_close = true
				break
		if too_close:
			continue
		return p
	return Vector2.INF


func _spawn_one(arena: Node, pos: Vector2) -> void:
	# Rough weights: 40% solid pillar, 35% destructible crumble, 25% spikes.
	var roll := randf()
	var inst: Node = null
	if roll < 0.4:
		inst = PILLAR_SCENE.instantiate()
	elif roll < 0.75:
		inst = CRUMBLE_SCENE.instantiate()
	else:
		inst = SPIKES_SCENE.instantiate()
	if inst == null:
		return
	arena.add_child(inst)
	(inst as Node2D).global_position = pos


func _find_floor(node: Node) -> GridBackground:
	if node is GridBackground:
		return node as GridBackground
	for child in node.get_children():
		var found := _find_floor(child)
		if found != null:
			return found
	return null
