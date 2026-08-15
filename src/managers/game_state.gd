extends Node

## Autoload (registered as "GameState") that owns the class roster and the
## currently selected class.
##
## Each class is its own scene under res://src/entities/player/classes/<id>/.
## GameState instantiates one instance of every class scene as a child, so the
## class selection menu and the player can read identity, starting stats, and
## starting weapons straight off the class nodes. Adding a new class = dropping
## a scene in classes/ and registering it below — it then appears in the menu
## automatically.

const KNIGHT_SCENE: PackedScene = preload("res://src/entities/player/classes/knight/knight.tscn")
const RANGER_SCENE: PackedScene = preload("res://src/entities/player/classes/ranger/ranger.tscn")
const MAGE_SCENE: PackedScene = preload("res://src/entities/player/classes/mage/mage.tscn")

const TEST_ARENA_MAP: PackedScene = preload("res://src/environment/maps/test_arena/test_arena.tscn")
const NARROW_ARENA_MAP: PackedScene = preload("res://src/environment/maps/narrow_arena/narrow_arena.tscn")
const TEST_MAP: PackedScene = preload("res://src/environment/maps/test_map/test_map.tscn")

var _classes: Array[ClassBase] = []
var selected_class_id: String = "knight"

var _maps: Array[MapBase] = []
var selected_map_id: String = "test_arena"


func _ready() -> void:
	register_class(KNIGHT_SCENE)
	register_class(RANGER_SCENE)
	register_class(MAGE_SCENE)
	register_map(TEST_ARENA_MAP)
	register_map(NARROW_ARENA_MAP)
	register_map(TEST_MAP)
	_register_class_ability_input()
	_register_interact_input()
	# Apply any saved player keybinds to the live InputMap so every scene (menu
	# or arena) starts with the player's configured bindings.
	KeybindSettings.apply_saved()


## Register the Space-bar class-ability movement input at runtime. Registered in
## code (not project.godot) because the editor reverts external project.godot
## edits, and the player needs this action the moment it enters an arena.
func _register_class_ability_input() -> void:
	if InputMap.has_action("class_ability"):
		return
	InputMap.add_action("class_ability")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_SPACE
	InputMap.action_add_event("class_ability", ev)


## Register the E-key "interact" input, used by shop pedestals / room interactables.
## Registered in code (not project.godot) for the same editor-revert reason.
func _register_interact_input() -> void:
	if InputMap.has_action("interact"):
		return
	InputMap.add_action("interact")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_E
	InputMap.action_add_event("interact", ev)


func register_class(scene: PackedScene) -> void:
	var cls: ClassBase = scene.instantiate()
	add_child(cls)
	_classes.append(cls)


## All registered classes, in registration order (drives menu order).
func get_class_list() -> Array[ClassBase]:
	return _classes


func get_class_by_id(id: String) -> ClassBase:
	for cls: ClassBase in _classes:
		if cls.class_id == id:
			return cls
	return null


func get_selected_class() -> ClassBase:
	return get_class_by_id(selected_class_id)


func set_selected_class(id: String) -> void:
	if get_class_by_id(id) != null:
		selected_class_id = id


func register_map(scene: PackedScene) -> void:
	var map: MapBase = scene.instantiate()
	add_child(map)
	_maps.append(map)


## All registered maps, in registration order (drives menu order).
func get_map_list() -> Array[MapBase]:
	return _maps


func get_map_by_id(id: String) -> MapBase:
	for map: MapBase in _maps:
		if map.map_id == id:
			return map
	return null


func get_selected_map() -> MapBase:
	return get_map_by_id(selected_map_id)


func set_selected_map(id: String) -> void:
	if get_map_by_id(id) != null:
		selected_map_id = id

# ---------------------------------------------------------------------------
# Run-state / stage progression.
# A "run" starts when the player picks a map. Each arena is one stage; finishing
# it (boss dead, room cleared, drops collected) opens a door that advances to the
# alternate arena at a higher minimum difficulty. Because each arena re-instantiates
# the Player, we capture its full progression so the next stage can restore it.
# ---------------------------------------------------------------------------

const TEST_ARENA_PATH: String = "res://src/environment/test_arena.tscn"
const NARROW_ARENA_PATH: String = "res://src/environment/narrow_arena.tscn"
const STAGE_DOOR_SCENE: PackedScene = preload("res://src/environment/stage_door/stage_door.tscn")
const STAGE_CONTROLLER_SCENE: PackedScene = preload("res://src/environment/stage_controller/stage_controller.tscn")
const OBSTACLE_SPAWNER_SCENE: PackedScene = preload("res://src/environment/obstacles/obstacle_spawner/obstacle_spawner.tscn")
const ANVIL_POINTER_SCENE: PackedScene = preload("res://src/ui/pointers/anvil_pointer/anvil_pointer.tscn")
const CHEST_POINTER_SCENE: PackedScene = preload("res://src/ui/pointers/chest_pointer/chest_pointer.tscn")
const MIN_DIFFICULTY_PER_STAGE: float = 2.0

var run_active: bool = false
var stage: int = 1
var min_difficulty: float = 0.0
var current_arena_path: String = ""
var player_snapshot: Dictionary = {}
var xp_snapshot: Dictionary = {}

# Run-stats for the end-of-run summary (kills, duration, difficulty reached).
var run_kills: int = 0
var run_elapsed_seconds: int = 0
var run_difficulty_at_end: float = 0.0
var run_gold_at_end: int = 0
var run_started_at: int = 0  # unix epoch ms when the run began

var _last_arena_scene: Node = null


func _process(_delta: float) -> void:
	# Track elapsed run time for the summary (only while a run is active).
	if run_active:
		run_elapsed_seconds = maxi(0, int((Time.get_ticks_msec() - run_started_at) / 1000.0))
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var scene: Node = tree.current_scene
	if scene == null or scene == _last_arena_scene:
		return
	_last_arena_scene = scene
	call_deferred("_maybe_setup_arena", scene)


func _maybe_setup_arena(scene: Node) -> void:
	if scene == null or not is_instance_valid(scene):
		return
	var floor_node: Node = _find_floor(scene)
	if floor_node == null:
		return
	if scene.get_node_or_null("Player") == null:
		return
	if scene.get_node_or_null("StageDoor") == null:
		_add_stage_door(scene, floor_node)
	if scene.get_node_or_null("StageController") == null:
		_add_stage_controller(scene)
	if scene.get_node_or_null("ObstacleSpawner") == null:
		_add_obstacle_spawner(scene)
	if scene.get_node_or_null("ChestPointer") == null:
		_add_chest_pointer(scene)
	if scene.get_node_or_null("AnvilPointer") == null:
		_add_anvil_pointer(scene)


func _add_stage_door(scene: Node, floor_node: Node) -> void:
	var door: Area2D = STAGE_DOOR_SCENE.instantiate() as Area2D
	door.name = "StageDoor"
	scene.add_child(door)
	var center: Vector2 = floor_node.arena_center
	var size: Vector2 = floor_node.arena_size
	door.global_position = Vector2(center.x, center.y - size.y * 0.5 + 60.0)


func _add_stage_controller(scene: Node) -> void:
	var ctrl: Node = STAGE_CONTROLLER_SCENE.instantiate()
	ctrl.name = "StageController"
	# Set the door path BEFORE adding to the tree: _ready() reads it during
	# add_child, so setting it afterward left _door null and the door never opened.
	ctrl.set("door_path", NodePath("../StageDoor"))
	scene.add_child(ctrl)


func _add_obstacle_spawner(scene: Node) -> void:
	# Randomize the arena's obstacles once per arena by clearing the baked-in
	# presets and letting the spawner place a fresh random set. Added at runtime
	# (like the StageController) so it survives editor reverts of the .tscn.
	var spawner: Node = OBSTACLE_SPAWNER_SCENE.instantiate()
	spawner.name = "ObstacleSpawner"
	scene.add_child(spawner)


func _add_anvil_pointer(scene: Node) -> void:
	var pointer: CanvasLayer = ANVIL_POINTER_SCENE.instantiate() as CanvasLayer
	pointer.name = "AnvilPointer"
	scene.add_child(pointer)


func _add_chest_pointer(scene: Node) -> void:
	var pointer: CanvasLayer = CHEST_POINTER_SCENE.instantiate() as CanvasLayer
	pointer.name = "ChestPointer"
	scene.add_child(pointer)


func _find_floor(node: Node) -> Node:
	if node.get("arena_center") != null and node.get("arena_size") != null:
		return node
	for child in node.get_children():
		var found := _find_floor(child)
		if found != null:
			return found
	return null


## Starts a brand-new run on the given arena. Called from the map choice menu.
func begin_run(arena_path: String) -> void:
	run_active = true
	stage = 1
	min_difficulty = 0.0
	current_arena_path = arena_path
	player_snapshot = {}
	xp_snapshot = {}
	run_kills = 0
	run_elapsed_seconds = 0
	run_difficulty_at_end = 0.0
	run_started_at = Time.get_ticks_msec()


func register_enemy_kill() -> void:
	if run_active:
		run_kills += 1


func set_run_difficulty_at_end(value: float) -> void:
	run_difficulty_at_end = maxf(0.0, value)


func set_run_gold_at_end(value: int) -> void:
	run_gold_at_end = maxi(0, value)


func get_summary_scene_path() -> String:
	return "res://src/ui/run_summary/run_summary.tscn"


func end_run() -> void:
	run_active = false
	player_snapshot = {}
	xp_snapshot = {}


func get_next_arena_path() -> String:
	if current_arena_path.ends_with(NARROW_ARENA_PATH):
		return TEST_ARENA_PATH
	return NARROW_ARENA_PATH


## Captures the player + team-XP state for a loop door that reloads the SAME
## map. Unlike advance_stage it does NOT bump the stage counter or advance to a
## different arena — the character keeps its progression but stays on this map.
func capture_loop_state(player: Node, xp_manager: Node) -> void:
	if player and player.has_method("capture_run_state"):
		var snap: Dictionary = player.capture_run_state()
		if not snap.is_empty():
			player_snapshot = snap
	if xp_manager and xp_manager.has_method("capture_xp_state"):
		xp_snapshot = xp_manager.capture_xp_state()


## Clears the carried-over snapshots for a reset/loop door that reloads the SAME
## map but starts the character FRESH (no auto-weapons, relics, gold, level or
## stat progression). On the fresh map, _setup_class_starting_weapons re-adds
## only the class primary/secondary, so the player can try something new.
func reset_loop_state() -> void:
	player_snapshot = {}
	xp_snapshot = {}


## Captures the player + team-XP state and advances to the next stage.
func advance_stage(player: Node, xp_manager: Node) -> void:
	if player and player.has_method("capture_run_state"):
		var snap: Dictionary = player.capture_run_state()
		if not snap.is_empty():
			player_snapshot = snap
	if xp_manager and xp_manager.has_method("capture_xp_state"):
		xp_snapshot = xp_manager.capture_xp_state()
	stage += 1
	min_difficulty = float(stage - 1) * MIN_DIFFICULTY_PER_STAGE
	current_arena_path = get_next_arena_path()


## Applies the stored snapshot to a freshly-instantiated player + XP manager on
## the new stage's arena. Returns true if a continuation was applied.
func apply_continue(player: Node, xp_manager: Node) -> bool:
	if not run_active:
		return false
	# Note: no `stage <= 1` guard. For a same-map loop door we capture a snapshot
	# with stage still 1, and apply_continue must restore it. At the very start of
	# a run the snapshots are empty, so nothing is restored then anyway.
	var appeared: bool = false
	if not player_snapshot.is_empty() and player and player.has_method("restore_run_state"):
		player.restore_run_state(player_snapshot)
		appeared = true
	if not xp_snapshot.is_empty() and xp_manager and xp_manager.has_method("restore_xp_state"):
		xp_manager.restore_xp_state(xp_snapshot)
	if player and player.has_method("set_min_difficulty"):
		player.set_min_difficulty(min_difficulty)
	return appeared