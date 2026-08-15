class_name SoulPickup
extends Area2D

## A soul dropped by enemies when the Soul Harvest relic is held. Magnetises
## toward the player and, on collection, grants a Shield equal to 5% of the
## player's Max Health (capped at the shield cap).

@export var drift_radius: float = 40.0
@export var drift_speed: float = 25.0

var is_being_collected: bool = false
var target_player: Node2D = null
var fly_speed: float = 180.0

const BASE_RADIUS: float = 4.0
const SOUL_COLOR: Color = Color(0.5, 0.95, 0.8)
const SOUL_EDGE: Color = Color(0.2, 0.6, 0.5)
const SOUL_CAP_PCT: float = 0.05  # 5% of max health per soul

@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("soul_pickups")
	body_entered.connect(_on_body_entered)


func _draw() -> void:
	var r: float = BASE_RADIUS
	draw_circle(Vector2.ZERO, r + 1.5, Color(0.4, 0.95, 0.8, 0.3))
	draw_circle(Vector2.ZERO, r, SOUL_COLOR)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 16, SOUL_EDGE, 1.0)
	draw_circle(Vector2(-r * 0.3, -r * 0.3), r * 0.3, Color(1, 1, 1, 0.85))


func _physics_process(delta: float) -> void:
	if is_being_collected and is_instance_valid(target_player):
		fly_speed += 500.0 * delta
		global_position = global_position.move_toward(target_player.global_position, fly_speed * delta)
		if global_position.distance_to(target_player.global_position) < 14.0:
			_collect()
		return
	# Gentle drift toward the player's area for clustering-adjacent feel.
	if not is_being_collected:
		var pl: Node = get_tree().get_first_node_in_group("player")
		if is_instance_valid(pl) and global_position.distance_to((pl as Node2D).global_position) < drift_radius:
			target_player = pl as Node2D
			start_attraction(target_player)


func start_attraction(player: Node2D) -> void:
	if is_being_collected:
		return
	is_being_collected = true
	target_player = player


func _collect() -> void:
	if target_player:
		if target_player.has_method("roll_pickup_gluttony"):
			target_player.roll_pickup_gluttony()
		if target_player.has_method("add_shield"):
			var shield_amt: float = float(target_player.current_max_health()) * SOUL_CAP_PCT
			target_player.add_shield(shield_amt)
	queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not is_being_collected:
		target_player = body
		_collect()
