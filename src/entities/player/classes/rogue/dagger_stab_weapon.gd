extends Weapon

## Rogue primary weapon: Dual Stab. Each attack makes TWO long, thin thrusts —
## one toward the cursor and one toward the nearest enemy, at the same time
## (dual wielding). Each stab is 1.25x the reach of the knight's finishing stab.

const StabVisual: PackedScene = preload("res://src/effects/sword_slash_visual/sword_slash_visual.tscn")

## Shadowblade (rogue ascension): damage multiplier vs enemies that are bleeding.
const SHADOWBLADE_BLEED_MULT: float = 1.3

@export var damage: int = 20
## 1.25x the knight stab's 100px reach.
@export var reach: float = 125.0
## Half-angle of each stab's thin thrust cone (degrees).
@export var cone_deg: float = 16.0
@export var knockback_force: float = 20.0

## Swiftblade signature: set when a stab crits so the next cooldown is shorter.
var _crit_accel: bool = false


func _ready() -> void:
	weapon_name = "Dual Stab"
	trigger_type = TriggerType.PRIMARY
	cooldown = 0.55
	super._ready()


func supports_area() -> bool:
	return true

func supports_projectile_count() -> bool:
	return true


func get_signature_pool() -> Array[Dictionary]:
	return [
		{
			"id": "swiftblade",
			"title": "Swiftblade",
			"description": "A critical stab shortens your next cooldown — the next hit comes faster.",
			"value": 1,
			"apply": func(_w: Weapon) -> void: pass,
		},
	]


## A critical hit on this swing halves the NEXT cooldown (Swiftblade signature).
func get_effective_cooldown() -> float:
	var cd: float = super.get_effective_cooldown()
	if _crit_accel and has_signature("swiftblade"):
		_crit_accel = false
		cd *= 0.5
	return cd


func fire() -> void:
	_crit_accel = false
	var dmg: int = get_attack_damage(damage)
	var crit: bool = roll_critical_hit()
	if crit:
		dmg = int(round(float(dmg) * get_critical_multiplier()))

	var hit: Dictionary = {}
	var aim: Vector2 = get_global_mouse_position() - global_position
	if aim.length_squared() < 1.0:
		aim = Vector2.RIGHT
	_stab(aim.normalized(), dmg, crit, hit)

	# Dual wield: a second simultaneous stab at the nearest enemy.
	var nearest_dir: Vector2 = _nearest_enemy_dir()
	if nearest_dir != Vector2.ZERO:
		_stab(nearest_dir, dmg, crit, hit)


func _stab(dir: Vector2, dmg: int, crit: bool, hit: Dictionary) -> void:
	var origin: Vector2 = global_position
	var angle: float = dir.angle()
	var half: float = deg_to_rad(cone_deg * 0.5)
	var eff_reach: float = reach * get_area_multiplier()
	var shadowblade: bool = false
	var player := get_player()
	if player != null and player.has_method("is_subclass") and player.is_subclass("shadowblade"):
		shadowblade = true

	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or hit.has(e):
			continue
		var en: Node2D = e as Node2D
		var rel: Vector2 = en.global_position - origin
		var dist: float = rel.length()
		if dist <= eff_reach and absf(angle_difference(angle, rel.angle())) <= half:
			hit[e] = true
			var dealt: int = dmg
			if shadowblade:
				# Bleeding (impaled) enemies take +30% damage from stabs.
				if "impale_pool" in en and float(en.impale_pool) > 0.0:
					dealt = int(round(float(dealt) * SHADOWBLADE_BLEED_MULT))
				if en.has_method("apply_impale"):
					en.apply_impale(float(dealt))
			if crit:
				_crit_accel = true
			en.take_damage(dealt, crit, damage_type, false, get_ailment_effect_multiplier())
			if en.has_method("apply_knockback"):
				en.apply_knockback(origin, get_knockback(knockback_force))
			apply_lifesteal()
			if en.has_method("has_died") and en.has_died():
				apply_explosion_on_kill(en.global_position, dealt)

	# Visual: a thin thrust for this stab.
	var visual: Node2D = StabVisual.instantiate()
	visual.global_position = origin
	visual.rotation = angle
	visual.setup_visual({
		"reach": eff_reach,
		"is_stab": true,
		"color": Color(0.9, 0.55, 0.3, 1),
	})
	get_tree().current_scene.add_child(visual)


func _nearest_enemy_dir() -> Vector2:
	var best: Node2D = null
	var best_d: float = INF
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var en: Node2D = e as Node2D
		var d: float = global_position.distance_squared_to(en.global_position)
		if d < best_d:
			best_d = d
			best = en
	if best == null:
		return Vector2.ZERO
	var dir: Vector2 = best.global_position - global_position
	if dir.length_squared() < 1.0:
		return Vector2.RIGHT
	return dir.normalized()
