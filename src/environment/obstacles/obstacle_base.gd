class_name ObstacleBase
extends StaticBody2D

## Indestructible map obstacle. Sits on physics layer 1 (World) so both the
## player and enemies collide with it and must route around it. Subclasses set
## the visual and exact collision shape. Unlike the arena edge walls, these are
## free-standing interior obstacles.

func _ready() -> void:
	add_to_group("obstacles")
	collision_layer = 1  # World/Environment — blocks player and enemies.

# Static body never moves, so it does not need a collision mask.
func _draw() -> void:
	pass
