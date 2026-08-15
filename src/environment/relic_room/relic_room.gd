class_name RelicRoom
extends Node2D

## Non-combat RELIC room: a single free relic offering sits in the middle.
## Walk over it to open the Artefact choice menu. Enclosed with proper walls.

func _ready() -> void:
	# Enclose this room with complete visible + physical walls and a door.
	RoomWalls.build(self, Rect2(-240, -150, 480, 300), 24.0, 80.0, "bottom")


## Where a freshly-entered player should stand (just inside the bottom door).
func get_spawn_point() -> Vector2:
	return Vector2(0, 105)


## Where the exit door should sit (near the top wall, inside the room).
func get_exit_point() -> Vector2:
	return Vector2(0, -90)
