class_name TestFacilities
extends Node2D

## Test-map placeholder facilities: infinitely-respawning pickup slots, each
## pinned to a fixed spot. When one is collected it reappears after a short
## cooldown, giving the player a moment to step away before the next one
## reappears. Slots are laid out in two tidy rows — top = the four anvils,
## bottom = the four pickups — so the central corridor (player spawn <-> dummy)
## stays open.

## Scene path for each slot type.
const SCENES := {
	"anvil": "res://src/environment/anvil/anvil.tscn",
	"golden_anvil": "res://src/environment/anvil/anvil.tscn",
	"elemental_anvil": "res://src/environment/anvil/elemental_anvil.tscn",
	"inverted_anvil": "res://src/environment/anvil/inverted_anvil.tscn",
	"box": "res://src/environment/treasure_chest/treasure_chest.tscn",
	"relic": "res://src/pickups/artefact_pickup/artefact_pickup.tscn",
	"cursed_relic": "res://src/pickups/artefact_pickup/artefact_pickup.tscn",
	"winged_boots": "res://src/pickups/winged_boots/winged_boots.tscn",
}

## slot_id -> position relative to this node. Organized as a 2x4 grid: anvils on
## the top row, pickups on the bottom row, spaced ~240px apart so nothing overlaps.
@export var slots: Dictionary = {
	"elemental_anvil": Vector2(-360, -120),
	"anvil": Vector2(-120, -120),
	"inverted_anvil": Vector2(120, -120),
	"golden_anvil": Vector2(360, -120),
	"relic": Vector2(-360, 120),
	"cursed_relic": Vector2(-120, 120),
	"box": Vector2(120, 120),
	"winged_boots": Vector2(360, 120),
}
@export var respawn_cooldown: float = 2.0

## Hotkey to manually spawn a skeleton just below the player (for testing
## on-kill effects like explosions / Corrosive Burst without waiting on spawners).
const SPAWN_KEY: Key = KEY_K
const SKELETON_SCENE: PackedScene = preload("res://src/entities/enemies/swarmer/skeleton/skeleton_enemy.tscn")

## Test-map altar: spawns the Altar of Ascension pedestal (subclass pick) once so
## the flow can be tested without playing to room 10. Offset places it well LEFT
## of the 2x4 facility grid (which spans world x 740..1460) so it reads as its own
## tidy station at world ~(580, 760) instead of cluttering the pickup row.
const ALTAR_SCENE: PackedScene = preload("res://src/environment/altar_room/altar_pedestal.tscn")
const ALTAR_OFFSET: Vector2 = Vector2(-520, 0)

var _nodes: Dictionary = {}   # slot_id -> live pickup node
var _waiting: Dictionary = {} # slot_id -> bool (collected, waiting to respawn)
var _timers: Dictionary = {}  # slot_id -> float countdown


func _ready() -> void:
	add_to_group("test_facilities")
	# Defer so we don't add_child onto the arena root while it's still instancing
	# its own children (adds to the parent would otherwise be rejected).
	for slot_id: String in slots:
		_nodes[slot_id] = null
		_waiting[slot_id] = false
		_timers[slot_id] = respawn_cooldown
		call_deferred("_spawn_slot", slot_id)
	call_deferred("_spawn_altar")


## Spawns the ascension altar pedestal once at a fixed spot near the player.
func _spawn_altar() -> void:
	var inst: Node = ALTAR_SCENE.instantiate()
	if inst is Node2D:
		(inst as Node2D).global_position = global_position + ALTAR_OFFSET
	get_parent().add_child(inst)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == SPAWN_KEY:
			_manual_spawn_skeleton()
			get_viewport().set_input_as_handled()


## Spawns a basic skeleton just below the player through the existing spawner
## pipeline (so it joins the enemies group and is correctly spawned in co-op).
func _manual_spawn_skeleton() -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var spawn_pos: Vector2 = player.global_position + Vector2(0, 40)
	var spawner: Node = _find_skeleton_spawner()
	if spawner != null:
		spawner.call("spawn_at_position", spawn_pos)
		return
	# No spawner present (e.g. the test map has none) — instantiate directly.
	var enemy: Node = SKELETON_SCENE.instantiate()
	if enemy is Node2D:
		(enemy as Node2D).global_position = spawn_pos
	get_tree().current_scene.add_child(enemy)


func _find_skeleton_spawner() -> Node:
	for s: Node in get_tree().get_nodes_in_group("regular_spawner"):
		if s.name == "SkeletonSpawner":
			return s
		var scene = s.get("enemy_scene")
		if scene != null and scene is PackedScene and scene.resource_path.ends_with("skeleton_enemy.tscn"):
			return s
	return null


func _physics_process(delta: float) -> void:
	# Respawn a slot once its pickup has been collected and the cooldown elapsed.
	for slot_id: String in _waiting.keys():
		if not _waiting[slot_id]:
			continue
		if not is_instance_valid(_nodes.get(slot_id)):
			_timers[slot_id] = float(_timers.get(slot_id, respawn_cooldown)) - delta
			if _timers[slot_id] <= 0.0:
				_waiting[slot_id] = false
				_spawn_slot(slot_id)


## Instantiates a fresh pickup for the given slot at its pinned position.
func _spawn_slot(slot_id: String) -> void:
	var inst: Node = (load(SCENES[slot_id]) as PackedScene).instantiate()
	# Set variant flags BEFORE add_child so _ready()/_set_visual() pick them up.
	if slot_id == "golden_anvil":
		inst.set("is_golden", true)
	elif slot_id == "cursed_relic":
		inst.set("cursed", true)
	inst.global_position = global_position + (slots[slot_id] as Vector2)
	get_parent().add_child(inst)
	_nodes[slot_id] = inst
	_waiting[slot_id] = true
	_timers[slot_id] = respawn_cooldown
