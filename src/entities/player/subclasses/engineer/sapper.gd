class_name SapperSubclass
extends SubclassBase

## Engineer ascension: your turret fires 30% faster and every 3rd shot is a
## charged double-damage grenade, and you deal +20% damage while a turret is
## deployed. Implemented in turret_weapon.gd, turret.gd and player.gd.

func _init() -> void:
	class_id = "sapper"
	parent_class_id = "engineer"
	display_name = "Sapper"
	description = "Your turret fires 30% faster and every 3rd shot is a charged double-damage grenade. Deal +20% damage while your turret is alive."
	starting_stats = {
		"max_health": 120,
	}
