extends Weapon

## Mage primary weapon: homing Arcane Bolts. Repurposed from the old
## automatic "Magic Bolts" into the Mage's manual (left-click) weapon.
@export var bolt_scene: PackedScene
@export var bolt_count: int = 3
@export var base_damage: int = 14
@export var bolt_speed: float = 340.0


func _ready() -> void:
	weapon_name = "Arcane Bolts"
	trigger_type = TriggerType.PRIMARY
	cooldown = 1.1
	super._ready()


func fire() -> void:
	if bolt_scene == null:
		return

	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return

	# Sort enemies by distance, target the nearest ones
	enemies.sort_custom(_sort_by_distance)

	var bolts_to_fire: int = mini(bolt_count, enemies.size())
	for i: int in range(bolts_to_fire):
		var bolt: Area2D = bolt_scene.instantiate() as Area2D
		get_tree().current_scene.add_child(bolt)

		var target_enemy: Node2D = enemies[i] as Node2D
		var attack_damage: int = get_attack_damage(base_damage)
		var is_crit: bool = roll_critical_hit()
		if is_crit:
			attack_damage = int(round(float(attack_damage) * get_critical_multiplier()))

		if bolt.has_method("setup"):
			bolt.setup(global_position, target_enemy, bolt_speed, attack_damage, is_crit, get_player())


func _sort_by_distance(a: Node, b: Node) -> bool:
	if not is_instance_valid(a) or not is_instance_valid(b):
		return false
	var dist_a: float = global_position.distance_squared_to((a as Node2D).global_position)
	var dist_b: float = global_position.distance_squared_to((b as Node2D).global_position)
	return dist_a < dist_b
