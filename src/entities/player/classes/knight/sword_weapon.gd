extends Weapon

const SwordSlashVisualScene: PackedScene = preload("res://src/effects/sword_slash_visual/sword_slash_visual.tscn")

## Knight primary weapon: a broadsword with a 3-hit combo.
## Hits 1 & 2 are WIDE 100-degree arc slashes that both swing forward;
## hit 3 is a STAB (the original thin triangle) dealing 1.5x damage.
@export var damage: int = 30
@export var knockback_force: float = 32.0
@export var stab_damage_multiplier: float = 1.5
@export var reach: float = 100.0
@export var slash_angle_deg: float = 100.0
@export var slash_arc_segments: int = 16

@onready var slash_area: Area2D = $SlashArea
@onready var col_poly: CollisionPolygon2D = $SlashArea/CollisionPolygon2D
@onready var draw_poly: Polygon2D = $SlashArea/Polygon2D

var hit_enemies_this_swing: Array[Node] = []
var current_attack_damage: int = 0
var current_attack_is_critical: bool = false
var combo_step: int = 0  # 0 = none, 1 = slash, 2 = reverse slash, 3 = stab

func _ready() -> void:
	weapon_name = "Knight Blade"
	trigger_type = TriggerType.PRIMARY
	cooldown = 0.7
	super._ready()

	_apply_combo_shape(false)
	slash_area.area_entered.connect(_on_slash_hit)
	slash_area.body_entered.connect(_on_slash_hit)
	slash_area.hide()
	col_poly.disabled = true

func fire() -> void:
	var fencing: bool = has_signature("fencing")
	var cyclone: bool = has_signature("cyclone")
	# Advance the combo. Fencing stabs on the 2nd hit; otherwise 3rd (unless
	# Cyclone removes the stab entirely — then it's always a swing).
	combo_step += 1
	var is_stab: bool = false
	var stab_mult: float = stab_damage_multiplier
	if fencing:
		if combo_step > 2:
			combo_step = 1
		is_stab = (combo_step == 2)
		stab_mult = 2.0
	elif cyclone:
		if combo_step > 3:
			combo_step = 1
		is_stab = false
	else:
		if combo_step > 3:
			combo_step = 1
		is_stab = (combo_step == 3)

	_apply_combo_shape(is_stab)

	hit_enemies_this_swing.clear()
	current_attack_damage = get_attack_damage(damage)
	if is_stab:
		current_attack_damage = int(round(float(current_attack_damage) * stab_mult))
	current_attack_is_critical = roll_critical_hit()
	if current_attack_is_critical:
		current_attack_damage = int(round(float(current_attack_damage) * get_critical_multiplier()))

	# Snap to player, aim at cursor, reveal collision for a moment.
	slash_area.global_position = global_position
	var angle_to_mouse = global_position.angle_to_point(get_global_mouse_position())
	slash_area.global_rotation = angle_to_mouse
	slash_area.show()
	col_poly.disabled = false

	# Co-op: broadcast a standalone visual of this swing so the other player sees
	# it (their copy of this player's weapon isn't animating). Purely cosmetic.
	sync_effect(slash_area, SwordSlashVisualScene, {
			"reach": reach * get_area_multiplier(),
			"is_stab": is_stab,
			"angle_deg": slash_angle_deg,
			"segments": slash_arc_segments,
			"color": Color(1.0, 0.95, 0.55, 1) if is_stab else Color.WHITE,
		})

	await get_tree().create_timer(0.1).timeout

	slash_area.hide()
	col_poly.disabled = true

## Builds the visible + collision geometry for the current attack.
## is_stab: thin thrust triangle (original behavior) — flat base at the player,
##   tip reaching `reach` forward. Slashes are a WIDE circular SECTOR (arc) of
##   `slash_angle_deg` (~100 degrees) centered on the forward direction, with
##   its tip at the player — both combo slashes swing forward.
func _apply_combo_shape(is_stab: bool) -> void:
	var area_mult: float = get_area_multiplier()
	var pts: PackedVector2Array
	if is_stab:
		pts = PackedVector2Array([
			Vector2(0, -12 * area_mult),
			Vector2(0, 12 * area_mult),
			Vector2(reach * area_mult, 0)
		])
		draw_poly.color = Color(1.0, 0.95, 0.55, 1)  # brighter for the finishing stab
	else:
		# A 100-degree pie-slice sector pointing forward (+X), tip at the player.
		# Cyclone: the swing becomes a full 360-degree circle.
		var r: float = reach * area_mult
		var span: float = TAU if has_signature("cyclone") else deg_to_rad(slash_angle_deg)
		var half: float = span * 0.5
		pts = PackedVector2Array([Vector2.ZERO])
		for i in range(slash_arc_segments + 1):
			var a: float = -half + span * float(i) / float(slash_arc_segments)
			pts.append(Vector2(r * cos(a), r * sin(a)))
		draw_poly.color = Color.WHITE
	col_poly.polygon = pts
	draw_poly.polygon = pts

func supports_explosion_on_kill() -> bool:
	return false


## Sword's signature upgrades (granted by the rare golden anvil).
func get_signature_pool() -> Array[Dictionary]:
	return [
		{
			"id": "defensive_stance",
			"title": "Defensive Stance",
			"description": "Sword hits restore +8% of the Tower Shield's HP.",
			"value": 8,
			"apply": func(_w: Weapon) -> void: pass,
		},
		{
			"id": "cyclone",
			"title": "Cyclone",
			"description": "Your swings become full 360-degree circles, and the finishing stab is replaced by a third full swing.",
			"value": 1,
			"apply": func(_w: Weapon) -> void: pass,
		},
		{
			"id": "fencing",
			"title": "Fencing",
			"description": "The stab comes every 2nd attack instead of the 3rd, and deals 2x damage instead of 1.5x.",
			"value": 2,
			"apply": func(_w: Weapon) -> void: pass,
		},
	]


## Restores a bit of the Tower Shield's HP after a sword hit (Defensive Stance).
func _signature_restore_shield() -> void:
	if not has_signature("defensive_stance"):
		return
	var player: Node = get_player()
	if player == null:
		return
	# Find the Knight's Tower Shield secondary weapon.
	for w: Node in player.get_node_or_null("Weapons").get_children():
		if w is Weapon and w.trigger_type == Weapon.TriggerType.SECONDARY and w.has_method("repair_shield"):
			w.repair_shield(0.08)
			return


func _on_slash_hit(node: Node) -> void:
	var target = node.get_parent() if node is Area2D else node
	if target and (target.is_in_group("enemies") or target.is_in_group("destructibles")) and target.has_method("take_damage"):
		if not hit_enemies_this_swing.has(target):
			hit_enemies_this_swing.append(target)
			target.take_damage(current_attack_damage, current_attack_is_critical, damage_type, false, get_ailment_effect_multiplier())
			# Retaliator (knight ascension): blade strikes also carry thorn damage.
			var p = get_player()
			if p and p.has_method("is_subclass") and p.is_subclass("retaliator") and p.has_method("get_thorns_damage"):
				var th: float = p.get_thorns_damage()
				if th > 0.0:
					target.take_damage(maxi(1, int(round(th))), false, damage_type, false, get_ailment_effect_multiplier())
			if target.has_method("apply_knockback"):
				target.apply_knockback(global_position, get_knockback(knockback_force))
			apply_lifesteal()
			_signature_restore_shield()
			if target.is_in_group("enemies"):
				if target.has_method("has_died") and target.has_died():
					apply_explosion_on_kill(target.global_position, current_attack_damage)
