extends Weapon

## Explosive Charge — automatic. Drops a bomb at the player's position that
## explodes with FIRE damage after a fuse. The longer the fuse, the bigger the
## blast. The anvil's "Shorter Duration" upgrade reduces the fuse (quicker but
## weaker booms). Projectile count drops more bombs.

const ExplosiveChargeScene: PackedScene = preload("res://src/entities/projectiles/explosive_charge/explosive_charge.tscn")

const BASE_BOMB_COUNT: int = 1
const BASE_DAMAGE: int = 26
const MAX_FUSE: float = 2.2
const MIN_FUSE: float = 1.0
const BOMB_RADIUS: float = 95.0
const COOLDOWN: float = 3.0


func _ready() -> void:
	weapon_name = "Explosive Charge"
	trigger_type = TriggerType.AUTOMATIC
	cooldown = COOLDOWN
	damage_type = DamageType.Type.FIRE
	super._ready()
	call_deferred("try_fire")


func supports_projectile_count() -> bool:
	return true

func supports_area() -> bool:
	return true

func supports_duration() -> bool:
	return true


## Explosive Charge's signature upgrades (granted by the rare golden anvil).
func get_signature_pool() -> Array[Dictionary]:
	return [
		{
			"id": "cluster_bomb",
			"title": "Cluster Bomb",
			"description": "Bombs split into smaller charges that scatter and detonate moments later.",
			"value": 1,
			"apply": func(_w: Weapon) -> void: pass,
		},
	]


func fire() -> void:
	var count: int = get_effective_projectile_count(BASE_BOMB_COUNT)
	var dmg: int = get_attack_damage(BASE_DAMAGE)
	var crit: bool = roll_critical_hit()
	if crit:
		dmg = int(round(float(dmg) * get_critical_multiplier()))

	for i in range(count):
		# Roll the natural fuse FIRST, then optionally shorten it by the
		# duration bonus. The natural (un-shortened) length is passed through as
		# the bomb's reference max, so the blast scales DOWN when the fuse is
		# shortened by the anvil's "Shorter Duration" upgrade (quicker, weaker
		# booms) and stays at full power for un-upgraded bombs.
		var natural_fuse: float = randf_range(MIN_FUSE, MAX_FUSE)
		var dur_mult: float = (1.0 + duration_bonus)
		var fuse_len: float = maxf(0.3, natural_fuse * dur_mult)

		var bomb: Node = ExplosiveChargeScene.instantiate()
		bomb.name = "ExplosiveCharge"
		bomb.global_position = global_position + Vector2(randf_range(-10, 10), randf_range(-10, 10))
		if bomb.has_method("setup"):
			bomb.setup(bomb.global_position, dmg, crit, fuse_len, natural_fuse, BOMB_RADIUS * get_area_multiplier(), get_player(), self)
		get_tree().current_scene.add_child(bomb)
		var net: Node = get_node_or_null("/root/Net")
		if net and net.has_method("sync_player_effect"):
			net.sync_player_effect(bomb, ExplosiveChargeScene, {"fuse": bomb.get("fuse"), "max_fuse": bomb.get("max_fuse"), "radius": bomb.get("radius")})
