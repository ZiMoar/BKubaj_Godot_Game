class_name DummyEnemy
extends EnemyBase

## A stationary target dummy for testing. It sits in place, never moves, never
## attacks, and has enormous HP so the player has an endless target on which to
## test weapons, statuses, and damage numbers. It still shows a HP bar and takes
## damage (and drops XP/gold like a normal enemy) so nothing in the damage chain
## is special-cased.

func _ready() -> void:
	# Bulk up so it survives extended testing; keep it immobile and harmless.
	speed = 0.0
	contact_damage = 0
	separation_radius = 0.0
	separation_strength = 0.0
	max_health = 50000
	super._ready()


## The dummy does not chase or move. Only process status dots so DoT applications
## (burn / bleed / poison) are still visible for testing.
func _physics_process(delta: float) -> void:
	_process_status_dots(delta)
