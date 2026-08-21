class_name ShadowbladeSubclass
extends SubclassBase

## Rogue ascension: your stabs make enemies bleed (impale) and bleeding enemies
## take +30% damage from your stabs. Implemented in dagger_stab_weapon._stab().

func _init() -> void:
	class_id = "shadowblade"
	parent_class_id = "rogue"
	display_name = "Shadowblade"
	description = "Your stabs make enemies bleed. Bleeding enemies take +30% damage from your stabs."
	starting_stats = {
		"critical_hit_chance": 0.10,
	}
