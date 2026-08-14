class_name RangerClass
extends ClassBase

func _ready() -> void:
	class_id = "ranger"
	display_name = "Ranger"
	description = "A piercing Longbow and a Rain of Arrows that blankets a whole area."
	primary_weapon_scene = preload("res://src/entities/player/classes/ranger/bow_weapon.tscn")
	secondary_ability_scene = preload("res://src/entities/player/classes/ranger/ranger_rain_weapon.tscn")
	class_ability_id = "dodge_roll"
	# Starting stats: a mobile kiter — faster and a bit more evasive, lighter HP.
	starting_stats = {
		"max_health": 90,
		"speed": 225.0,
	}