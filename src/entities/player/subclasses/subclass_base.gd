class_name SubclassBase
extends ClassBase

## A subclass ("ascension") picked once per run at the Altar of Ascension
## (room 10). Extends ClassBase so it reuses display_name / description /
## starting_stats, but a subclass grants a PASSIVE rather than weapons.
##
## The passive is two parts:
##   - starting_stats   : static stat overrides applied to the player
##   - _apply_passive() : optional runtime behavior (signal hooks, cooldown
##                        randomization, etc.)
## The player is re-instantiated every arena, so _apply_passive() runs on every
## spawn and must be idempotent / re-hookable (never assume prior state).
##
## Subclass scripts live under res://src/entities/player/subclasses/<class>/.

## The class this subclass belongs to (e.g. "knight"). Only shown/applied when
## the player's class matches.
@export var parent_class_id: String = ""


## Applies this subclass to a player: static stats first, then any dynamic
## passive behavior.
func apply(player: Node) -> void:
	if player == null:
		return
	apply_starting_stats(player)
	_apply_passive(player)


## Override in subclasses that need runtime behavior (connect to player/weapon
## signals, override timings, etc.). Runs on every player spawn.
func _apply_passive(_player: Node) -> void:
	pass
