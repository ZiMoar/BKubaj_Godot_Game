class_name DevArena
extends Node2D

## DEV-ONLY test arena. Instances a single self-contained room (which owns its
## own floor + enclosed walls) and drops a playable player just inside its door.
## Not part of the shipped game flow — driven by the Dev Main Menu.

## The room scene to place (a Shop / Special Anvil / Relic room). Each room
## exposes get_spawn_point() so the player lands just inside its door.
@export var room_scene: PackedScene
## Starting gold granted to the player so shop purchases can be tested.
@export var start_gold: int = 0
## World position of the room's centre (arena origin by default).
@export var room_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	_spawn_room()
	# Place the player immediately (not deferred) so they never spawn on the
	# room centre and mistakenly trigger the shop/anvil/relic pickup on frame 0.
	_place_player()
	call_deferred("_grant_gold")


func _spawn_room() -> void:
	if room_scene == null:
		return
	var room: Node2D = room_scene.instantiate()
	room.name = "Room"
	add_child(room)
	room.global_position = room_position


## Put the player just inside the room's door (falls back to the room centre).
func _place_player() -> void:
	var player: Node2D = _find_player()
	if player == null:
		return
	var room: Node2D = get_node_or_null("Room") as Node2D
	var spawn: Vector2 = Vector2.ZERO
	if room and room.has_method("get_spawn_point"):
		spawn = room.get_spawn_point()
	player.global_position = room_position + spawn


func _find_player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


func _grant_gold() -> void:
	if start_gold <= 0:
		return
	var player: Node = _find_player()
	if player and player.has_method("add_gold"):
		player.add_gold(start_gold)
