extends Weapon

## Berserker secondary ability: Axe Throw. Hurls an axe that bounces between
## enemies — it flies at the nearest, and on hitting one ricochets to the next
## nearest, endlessly, until its short lifetime runs out.

const BouncingAxeScene: PackedScene = preload("res://src/entities/projectiles/bouncing_axe/bouncing_axe.tscn")

@export var damage: int = 30
@export var axe_speed: float = 620.0
@export var lifetime: float = 3.0


func _ready() -> void:
	weapon_name = "Axe Throw"
	trigger_type = TriggerType.SECONDARY
	cooldown = 4.0
	super._ready()


func supports_projectile_speed() -> bool:
	return true

func supports_duration() -> bool:
	return true


func get_signature_pool() -> Array[Dictionary]:
	return [
		{
			"id": "ricochet",
			"title": "Ricochet",
			"description": "Your axe ricochets to one more enemy on each throw and bounces never lose damage.",
			"value": 1,
			"apply": func(_w: Weapon) -> void: pass,
		},
	]


func fire() -> void:
	var dmg: int = get_attack_damage(damage)
	var crit: bool = roll_critical_hit()
	if crit:
		dmg = int(round(float(dmg) * get_critical_multiplier()))

	var axe: Node = BouncingAxeScene.instantiate()
	axe.name = "BouncingAxe"
	axe.global_position = global_position
	if axe.has_method("setup"):
		axe.setup(global_position, dmg, crit, get_effective_projectile_speed(axe_speed), get_player(), self, get_effective_duration(lifetime))
	get_tree().current_scene.add_child(axe)
	var net: Node = get_node_or_null("/root/Net")
	if net and net.has_method("sync_player_projectile"):
		net.sync_player_projectile(axe, BouncingAxeScene)
