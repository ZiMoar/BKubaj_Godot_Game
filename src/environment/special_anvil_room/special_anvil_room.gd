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
	_spawn_free_anvil()


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

	if get_tree().current_scene != null:
		get_tree().current_scene.add_child(anvil)
	else:
		add_child(anvil)
	anvil.global_position = global_position
