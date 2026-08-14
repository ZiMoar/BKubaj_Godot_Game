class_name KnightClass
extends ClassBase

func _ready() -> void:
	class_id = "knight"
	display_name = "Knight"
	description = "Broad combo slashes that end in a heavy stab, plus a tower shield that blocks projectiles and shoves enemies back."
	primary_weapon_scene = preload("res://src/entities/player/classes/knight/sword_weapon.tscn")
	secondary_ability_scene = preload("res://src/entities/player/classes/knight/knight_shield.tscn")
	class_ability_id = "shield_charge"
	# Starting stats: a tanky front-liner — more HP and a little armor.
	starting_stats = {
		"max_health": 130,
		"armor": 5.0,
	}