class_name GoldPickup
extends Area2D

## A coin dropped by enemies. Magnetises toward the player and merges with nearby
## coins (like XP orbs), clumping smaller drops into bigger ones. On collection
## it credits gold to the player, applying their Greed / gold artefacts.

@export var gold_value: int = 1
@export var drift_radius: float = 65.0
@export var drift_speed: float = 30.0

var is_being_collected: bool = false
var is_merging: bool = false
var target_player: Node2D = null
var fly_speed: float = 180.0

# Base coin visual radius (drawn). Kept small (~XP orb size) so coins don't cover
# the XP orbs they drop alongside. Merged / high-value coins grow a little.
const BASE_RADIUS: float = 3.5
const MAX_SCALE: float = 1.5

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


# Larger merged coins read as more valuable, but stay close to XP orb scale.
func _coin_scale() -> float:
	return clampf(1.0 + log(float(max(1, gold_value))) * 0.12, 1.0, MAX_SCALE)


func _draw() -> void:
	var s: float = _coin_scale()
	var r: float = BASE_RADIUS * s
	# Outer glow, gold body, edge ring, inner ring, highlight.
	draw_circle(Vector2.ZERO, r + 1.5, Color(1.0, 0.82, 0.2, 0.35))
	draw_circle(Vector2.ZERO, r, GOLD_COLOR)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 20, GOLD_EDGE, 1.0)
	draw_arc(Vector2.ZERO, r * 0.5, 0.0, TAU, 10, Color(1.0, 0.95, 0.6), 0.8)
	draw_circle(Vector2(-r * 0.3, -r * 0.3), r * 0.3, Color(1, 1, 1, 0.85))


func _physics_process(delta: float) -> void:
	if is_being_collected and is_instance_valid(target_player):
		fly_speed += 500.0 * delta
		global_position = global_position.move_toward(target_player.global_position, fly_speed * delta)
		if global_position.distance_to(target_player.global_position) < 14.0:
			_collect()
		return

	# Gentle drift toward nearby coins so drops clump together and merge.
	if not is_merging:
		_drift_towards_nearby_gold(delta)


func _drift_towards_nearby_gold(delta: float) -> void:
	var nearest: GoldPickup = null
	var best: float = drift_radius
	for coin in get_tree().get_nodes_in_group("gold_pickups"):
		if coin == self:
			continue
		if not is_instance_valid(coin) or coin.is_being_collected or coin.is_merging:
			continue
		var d: float = global_position.distance_to(coin.global_position)
		if d < best:
			best = d
			nearest = coin
	if nearest:
		global_position = global_position.move_toward(nearest.global_position, drift_speed * delta)


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


func _on_area_entered(other_area: Area2D) -> void:
	if is_being_collected or is_merging:
		return
	if other_area is GoldPickup:
		var other: GoldPickup = other_area as GoldPickup
		if other.is_being_collected or other.is_merging:
			return
		# Deterministic ordering so both sides don't try to merge simultaneously.
		if get_instance_id() > other.get_instance_id():
			return
		_merge_with(other)


func _merge_with(other: GoldPickup) -> void:
	other.is_merging = true
	gold_value += other.gold_value
	# Bonus so merging is slightly rewarding for clusters of coin drops.
	gold_value += int(floor(float(other.gold_value) * 0.25))
	print("Gold coins merged! Value: ", gold_value)

	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.08)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.08)

	queue_redraw()
	other.queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not is_being_collected:
		target_player = body
		_collect()
