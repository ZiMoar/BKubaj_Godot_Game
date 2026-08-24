class_name DummyRange
extends Node2D

## The "Dummy Range" test room. The whole floor is covered in non-overlapping
## dummy-spawner spots (a grid inside the arena walls, clear of the player spawn
## and the return door). Walk up to any spot and press E (interact) to spawn a
## target dummy exactly there. A door at the top returns to the Armory.

const DUMMY_SPAWNER_SCENE: PackedScene = preload("res://src/environment/test_map/test_dummy_spawner.tscn")

## Grid spacing — larger than a dummy and its spot collision, so spawned dummies
## never overlap each other.
const SPACING: float = 130.0
const MARGIN: float = 100.0
## Clear radius around the player spawn and the return door so they don't sit on
## a spawner spot.
const CLEAR_RADIUS: float = 220.0

@export var player_spawn: Vector2 = Vector2(1100, 820)
@export var door_spawn: Vector2 = Vector2(1100, 70)


func _ready() -> void:
	_build_grid()


func _build_grid() -> void:
	var floor_node := _find_floor_node()
	if floor_node == null:
		return
	var top_left: Vector2 = floor_node.arena_center - floor_node.arena_size * 0.5
	var size: Vector2 = floor_node.arena_size
	var x := top_left.x + MARGIN
	while x <= top_left.x + size.x - MARGIN:
		var y := top_left.y + MARGIN
		while y <= top_left.y + size.y - MARGIN:
			var pos := Vector2(x, y)
			if _is_clear(pos):
				_add_spot(pos)
			y += SPACING
		x += SPACING


func _is_clear(pos: Vector2) -> bool:
	if pos.distance_to(player_spawn) < CLEAR_RADIUS:
		return false
	if pos.distance_to(door_spawn) < CLEAR_RADIUS:
		return false
	return true


func _add_spot(pos: Vector2) -> void:
	var spot: Node2D = DUMMY_SPAWNER_SCENE.instantiate()
	add_child(spot)
	spot.global_position = pos


# Walk up from this node to find the arena "Floor" (GridBackground).
func _find_floor_node() -> GridBackground:
	var node: Node = self
	while node != null:
		var floor_node := node.get_node_or_null("Floor") as GridBackground
		if floor_node != null:
			return floor_node
		node = node.get_parent()
	return null
