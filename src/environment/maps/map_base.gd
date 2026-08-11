class_name MapBase
extends Node

## Base class for a playable map / arena. Each map is its own scene under
## res://src/environment/maps/<id>/. It holds the map's identity and the path to
## its gameplay scene (the arena that actually runs the run).
##
## GameState owns one instantiated instance per map (as children), so the roster
## and the selected map can be read from the map nodes directly. The map choice
## menu builds its buttons from this roster.
##
## This is intentionally simple for now. Later it will grow richer data (thumbnail,
## difficulty curve, enemy compositions, etc.) to drive a graphical dungeon map.

@export var map_id: String = ""
@export var display_name: String = "Map"
@export_multiline var description: String = ""
## The scene that contains the actual arena gameplay (walls, spawners, player).
@export var arena_scene: PackedScene