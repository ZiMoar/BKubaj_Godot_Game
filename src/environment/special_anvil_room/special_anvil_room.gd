class_name SpecialAnvilRoom
extends Node2D

## Non-combat SPECIAL ANVIL room: a single FREE anvil sits in the middle.
## When the room spawns, one variant is rolled (once): 45% Elemental / 45%
## Inverted / 10% Golden.

const ANVIL_SCENE: PackedScene = preload("res://src/environment/anvil/anvil.tscn")
const ELEMENTAL_ANVIL_SCENE: PackedScene = preload("res://src/environment/anvil/elemental_anvil.tscn")
const INVERTED_ANVIL_SCENE: PackedScene = preload("res://src/environment/anvil/inverted_anvil.tscn")

var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	# Enclose this room with complete visible + physical walls and a door.
	RoomWalls.build(self, Rect2(-240, -150, 480, 300), 24.0, 80.0, "bottom")
	_spawn_free_anvil()


## Where a freshly-entered player should stand (just inside the bottom door).
func get_spawn_point() -> Vector2:
	return Vector2(0, 105)


## Where the exit door should sit (near the top wall, inside the room).
func get_exit_point() -> Vector2:
	return Vector2(0, -90)


func _spawn_free_anvil() -> void:
	var roll: float = rng.randf()
	var anvil: Node2D
	# 45% elemental / 45% inverted / 10% golden.
	if roll < 0.45:
		anvil = ELEMENTAL_ANVIL_SCENE.instantiate()
	elif roll < 0.90:
		anvil = INVERTED_ANVIL_SCENE.instantiate()
	else:
		anvil = ANVIL_SCENE.instantiate()
		anvil.set("is_golden", true)

	# Add as a child of the room (which owns the world coordinates), deferred so
	# we never collide with the arena root's own child-setup phase.
	add_child.call_deferred(anvil)
