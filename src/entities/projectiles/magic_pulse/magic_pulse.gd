class_name MagicPulseEffect
extends Node2D

## Short-lived cone of arcane energy fired by the Magic Pulse weapon. Immediately
## damages and knocks back every enemy inside the cone on spawn, then plays a
## quick fade-out.

var direction: Vector2 = Vector2.RIGHT
var damage: int = 0
var is_critical: bool = false
var range_px: float = 200.0
var half_angle: float = 0.7  # radians
var knockback: float = 260.0
var source_player: Node = null
var source_weapon: Node = null

var _life: float = 0.28
var _applied: bool = false


func setup(weapon: Node, player: Node, aim_dir: Vector2, dmg: int, crit: bool, rng_px: float, knock: float) -> void:
	source_weapon = weapon
	source_player = player
	direction = aim_dir.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	damage = dmg
	is_critical = crit
	range_px = rng_px
	knockback = knock
	rotation = direction.angle()
	# Pulse damage is applied on the first physics frame, after the node has been
	# parented, so the tree is valid.


func _physics_process(delta: float) -> void:
	if not _applied:
		_applied = true
		_apply_pulse()
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	queue_redraw()


func _apply_pulse() -> void:
	# Co-op: this is a visual-only copy of a teammate's pulse. Its damage is a
	# manual cone check (no physics collision), so it would double-hit here on top
	# of the firing player's forwarded damage — a visual copy never applies it.
	# It still renders the expanding cone and fades out normally.
	if get_meta("visual_copy", false):
		return
	# Vacuum Grasp: pull enemies toward the player instead of knocking away.
	var pull: bool = source_weapon != null and source_weapon.has_method("has_signature") and source_weapon.has_signature("vacuum_grasp")
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for e: Node in enemies:
		if not is_instance_valid(e):
			continue
		var en: Node2D = e as Node2D
		if not _in_cone(en.global_position):
			continue
		en.take_damage(damage, is_critical, source_weapon.damage_type if source_weapon != null else DamageType.Type.ARCANE, false, source_weapon.get_ailment_effect_multiplier() if source_weapon != null else 1.0)
		# Extinguish: instantly pay out all remaining DoT on the enemy as one hit.
		if source_weapon != null and source_weapon.has_method("has_signature") and source_weapon.has_signature("extinguish") and en.has_method("extinguish_dots"):
			var burst: int = en.extinguish_dots()
			if burst > 0:
				en.take_damage(burst, false, source_weapon.damage_type if source_weapon != null else DamageType.Type.ARCANE, false, source_weapon.get_ailment_effect_multiplier() if source_weapon != null else 1.0)
		if source_player and source_player.has_method("apply_lifesteal"):
			source_player.apply_lifesteal()
		if en.has_method("apply_knockback"):
			if pull:
				# Push away from a point on the FAR side of the enemy relative to
				# the player, which shoves it toward the player (a pull).
				var away: Vector2 = (en.global_position - global_position)
				if away.length_squared() < 0.01:
					away = Vector2.RIGHT
				en.apply_knockback(en.global_position + away.normalized(), knockback)
			else:
				en.apply_knockback(global_position, knockback)
		if source_weapon and en.is_in_group("enemies"):
			if en.has_method("has_died") and en.has_died():
				source_weapon.apply_explosion_on_kill(en.global_position, damage)


## Co-op: configure a remote visual-only copy from broadcast data (no weapon/
## player refs available on the remote machine). Renders the cone but never hits.
func setup_visual(data: Dictionary) -> void:
	direction = (data.get("dir", Vector2.RIGHT) as Vector2).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	range_px = float(data.get("rng", 200.0))
	half_angle = float(data.get("half_angle", 0.7))
	rotation = direction.angle()


func _in_cone(target: Vector2) -> bool:
	var to: Vector2 = target - global_position
	var dist: float = to.length()
	if dist > range_px:
		return false
	var ang: float = wrapf(to.angle() - direction.angle(), -PI, PI)
	return absf(ang) <= half_angle


func _draw() -> void:
	var fade: float = clampf(_life / 0.28, 0.0, 1.0)
	var pts := PackedVector2Array()
	pts.append(Vector2.ZERO)
	var steps := 22
	for i in range(steps + 1):
		var a: float = -half_angle + (2.0 * half_angle) * float(i) / float(steps)
		pts.append(Vector2(cos(a), sin(a)) * range_px)
	draw_colored_polygon(pts, Color(0.85, 0.5, 1.0, 0.22 * fade))
	draw_arc(Vector2.ZERO, range_px, -half_angle, half_angle, steps, Color(0.85, 0.55, 1.0, 0.6 * fade), 2.5)
