class_name BookProjectile
extends Area2D

@export var damage: int = 14
@export var target_radius: float = 55.0
@export var orbit_speed: float = 4.0
@export var lifetime: float = 6.0
@export var spiral_speed: float = 110.0
@export var hit_cooldown: float = 0.2  # Prevents damaging same enemy every single frame
@export var knockback_force: float = 14.0

var current_radius: float = 0.0
var current_angle: float = 0.0
var center_position: Vector2 = Vector2.ZERO
var is_critical: bool = false
var source_player: Player = null
var source_weapon: Node = null

# Dictionary to track per-enemy hit cooldowns
var recently_hit: Dictionary = {}

func _ready() -> void:
	z_index = 10
	area_entered.connect(_on_touch)
	body_entered.connect(_on_touch)
	
	# Auto-destroy after lifetime expires
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func setup(initial_angle: float, start_pos: Vector2) -> void:
	current_angle = initial_angle
	center_position = start_pos
	global_position = start_pos

func update_orbit(delta: float, current_center: Vector2) -> void:
	center_position = current_center
	
	# 1. Update cooldown timers
	for target in recently_hit.keys():
		recently_hit[target] -= delta
		if recently_hit[target] <= 0:
			recently_hit.erase(target)
	
	# 2. Calculate new orbit coordinates
	if current_radius < target_radius:
		current_radius = move_toward(current_radius, target_radius, spiral_speed * delta)
		
	current_angle += orbit_speed * delta
	var offset = Vector2(cos(current_angle), sin(current_angle)) * current_radius
	
	# 3. Apply position & force Godot physics engine to register the shift
	global_position = center_position + offset
	rotation = current_angle + PI / 2.0
	
	# FORCES GODOT TO INSTANTLY UPDATE PHYSICS COLLISION QUAD-TREE
	force_update_transform()
	_check_overlaps()

func _check_overlaps() -> void:
	# Manually check for overlapping areas & bodies on every frame tick
	for body in get_overlapping_bodies():
		_process_hit(body)
	for area in get_overlapping_areas():
		_process_hit(area)

func _on_touch(node: Node) -> void:
	_process_hit(node)

func _process_hit(node: Node) -> void:
	var target = node.get_parent() if node is Area2D else node
	
	if target and (target.is_in_group("enemies") or target.is_in_group("destructibles")) and target.has_method("take_damage"):
		# Ignore if this enemy was hit recently (prevents 60 hits/sec instakill)
		if recently_hit.has(target):
			return
			
		recently_hit[target] = hit_cooldown
		target.take_damage(damage, is_critical, source_weapon.damage_type if source_weapon != null else DamageType.Type.PHYSICAL, false, source_weapon.get_ailment_effect_multiplier() if source_weapon != null else 1.0)
		if target.has_method("apply_knockback"):
			target.apply_knockback(global_position, source_weapon.get_knockback(knockback_force) if source_weapon != null else knockback_force)
		if source_player and source_player.has_method("apply_lifesteal"):
			source_player.apply_lifesteal()
		if source_weapon and target.is_in_group("enemies"):
			if target.has_method("has_died") and target.has_died():
				source_weapon.apply_explosion_on_kill(global_position, damage)
