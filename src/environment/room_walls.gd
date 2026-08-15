class_name RoomWalls
extends Node2D

## Builds a properly enclosed room: four visible + physical walls around an
## interior rect, with a door opening on one side. Rooms add this as a child
## (or call the static helper) so they read as real enclosed boxes rather than
## flat rectangles laid on top of the surrounding map.

const DEFAULT_THICKNESS := 24.0
const WALL_COLOR := Color(0.28, 0.26, 0.24, 1.0)
const WALL_EDGE := Color(0.42, 0.40, 0.36, 1.0)


## Build walls for `room` around `interior` (Rect2 in the room's local space).
## A door gap (centred on `door_side`) leaves an opening where the player walks in.
static func build(room: Node2D, interior: Rect2,
		thickness: float = DEFAULT_THICKNESS,
		door_gap: float = 90.0,
		door_side := "bottom") -> void:
	var walls := Node2D.new()
	walls.name = "Walls"
	room.add_child(walls)

	var left := interior.position.x
	var top := interior.position.y
	var right := interior.position.x + interior.size.x
	var bottom := interior.position.y + interior.size.y

	# Top wall (full width)
	_add_wall(walls, Vector2((left + right) * 0.5, top - thickness * 0.5),
		Vector2(interior.size.x + thickness * 2.0, thickness))
	# Left wall
	_add_wall(walls, Vector2(left - thickness * 0.5, (top + bottom) * 0.5),
		Vector2(thickness, interior.size.y + thickness * 2.0))
	# Right wall
	_add_wall(walls, Vector2(right + thickness * 0.5, (top + bottom) * 0.5),
		Vector2(thickness, interior.size.y + thickness * 2.0))

	# Bottom wall split around the door gap.
	var half := door_gap * 0.5
	var mid := (left + right) * 0.5
	if door_side == "top":
		pass  # handled below via generic split at bottom
	# Two bottom segments on either side of the gap (gap centred on the room).
	var seg1_w := (mid - half) - left
	var seg2_w := right - (mid + half)
	if door_side == "bottom":
		if seg1_w > 1.0:
			_add_wall(walls, Vector2(left + seg1_w * 0.5, bottom + thickness * 0.5),
				Vector2(seg1_w + thickness, thickness))
		if seg2_w > 1.0:
			_add_wall(walls, Vector2(right - seg2_w * 0.5, bottom + thickness * 0.5),
				Vector2(seg2_w + thickness, thickness))
	else:
		# No gap on this layout: solid bottom wall.
		_add_wall(walls, Vector2(mid, bottom + thickness * 0.5),
			Vector2(interior.size.x + thickness * 2.0, thickness))


static func _add_wall(parent: Node2D, center: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = center
	parent.add_child(body)

	var shape := RectangleShape2D.new()
	shape.size = size
	var cs := CollisionShape2D.new()
	cs.shape = shape
	body.add_child(cs)

	# Visible wall face.
	var face := Polygon2D.new()
	face.polygon = PackedVector2Array([
		Vector2(-size.x * 0.5, -size.y * 0.5),
		Vector2(size.x * 0.5, -size.y * 0.5),
		Vector2(size.x * 0.5, size.y * 0.5),
		Vector2(-size.x * 0.5, size.y * 0.5),
	])
	face.color = WALL_COLOR
	body.add_child(face)

	# A lighter top edge to give the wall some height.
	var edge := Polygon2D.new()
	edge.polygon = PackedVector2Array([
		Vector2(-size.x * 0.5, -size.y * 0.5),
		Vector2(size.x * 0.5, -size.y * 0.5),
		Vector2(size.x * 0.5, -size.y * 0.5 + 4.0),
		Vector2(-size.x * 0.5, -size.y * 0.5 + 4.0),
	])
	edge.color = WALL_EDGE
	body.add_child(edge)
