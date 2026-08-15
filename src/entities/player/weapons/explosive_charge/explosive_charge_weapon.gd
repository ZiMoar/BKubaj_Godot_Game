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


func fire() -> void:
	var count: int = get_effective_projectile_count(BASE_BOMB_COUNT)
	var dmg: int = get_attack_damage(BASE_DAMAGE)
	var crit: bool = roll_critical_hit()
	if crit:
		dmg = int(round(float(dmg) * get_critical_multiplier()))

	for i in range(count):
		var fuse_len: float = randf_range(MIN_FUSE, MAX_FUSE)
		# Shorter-duration anvil shrinks the fuse range (quicker booms).
		var dur_mult: float = (1.0 + duration_bonus)
		fuse_len = maxf(0.3, fuse_len * dur_mult)

		var bomb: Node = ExplosiveChargeScene.instantiate()
		bomb.name = "ExplosiveCharge"
		bomb.global_position = global_position + Vector2(randf_range(-10, 10), randf_range(-10, 10))
		if bomb.has_method("setup"):
			bomb.setup(bomb.global_position, dmg, crit, fuse_len, BOMB_RADIUS * get_area_multiplier(), get_player(), self)
		get_tree().current_scene.add_child(bomb)
