extends Weapon

## Mage primary weapon: Arcane Bolts fired toward the cursor. Bolts fire in a
## sequence, each later bolt allowed a larger random deviation (like a volley
## that spreads further as it repeats). Bolts curve gently via weak homing.
@export var bolt_scene: PackedScene
@export var bolt_count: int = 3  # first bolt + 2 repeats by default
@export var base_damage: int = 14
@export var bolt_speed: float = 260.0  # reduced so homing can correct the curve
## Degrees of max random deviation added per repeat (bolt index beyond the first).
@export var dev_per_repeat_deg: float = 20.0
## Minimum deviation for the very first bolt (aims nearly true but never pixel-perfect).
@export var base_dev_deg: float = 10.0
## Hard cap on a single bolt's allowed deviation.
@export var dev_cap_deg: float = 180.0


func _ready() -> void:
	weapon_name = "Arcane Bolts"
	trigger_type = TriggerType.PRIMARY
	cooldown = 1.1
	super._ready()

func supports_projectile_count() -> bool:
	return true

func supports_projectile_speed() -> bool:
	return true

func supports_range_damage() -> bool:
	return true


func fire() -> void:
	if bolt_scene == null:
		return

	# Aim the volley toward the cursor.
	var aim: Vector2 = (get_global_mouse_position() - global_position).normalized()
	if aim == Vector2.ZERO:
		aim = Vector2.RIGHT

	var bolts_to_fire: int = get_effective_projectile_count(bolt_count)
	var eff_speed: float = get_effective_projectile_speed(bolt_speed)
	for i: int in range(bolts_to_fire):
		var bolt: Area2D = bolt_scene.instantiate() as Area2D
		get_tree().current_scene.add_child(bolt)

		# Sequential deviation: each repeat allows 20 more degrees of random
		# deviation, capped at dev_cap_deg.
		var dev_deg: float = minf(base_dev_deg + float(i) * dev_per_repeat_deg, dev_cap_deg)
		var dev_rad: float = deg_to_rad(dev_deg)
		var bolt_dir: Vector2 = aim.rotated(randf_range(-dev_rad, dev_rad))

		var attack_damage: int = get_attack_damage(base_damage)
		var is_crit: bool = roll_critical_hit()
		if is_crit:
			attack_damage = int(round(float(attack_damage) * get_critical_multiplier()))

		if bolt.has_method("setup"):
			bolt.setup(global_position, bolt_dir, eff_speed, attack_damage, is_crit, get_player(), self)
			bolt.scale *= get_area_multiplier()
