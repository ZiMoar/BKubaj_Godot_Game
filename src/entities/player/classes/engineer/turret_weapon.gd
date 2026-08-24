extends Weapon

## Engineer secondary ability: places a Turret that lobs grenades at enemies.
## The turret inherits the Grenade Launcher's anvil stats (damage, area, crit,
## projectile count, explosion-on-kill) — same pattern as Ranger's Rain of
## Arrows inheriting the Longbow — so upgrading the primary weapon also upgrades
## the turret.

const TurretScene: PackedScene = preload("res://src/entities/player/classes/engineer/turret.tscn")
const GrenadeScene: PackedScene = preload("res://src/entities/projectiles/grenade_projectile/grenade_projectile.tscn")

@export var turret_lifetime: float = 6.0
@export var fire_interval: float = 0.9
@export var throw_speed: float = 360.0


func _ready() -> void:
	weapon_name = "Deploy Turret"
	trigger_type = TriggerType.SECONDARY
	cooldown = 6.0
	damage_type = DamageType.Type.FIRE
	super._ready()


func get_signature_pool() -> Array[Dictionary]:
	# This is an ability (secondary), not selectable in the anvil — no signatures.
	return []


## The Grenade Launcher is this ability's upgrade source: the turret reads the
## grenade's stats so anvil upgrades on the primary strengthen the turret too.
func _grenade_weapon() -> Weapon:
	var p = get_player()
	if p == null:
		return null
	var container: Node = p.get_node_or_null("Weapons")
	if container == null:
		return null
	for w: Node in container.get_children():
		if w is Weapon and w != self and w.weapon_name == "Grenade Launcher":
			return w as Weapon
	return null


func fire() -> void:
	var player := get_player()
	if player == null:
		return
	var grenade: Weapon = _grenade_weapon()
	# Place the turret just ahead of the player toward the cursor.
	var to_mouse: Vector2 = get_global_mouse_position() - global_position
	if to_mouse.length_squared() < 1.0:
		to_mouse = Vector2.RIGHT
	var pos: Vector2 = global_position + to_mouse.normalized() * 40.0

	var turret: Node = TurretScene.instantiate()
	turret.name = "Turret"
	turret.global_position = pos
	# The turret fires the SAME grenade projectile, inheriting the grenade's stats.
	var eff_interval: float = fire_interval
	var eff_life: float = turret_lifetime
	if turret.has_method("setup"):
		if grenade:
			# Only the DURATION upgrade changes the turret itself (how long it
			# stays deployed). Everything else the grenade gains — damage, area,
			# crit, projectile count, speed — is applied to the grenades the
			# turret fires, not to the turret.
			eff_interval = maxf(0.15, fire_interval)
			eff_life = grenade.get_effective_duration(turret_lifetime)
		# Sapper (engineer ascension): turret fires 30% faster.
		if player.has_method("is_subclass") and player.is_subclass("sapper"):
			eff_interval = maxf(0.1, eff_interval * 0.7)
		turret.setup(GrenadeScene, eff_interval, eff_life, player, grenade, throw_speed)
	get_tree().current_scene.add_child(turret)
	sync_effect(turret, TurretScene, {"lifetime": eff_life})
