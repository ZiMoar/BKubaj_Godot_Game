class_name StormchaserSubclass
extends SubclassBase

## Ranger ascension: increases to movement speed also apply to damage.
## Static baseline below; dynamic speed-to-damage scaling in a later batch.

func _init() -> void:
	class_id = "stormchaser"
	parent_class_id = "ranger"
	display_name = "Stormchaser"
	description = "Movement speed empowers your attacks — the faster you are, the harder you hit."
	starting_stats = {
		"move_speed_percent_bonus": 0.05,
	}


## Passive: increases to movement speed also apply to damage. Marks the player as
## a stormchaser so get_attack_damage() adds the move speed bonus to outgoing
## damage. Runs on every spawn (idempotent).
func _apply_passive(player: Node) -> void:
	if player == null or not player.has_method("set"):
		return
	player.set("stormchaser_active", true)
