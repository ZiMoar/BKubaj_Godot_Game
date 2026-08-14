class_name TestFacilities
extends Node2D

## Test-map placeholder facilities: an infinitely-respawning anvil and weapon box,
## each pinned to a fixed spot. When one is collected it reappears after a short
## cooldown, giving the player a moment to step away before the next one rolls in.

const ANVIL_SCENE: PackedScene = preload("res://src/environment/anvil/anvil.tscn")
const CHEST_SCENE: PackedScene = preload("res://src/environment/treasure_chest/treasure_chest.tscn")

@export var anvil_position: Vector2 = Vector2(-300, 0)
@export var box_position: Vector2 = Vector2(300, 0)
@export var respawn_cooldown: float = 5.0

var _anvil: Node = null
var _box: Node = null
var _anvil_timer: float = 0.0
var _box_timer: float = 0.0
var _anvil_waiting: bool = false
var _box_waiting: bool = false


func _ready() -> void:
	# Defer so we don't add_child while the arena root is still instancing children.
	call_deferred("_spawn_anvil")
	call_deferred("_spawn_box")


func _physics_process(delta: float) -> void:
	# When the anvil/box is gone (collected), start the cooldown then respawn.
	if _anvil_waiting and is_instance_valid(_anvil) == false:
		_anvil_timer -= delta
		if _anvil_timer <= 0.0:
			_anvil_waiting = false
			_spawn_anvil()
	if _box_waiting and not is_instance_valid(_box):
		_box_timer -= delta
		if _box_timer <= 0.0:
			_box_waiting = false
			_spawn_box()


func _spawn_anvil() -> void:
	var anvil: Node = ANVIL_SCENE.instantiate()
	anvil.global_position = global_position + anvil_position
	get_parent().add_child(anvil)
	_anvil = anvil
	_anvil_waiting = true
	_anvil_timer = respawn_cooldown


func _spawn_box() -> void:
	var box: Node = CHEST_SCENE.instantiate()
	box.global_position = global_position + box_position
	get_parent().add_child(box)
	_box = box
	_box_waiting = true
	_box_timer = respawn_cooldown
