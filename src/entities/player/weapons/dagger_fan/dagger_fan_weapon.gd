extends Weapon

## Dagger Fan — automatic. Throws a full ring of daggers outward, giving a
## quick burst of coverage while the weapon's short cooldown recharges.

@export var dagger_scene: PackedScene
@export var dagger_count: int = 8
@export var base_damage: int = 44
@export var dagger_speed: float = 380.0
## Enemies each dagger pierces through (default 3). Can be raised later via a pierce stat.
@export var pierce_count: int = 3
## Once a dagger exhausts its pierce it can chain-bounce to another enemy within this range.
@export var chain_range: float = 180.0


func _ready() -> void:
	weapon_name = "Dagger Fan"
	trigger_type = TriggerType.AUTOMATIC
	cooldown = 1.8
	super._ready()
	call_deferred("try_fire")

func supports_projectile_count() -> bool:
	return true

func supports_pierce() -> bool:
	return true

func supports_chain() -> bool:
	return true

func supports_projectile_speed() -> bool:
	return true

func supports_range_damage() -> bool:
	return true


## Dagger Fan's signature upgrades (granted by the rare golden anvil).
func get_signature_pool() -> Array[Dictionary]:
	return [
		{
			"id": "returning_blades",
			"title": "Returning Blades",
			"description": "Daggers return after their flight, hitting enemies again on the way back.",
			"value": 1,
			"apply": func(_w: Weapon) -> void: pass,
		},
		{
			"id": "impaling_blades",
			"title": "Impaling Blades",
			"description": "Your daggers always impale, no matter their element. Physical daggers deal +25% damage.",
			"value": 25,
			"apply": func(_w: Weapon) -> void: pass,
		},
		{
			"id": "splitting_steel",
			"title": "Splitting Steel",
			"description": "Hitting an enemy releases 2 additional daggers at 90 degrees to each side.",
			"value": 1,
			"apply": func(_w: Weapon) -> void: pass,
		},
	]


func fire() -> void:
	if dagger_scene == null:
		return

	var dmg: int = get_attack_damage(base_damage)
	var crit: bool = roll_critical_hit()
	if crit:
		dmg = int(round(float(dmg) * get_critical_multiplier()))

	# Piercing total = weapon base + anvil pierce bonus + global player pierce.
	var total_pierce: int = get_effective_pierce(pierce_count)
	var player := get_player()
	if player and player.has_method("get_extra_pierce"):
		total_pierce += int(player.get_extra_pierce())
	var total_chain: int = get_effective_chain_count(0)
	var eff_chain_range: float = chain_range * get_area_multiplier()

	# Slight random jitter so consecutive volleys don't overlap perfectly.
	var eff_count: int = get_effective_projectile_count(dagger_count)
	var eff_speed: float = get_effective_projectile_speed(dagger_speed)
	var do_return: bool = has_signature("returning_blades")
	var step: float = TAU / eff_count
	for i in range(eff_count):
		var dir: Vector2 = Vector2.RIGHT.rotated(step * i + randf_range(-0.07, 0.07))
		var dagger = dagger_scene.instantiate()
		if dagger == null or not dagger.has_method("setup"):
			continue
		get_tree().current_scene.add_child(dagger)
		dagger.setup(global_position, dir, eff_speed, dmg, crit, get_player(), total_pierce, total_chain, eff_chain_range, self, do_return)
		dagger.scale *= get_area_multiplier()
		var net: Node = get_node_or_null("/root/Net")
		if net and net.has_method("sync_player_projectile"):
			net.sync_player_projectile(dagger, dagger_scene)
