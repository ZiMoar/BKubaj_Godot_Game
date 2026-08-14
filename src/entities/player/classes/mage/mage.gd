class_name MageClass
extends ClassBase

func _ready() -> void:
	class_id = "mage"
	display_name = "Mage"
	description = "Homing Arcane Bolts and Mana Overload that briefly halves every cooldown."
	primary_weapon_scene = preload("res://src/entities/player/classes/mage/magic_bolts_weapon.tscn")
	secondary_ability_scene = preload("res://src/entities/player/classes/mage/mage_overload_weapon.tscn")
	class_ability_id = "teleport"
	# Starting stats: a fragile artillery caster — lower HP but more damage and area.
	starting_stats = {
		"max_health": 80,
		"might_flat_bonus": 3.0,
		"area_bonus": 0.1,
	}