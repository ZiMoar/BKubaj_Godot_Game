extends Weapon

@export var damage: int = 20
@export var knockback_force: float = 32.0

@onready var slash_area: Area2D = $SlashArea
@onready var col_poly: CollisionPolygon2D = $SlashArea/CollisionPolygon2D
@onready var draw_poly: Polygon2D = $SlashArea/Polygon2D

var hit_enemies_this_swing: Array[Node] = []
var current_attack_damage: int = 0
var current_attack_is_critical: bool = false

func _ready() -> void:
	weapon_name = "Sword Slash"
	trigger_type = TriggerType.SECONDARY
	cooldown = 0.5
	super._ready()
	
	# Create triangle pointing right (0 degrees)
	var triangle_points = PackedVector2Array([
		Vector2(0, -12),
		Vector2(0, 12),
		Vector2(50, 0)
	])
	
	col_poly.polygon = triangle_points
	draw_poly.polygon = triangle_points
	draw_poly.color = Color.WHITE
	
	slash_area.area_entered.connect(_on_slash_hit)
	slash_area.body_entered.connect(_on_slash_hit)
	slash_area.hide()
	col_poly.disabled = true

func fire() -> void:
	hit_enemies_this_swing.clear()
	current_attack_damage = get_attack_damage(damage)
	current_attack_is_critical = roll_critical_hit()
	if current_attack_is_critical:
		current_attack_damage = int(round(float(current_attack_damage) * get_critical_multiplier()))
	
	# 1. Snap SlashArea to exact player position in global space
	slash_area.global_position = global_position
	
	# 2. Aim directly at cursor position in absolute world degrees
	var angle_to_mouse = global_position.angle_to_point(get_global_mouse_position())
	slash_area.global_rotation = angle_to_mouse
	
	# 3. Show & enable collision
	slash_area.show()
	col_poly.disabled = false
	
	await get_tree().create_timer(0.1).timeout
	
	slash_area.hide()
	col_poly.disabled = true

func _on_slash_hit(node: Node) -> void:
	var target = node.get_parent() if node is Area2D else node
	if target and target.is_in_group("enemies") and target.has_method("take_damage"):
		if not hit_enemies_this_swing.has(target):
			hit_enemies_this_swing.append(target)
			target.take_damage(current_attack_damage, current_attack_is_critical)
			if target.has_method("apply_knockback"):
				target.apply_knockback(global_position, knockback_force)
			apply_lifesteal()
