class_name DamageType
##########################################################################
## Elemental damage types. Every weapon/projectile reports the type of
## damage it deals; enemies roll "ailment chance" on each hit and inflict the
## ailment matching that damage type (see EnemyBase._apply_ailment).
##
## PHYSICAL is the default for weapons that do not specify an element.
## NECROTIC / HOLY / POISON have no dedicated weapon yet but are declared so the
## framework (and the anvil's damage-type upgrades) are ready for them.
##########################################################################
enum Type {
	PHYSICAL,   # default — impale (stores % of the hit, released on next hit)
	FIRE,       # burn (DoT scaled off the hit)
	LIGHTNING,  # shock (zap a nearby different enemy for 50% of the hit)
	COLD,       # slow
	ARCANE,     # crit vulnerability (more likely to be critically hit)
	NECROTIC,   # decay (enemy deals 20% less damage)
	HOLY,       # brand (enemy takes increased damage from all sources)
	POISON,     # stackable DoT (long duration, slow ticks, < burn magnitude)
}
