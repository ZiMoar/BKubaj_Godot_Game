class_name GrenadeProjectile
extends Node2D

## Grenade launched by the Engineer's main weapon and by its turret. In this
## top-down game it flies straight toward a specific target point and explodes
## exactly there when it arrives, dealing FIRE damage in a radius. Shared between
## the Grenade Launcher and the Turret so both use the exact same projectile.

var damage: int = 20
var is_critical: bool = false
var speed: float = 430.0
var radius: float = 80.0
## World point the grenade flies toward and explodes on arrival.
var target: Vector2 = Vector2.ZERO
var source_player: Node = null
var source_weapon: Node = null

var _age: float = 0.0
var _max_flight: float = 1.0
var _exploded: bool = false

const ExplosionEffectScript: Script = preload("res://src/effects/explosion_effect/explosion_effect.gd")
const FireZoneScript: Script = preload("res://src/effects/fire_zone/fire_zone.gd")


func setup(pos: Vector2, tgt: Vector2, spd: float, dmg: int, crit: bool, r: float, player: Node, weapon: Node) -> void:
	global_position = pos
	target = tgt
	speed = spd
	damage = dmg
	is_critical = crit
	radius = r
	source_player = player
	source_weapon = weapon
	# Safety cap so a mis-targeted grenade can't fly forever; a normal target is
	# always reached well before this.
	var dist: float = (target - global_position).length()
	_max_flight = clampf(dist / maxf(1.0, speed) * 1.6, 0.5, 4.0)


func _physics_process(delta: float) -> void:
	if _exploded:
		return
	_age += delta
	if _age >= _max_flight:
		_explode()
		return
	# Fly straight toward the target point; explode on arrival.
	var to_target: Vector2 = target - global_position
	var dist: float = to_target.length()
	var step: float = speed * delta
	if dist <= step:
		global_position = target
		_explode()
		return
	global_position += to_target / dist * step
	queue_redraw()


func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	# Co-op: visual-only copy of a teammate's grenade. No damage.
	if get_meta("visual_copy", false):
		queue_free()
		return

	var origin: Vector2 = global_position
	var targets: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for d: Node in get_tree().get_nodes_in_group("destructibles"):
		targets.append(d)
	for e: Node in targets:
		if not is_instance_valid(e):
			continue
		var en: Node2D = e as Node2D
		if origin.distance_to(en.global_position) <= radius:
			# Close/Far range damage bonuses scale per-target by its distance from
			# the player (the grenade's source weapon sits on the player).
			var dmg_dealt: int = damage
			if source_weapon != null and source_weapon.has_method("apply_range_damage_multiplier"):
				dmg_dealt = source_weapon.apply_range_damage_multiplier(damage, (source_weapon.global_position - en.global_position).length())
			# "Dead Center" signature: enemies take MORE damage the closer they are
			# to the center of the blast (up to +50% at ground zero).
			if source_weapon != null and source_weapon.has_signature("dead_center"):
				var center_dist: float = origin.distance_to(en.global_position)
				var falloff: float = 1.0 - clampf(center_dist / maxf(1.0, radius), 0.0, 1.0)
				dmg_dealt = maxi(1, int(round(float(dmg_dealt) * (1.0 + 0.5 * falloff))))
			en.take_damage(dmg_dealt, is_critical, source_weapon.damage_type if source_weapon != null else DamageType.Type.FIRE, false, source_weapon.get_ailment_effect_multiplier() if source_weapon != null else 1.0)
			if source_player and source_player.has_method("apply_lifesteal"):
				source_player.apply_lifesteal()
			if en.has_method("apply_knockback"):
				en.apply_knockback(origin, 150.0)
			if source_weapon and en.is_in_group("enemies"):
				if en.has_method("has_died") and en.has_died():
					source_weapon.apply_explosion_on_kill(en.global_position, dmg_dealt)

	# Demolitionist (engineer ascension): leave burning ground at the blast site.
	if source_player and source_player.has_method("is_subclass") and source_player.is_subclass("demolitionist"):
		var zone: Node2D = FireZoneScript.new()
		zone.name = "BurningGround"
		zone.global_position = origin
		zone.set("radius", radius)
		zone.set("duration", 2.5)
		zone.set("dps", float(damage) * 0.35)
		zone.set("source_weapon", source_weapon)
		if source_weapon != null:
			zone.set("damage_type", source_weapon.damage_type)
		get_tree().current_scene.add_child(zone)

	if get_tree() and get_tree().current_scene:
		var fx: Node2D = ExplosionEffectScript.new()
		fx.name = "GrenadeFX"
		fx.global_position = origin
		fx.set("max_radius", radius)
		fx.set("color", Color(1.0, 0.6, 0.2, 0.95))
		get_tree().current_scene.add_child(fx)
	queue_free()


func _draw() -> void:
	# A small dark grenade with a brighter highlight.
	draw_circle(Vector2.ZERO, 5.5, Color(0.16, 0.16, 0.18, 0.95))
	draw_circle(Vector2(-1.5, -1.5), 2.0, Color(0.4, 0.4, 0.45))
	# Fuse nub.
	draw_rect(Rect2(3.0, -5.0, 2.0, 3.0), Color(0.8, 0.7, 0.5))
