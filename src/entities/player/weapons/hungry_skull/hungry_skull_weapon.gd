extends Weapon

## Hungry Skull — automatic. Sends a slowly homing skull that attaches to an
## enemy and rapidly chews it with NECROTIC damage. If the mob dies before the
## skull's duration ends, it seeks another target. Projectile count raises how
## many skulls each cast sends.

const HungrySkullScene: PackedScene = preload("res://src/entities/projectiles/hungry_skull/hungry_skull.tscn")

const BASE_SKULL_COUNT: int = 1
const BASE_DAMAGE: int = 9
const SKULL_SPEED: float = 120.0
const SKULL_LIFETIME: float = 6.0
const COOLDOWN: float = 3.5


func _ready() -> void:
	weapon_name = "Hungry Skull"
	trigger_type = TriggerType.AUTOMATIC
	cooldown = COOLDOWN
	damage_type = DamageType.Type.NECROTIC
	super._ready()
	call_deferred("try_fire")


func supports_projectile_count() -> bool:
	return true

func supports_duration() -> bool:
	return true


func fire() -> void:
	var count: int = get_effective_projectile_count(BASE_SKULL_COUNT)
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	var dmg: int = get_attack_damage(BASE_DAMAGE)
	var crit: bool = roll_critical_hit()
	if crit:
		dmg = int(round(float(dmg) * get_critical_multiplier()))

	var aim: Vector2 = Vector2.RIGHT
	if not enemies.is_empty():
		var nearest: Node2D = _nearest_enemy(enemies)
		if nearest != null:
			aim = (nearest.global_position - global_position).normalized()

	for i in range(count):
		var skull: Node = HungrySkullScene.instantiate()
		skull.name = "HungrySkull"
		# Offset slightly so multiple skulls don't stack exactly.
		skull.global_position = global_position + Vector2(randf_range(-6, 6), randf_range(-6, 6))
		skull.rotation = aim.angle()
		if skull.has_method("setup"):
			skull.setup(global_position + Vector2(randf_range(-6, 6), randf_range(-6, 6)), dmg, crit, get_player(), self, SKULL_SPEED, get_effective_duration(SKULL_LIFETIME))
		get_tree().current_scene.add_child(skull)


func _nearest_enemy(enemies: Array) -> Node2D:
	var best: Node2D = null
	var best_d: float = INF
	for e: Node in enemies:
		if not is_instance_valid(e):
			continue
		var en: Node2D = e as Node2D
		var d: float = global_position.distance_squared_to(en.global_position)
		if d < best_d:
			best_d = d
			best = en
	return best
