class_name MagnetPickup
extends Area2D

## Magnet pickup. Collecting it performs an all-screen "grab" just like the
## room-end sweep: every XP orb and gold coin still on the floor flies to the
## player. Dropped by Loot Pots in place of gold.

var _collected: bool = false

const STEEL: Color = Color(0.42, 0.62, 0.95)
const POLE_N: Color = Color(0.9, 0.28, 0.28)   # red
const POLE_S: Color = Color(0.28, 0.4, 0.98)   # blue
const GLOW: Color = Color(0.4, 0.7, 1.0)


func _ready() -> void:
	add_to_group("pickups")
	body_entered.connect(_on_body_entered)
	# Pulse so it clearly reads as a pickup.
	var tween: Tween = create_tween()
	tween.set_loops()
	tween.tween_property(self, "scale", Vector2(1.18, 1.18), 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)


func _draw() -> void:
	# Glow halo (magnetic pull).
	draw_circle(Vector2.ZERO, 9.0, Color(GLOW.r, GLOW.g, GLOW.b, 0.28))
	# Horseshoe magnet body: top bar + two legs.
	draw_circle(Vector2(0, -1.5), 5.0, STEEL)                 # top arc base
	draw_rect(Rect2(-6.5, -1.0, 3.2, 8.0), POLE_N)            # left leg (N)
	draw_rect(Rect2(3.3, -1.0, 3.2, 8.0), POLE_S)             # right leg (S)
	draw_rect(Rect2(-4.2, -6.5, 8.4, 3.4), STEEL)             # top bar
	# White tip caps.
	draw_rect(Rect2(-6.5, 5.6, 3.2, 1.4), Color(1, 1, 1, 0.9))
	draw_rect(Rect2(3.3, 5.6, 3.2, 1.4), Color(1, 1, 1, 0.9))


## On pickup, pull every XP orb + gold coin still on the floor to the player,
## exactly like the room-clear sweep.
func _on_body_entered(body: Node2D) -> void:
	if _collected:
		return
	if not body.is_in_group("player"):
		return
	_collected = true
	if body.has_method("roll_pickup_gluttony"):
		body.roll_pickup_gluttony()
	var player: Node2D = body as Node2D
	var tree := get_tree()
	if tree != null:
		for orb in tree.get_nodes_in_group("xp_orbs"):
			if is_instance_valid(orb) and orb.has_method("start_attraction"):
				orb.start_attraction(player)
		for coin in tree.get_nodes_in_group("gold_pickups"):
			if is_instance_valid(coin) and coin.has_method("start_attraction"):
				coin.start_attraction(player)
	queue_free()
