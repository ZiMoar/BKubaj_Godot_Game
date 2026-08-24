class_name BerserkerClass
extends ClassBase

func _ready() -> void:
	class_id = "berserker"
	display_name = "Berserker"
	description = "A giant spinning axe that wrecks the outer edge, a bouncing axe throw, and a whirlwind dash."
	primary_weapon_scene = preload("res://src/entities/player/classes/berserker/spin_axe_weapon.tscn")
	secondary_ability_scene = preload("res://src/entities/player/classes/berserker/axe_throw_weapon.tscn")
	class_ability_id = "spin_dash"
	# Starting stats: a bruiser — beefy and strong, but slower.
	starting_stats = {
		"max_health": 130,
		"speed": 185.0,
		"might_percent_bonus": 0.1,
	}
