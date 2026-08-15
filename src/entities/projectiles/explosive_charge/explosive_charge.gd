class_name ExplosiveCharge
extends Node2D

## Bomb dropped by the Explosive Charge weapon. Sits on the ground for a fuse,
## then explodes dealing FIRE damage in a radius. The LONGER the fuse, the bigger
## the explosion (damage scales with fuse length). The fuse can be shortened by
## the anvil's "Shorter Duration" upgrade — quicker but weaker booms.

var damage: int = 20
var is_critical: bool = false
var fuse: float = 2.0
var max_fuse: float = 2.0
var radius: float = 90.0
var source_player: Node = null
var source_weapon: Node = null

var _age: float = 0.0
var _exploded: bool = false

# Preloaded so it stays decoupled from the global class cache.
const ExplosionEffectScript: Script = preload("res://src/effects/explosion_effect/explosion_effect.gd")


func setup(pos: Vector2, dmg: int, crit: bool, fuse_len: float, radius_px: float, player: Node, weapon: Node) -> void:
	global_position = pos
	damage = dmg
	is_critical = crit
	fuse = maxf(0.3, fuse_len)
	max_fuse = fuse
	radius = radius_px
	source_player = player
	source_weapon = weapon


func _physics_process(delta: float) -> void:
	if _exploded:
		return
	_age += delta
	if _age >= fuse:
		_explode()
		return
	queue_redraw()


func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	# Damage scales with how long the fuse was: a longer fuse = a bigger blast.
	# (base 1.0 at the shortest fuse, up to ~2.0x at the full fuse length).
	var charge_mult: float = lerpf(1.0, 2.0, clampf(fuse / max_fuse, 0.0, 1.0))
	var dmg: int = maxi(1, int(round(float(damage) * charge_mult)))

	var origin: Vector2 = global_position
	var targets: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for d: Node in get_tree().get_nodes_in_group("destructibles"):
		targets.append(d)
	for e: Node in targets:
		if not is_instance_valid(e):
			continue
		var en: Node2D = e as Node2D
		if origin.distance_to(en.global_position) <= radius:
			en.take_damage(dmg, is_critical, DamageType.Type.FIRE)
			if source_player and source_player.has_method("apply_lifesteal"):
				source_player.apply_lifesteal()
			if en.has_method("apply_knockback"):
				en.apply_knockback(origin, 130.0)
			if source_weapon and en.is_in_group("enemies"):
				if en.has_method("has_died") and en.has_died():
					source_weapon.apply_explosion_on_kill(en.global_position, dmg)

	if get_tree() and get_tree().current_scene:
		var fx: Node2D = ExplosionEffectScript.new()
		fx.name = "ExplosiveChargeFX"
		fx.global_position = origin
		fx.set("max_radius", radius)
		fx.set("color", Color(1.0, 0.6, 0.2, 0.95))
		get_tree().current_scene.add_child(fx)
	queue_free()


func _draw() -> void:
	# Ticking bomb: dark sphere with a fuse spark that grows brighter.
	var remain: float = maxf(0.0, 1.0 - _age / max_fuse)
	draw_circle(Vector2.ZERO, 7.0, Color(0.12, 0.12, 0.14, 0.95))
	draw_circle(Vector2.ZERO, 4.5, Color(0.25, 0.25, 0.3))
	# Fuse spark.
	var spark: float = 0.5 + 0.5 * sin(_age * 30.0)
	draw_circle(Vector2(4.0, -4.0), 2.0 + remain * 2.0, Color(1.0, 0.5 + spark * 0.4, 0.2, 0.9))
