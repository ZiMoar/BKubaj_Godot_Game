class_name WildMageSubclass
extends SubclassBase

## Mage ascension: each cast randomizes that weapon's cooldown between 0.5x and
## 1.2x of its base. Implemented in weapon_base.get_effective_cooldown(), gated
## on Player.is_subclass("wild_mage").

func _init() -> void:
	class_id = "wild_mage"
	parent_class_id = "mage"
	display_name = "Wild Mage"
	description = "Your weapon cooldowns are chaotic, fluctuating between faster and slower than normal."
	starting_stats = {
		"attack_speed_bonus": 0.05,
	}
