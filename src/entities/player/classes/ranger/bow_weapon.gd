extends Weapon

## Ranger primary weapon: a Longbow with a 3-shot combo for clearing hordes.
## Combo step 1 fires 3 arrows spread over 45°, step 2 fires 4 over 90°,
## step 3 fires 5 over 135°, then it loops back to step 1.
@export var arrow_scene: PackedScene
@export var damage: int = 18
@export var arrow_speed: float = 540.0
@export var pierce_total: int = 6
## Once the arrow exhausts its pierce it can chain-bounce to another enemy within this range.
@export var chain_range: float = 200.0

# Combo definition: [arrow_count, total_spread_degrees] per step.
const COMBO: Array[Vector2i] = [
	Vector2i(3, 45),
	Vector2i(4, 90),
	Vector2i(5, 135),
]

var combo_step: int = 0


func _ready() -> void:
	weapon_name = "Longbow"
	trigger_type = TriggerType.PRIMARY
	cooldown = 0.65
	super._ready()

func supports_pierce() -> bool:
	return true

func supports_chain() -> bool:
	return true

func supports_projectile_speed() -> bool:
	return true

func supports_range_damage() -> bool:
	return true


func supports_explosion_on_kill() -> bool:
	return false


## Longbow's signature upgrades (granted by the rare golden anvil).
func get_signature_pool() -> Array[Dictionary]:
	return [
		{
			"id": "dancing_arrows",
			"title": "Dancing Arrows",
			"description": "Convert all pierce bonuses to chain. Each chain-hit deals +20% damage.",
			"value": 20,
			"apply": func(_w: Weapon) -> void: pass,
		},
	]


## Under "Dancing Arrows", pierce is traded for chain and each chain won't
## happen — see get_fire payload below. Returns the total pierce to spend.
func _get_dancing_pierce() -> int:
	return get_effective_pierce(pierce_total)


func fire() -> void:
	if arrow_scene == null:
		return

	# Advance the combo: 3 arrows / 45°, 4 / 90°, 5 / 135°, always centered on the cursor.
	var step: Vector2i = COMBO[combo_step]
	combo_step = (combo_step + 1) % COMBO.size()

	var arrow_count: int = step.x
	var total_spread: float = deg_to_rad(float(step.y))

	var base_dir: Vector2 = (get_global_mouse_position() - global_position).normalized()
	if base_dir == Vector2.ZERO:
		base_dir = Vector2.RIGHT

	var arrow_damage: int = get_attack_damage(damage)
	var arrow_is_critical: bool = roll_critical_hit()
	if arrow_is_critical:
		arrow_damage = int(round(float(arrow_damage) * get_critical_multiplier()))

	var total_pierce: int = get_effective_pierce(pierce_total)
	var total_chain: int = get_effective_chain_count(0)
	var eff_chain_range: float = chain_range * get_area_multiplier()
	var eff_speed: float = get_effective_projectile_speed(arrow_speed)

	# Dancing Arrows: pierce is converted into chain, and the arrow ramps +20%
	# damage after each chain-hop.
	var dancing: bool = has_signature("dancing_arrows")
	var dmg_per_chain: int = 0
	if dancing:
		total_chain += total_pierce
		total_pierce = 0
		dmg_per_chain = maxi(1, int(round(float(arrow_damage) * 0.20)))

	for i: int in range(arrow_count):
		var arrow = arrow_scene.instantiate()
		var t: float = float(i) / float(arrow_count - 1) if arrow_count > 1 else 0.5
		var dir: Vector2 = base_dir.rotated(-total_spread * 0.5 + total_spread * t)
		if arrow.has_method("setup"):
			arrow.setup(global_position, dir, eff_speed, arrow_damage, arrow_is_critical, get_player(), total_pierce, total_chain, eff_chain_range, self)
			arrow.set("damage_per_chain", dmg_per_chain)
			arrow.scale *= get_area_multiplier()
		get_tree().current_scene.add_child(arrow)
