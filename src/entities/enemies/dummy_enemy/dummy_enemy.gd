class_name DummyEnemy
extends EnemyBase

## A stationary target dummy for testing. It sits in place, never moves, never
## attacks, and has enormous HP so the player has an endless target on which to
## test weapons, statuses, and damage numbers. It shows a HP bar and takes
## damage, but can NEVER die — damage numbers, status dots, and the red flash all
## still run through the normal enemy damage chain, so testing stays realistic
## while the dummy remains a permanent, non-leveling target.

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


## The dummy can never die. Death is the single choke-point every damage-based
## kill flows through (both instant hits and status dots), so blocking it here
## makes the dummy a permanent target no matter how much damage the player deals.
## Instead of queue_free + dropping loot, it simply refills its health and stays.
func die() -> void:
	current_health = max_health
	_is_dead = false
	if hp_bar:
		hp_bar.value = current_health
		hp_bar.visible = true
