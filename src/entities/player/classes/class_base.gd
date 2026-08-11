class_name ClassBase
extends Node

## Base class for a playable class. Each class is its own scene under
## res://src/entities/player/classes/<id>/. It holds the class's identity, its
## starting primary weapon + secondary ability, and any per-class starting stat
## overrides. Extra per-class data can be added here and overridden per subclass.
##
## GameState owns one instantiated instance per class (as children), so the
## roster and the selected class can be read from the class nodes directly.

@export var class_id: String = ""
@export var display_name: String = "Class"
@export_multiline var description: String = ""
@export var primary_weapon_scene: PackedScene
@export var secondary_ability_scene: PackedScene

## Optional per-class starting stat overrides: property name -> value.
## Applied to the Player when a run starts (before HP is computed).
@export var starting_stats: Dictionary = {}


## Applies this class's starting stat overrides onto the player.
## Only touches properties the player already exposes, so adding a new stat to
## the player makes it automatically usable as a per-class starting stat.
func apply_starting_stats(player: Node) -> void:
	if player == null:
		return
	for key: String in starting_stats:
		if key in player:
			player.set(key, starting_stats[key])