class_name InvertedAnvil
extends "res://src/environment/anvil/anvil.gd"

## Inverted anvil — trades away a weapon stat for a payoff. Placed by inverted/odd rooms.

func _ready() -> void:
	anvil_kind = 2
	super._ready()
