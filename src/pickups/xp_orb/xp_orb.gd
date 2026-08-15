class_name XPOrb
extends Area2D

@export var xp_value: int = 1
@export var tier: int = 1
@export var drift_radius: float = 75.0
@export var drift_speed: float = 35.0

var is_being_collected: bool = false
var target_player: Node2D = null
var fly_speed: float = 200.0
var is_merging: bool = false
var spatial_manager: XPOrbSpatialManager = null
var is_registered_in_spatial_manager: bool = false

# Tier Color Palette (Tier 1 to 5+)
const TIER_COLORS: Array[Color] = [
	Color(0.2, 0.9, 0.3), # Tier 1: Lime Green
	Color(0.2, 0.6, 1.0), # Tier 2: Bright Blue
	Color(0.7, 0.3, 1.0), # Tier 3: Purple
	Color(1.0, 0.8, 0.1), # Tier 4: Gold
	Color(1.0, 0.2, 0.4)  # Tier 5+: Crimson Diamond
]

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("xp_orbs")
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	_try_register_spatial_manager()
	_update_visuals()

func _exit_tree() -> void:
	if is_registered_in_spatial_manager and spatial_manager:
		spatial_manager.unregister_orb(self)
		is_registered_in_spatial_manager = false

func setup(p_value: int, p_tier: int = 1) -> void:
	xp_value = p_value
	tier = p_tier
	_update_visuals()

func _update_visuals() -> void:
	queue_redraw()

func _draw() -> void:
	var color_idx = clamp(tier - 1, 0, TIER_COLORS.size() - 1)
	var orb_color = TIER_COLORS[color_idx]
	
	# Compact micro-orb sizing (Tier 1: 3.0px -> Tier 5: 5.0px)
	var radius = 2.5 + (tier * 0.5)
	
	# Glow / Outer circle
	draw_circle(Vector2.ZERO, radius + 1.5, Color(orb_color.r, orb_color.g, orb_color.b, 0.35))
	# Inner solid orb
	draw_circle(Vector2.ZERO, radius, orb_color)
	# Center highlight point
	draw_circle(Vector2(-radius * 0.3, -radius * 0.3), radius * 0.35, Color(1, 1, 1, 0.8))

func _physics_process(delta: float) -> void:
	_try_register_spatial_manager()

	if is_being_collected and is_instance_valid(target_player):
		fly_speed += 600.0 * delta
		global_position = global_position.move_toward(target_player.global_position, fly_speed * delta)
		_sync_spatial_cell()
		
		if global_position.distance_to(target_player.global_position) < 15.0:
			_collect()
		return

	# Gentle gravitational drift towards nearby same-tier XP Orbs to facilitate merging
	if not is_merging:
		_drift_towards_matching_orbs(delta)
		_sync_spatial_cell()

func _drift_towards_matching_orbs(delta: float) -> void:
	var nearest_orb: XPOrb = null
	var min_dist: float = drift_radius

	if is_registered_in_spatial_manager and spatial_manager:
		nearest_orb = spatial_manager.find_nearest_merge_candidate(self, drift_radius)
		if nearest_orb:
			min_dist = global_position.distance_to(nearest_orb.global_position)
	else:
		for orb in get_tree().get_nodes_in_group("xp_orbs"):
			if orb != self and is_instance_valid(orb) and not orb.is_being_collected and not orb.is_merging and orb.tier == tier:
				var dist = global_position.distance_to(orb.global_position)
				if dist < min_dist:
					min_dist = dist
					nearest_orb = orb
				
	if nearest_orb:
		global_position = global_position.move_toward(nearest_orb.global_position, drift_speed * delta)

func _try_register_spatial_manager() -> void:
	if is_registered_in_spatial_manager:
		return

	if spatial_manager == null:
		spatial_manager = get_tree().get_first_node_in_group("xp_orb_spatial_manager") as XPOrbSpatialManager

	if spatial_manager:
		spatial_manager.register_orb(self)
		is_registered_in_spatial_manager = true

func _sync_spatial_cell() -> void:
	if is_registered_in_spatial_manager and spatial_manager:
		spatial_manager.update_orb_cell(self)

func start_attraction(player: Node2D) -> void:
	if is_being_collected or is_merging:
		return
	is_being_collected = true
	target_player = player

func _collect() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player and player.has_method("roll_pickup_gluttony"):
		player.roll_pickup_gluttony()
	var manager = get_tree().get_first_node_in_group("team_xp_manager") as TeamXPManager
	if manager:
		manager.add_xp(xp_value)
	
	queue_free()

func _on_area_entered(other_area: Area2D) -> void:
	if is_being_collected or is_merging:
		return
		
	if other_area is XPOrb and not other_area.is_being_collected and not other_area.is_merging:
		var other_orb = other_area as XPOrb
		
		if other_orb.tier == tier:
			if get_instance_id() > other_orb.get_instance_id():
				return
				
			_merge_with(other_orb)

func _merge_with(other_orb: XPOrb) -> void:
	other_orb.is_merging = true
	
	tier += 1
	var bonus_xp = max(1, int(ceil(xp_value * 0.5)))
	xp_value = xp_value + other_orb.xp_value + bonus_xp
	
	print("XP Orbs merged! New Tier: ", tier, " | Total XP Value: ", xp_value, " (Bonus +", bonus_xp, ")")
	
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.08)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.08)
	
	_update_visuals()
	other_orb.queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if not is_being_collected:
			target_player = body
		_collect()
