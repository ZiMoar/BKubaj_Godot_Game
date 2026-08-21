extends Weapon

## Engineer primary weapon: a Grenade Launcher. Throws a grenade that flies to the
## cursor and explodes exactly where the player aimed, dealing FIRE damage in an
## area. The Turret shares this weapon's stats (like Ranger's Rain inherits the
## Longbow), so upgrading the grenade also strengthens the turret.

const GrenadeScene: PackedScene = preload("res://src/entities/projectiles/grenade_projectile/grenade_projectile.tscn")

@export var damage: int = 22
@export var blast_radius: float = 80.0
@export var throw_speed: float = 430.0
@export var fuse: float = 0.55


func _ready() -> void:
	weapon_name = "Grenade Launcher"
	trigger_type = TriggerType.PRIMARY
	cooldown = 0.85
	damage_type = DamageType.Type.FIRE
	super._ready()


func supports_projectile_count() -> bool:
	return true

func supports_area() -> bool:
	return true

func supports_projectile_speed() -> bool:
	return true

## Duration upgrades don't change the grenade's flight (it flies to its target),
## but they DO extend the Turret's lifetime — the turret inherits this stat.
func supports_duration() -> bool:
	return true


func get_signature_pool() -> Array[Dictionary]:
	return [
		{
			"id": "dead_center",
			"title": "Dead Center",
			"description": "Enemies take more damage the closer they are to the center of the explosion (up to +50% at ground zero).",
			"value": 1,
			"apply": func(_w: Weapon) -> void: pass,
		},
	]


func fire() -> void:
	var to_mouse: Vector2 = get_global_mouse_position() - global_position
	if to_mouse.length_squared() < 1.0:
		to_mouse = Vector2.RIGHT
	var mouse_dist: float = to_mouse.length()
	var base_dir: Vector2 = to_mouse.normalized()

	var count: int = get_effective_projectile_count(1)
	var dmg: int = get_attack_damage(damage)
	var crit: bool = roll_critical_hit()
	if crit:
		dmg = int(round(float(dmg) * get_critical_multiplier()))

	var spread_deg: float = 12.0
	for i in range(count):
		var t: float = float(i) / float(count - 1) if count > 1 else 0.5
		var dir: Vector2 = base_dir.rotated(deg_to_rad(-spread_deg * 0.5 + spread_deg * t))
		# Each grenade targets the point at the cursor's distance along its own
		# (slightly spread) direction, so it explodes where the player aimed.
		var target: Vector2 = global_position + dir * mouse_dist
		var grenade: Node = GrenadeScene.instantiate()
		grenade.name = "Grenade"
		grenade.global_position = global_position
		if grenade.has_method("setup"):
			grenade.setup(global_position, target, get_effective_projectile_speed(throw_speed), dmg, crit, blast_radius * get_area_multiplier(), get_player(), self)
		get_tree().current_scene.add_child(grenade)
		var net: Node = get_node_or_null("/root/Net")
		if net and net.has_method("sync_player_projectile"):
			net.sync_player_projectile(grenade, GrenadeScene)
