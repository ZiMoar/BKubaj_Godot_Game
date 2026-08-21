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
## Guards against infinite recursion: a cluster sub-charge must NOT spawn its own
## cluster of charges (only the original bomb does). Set true on cluster children.
var is_cluster: bool = false

var _age: float = 0.0
var _exploded: bool = false

# Preloaded so it stays decoupled from the global class cache.
const ExplosionEffectScript: Script = preload("res://src/effects/explosion_effect/explosion_effect.gd")
# Cluster Bomb: same scene reused for the smaller secondary charges.
const ClusterScene: PackedScene = preload("res://src/entities/projectiles/explosive_charge/explosive_charge.tscn")


func setup(pos: Vector2, dmg: int, crit: bool, fuse_len: float, ref_fuse: float, radius_px: float, player: Node, weapon: Node) -> void:
	global_position = pos
	damage = dmg
	is_critical = crit
	fuse = maxf(0.3, fuse_len)
	# max_fuse is the REFERENCE maximum fuse (not the bomb's own fuse). Keeping
	# them distinct lets the blast scale with how short the fuse actually got:
	# charge_mult = lerp(1.0, 2.0, fuse/max_fuse). If max_fuse were just `fuse`
	# the ratio would always be 1.0 and "Shorter Duration" would never weaken
	# the bomb — the exact bug this fixes.
	max_fuse = maxf(0.3, ref_fuse)
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


## Co-op: configure a remote visual-only copy from broadcast data (no weapon/
## player refs on the remote machine). Renders the ticking bomb; on fuse expiry
## it just disappears (no damage, no cluster, no explosion FX).
func setup_visual(data: Dictionary) -> void:
	fuse = maxf(0.3, float(data.get("fuse", 2.0)))
	max_fuse = maxf(0.3, float(data.get("max_fuse", fuse)))
	radius = float(data.get("radius", 90.0))


func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	# Co-op: visual-only copy of a teammate's bomb. Its damage/cluster/FX are all
	# manual (no physics collision), so it would double-hit here on top of the
	# firing player's forwarded damage — it just disappears on fuse expiry.
	if get_meta("visual_copy", false):
		queue_free()
		return
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
			en.take_damage(dmg, is_critical, source_weapon.damage_type if source_weapon != null else DamageType.Type.FIRE, false, source_weapon.get_ailment_effect_multiplier() if source_weapon != null else 1.0)
			if source_player and source_player.has_method("apply_lifesteal"):
				source_player.apply_lifesteal()
			if en.has_method("apply_knockback"):
				en.apply_knockback(origin, 130.0)
			if source_weapon and en.is_in_group("enemies"):
				if en.has_method("has_died") and en.has_died():
					source_weapon.apply_explosion_on_kill(en.global_position, dmg)

	# Cluster Bomb: instead of just expiring, scatter several smaller secondary
	# charges in a ring that detonate a moment later with a reduced blast.
	# Only the ORIGINAL bomb clusters — cluster sub-charges are marked is_cluster
	# so they never recurse into another cluster (which would be infinite).
	if not is_cluster \
			and source_weapon and source_weapon.has_method("has_signature") and source_weapon.has_signature("cluster_bomb") \
			and get_tree() and get_tree().current_scene:
		var cluster_count: int = 4
		var step: float = TAU / float(cluster_count)
		var sub_radius: float = radius * 0.55
		var sub_dmg: int = maxi(1, int(round(float(damage) * 0.45)))
		var sub_fuse: float = 0.35
		for k: int in range(cluster_count):
			var mini_charge: Node = ClusterScene.instantiate()
			mini_charge.name = "ClusterCharge"
			mini_charge.set("is_cluster", true)
			var offset: Vector2 = Vector2.RIGHT.rotated(step * k + _age) * (radius * 0.55)
			var mini_pos: Vector2 = origin + offset
			mini_charge.global_position = mini_pos
			if mini_charge.has_method("setup"):
				mini_charge.setup(mini_pos, sub_dmg, is_critical, sub_fuse, sub_fuse, sub_radius, source_player, source_weapon)
			get_tree().current_scene.add_child(mini_charge)

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
