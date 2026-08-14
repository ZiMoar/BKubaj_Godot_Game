extends Weapon

## Mage primary weapon: Arcane Bolts fired toward the cursor with a random
## spread (up to spread_deg total). Bolts curve gently via weak homing instead
## of acting like auto-aim.
@export var bolt_scene: PackedScene
@export var bolt_count: int = 3
@export var base_damage: int = 14
@export var bolt_speed: float = 340.0
@export var spread_deg: float = 90.0  # total random spread across the volley


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
	var total_spread: float = deg_to_rad(spread_deg)
	for i: int in range(bolts_to_fire):
		var bolt: Area2D = bolt_scene.instantiate() as Area2D
		get_tree().current_scene.add_child(bolt)

		# Random spread up to total_spread, biased negative->positive across
		# the volley so a multi-shot volley fans out instead of doubling up.
		var t: float = 0.0 if bolts_to_fire <= 1 else -total_spread * 0.5 + total_spread * float(i) / float(bolts_to_fire - 1)
		var bolt_dir: Vector2 = aim.rotated(t + randf_range(-12.0, 12.0) * 0.0174533)

		var attack_damage: int = get_attack_damage(base_damage)
		var is_crit: bool = roll_critical_hit()
		if is_crit:
			attack_damage = int(round(float(attack_damage) * get_critical_multiplier()))

		if bolt.has_method("setup"):
			bolt.setup(global_position, bolt_dir, eff_speed, attack_damage, is_crit, get_player(), self)
			bolt.scale *= get_area_multiplier()
