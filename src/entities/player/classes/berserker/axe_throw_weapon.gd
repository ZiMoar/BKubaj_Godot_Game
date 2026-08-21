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


## The Spin Axe is this weapon's upgrade source: the thrown axe inherits the
## swing's anvil stats (damage, crit, element) so upgrading the primary also
## strengthens the secondary.
func _spin_axe_weapon() -> Weapon:
	var p := get_player()
	if p == null:
		return null
	var container: Node = p.get_node_or_null("Weapons")
	if container == null:
		return null
	for w: Node in container.get_children():
		if w is Weapon and w != self and w.weapon_name == "Spin Axe":
			return w as Weapon
	return null


func fire() -> void:
	var spin: Weapon = _spin_axe_weapon()
	# Delegate damage & crit to the Spin Axe so its anvil upgrades apply here too.
	var dmg: int = (spin.get_attack_damage(damage) if spin else get_attack_damage(damage))
	var crit: bool = (spin.roll_critical_hit() if spin else roll_critical_hit())
	if crit:
		var crit_mult: float = (spin.get_critical_multiplier() if spin else get_critical_multiplier())
		dmg = int(round(float(dmg) * crit_mult))
	# Inherit the Spin Axe's element too, so infusing the swing changes the throw.
	if spin:
		damage_type = spin.damage_type

	var axe: Node = BouncingAxeScene.instantiate()
	axe.name = "BouncingAxe"
	axe.global_position = global_position
	if axe.has_method("setup"):
		axe.setup(global_position, dmg, crit, get_effective_projectile_speed(axe_speed), get_player(), self, get_effective_duration(lifetime))
	get_tree().current_scene.add_child(axe)
	var net: Node = get_node_or_null("/root/Net")
	if net and net.has_method("sync_player_projectile"):
		net.sync_player_projectile(axe, BouncingAxeScene)
