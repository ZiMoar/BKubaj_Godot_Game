class_name ElementalAnvil
extends "res://src/environment/anvil/anvil.gd"

## Elemental anvil — re-forges a weapon's damage type. Placed by elemental rooms.

func _ready() -> void:
	anvil_kind = 1
	super._ready()
