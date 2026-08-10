extends Weapon

## Dagger Fan — automatic. Throws a full ring of daggers outward, giving a
## quick burst of coverage while the weapon's short cooldown recharges.

@export var dagger_scene: PackedScene
@export var dagger_count: int = 8
@export var base_damage: int = 25
@export var dagger_speed: float = 380.0
## Enemies each dagger pierces through (default 3). Can be raised later via a pierce stat.
@export var pierce_count: int = 3


func _ready() -> void:
	weapon_name = "Dagger Fan"
	trigger_type = TriggerType.AUTOMATIC
	cooldown = 1.8
	super._ready()
	call_deferred("try_fire")


func fire() -> void:
	if dagger_scene == null:
		return

	var dmg: int = get_attack_damage(base_damage)
	var crit: bool = roll_critical_hit()
	if crit:
		dmg = int(round(float(dmg) * get_critical_multiplier()))

	# Piercing can be boosted in the future via a player stat/upgrade.
	var total_pierce: int = pierce_count
	var player := get_player()
	if player and player.has_method("get_extra_pierce"):
		total_pierce += int(player.get_extra_pierce())

	# Slight random jitter so consecutive volleys don't overlap perfectly.
	var step: float = TAU / dagger_count
	for i in range(dagger_count):
		var dir: Vector2 = Vector2.RIGHT.rotated(step * i + randf_range(-0.07, 0.07))
		var dagger = dagger_scene.instantiate()
		if dagger == null or not dagger.has_method("setup"):
			continue
		get_tree().current_scene.add_child(dagger)
		dagger.setup(global_position, dir, dagger_speed, dmg, crit, get_player(), total_pierce)
		dagger.scale *= get_area_multiplier()
