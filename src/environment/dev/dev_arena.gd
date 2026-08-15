class_name DevArena
extends Node2D

## DEV-ONLY test arena. Instances a single room scene at the arena centre with a
## playable player, HUD and XP managers so a room can be tested in isolation.
## Not part of the shipped game flow — driven by the Dev Main Menu.

## The room scene to drop in the middle (a Shop / Special Anvil / Relic room).
@export var room_scene: PackedScene
## Starting gold granted to the player so shop purchases can be tested.
@export var start_gold: int = 0
## World position where the room is placed (near the player spawn so it is in
## view and walkable).
@export var room_position: Vector2 = Vector2(1000, 820)


func _ready() -> void:
	_spawn_room()
	call_deferred("_grant_gold")


func _spawn_room() -> void:
	if room_scene == null:
		return
	var room: Node2D = room_scene.instantiate()
	add_child(room)
	room.global_position = room_position


func _grant_gold() -> void:
	if start_gold <= 0:
		return
	var player: Node = get_tree().get_first_node_in_group("player")
	if player and player.has_method("add_gold"):
		player.add_gold(start_gold)
