class_name BloodMageSubclass
extends SubclassBase

## Mage ascension: during Mana Overload, spells drain your health but deal far
## more damage. Implemented in player.gd (BLOOD_MAGE_DAMAGE_MULT in
## get_attack_damage, drain_overload_cost) + weapon_base.gd (drain per cast) +
## mage_overload_weapon.gd (overload_active flag), gated on
## Player.is_subclass("blood_mage").

func _init() -> void:
	class_id = "blood_mage"
	parent_class_id = "mage"
	display_name = "Blood Mage"
	description = "During Mana Overload, spells drain your health but deal far more damage."
	starting_stats = {
		"lifesteal_flat": 1.5,
	}
