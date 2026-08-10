extends Weapon

## Knight primary weapon: a broadsword with a 3-hit combo.
## Hits 1 & 2 are WIDE slashes (the 2nd swings the opposite direction);
## hit 3 is a STAB (the original thin triangle) dealing 1.5x damage.
@export var damage: int = 20
@export var knockback_force: float = 32.0
@export var stab_damage_multiplier: float = 1.5
@export var reach: float = 150.0
@export var slash_widen: float = 40.0

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
	cooldown = 0.5
	super._ready()

	_apply_combo_shape(false, 1)
	slash_area.area_entered.connect(_on_slash_hit)
	slash_area.body_entered.connect(_on_slash_hit)
	slash_area.hide()
	col_poly.disabled = true

func fire() -> void:
	# Advance the combo: 1 slash, 2 reverse-slash, 3 stab, then loop.
	combo_step += 1
	if combo_step > 3:
		combo_step = 1
	var is_stab: bool = (combo_step == 3)
	var reversed: bool = (combo_step == 2)

	_apply_combo_shape(is_stab, 1 if reversed else 1, reversed)

	hit_enemies_this_swing.clear()
	current_attack_damage = get_attack_damage(damage)
	if is_stab:
		current_attack_damage = int(round(float(current_attack_damage) * stab_damage_multiplier))
	current_attack_is_critical = roll_critical_hit()
	if current_attack_is_critical:
		current_attack_damage = int(round(float(current_attack_damage) * get_critical_multiplier()))

	# Snap to player, aim at cursor, reveal collision for a moment.
	slash_area.global_position = global_position
	var angle_to_mouse = global_position.angle_to_point(get_global_mouse_position())
	slash_area.global_rotation = angle_to_mouse
	slash_area.show()
	col_poly.disabled = false

	await get_tree().create_timer(0.1).timeout

	slash_area.hide()
	col_poly.disabled = true

## Builds the visible + collision geometry for the current attack.
## is_stab: thin thrust triangle (original behavior) — flat base at the player,
##   tip reaching `reach` forward. Slashes are wide CONES whose TIP originates
##   from the player, spreading out to the wide base `reach` away.
## reversed: mirror the cone to swing backward (combo step 2).
func _apply_combo_shape(is_stab: bool, _dir: int = 1, reversed: bool = false) -> void:
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
		var w: float = slash_widen * area_mult
		var base: Vector2 = Vector2(reach * area_mult, 0) if not reversed else Vector2(-reach * area_mult, 0)
		pts = PackedVector2Array([
			Vector2.ZERO,                       # tip originates from the player
			base + Vector2(0, -w),              # wide base top corner
			base + Vector2(0, w),               # wide base bottom corner
		])
		draw_poly.color = Color.WHITE
	col_poly.polygon = pts
	draw_poly.polygon = pts

func _on_slash_hit(node: Node) -> void:
	var target = node.get_parent() if node is Area2D else node
	if target and target.is_in_group("enemies") and target.has_method("take_damage"):
		if not hit_enemies_this_swing.has(target):
			hit_enemies_this_swing.append(target)
			target.take_damage(current_attack_damage, current_attack_is_critical)
			if target.has_method("apply_knockback"):
				target.apply_knockback(global_position, knockback_force)
			apply_lifesteal()
