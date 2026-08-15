class_name RoomArena
extends Node2D

## Run-stage wrapper for a NON-COMBAT room (Shop / Special Anvil / Relic).
##
## Instances a single self-contained room (which owns its own floor + enclosed
## walls), drops a playable player just inside its door, and provides the exit
## StageDoor at the top. Because these rooms have no boss to clear, the exit
## door opens automatically a short moment after the player arrives, so they can
## take the room's services and leave whenever they're ready.

## The room scene to place (a Shop / Special Anvil / Relic room). Each room
## exposes get_spawn_point() and get_exit_point().
@export var room_scene: PackedScene
## Seconds after arrival before the exit door opens. A short grace period so the
## room doesn't look wide open the instant the player spawns.
@export var exit_door_delay: float = 0.8

const STAGE_DOOR_SCENE: PackedScene = preload("res://src/environment/stage_door/stage_door.tscn")

var _door: Area2D = null


func _ready() -> void:
	_spawn_room()
	_place_player()
	_add_exit_door()
	_schedule_door_open()


func _spawn_room() -> void:
	if room_scene == null:
		return
	var room: Node2D = room_scene.instantiate()
	room.name = "Room"
	add_child(room)


## Put the player just inside the room's door (falls back to the room centre).
func _place_player() -> void:
	var player: Node2D = _find_player()
	if player == null:
		return
	var room: Node2D = get_node_or_null("Room") as Node2D
	var spawn: Vector2 = Vector2.ZERO
	if room and room.has_method("get_spawn_point"):
		spawn = room.get_spawn_point()
	player.global_position = spawn


func _get_exit_point() -> Vector2:
	var room: Node2D = get_node_or_null("Room") as Node2D
	if room and room.has_method("get_exit_point"):
		return room.get_exit_point()
	return Vector2(0, -90)


func _add_exit_door() -> void:
	var door: Area2D = STAGE_DOOR_SCENE.instantiate() as Area2D
	door.name = "StageDoor"
	add_child(door)
	door.global_position = _get_exit_point()
	_door = door


func _schedule_door_open() -> void:
	if exit_door_delay <= 0.0:
		_open_door()
		return
	await get_tree().create_timer(exit_door_delay).timeout
	if not is_instance_valid(self):
		return
	_open_door()


func _open_door() -> void:
	if is_instance_valid(_door) and _door.has_method("open_door"):
		_door.open_door()


func _find_player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D
