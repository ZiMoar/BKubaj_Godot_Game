class_name EngineerClass
extends ClassBase

func _ready() -> void:
	class_id = "engineer"
	display_name = "Engineer"
	description = "Hurls exploding grenades and drops a turret that lobs the same fire at enemies."
	primary_weapon_scene = preload("res://src/entities/player/classes/engineer/grenade_weapon.tscn")
	secondary_ability_scene = preload("res://src/entities/player/classes/engineer/turret_weapon.tscn")
	class_ability_id = "rocket_jump"
	# Starting stats: a sturdy, mid-range zone controller.
	starting_stats = {
		"max_health": 115,
		"armor": 3.0,
		"speed": 200.0,
	}
