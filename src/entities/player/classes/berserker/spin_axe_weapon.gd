extends Weapon

## Berserker primary weapon: a huge spinning axe swing around the player. It
## covers 0.75x the Fire Aura's radius and deals DOUBLE damage to enemies hit on
## the outer edge (the outermost 1/8 of the swing) — rewarding players who keep
## enemies at the blade's sweet spot.

@export var damage: int = 30
## 0.75x the Fire Aura's 144px radius.
@export var reach: float = 108.0
## Outer-edge band starts at this fraction of the radius (outer 1/8).
@export var outer_ratio: float = 0.875
@export var outer_damage_mult: float = 2.0
@export var swing_duration: float = 0.18

var _swing_timer: float = 0.0
var _swing_rot: float = 0.0


func _ready() -> void:
	weapon_name = "Spin Axe"
	trigger_type = TriggerType.PRIMARY
	cooldown = 1.0
	super._ready()
	# Slayer (berserker ascension): the outer-edge sweet spot is twice as wide
	# and the cooldown is reduced.
	var p := get_player()
	if p != null and p.has_method("is_subclass") and p.is_subclass("slayer"):
		outer_ratio = 0.75
		cooldown = 0.8
		base_cooldown = 0.8


func supports_area() -> bool:
	return true


func get_signature_pool() -> Array[Dictionary]:
	return [
		{
			"id": "executioner",
			"title": "Executioner",
			"description": "Spin Axe's outer-edge hits gain +40% crit chance.",
			"value": 1,
			"apply": func(_w: Weapon) -> void: pass,
		},
		{
			"id": "bloodthirst",
			"title": "Bloodthirst",
			"description": "An outer-edge hit heals you once per swing.",
			"value": 1,
			"apply": func(_w: Weapon) -> void: pass,
		},
		{
			"id": "twin_throw",
			"title": "Twin Throw",
			"description": "Your Axe Throw hurls a second axe alongside the first.",
			"value": 1,
			"apply": func(_w: Weapon) -> void: pass,
		},
	]


func fire() -> void:
	var origin: Vector2 = global_position
	var base: int = get_attack_damage(damage)

	var eff_reach: float = reach * get_area_multiplier()
	var edge: float = eff_reach * outer_ratio
	var executioner: bool = has_signature("executioner")
	var bloodthirst: bool = has_signature("bloodthirst")
	var bloodthirsted: bool = false

	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var en: Node2D = e as Node2D
		var dist: float = global_position.distance_to(en.global_position)
		if dist <= eff_reach:
			# Outer edge hits for double damage.
			var edge_hit: bool = dist >= edge
			var eff_dmg: int = base if not edge_hit else int(round(float(base) * outer_damage_mult))
			# "Bloodthirst": an outer-edge hit heals the player (once per swing).
			if bloodthirst and edge_hit and not bloodthirsted:
				bloodthirsted = true
				var p: Node = get_player()
				if p != null and p.has_method("heal"):
					p.heal(maxf(1.0, float(eff_dmg) * 0.15))
			# Roll crit per target; Executioner adds +40% crit chance on the edge.
			var c: bool = roll_critical_hit()
			if executioner and edge_hit and randf() < 0.40:
				c = true
			if c:
				eff_dmg = int(round(float(eff_dmg) * get_critical_multiplier()))
			# Close/Far range damage bonuses also apply, scaled by distance.
			eff_dmg = apply_range_damage_multiplier(eff_dmg, dist)
			en.take_damage(eff_dmg, c, damage_type, false, get_ailment_effect_multiplier())
			if en.has_method("apply_knockback"):
				en.apply_knockback(origin, 150.0)
			apply_lifesteal()
			if en.has_method("has_died") and en.has_died():
				apply_explosion_on_kill(en.global_position, eff_dmg)

	# Orient the swing toward the cursor so it feels aimed, not random — the
	# swing's center line points at where the player is aiming.
	var aim: Vector2 = get_global_mouse_position() - global_position
	if aim.length_squared() < 1.0:
		aim = Vector2.RIGHT
	var sweep: float = deg_to_rad(250.0)
	_swing_rot = aim.angle() - sweep * 0.5
	_swing_timer = swing_duration
	queue_redraw()


func _process(delta: float) -> void:
	if _swing_timer > 0.0:
		_swing_timer -= delta
		if _swing_timer <= 0.0:
			queue_redraw()


func _draw() -> void:
	if _swing_timer <= 0.0:
		return
	var r: float = reach * get_area_multiplier()
	var sweep: float = deg_to_rad(250.0)
	var a0: float = _swing_rot
	var fade: float = clampf(_swing_timer / swing_duration, 0.0, 1.0)
	# Main blade sweep.
	draw_arc(Vector2.ZERO, r, a0, a0 + sweep, 44, Color(0.85, 0.6, 0.4, 0.7 * fade), 7.0)
	# Highlight the outer-edge double-damage band.
	draw_arc(Vector2.ZERO, r * outer_ratio, a0, a0 + sweep, 44, Color(1.0, 0.35, 0.2, 0.6 * fade), 2.5)
	# Inner guard circle.
	draw_arc(Vector2.ZERO, r * 0.3, 0.0, TAU, 24, Color(0.7, 0.5, 0.35, 0.4 * fade), 2.0)
