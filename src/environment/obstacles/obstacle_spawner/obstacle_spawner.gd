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
@export_range(0, 16) var min_obstacles: int = 10
@export_range(0, 16) var max_obstacles: int = 10

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


## Authoritative obstacle layout (host only): list of {"scene", "pos"} dicts.
var _layout: Array = []
## Client peer ids that asked for the layout before the host had generated it.
var _pending_requests: Array = []


func _ready() -> void:
	if not enabled:
		return
	# Defer until this frame's tree is fully settled so the arena root, its walls
	# and Floor are all in place and registered.
	call_deferred("_setup")


func _setup() -> void:
	if _is_network_client():
		# Co-op: the HOST owns the layout (its RNG). Ask it for the authoritative
		# obstacle placement instead of scattering our own random set — otherwise
		# the two machines would build DIFFERENT obstacle layouts and collide with
		# different things. Do NOT self-populate.
		request_obstacle_layout.rpc_id(1)
		return
	# Host or single-player: generate the layout and apply it locally.
	_generate_and_apply()


func _generate_and_apply() -> void:
	var arena: Node2D = get_parent() as Node2D
	if arena == null:
		return
	var floor_node: GridBackground = _find_floor(arena)
	if floor_node == null:
		# No floor to measure against — don't scatter randomly.
		return
	var layout := _generate_layout(arena, floor_node)
	_layout = layout
	_apply_layout(arena, layout)
	# Clients that asked before we finished generating can now be answered.
	for id: int in _pending_requests:
		sync_obstacles.rpc_id(id, layout)
	_pending_requests.clear()


## Generates the obstacle placement (host-only RNG). Returns a list of dicts
## {"scene": resource_path, "pos": Vector2}.
func _generate_layout(arena: Node2D, floor_node: GridBackground) -> Array:
	var bounds := Rect2(
		floor_node.arena_center - floor_node.arena_size * 0.5,
		floor_node.arena_size
	).grow(-wall_inset)

	var player_spawn := floor_node.arena_center
	var door_pos := Vector2(floor_node.arena_center.x, bounds.position.y)

	var count := randi_range(min_obstacles, max_obstacles)
	var layout: Array = []
	var placed: Array[Vector2] = []
	for i in count:
		var pos := _find_valid_position(bounds, player_spawn, door_pos, placed)
		if pos == Vector2.INF:
			continue
		placed.append(pos)
		# Rough weights: 40% solid pillar, 35% destructible crumble, 25% spikes.
		var roll := randf()
		var scene_path: String = PILLAR_SCENE.resource_path
		if roll >= 0.4 and roll < 0.75:
			scene_path = CRUMBLE_SCENE.resource_path
		elif roll >= 0.75:
			scene_path = SPIKES_SCENE.resource_path
		layout.append({"scene": scene_path, "pos": pos})
	return layout


## Clears baked presets and places the given obstacle layout. Shared by the host
## (its own generated layout) and clients (the layout received from the host).
func _apply_layout(arena: Node2D, layout: Array) -> void:
	if arena == null:
		return
	# Removes any obstacles baked into the arena scene at authoring time (we now
	# replace fixed presets with the shared placement). Obstacles are identified
	# by group so we clear every type (solid / destructible / hazard).
	_clear_preset_obstacles(arena)
	for entry: Dictionary in layout:
		var scn: PackedScene = load(str(entry["scene"]))
		if scn == null:
			continue
		var inst: Node = scn.instantiate()
		if inst == null:
			continue
		arena.add_child(inst)
		(inst as Node2D).global_position = entry["pos"]


## Client -> host: this machine is ready and needs the authoritative obstacle
## layout. The host answers with sync_obstacles (or queues us if it hasn't
## generated its layout yet).
@rpc("any_peer", "reliable")
func request_obstacle_layout() -> void:
	if not multiplayer.is_server():
		return
	var from: int = multiplayer.get_remote_sender_id()
	if _layout.is_empty():
		_pending_requests.append(from)
	else:
		sync_obstacles.rpc_id(from, _layout)


## Host -> a client: the authoritative obstacle layout for this arena.
@rpc("authority", "reliable")
func sync_obstacles(layout: Array) -> void:
	if multiplayer.is_server():
		return  # host already applied its own layout
	_apply_layout(get_parent() as Node2D, layout)


func _is_network_client() -> bool:
	var net: Node = get_node_or_null("/root/Net")
	if net == null or not net.active():
		return false
	return not multiplayer.is_server()


func _clear_preset_obstacles(arena: Node) -> void:
	for child in arena.get_children():
		# Identify baked presets by group (legacy) or by obstacle class, since the
		# pillar/crumble/spike scenes don't declare groups. Replaces fixed presets
		# with the fresh random set so an arena never doubles up its obstacles.
		if child.is_in_group("obstacles") or child.is_in_group("destructibles") or child.is_in_group("hazards") \
				or child is Pillar or child is CrumblingPillar or child is Spikes:
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


func _find_floor(node: Node) -> GridBackground:
	if node is GridBackground:
		return node as GridBackground
	for child in node.get_children():
		var found := _find_floor(child)
		if found != null:
			return found
	return null
