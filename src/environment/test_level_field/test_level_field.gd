class_name TestLevelField
extends Area2D

## A test-map field that grants one free team level when the player touches it,
## ignoring the XP cost. After firing it goes on a short internal cooldown so the
## player can walk away before it can "unintentionally" grant another level.

@export var radius: float = 40.0
@export var cooldown_seconds: float = 1.0
@export var _draw_dim: Color = Color(0.2, 0.9, 0.4, 0.35)
@export var _draw_ready: Color = Color(0.3, 1.0, 0.5, 0.6)

var _on_cooldown_timer: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	queue_redraw()


func _process(delta: float) -> void:
	if _on_cooldown_timer > 0.0:
		_on_cooldown_timer = maxf(0.0, _on_cooldown_timer - delta)
		queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if _on_cooldown_timer > 0.0:
		return
	if not body.is_in_group("player"):
		return
	var mgr: Node = get_tree().get_first_node_in_group("team_xp_manager")
	if mgr and mgr.has_method("add_free_level"):
		mgr.add_free_level()
		_on_cooldown_timer = cooldown_seconds
		queue_redraw()


func _draw() -> void:
	var col := _draw_ready if _on_cooldown_timer <= 0.0 else _draw_dim
	draw_circle(Vector2.ZERO, radius, col)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(0.7, 1.0, 0.8, 0.9), 2.0)
	# A small "plus" glyph to read as "level up".
	draw_line(Vector2(-8, 0), Vector2(8, 0), Color(1, 1, 1, 0.9), 3.0)
	draw_line(Vector2(0, -8), Vector2(0, 8), Color(1, 1, 1, 0.9), 3.0)
