class_name RogueClass
extends ClassBase

func _ready() -> void:
	class_id = "rogue"
	display_name = "Rogue"
	description = "Dual-wielded long stabs, a smoke bomb that pushes dodge chance to the limit, and an invisibility dash."
	primary_weapon_scene = preload("res://src/entities/player/classes/rogue/dagger_stab_weapon.tscn")
	secondary_ability_scene = preload("res://src/entities/player/classes/rogue/smoke_bomb_weapon.tscn")
	class_ability_id = "invisibility"
	# Starting stats: a nimble duelist — quick, evasive, lighter HP.
	starting_stats = {
		"max_health": 95,
		"speed": 230.0,
		"evasion_chance": 12.0,
	}
