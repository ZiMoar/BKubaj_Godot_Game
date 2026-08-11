class_name GoldPickup
extends Area2D

## A coin dropped by enemies. Magnetised toward the player; on collection it
## credits gold to the player, applying their Greed / gold artefacts.

@export var gold_value: int = 1

var is_being_collected: bool = false
var target_player: Node2D = null
var fly_speed: float = 180.0

const GOLD_COLOR: Color = Color(1.0, 0.82, 0.2)
const GOLD_EDGE: Color = Color(0.75, 0.55, 0.1)

@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("gold_pickups")
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func setup(value: int) -> void:
	gold_value = max(1, value)
	queue_redraw()


func _draw() -> void:
	# Coin: outer glow, gold body, inner ring, highlight.
	draw_circle(Vector2.ZERO, 6.5, Color(1.0, 0.82, 0.2, 0.35))
	draw_circle(Vector2.ZERO, 5.0, GOLD_COLOR)
	draw_arc(Vector2.ZERO, 5.0, 0.0, TAU, 20, GOLD_EDGE, 1.2)
	draw_arc(Vector2.ZERO, 2.6, 0.0, TAU, 10, Color(1.0, 0.95, 0.6), 1.0)
	draw_circle(Vector2(-1.4, -1.4), 1.0, Color(1, 1, 1, 0.85))


func _physics_process(delta: float) -> void:
	if is_being_collected and is_instance_valid(target_player):
		fly_speed += 500.0 * delta
		global_position = global_position.move_toward(target_player.global_position, fly_speed * delta)
		if global_position.distance_to(target_player.global_position) < 14.0:
			_collect()


func start_attraction(player: Node2D) -> void:
	if is_being_collected:
		return
	is_being_collected = true
	target_player = player


func _collect() -> void:
	if target_player and target_player.has_method("add_gold"):
		var base: int = max(1, gold_value)
		# Midas Bulwark artefact: gold pickups are worth bonus = 20% of Armor.
		if target_player.has_method("has_artefact") and target_player.has_artefact("armor_to_gold"):
			base += int(round(float(target_player.armor) * 0.2))
		target_player.add_gold(base)
	queue_free()


func _on_area_entered(_other_area: Area2D) -> void:
	# Gold does not merge (unlike XP orbs).
	pass


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not is_being_collected:
		target_player = body
		_collect()
