class_name TestFacilities
extends Node2D

## Test-map placeholder facilities: infinitely-respawning anvil, weapon box, and
## relic spawner — each pinned to a fixed spot. When one is collected it reappears
## after a short cooldown, giving the player a moment to step away before the next
## one rolls in. They sit in a wide triangle around the arena so the central
## corridor (player spawn <-> dummy) stays open.

const ANVIL_SCENE: PackedScene = preload("res://src/environment/anvil/anvil.tscn")
const CHEST_SCENE: PackedScene = preload("res://src/environment/treasure_chest/treasure_chest.tscn")
const RELIC_SCENE: PackedScene = preload("res://src/pickups/artefact_pickup/artefact_pickup.tscn")

@export var anvil_position: Vector2 = Vector2(-280, -100)
@export var box_position: Vector2 = Vector2(280, -100)
@export var relic_position: Vector2 = Vector2(-280, 100)
@export var golden_anvil_position: Vector2 = Vector2(280, 100)
@export var respawn_cooldown: float = 2.0

var _anvil: Node = null
var _box: Node = null
var _relic: Node = null
var _golden_anvil: Node = null
var _anvil_timer: float = 0.0
var _box_timer: float = 0.0
var _relic_timer: float = 0.0
var _golden_anvil_timer: float = 0.0
var _anvil_waiting: bool = false
var _box_waiting: bool = false
var _relic_waiting: bool = false
var _golden_anvil_waiting: bool = false


func _ready() -> void:
	add_to_group("test_facilities")
	# Defer so we don't add_child while the arena root is still instancing children.
	call_deferred("_spawn_anvil")
	call_deferred("_spawn_box")
	call_deferred("_spawn_relic")
	call_deferred("_spawn_golden_anvil")


func _physics_process(delta: float) -> void:
	# When the anvil/box/relic is gone (collected), start the cooldown then respawn.
	if _anvil_waiting and not is_instance_valid(_anvil):
		_anvil_timer -= delta
		if _anvil_timer <= 0.0:
			_anvil_waiting = false
			_spawn_anvil()
	if _box_waiting and not is_instance_valid(_box):
		_box_timer -= delta
		if _box_timer <= 0.0:
			_box_waiting = false
			_spawn_box()
	if _relic_waiting and not is_instance_valid(_relic):
		_relic_timer -= delta
		if _relic_timer <= 0.0:
			_relic_waiting = false
			_spawn_relic()
	if _golden_anvil_waiting and not is_instance_valid(_golden_anvil):
		_golden_anvil_timer -= delta
		if _golden_anvil_timer <= 0.0:
			_golden_anvil_waiting = false
			_spawn_golden_anvil()


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


func _spawn_relic() -> void:
	var relic: Node = RELIC_SCENE.instantiate()
	relic.global_position = global_position + relic_position
	get_parent().add_child(relic)
	_relic = relic
	_relic_waiting = true
	_relic_timer = respawn_cooldown


## Golden anvil: guarantees a signature upgrade in the menu. Must set is_golden
## BEFORE add_child so the visual picks it up in _ready().
func _spawn_golden_anvil() -> void:
	var anvil: Node = ANVIL_SCENE.instantiate()
	anvil.set("is_golden", true)
	anvil.global_position = global_position + golden_anvil_position
	get_parent().add_child(anvil)
	_golden_anvil = anvil
	_golden_anvil_waiting = true
	_golden_anvil_timer = respawn_cooldown
