class_name AltarRoom
extends Node2D

## Non-combat ALTAR room (appears at room 10): a single Ascension pedestal in the
## middle. Walk over it to open the Subclass choice menu. Enclosed with walls.

func _ready() -> void:
	RoomWalls.build(self, Rect2(-240, -150, 480, 300), 24.0, 80.0, "bottom")


## Where a freshly-entered player should stand (just inside the bottom door).
func get_spawn_point() -> Vector2:
	return Vector2(0, 105)


## Where the exit door should sit (near the top wall, inside the room).
func get_exit_point() -> Vector2:
	return Vector2(0, -90)
